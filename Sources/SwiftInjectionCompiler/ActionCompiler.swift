//
//  ActionCompiler.swift
//  SwiftInjectionCompiler
//

import SwiftSyntax
import SwiftInjectionCore

extension CompilerContext {
    /// Compiles the statements of an action closure (a button action, `onAppear`, `onTapGesture`).
    func actions(_ closure: ClosureExprSyntax) -> [InjectedAction]? {
        if let parameters = closure.signature?.parameterClause {
            error("Action closures take no parameters", at: parameters)
            return nil
        }
        return actions(closure.statements)
    }

    func actions(_ statements: CodeBlockItemListSyntax) -> [InjectedAction]? {
        var result: [InjectedAction] = []
        var failed = false
        for statement in statements {
            if let action = action(statement.item) {
                result.append(action)
            } else {
                failed = true
            }
        }
        return failed ? nil : result
    }

    private func action(_ item: CodeBlockItemSyntax.Item) -> InjectedAction? {
        let syntax: ExprSyntax
        switch item {
        case .expr(let expr):
            syntax = expr
        case .stmt(let stmt):
            guard let expr = stmt.as(ExpressionStmtSyntax.self)?.expression else {
                error("Unsupported statement in an action (v1 supports assignments, `+=`-style updates, `toggle()` and `if`)", at: stmt)
                return nil
            }
            syntax = expr
        case .decl(let decl):
            error("Declarations aren't supported in actions; assign @State properties directly", at: decl)
            return nil
        }

        if let ifExpr = syntax.as(IfExprSyntax.self) {
            return ifAction(ifExpr)
        }
        if let infix = syntax.as(InfixOperatorExprSyntax.self) {
            return assignment(infix)
        }
        if let call = syntax.as(FunctionCallExprSyntax.self), let member = call.calledExpression.as(MemberAccessExprSyntax.self),
           member.declName.baseName.text == "toggle", call.arguments.isEmpty, let base = member.base {
            guard let target = writablePath(base), let current = expression(base) else { return nil }
            guard expect(current, .bool, for: "toggle()", at: call) else { return nil }
            return .set(path: target, to: .operation(.not, [current.expression]))
        }
        error("Unsupported statement in an action: '\(syntax.trimmedDescription)'", at: syntax)
        return nil
    }

    private func assignment(_ infix: InfixOperatorExprSyntax) -> InjectedAction? {
        guard let target = writablePath(infix.leftOperand) else { return nil }
        if infix.operator.is(AssignmentExprSyntax.self) {
            guard let value = expression(infix.rightOperand) else { return nil }
            return .set(path: target, to: value.expression)
        }
        let op = infix.operator.as(BinaryOperatorExprSyntax.self)?.operator.text ?? ""
        guard ["+=", "-=", "*=", "/="].contains(op) else {
            error("Unsupported operator '\(op)' in an action", at: infix.operator)
            return nil
        }
        guard let current = expression(infix.leftOperand), let value = expression(infix.rightOperand),
              let updated = binary(String(op.dropLast()), current, value, at: infix) else { return nil }
        return .set(path: target, to: updated.expression)
    }

    private func ifAction(_ ifExpr: IfExprSyntax) -> InjectedAction? {
        guard let condition = condition(ifExpr.conditions), let then = actions(ifExpr.body.statements) else { return nil }
        var otherwise: [InjectedAction] = []
        switch ifExpr.elseBody {
        case .ifExpr(let elseIf)?:
            guard let nested = ifAction(elseIf) else { return nil }
            otherwise = [nested]
        case .codeBlock(let block)?:
            guard let compiled = actions(block.statements) else { return nil }
            otherwise = compiled
        case nil:
            break
        }
        return .if(condition, then: then, else: otherwise)
    }

    /// An `if` condition list; several conditions (`if a, b`) are combined with `and`.
    func condition(_ conditions: ConditionElementListSyntax) -> InjectedExpression? {
        var parts: [InjectedExpression] = []
        for element in conditions {
            guard case .expression(let expr) = element.condition else {
                error("Only boolean conditions are supported (no `if let` or `case` patterns in v1)", at: element)
                return nil
            }
            guard let typed = expression(expr), expect(typed, .bool, for: "if", at: expr) else { return nil }
            parts.append(typed.expression)
        }
        return parts.count == 1 ? parts[0] : .operation(.and, parts)
    }

    /// The state path an assignment writes to: `count`, `self.count`, `user["name"]`, `items[0]`.
    func writablePath(_ syntax: ExprSyntax) -> String? {
        guard let typed = expression(syntax) else { return nil }
        guard case let .variable(path, nil) = typed.expression else {
            error("Only @State properties (and literal subscripts of them) can be assigned", at: syntax)
            return nil
        }
        return path
    }
}
