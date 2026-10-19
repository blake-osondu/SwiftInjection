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
    public static func compile(source: String, fileName: String = "Screen.swift", version: String? = nil) -> CompileResult {
        let tree = Parser.parse(source: source)
        let context = CompilerContext(fileName: fileName, tree: tree)

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
    case int, double, string, bool, array(ValueType), dictionary, unknown

    var isNumber: Bool { self == .int || self == .double }

    var description: String {
        switch self {
        case .int: return "Int"
        case .double: return "Double"
        case .string: return "String"
        case .bool: return "Bool"
        case .array(let element): return "[\(element)]"
        case .dictionary: return "Dictionary"
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
        let views = file.statements.compactMap { $0.item.as(StructDeclSyntax.self) }.filter(conformsToView)
        guard let screen = views.first else {
            error("No `struct …: View` found to compile", at: file)
            return nil
        }
        for extra in views.dropFirst() {
            error("Only one View per file is supported in v1 (helper views come in v2): move '\(extra.name.text)' to its own file", at: extra.name)
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
                error("Only @State properties are supported in v1; '\(name)' isn't one", at: variable)
            }
        }
        guard let body else {
            error("'\(screen.name.text)' has no `body`", at: screen.name)
            return nil
        }
        guard let root = viewBody(body) else { return nil }
        return InjectedPayload(schemaVersion: .current, version: version, state: .object(initialState), body: root)
    }

    private func conformsToView(_ decl: StructDeclSyntax) -> Bool {
        decl.inheritanceClause?.inheritedTypes.contains { $0.type.trimmedDescription == "View" } ?? false
    }

    private func isState(_ variable: VariableDeclSyntax) -> Bool {
        variable.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "State"
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
        case (.double, .int), (_, .unknown): return true
        case let (.array(a), .array(b)): return a == .unknown || b == .unknown || compatible(a, b)
        default: return declared == actual
        }
    }

    func valueType(of type: TypeSyntax) -> ValueType {
        if let array = type.as(ArrayTypeSyntax.self) {
            return .array(valueType(of: array.element))
        }
        if type.is(DictionaryTypeSyntax.self) { return .dictionary }
        switch type.trimmedDescription {
        case "Int": return .int
        case "Double", "CGFloat", "Float": return .double
        case "String": return .string
        case "Bool": return .bool
        default: return .unknown
        }
    }
}
