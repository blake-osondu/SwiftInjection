//
//  ExpressionCompiler.swift
//  SwiftInjectionCompiler
//

import SwiftSyntax
import SwiftInjectionCore

extension CompilerContext {
    /// Compiles a Swift expression over `@State` properties. Reports and returns nil if unsupported.
    func expression(_ syntax: ExprSyntax) -> Typed? {
        if let integer = syntax.as(IntegerLiteralExprSyntax.self) {
            guard let value = Int(integer.literal.text.replacingOccurrences(of: "_", with: "")) else {
                error("Unsupported integer literal '\(integer.literal.text)'", at: integer)
                return nil
            }
            return Typed(expression: .literal(.number(Double(value))), type: .int)
        }
        if let float = syntax.as(FloatLiteralExprSyntax.self) {
            guard let value = Double(float.literal.text.replacingOccurrences(of: "_", with: "")) else {
                error("Unsupported number literal '\(float.literal.text)'", at: float)
                return nil
            }
            return Typed(expression: .literal(.number(value)), type: .double)
        }
        if let boolean = syntax.as(BooleanLiteralExprSyntax.self) {
            return Typed(expression: .literal(.bool(boolean.literal.tokenKind == .keyword(.true))), type: .bool)
        }
        if syntax.is(NilLiteralExprSyntax.self) {
            return Typed(expression: .literal(.null), type: .unknown)
        }
        if let string = syntax.as(StringLiteralExprSyntax.self) {
            return stringLiteral(string)
        }
        if let reference = syntax.as(DeclReferenceExprSyntax.self) {
            return stateReference(reference.baseName.text, at: reference)
        }
        if let member = syntax.as(MemberAccessExprSyntax.self) {
            return memberAccess(member)
        }
        if let subscriptCall = syntax.as(SubscriptCallExprSyntax.self) {
            return subscriptAccess(subscriptCall)
        }
        if let infix = syntax.as(InfixOperatorExprSyntax.self) {
            return infixOperation(infix)
        }
        if let prefix = syntax.as(PrefixOperatorExprSyntax.self) {
            guard let operand = expression(prefix.expression) else { return nil }
            switch prefix.operator.text {
            case "!":
                guard expect(operand, .bool, for: "!", at: prefix) else { return nil }
                return Typed(expression: .operation(.not, [operand.expression]), type: .bool)
            case "-":
                guard expectNumber(operand, for: "-", at: prefix) else { return nil }
                if case .literal(.number(let value)) = operand.expression {
                    return Typed(expression: .literal(.number(-value)), type: operand.type)
                }
                return Typed(expression: .operation(.sub, [operand.expression]), type: operand.type)
            default:
                error("Unsupported operator '\(prefix.operator.text)'", at: prefix)
                return nil
            }
        }
        if let ternary = syntax.as(TernaryExprSyntax.self) {
            guard let condition = expression(ternary.condition), let then = expression(ternary.thenExpression),
                  let otherwise = expression(ternary.elseExpression) else { return nil }
            guard expect(condition, .bool, for: "?:", at: ternary.condition) else { return nil }
            return Typed(expression: .operation(.if, [condition.expression, then.expression, otherwise.expression]),
                         type: then.type == otherwise.type ? then.type : .unknown)
        }
        if let cast = syntax.as(AsExprSyntax.self) {
            // `[…] as [String: Any]` is how Swift spells mixed-type literals; the cast only informs the type.
            guard var typed = expression(cast.expression) else { return nil }
            let castType = valueType(of: cast.type)
            if castType != .unknown { typed.type = castType }
            return typed
        }
        if let tuple = syntax.as(TupleExprSyntax.self), tuple.elements.count == 1, let inner = tuple.elements.first {
            return expression(inner.expression)
        }
        if let array = syntax.as(ArrayExprSyntax.self) {
            var elements: [InjectedExpression] = []
            var elementType: ValueType?
            for element in array.elements {
                guard let typed = expression(element.expression) else { return nil }
                elements.append(typed.expression)
                elementType = elementType.map { $0 == typed.type ? $0 : .unknown } ?? typed.type
            }
            return Typed(expression: .array(elements), type: .array(elementType ?? .unknown))
        }
        if let dictionary = syntax.as(DictionaryExprSyntax.self) {
            var fields: [String: InjectedExpression] = [:]
            if case .elements(let elements) = dictionary.content {
                for element in elements {
                    guard let key = element.key.as(StringLiteralExprSyntax.self), let keyText = plainText(key) else {
                        error("Dictionary keys must be string literals", at: element.key)
                        return nil
                    }
                    guard let value = expression(element.value) else { return nil }
                    fields[keyText] = value.expression
                }
            }
            return Typed(expression: .object(fields), type: .dictionary)
        }
        if let call = syntax.as(FunctionCallExprSyntax.self) {
            return conversion(call)
        }
        error("Unsupported expression '\(syntax.trimmedDescription)'", at: syntax)
        return nil
    }

    // MARK: - Pieces

    func plainText(_ string: StringLiteralExprSyntax) -> String? {
        var text = ""
        for segment in string.segments {
            guard let literal = segment.as(StringSegmentSyntax.self) else { return nil }
            text += literal.content.text
        }
        return text
    }

    private func stringLiteral(_ string: StringLiteralExprSyntax) -> Typed? {
        if let text = plainText(string) {
            return Typed(expression: .literal(.string(text)), type: .string)
        }
        var template = ""
        var arguments: [InjectedExpression] = []
        for segment in string.segments {
            if let literal = segment.as(StringSegmentSyntax.self) {
                template += literal.content.text
            } else if let interpolation = segment.as(ExpressionSegmentSyntax.self) {
                guard interpolation.expressions.count == 1, let inner = interpolation.expressions.first, inner.label == nil else {
                    error("Only plain `\\(value)` interpolation is supported", at: interpolation)
                    return nil
                }
                guard let typed = expression(inner.expression) else { return nil }
                template += "{\(arguments.count)}"
                arguments.append(typed.expression)
            }
        }
        return Typed(expression: .operation(.format, [.literal(.string(template))] + arguments), type: .string)
    }

    private func stateReference(_ name: String, at node: some SyntaxProtocol) -> Typed? {
        if name.hasPrefix("$") {
            error("'\(name)' is a binding; bindings can only be passed where SwiftUI expects one (text:, isOn:, selection:, …)", at: node)
            return nil
        }
        switch parameters[name] {
        case .value(let typed)?: return typed
        case let .binding(path, type)?: return Typed(expression: .var(path), type: type)
        case nil: break
        }
        if let type = locals[name] { return Typed(expression: .var(name), type: type) }
        guard let type = state[name] else {
            error("Unknown name '\(name)': expressions can use @State properties, ForEach items, view parameters and literals", at: node)
            return nil
        }
        return Typed(expression: .var(name), type: type)
    }

    /// The state path behind a binding argument: `$name`, `$todo.title`, or a `@Binding` parameter.
    func bindingPath(_ syntax: ExprSyntax) -> (path: String, type: ValueType)? {
        func resolve(_ syntax: ExprSyntax) -> (path: String, type: ValueType)? {
            if let reference = syntax.as(DeclReferenceExprSyntax.self) {
                let name = reference.baseName.text
                if name.hasPrefix("$") {
                    let root = String(name.dropFirst())
                    if case let .binding(path, type)? = parameters[root] { return (path, type) }
                    if let type = locals[root] { return (root, type) }
                    if let type = state[root] { return (root, type) }
                    error("Unknown binding '\(name)'", at: reference)
                    return nil
                }
                if case let .binding(path, type)? = parameters[name] { return (path, type) }
            } else if let member = syntax.as(MemberAccessExprSyntax.self), let base = member.base,
                      let (path, type) = resolve(base) {
                let field = member.declName.baseName.text
                var fieldType: ValueType = .unknown
                if case .model(let modelName) = type { fieldType = models[modelName]?.field(field)?.type ?? .unknown }
                return ("\(path).\(field)", fieldType)
            }
            error("Expected a binding like `$name` or `$item.field`", at: syntax)
            return nil
        }
        return resolve(syntax)
    }

    private func memberAccess(_ member: MemberAccessExprSyntax) -> Typed? {
        let name = member.declName.baseName.text
        guard let base = member.base else {
            error("'.\(name)' isn't supported here", at: member)
            return nil
        }
        if base.as(DeclReferenceExprSyntax.self)?.baseName.text == "self" {
            return stateReference(name, at: member)
        }
        guard let typed = expression(base) else { return nil }
        // Model fields (`todo.title`) stay paths, so they're readable and writable.
        if case .model(let modelName) = typed.type, let field = models[modelName]?.field(name),
           case let .variable(path, nil) = typed.expression {
            return Typed(expression: .var("\(path).\(name)"), type: field.type)
        }
        switch name {
        case "count":
            return Typed(expression: .operation(.count, [typed.expression]), type: .int)
        case "isEmpty":
            return Typed(expression: .operation(.eq, [.operation(.count, [typed.expression]), 0]), type: .bool)
        default:
            if case let .variable(path, nil) = typed.expression, typed.type == .unknown || typed.type == .dictionary {
                return Typed(expression: .var("\(path).\(name)"), type: .unknown)
            }
            error("'.\(name)' isn't supported (use model fields, `.count`, `.isEmpty`, or a subscript)", at: member.declName)
            return nil
        }
    }

    private func subscriptAccess(_ call: SubscriptCallExprSyntax) -> Typed? {
        guard call.arguments.count == 1, let argument = call.arguments.first else {
            error("Subscripts take one key or index", at: call)
            return nil
        }
        guard let base = expression(call.calledExpression), let key = expression(argument.expression) else { return nil }
        var elementType: ValueType = .unknown
        if case .array(let element) = base.type { elementType = element }
        // A literal key on a state path stays a path, so it's also writable (`user["name"] = …`).
        if case let .variable(path, nil) = base.expression, case .literal(let literal) = key.expression {
            switch literal {
            case .string(let text): return Typed(expression: .var("\(path).\(text)"), type: elementType)
            case .number(let index) where index >= 0 && index.rounded() == index:
                return Typed(expression: .var("\(path).\(Int(index))"), type: elementType)
            default: break
            }
        }
        return Typed(expression: .operation(.at, [base.expression, key.expression]), type: elementType)
    }

    private func conversion(_ call: FunctionCallExprSyntax) -> Typed? {
        let callee = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text
        if let callee, let model = models[callee] {
            return modelLiteral(model, call)
        }
        if callee == "script" {
            return scriptCall(call).map { Typed(expression: $0.expression, type: $0.type) }
        }
        if callee == "Date", call.arguments.isEmpty {
            // "Now": stored as null, which date pickers read as the current date.
            return Typed(expression: .literal(.null), type: .date)
        }
        if call.trimmedDescription == "UUID().uuidString" || callee == "UUID" {
            error("UUID() is only supported as a model field default (it becomes a fixed id)", at: call)
            return nil
        }
        guard let callee, call.arguments.count == 1, let argument = call.arguments.first, argument.label == nil,
              call.trailingClosure == nil else {
            error("Unsupported call '\(call.trimmedDescription)'", at: call)
            return nil
        }
        guard let value = expression(argument.expression) else { return nil }
        switch callee {
        case "String":
            return Typed(expression: .operation(.concat, [value.expression]), type: .string)
        case "Double", "CGFloat":
            guard expectNumber(value, for: callee, at: call) else { return nil }
            return Typed(expression: value.expression, type: .double)
        default:
            error("Unsupported call '\(callee)(…)'", at: call)
            return nil
        }
    }

    private func infixOperation(_ infix: InfixOperatorExprSyntax) -> Typed? {
        guard let op = infix.operator.as(BinaryOperatorExprSyntax.self)?.operator.text else {
            error("Assignments aren't expressions; use them inside an action closure", at: infix)
            return nil
        }
        guard let left = expression(infix.leftOperand), let right = expression(infix.rightOperand) else { return nil }
        return binary(op, left, right, at: infix)
    }

    /// `left op right`, shared with compound assignments (`+=`).
    func binary(_ op: String, _ left: Typed, _ right: Typed, at node: some SyntaxProtocol) -> Typed? {
        let numberType: ValueType = left.type == .double || right.type == .double ? .double : left.type == .unknown || right.type == .unknown ? .unknown : .int
        func arithmetic(_ operation: InjectedExpression.Operator) -> Typed? {
            guard expectNumber(left, for: op, at: node), expectNumber(right, for: op, at: node) else { return nil }
            return Typed(expression: .operation(operation, [left.expression, right.expression]), type: numberType)
        }
        func comparison(_ operation: InjectedExpression.Operator) -> Typed {
            Typed(expression: .operation(operation, [left.expression, right.expression]), type: .bool)
        }
        switch op {
        case "+":
            if left.type == .string || right.type == .string {
                return Typed(expression: .operation(.concat, [left.expression, right.expression]), type: .string)
            }
            return arithmetic(.add)
        case "-": return arithmetic(.sub)
        case "*": return arithmetic(.mul)
        case "/":
            if left.type == .int && right.type == .int {
                error("Integer division isn't supported (it would round differently at runtime); make one side a Double", at: node)
                return nil
            }
            return arithmetic(.div)
        case "%": return arithmetic(.mod)
        case "==": return comparison(.eq)
        case "!=": return comparison(.neq)
        case "<": return comparison(.lt)
        case "<=": return comparison(.lte)
        case ">": return comparison(.gt)
        case ">=": return comparison(.gte)
        case "&&", "||":
            guard expect(left, .bool, for: op, at: node), expect(right, .bool, for: op, at: node) else { return nil }
            return Typed(expression: .operation(op == "&&" ? .and : .or, [left.expression, right.expression]), type: .bool)
        default:
            error("Unsupported operator '\(op)'", at: node)
            return nil
        }
    }

    // MARK: - Type checks

    func expect(_ value: Typed, _ type: ValueType, for op: String, at node: some SyntaxProtocol) -> Bool {
        guard value.type == type || value.type == .unknown else {
            error("'\(op)' needs a \(type), got a \(value.type)", at: node)
            return false
        }
        return true
    }

    func expectNumber(_ value: Typed, for op: String, at node: some SyntaxProtocol) -> Bool {
        guard value.type.isNumber || value.type == .unknown else {
            error("'\(op)' needs a number, got a \(value.type)", at: node)
            return false
        }
        return true
    }

    // MARK: - Models and scripts

    /// `Todo(title: "Milk")` → `{"title": "Milk", "done": false}` using the memberwise initializer and defaults.
    private func modelLiteral(_ model: ModelType, _ call: FunctionCallExprSyntax) -> Typed? {
        var provided: [String: ExprSyntax] = [:]
        for argument in call.arguments {
            guard let label = argument.label?.text, model.field(label) != nil else {
                error("'\(model.name)' has no field '\(argument.label?.text ?? "_")'", at: argument)
                return nil
            }
            provided[label] = argument.expression
        }
        var fields: [String: InjectedExpression] = [:]
        for field in model.fields {
            if let argument = provided[field.name] {
                guard let typed = expression(argument) else { return nil }
                fields[field.name] = typed.expression
            } else if let defaultValue = field.defaultValue {
                if defaultValue.trimmedDescription == "UUID()" || defaultValue.trimmedDescription == "UUID().uuidString" {
                    fields[field.name] = .literal(.string(generatedID(for: model.name)))
                } else {
                    guard let typed = expression(defaultValue) else { return nil }
                    fields[field.name] = typed.expression
                }
            } else {
                error("Missing argument '\(field.name)' for '\(model.name)'", at: call)
                return nil
            }
        }
        return Typed(expression: .object(fields), type: .model(model.name))
    }

    /// `script("name", args…)` (from SwiftInjectionAuthoring) → `{"call": ["name", args…]}`.
    /// The result is a String unless `placeholder:` gives another type.
    func scriptCall(_ call: FunctionCallExprSyntax) -> (name: String, arguments: [InjectedExpression], expression: InjectedExpression, type: ValueType)? {
        guard let first = call.arguments.first, first.label == nil,
              let literal = first.expression.as(StringLiteralExprSyntax.self), let name = plainText(literal) else {
            error("The first argument of script(…) must be the function name as a string literal", at: call)
            return nil
        }
        var arguments: [InjectedExpression] = []
        var type: ValueType = .string
        for argument in call.arguments.dropFirst() {
            if argument.label?.text == "placeholder" {
                guard let placeholder = expression(argument.expression) else { return nil }
                type = placeholder.type
                continue
            }
            guard argument.label == nil, let typed = expression(argument.expression) else {
                if argument.label != nil { error("Unexpected argument label '\(argument.label!.text)'", at: argument) }
                return nil
            }
            arguments.append(typed.expression)
        }
        scriptsUsed.insert(name)
        return (name, arguments, .operation(.call, [.literal(.string(name))] + arguments), type)
    }
}
