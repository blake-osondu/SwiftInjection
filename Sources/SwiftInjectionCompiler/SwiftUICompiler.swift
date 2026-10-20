//
//  SwiftUICompiler.swift
//  SwiftInjectionCompiler
//

import Foundation
import SwiftSyntax
import SwiftParser
import SwiftOperators
import SwiftInjectionCore

/// A problem in the source, reported like a compiler diagnostic (`file:line:column: error: message`).
public struct CompilerDiagnostic: Error, Equatable, CustomStringConvertible {
    public enum Severity: String { case error, warning }

    public var file: String
    public var line: Int
    public var column: Int
    public var severity: Severity
    public var message: String

    public var description: String { "\(file):\(line):\(column): \(severity.rawValue): \(message)" }
}

public struct CompileResult {
    /// The compiled payload, or nil when there were errors.
    public var payload: InjectedPayload?
    public var diagnostics: [CompilerDiagnostic]
    public var errors: [CompilerDiagnostic] { diagnostics.filter { $0.severity == .error } }

    /// The payload as JSON with sorted keys, ready to sign and publish.
    public func json() throws -> Data? {
        guard let payload else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }
}

/// Compiles one SwiftUI `View` struct, written in a supported subset of Swift, into a payload.
///
/// The source is ordinary SwiftUI that also builds in Xcode (so Previews work). Supported in v1:
/// `@State` properties with literal initial values; the `body` view tree (text, images, labels, colors, shapes,
/// spacers, dividers, stacks, groups, forms, sections, scroll views, navigation stacks, buttons, `if`/`else`);
/// common modifiers; expressions over state (arithmetic, comparison, logic, ternaries, string interpolation);
/// and button/gesture actions (assignments, `+=`-style updates, `toggle()`, `if`/`else`).
///
/// Anything outside the subset produces a diagnostic at its location; the compiler never guesses.
public enum SwiftUICompiler {
    /// - Parameter scripts: JavaScript defining the functions the screen calls with `script(…)` / `runScript(…)`.
    public static func compile(source: String, fileName: String = "Screen.swift", version: String? = nil,
                               scripts: String? = nil) -> CompileResult {
        let tree = Parser.parse(source: source)
        let context = CompilerContext(fileName: fileName, tree: tree)
        context.scriptSource = scripts

        if tree.hasError {
            context.error("The file doesn't parse as Swift; fix the syntax errors Xcode reports first", at: tree)
            return CompileResult(payload: nil, diagnostics: context.diagnostics)
        }
        let folded = OperatorTable.standardOperators.foldAll(tree) { error in
            context.error("Can't resolve operator precedence: \(error)", at: tree)
        }.as(SourceFileSyntax.self) ?? tree

        let payload = context.compileFile(folded, version: version)
        guard context.diagnostics.allSatisfy({ $0.severity != .error }), let payload else {
            return CompileResult(payload: nil, diagnostics: context.diagnostics)
        }
        // The output must load in the app exactly as written.
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            _ = try PayloadValidator().validate(try encoder.encode(payload), signature: nil)
        } catch {
            context.error("Internal error: the compiled payload doesn't validate (\(error)). Please report this.", at: folded)
            return CompileResult(payload: nil, diagnostics: context.diagnostics)
        }
        return CompileResult(payload: payload, diagnostics: context.diagnostics)
    }
}

/// The value types the compiler tracks to choose operators (e.g. `+` as addition or concatenation).
indirect enum ValueType: Equatable, CustomStringConvertible {
    case int, double, string, bool, date, array(ValueType), dictionary, model(String), unknown

    var isNumber: Bool { self == .int || self == .double }

    var element: ValueType {
        if case .array(let element) = self { return element }
        return .unknown
    }

    var description: String {
        switch self {
        case .int: return "Int"
        case .double: return "Double"
        case .string: return "String"
        case .bool: return "Bool"
        case .array(let element): return "[\(element)]"
        case .dictionary: return "Dictionary"
        case .date: return "Date"
        case .model(let name): return name
        case .unknown: return "unknown"
        }
    }
}

struct Typed {
    var expression: InjectedExpression
    var type: ValueType
}

final class CompilerContext {
    let fileName: String
    let converter: SourceLocationConverter
    private(set) var diagnostics: [CompilerDiagnostic] = []
    /// `@State` properties and their types.
    var state: [String: ValueType] = [:]
    /// Names bound by `ForEach` / `List` closures (`todo` in `ForEach(todos) { todo in … }`).
    var locals: [String: ValueType] = [:]
    /// Parameters of the helper view being inlined.
    var parameters: [String: Parameter] = [:]
    /// Non-View structs, used as model types in state.
    var models: [String: ModelType] = [:]
    /// View structs other than the screen, compiled on use.
    var helpers: [String: StructDeclSyntax] = [:]
    /// Parameterless helpers compiled to shared views (`{"ref": name}`).
    var namedViews: [String: InjectedView] = [:]
    /// Helpers being compiled, to stop recursion.
    var helperStack: [String] = []
    /// Synthesized state (e.g. static picker options).
    var syntheticState: [String: RuntimeValue] = [:]
    var scriptSource: String?
    var scriptsUsed: Set<String> = []
    private var generatedIDs = 0

    enum Parameter {
        case value(Typed)
        case binding(path: String, type: ValueType)
    }

    struct ModelType {
        struct Field {
            let name: String
            let type: ValueType
            let defaultValue: ExprSyntax?
        }
        let name: String
        let fields: [Field]
        var hasID: Bool { fields.contains { $0.name == "id" } }
        func field(_ name: String) -> Field? { fields.first { $0.name == name } }
    }

    /// A deterministic stand-in for `UUID()` in model defaults, so output is reproducible.
    func generatedID(for model: String) -> String {
        generatedIDs += 1
        return "\(model)-\(generatedIDs)"
    }

    init(fileName: String, tree: SourceFileSyntax) {
        self.fileName = fileName
        self.converter = SourceLocationConverter(fileName: fileName, tree: tree)
    }

    func error(_ message: String, at node: some SyntaxProtocol) {
        report(.error, message, at: node)
    }

    func warning(_ message: String, at node: some SyntaxProtocol) {
        report(.warning, message, at: node)
    }

    private func report(_ severity: CompilerDiagnostic.Severity, _ message: String, at node: some SyntaxProtocol) {
        let location = node.startLocation(converter: converter)
        diagnostics.append(CompilerDiagnostic(file: fileName, line: location.line, column: location.column,
                                              severity: severity, message: message))
    }

    // MARK: - File

    func compileFile(_ file: SourceFileSyntax, version: String?) -> InjectedPayload? {
        let structs = file.statements.compactMap { $0.item.as(StructDeclSyntax.self) }
        let views = structs.filter(conformsToView)
        for model in structs where !conformsToView(model) {
            models[model.name.text] = modelType(model)
        }
        // The screen is the view named after the file (Counter.swift → Counter), else the one with @State, else the
        // first; the rest are helper views.
        let fileBaseName = (fileName as NSString).lastPathComponent.components(separatedBy: ".").first ?? ""
        let screenCandidate = views.first { $0.name.text == fileBaseName }
            ?? views.first { $0.memberBlock.members.contains { isState($0.decl.as(VariableDeclSyntax.self)) } }
            ?? views.first
        guard let screen = screenCandidate else {
            error("No `struct …: View` found to compile", at: file)
            return nil
        }
        for helper in views where helper.name.text != screen.name.text {
            helpers[helper.name.text] = helper
        }

        var initialState: [String: RuntimeValue] = [:]
        var body: CodeBlockItemListSyntax?
        for member in screen.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self), let binding = variable.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
            if name == "body" {
                if case .getter(let statements)? = binding.accessorBlock?.accessors {
                    body = statements
                } else {
                    error("`body` must be a computed property: `var body: some View { … }`", at: binding)
                }
            } else if isState(variable) {
                if let value = compileState(name: name, binding: binding) {
                    initialState[name] = value
                }
            } else {
                error("The screen's properties must be @State; '\(name)' isn't (pass values into helper views instead)", at: variable)
            }
        }
        guard let body else {
            error("'\(screen.name.text)' has no `body`", at: screen.name)
            return nil
        }
        guard let root = viewBody(body) else { return nil }
        for (key, value) in syntheticState { initialState[key] = value }
        let compiledScripts = compileScripts(at: screen.name)
        return InjectedPayload(schemaVersion: .current, version: version, state: .object(initialState), body: root,
                               views: namedViews, scripts: compiledScripts)
    }

    /// Each used script becomes a function expression evaluating the whole script file, so helpers in it work.
    private func compileScripts(at node: some SyntaxProtocol) -> [String: String] {
        guard !scriptsUsed.isEmpty else { return [:] }
        guard let source = scriptSource else {
            error("The screen calls scripts (\(scriptsUsed.sorted().joined(separator: ", "))) but no script file was given; pass --scripts or add <Screen>.scripts.js", at: node)
            return [:]
        }
        var scripts: [String: String] = [:]
        for name in scriptsUsed.sorted() {
            let pattern = "\\b(function\\s+\(name)\\b|(const|let|var)\\s+\(name)\\s*=)"
            guard source.range(of: pattern, options: .regularExpression) != nil else {
                error("Script '\(name)' isn't defined in the script file (expected `function \(name)(…)` or `const \(name) = …`)", at: node)
                continue
            }
            scripts[name] = "(function () {\n\(source)\nreturn \(name);\n})()"
        }
        return scripts
    }

    private func modelType(_ decl: StructDeclSyntax) -> ModelType {
        var fields: [ModelType.Field] = []
        for member in decl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings where binding.accessorBlock == nil {
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
                let type = binding.typeAnnotation.map { valueType(of: $0.type) } ?? .unknown
                fields.append(.init(name: name, type: type, defaultValue: binding.initializer?.value))
            }
        }
        return ModelType(name: decl.name.text, fields: fields)
    }

    private func conformsToView(_ decl: StructDeclSyntax) -> Bool {
        decl.inheritanceClause?.inheritedTypes.contains { $0.type.trimmedDescription == "View" } ?? false
    }

    func isState(_ variable: VariableDeclSyntax?) -> Bool {
        hasAttribute("State", variable)
    }

    func hasAttribute(_ name: String, _ variable: VariableDeclSyntax?) -> Bool {
        guard let variable else { return false }
        return variable.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name
        }
    }

    // MARK: - State

    private func compileState(name: String, binding: PatternBindingSyntax) -> RuntimeValue? {
        guard let initializer = binding.initializer?.value else {
            error("@State '\(name)' needs an initial value", at: binding)
            return nil
        }
        // Initial values may not refer to other state.
        let saved = state
        state = [:]
        let typed = expression(initializer)
        state = saved
        guard let typed else { return nil }

        let declared = binding.typeAnnotation.map { valueType(of: $0.type) }
        var type = declared ?? typed.type
        if declared == .double, typed.type == .int { type = .double }
        if let declared, declared != .unknown, !compatible(declared, typed.type) {
            error("'\(name)' is declared \(declared) but initialized with a \(typed.type)", at: initializer)
            return nil
        }
        do {
            let value = try ExpressionEvaluator().evaluate(typed.expression, in: RuntimeValue.object([:]))
            state[name] = type
            return value
        } catch {
            self.error("@State initial values must be literals (numbers, strings, booleans, arrays and dictionaries of those)", at: initializer)
            return nil
        }
    }

    private func compatible(_ declared: ValueType, _ actual: ValueType) -> Bool {
        switch (declared, actual) {
        case (.double, .int), (_, .unknown), (.unknown, _): return true
        case let (.array(a), .array(b)): return a == .unknown || b == .unknown || compatible(a, b)
        default: return declared == actual
        }
    }

    func valueType(of type: TypeSyntax) -> ValueType {
        if let array = type.as(ArrayTypeSyntax.self) {
            return .array(valueType(of: array.element))
        }
        if type.is(DictionaryTypeSyntax.self) { return .dictionary }
        if let optional = type.as(OptionalTypeSyntax.self) { return valueType(of: optional.wrappedType) }
        let name = type.trimmedDescription
        if models[name] != nil { return .model(name) }
        switch name {
        case "Int": return .int
        case "Double", "CGFloat", "Float": return .double
        case "String": return .string
        case "Bool": return .bool
        case "Date": return .date
        default: return .unknown
        }
    }
}
