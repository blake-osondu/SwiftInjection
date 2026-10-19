//
//  ViewCompiler.swift
//  SwiftInjectionCompiler
//

import SwiftSyntax
import SwiftInjectionCore

/// The arguments of a call: labeled and unlabeled, plus trailing closures.
struct Arguments {
    let call: FunctionCallExprSyntax?
    var labeled: [String: ExprSyntax] = [:]
    var unlabeled: [ExprSyntax] = []
    var trailing: ClosureExprSyntax?
    var additionalTrailing: [String: ClosureExprSyntax] = [:]

    init(_ call: FunctionCallExprSyntax?) {
        self.call = call
        guard let call else { return }
        for argument in call.arguments {
            if let label = argument.label?.text { labeled[label] = argument.expression } else { unlabeled.append(argument.expression) }
        }
        trailing = call.trailingClosure
        for closure in call.additionalTrailingClosures {
            additionalTrailing[closure.label.text] = closure.closure
        }
    }

    func closure(_ label: String) -> ClosureExprSyntax? {
        labeled[label]?.as(ClosureExprSyntax.self) ?? additionalTrailing[label]
    }
}

extension CompilerContext {

    // MARK: - View lists

    /// The body: one view, or several (rendered like SwiftUI's implicit group).
    func viewBody(_ statements: CodeBlockItemListSyntax) -> InjectedView? {
        viewList(statements).map(single)
    }

    func single(_ views: [InjectedView]) -> InjectedView {
        switch views.count {
        case 0: return .empty()
        case 1: return views[0]
        default: return .group(viewStore: GroupViewStore(children: views))
        }
    }

    func viewList(_ statements: CodeBlockItemListSyntax) -> [InjectedView]? {
        var views: [InjectedView] = []
        var failed = false
        for statement in statements {
            var syntax: ExprSyntax?
            switch statement.item {
            case .expr(let expr): syntax = expr
            case .stmt(let stmt): syntax = stmt.as(ExpressionStmtSyntax.self)?.expression
            case .decl: syntax = nil
            }
            guard let syntax else {
                error("Only views and `if` are supported inside a view builder", at: statement)
                failed = true
                continue
            }
            let compiled = syntax.as(IfExprSyntax.self).map(ifView) ?? view(syntax)
            if let compiled { views.append(compiled) } else { failed = true }
        }
        return failed ? nil : views
    }

    func children(_ closure: ClosureExprSyntax?) -> [InjectedView]? {
        guard let closure else { return [] }
        return viewList(closure.statements)
    }

    private func ifView(_ ifExpr: IfExprSyntax) -> InjectedView? {
        guard let condition = condition(ifExpr.conditions), let then = viewList(ifExpr.body.statements) else { return nil }
        var otherwise: InjectedView?
        switch ifExpr.elseBody {
        case .ifExpr(let elseIf)?:
            guard let nested = ifView(elseIf) else { return nil }
            otherwise = nested
        case .codeBlock(let block)?:
            guard let views = viewList(block.statements) else { return nil }
            otherwise = single(views)
        case nil:
            break
        }
        return .if(viewStore: IfViewStore(condition: condition, then: single(then), otherwise: otherwise))
    }

    // MARK: - Views

    /// A view expression with its modifier chain, e.g. `Text("Hi").padding().bold()`.
    func view(_ syntax: ExprSyntax) -> InjectedView? {
        var calls: [(name: String, call: FunctionCallExprSyntax)] = []
        var current = syntax
        while let call = current.as(FunctionCallExprSyntax.self),
              let member = call.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base {
            calls.insert((member.declName.baseName.text, call), at: 0)
            current = base
        }
        // Check the modifiers even if the base view failed, so every problem is reported in one pass.
        let base = baseView(current)
        var modifiers: [InjectedModifier] = []
        var failed = false
        for (name, call) in calls {
            if let modifier = modifier(name, Arguments(call), at: call) { modifiers.append(modifier) } else { failed = true }
        }
        guard var view = base, !failed else { return nil }
        view.modifiers = modifiers
        return view
    }

    private func baseView(_ syntax: ExprSyntax) -> InjectedView? {
        if let color = color(syntax, reportErrors: false) {
            return .color(viewStore: ColorViewStore(color: color))
        }
        guard let call = syntax.as(FunctionCallExprSyntax.self),
              let name = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else {
            error("Expected a view, found '\(syntax.trimmedDescription)'", at: syntax)
            return nil
        }
        let args = Arguments(call)
        switch name {
        case "Text":
            guard let value = args.unlabeled.first ?? args.labeled["verbatim"], let typed = expression(value) else {
                if args.unlabeled.isEmpty && args.labeled["verbatim"] == nil { error("Text needs a string", at: call) }
                return nil
            }
            return .text(viewStore: TextViewStore(value: typed.expression))
        case "Image":
            if let systemName = args.labeled["systemName"] {
                return expression(systemName).map { .image(viewStore: ImageViewStore(systemName: $0.expression)) }
            }
            guard let imageName = args.unlabeled.first else {
                error("Supported images: Image(\"name\") and Image(systemName:)", at: call)
                return nil
            }
            return expression(imageName).map { .image(viewStore: ImageViewStore(name: $0.expression)) }
        case "Label":
            guard let title = args.unlabeled.first.flatMap(expression) else {
                error("Supported labels: Label(\"Title\", systemImage: \"…\") and Label(\"Title\", image: \"…\")", at: call)
                return nil
            }
            let systemImage = args.labeled["systemImage"].flatMap(expression)
            let image = args.labeled["image"].flatMap(expression)
            return .label(viewStore: LabelViewStore(title: title.expression, systemImage: systemImage?.expression, image: image?.expression))
        case "Button":
            return button(args, at: call)
        case "Spacer":
            let minLength = args.labeled["minLength"].flatMap(number)
            return .spacer(viewStore: SpacerViewStore(minLength: minLength))
        case "Divider":
            return .divider(viewStore: DividerViewStore())
        case "EmptyView":
            return .empty()
        case "Rectangle":
            return .rectangle(viewStore: RectangleViewStore())
        case "Circle":
            return .circle(viewStore: CircleViewStore())
        case "Ellipse":
            return .ellipse(viewStore: EllipseViewStore())
        case "Capsule":
            let style = args.labeled["style"].flatMap { option($0, InjectedRoundedCornerStyle.self, "style") }
            return .capsule(viewStore: CapsuleViewStore(style: style))
        case "RoundedRectangle":
            guard let radius = args.labeled["cornerRadius"].flatMap(number) else {
                error("Supported: RoundedRectangle(cornerRadius:style:)", at: call)
                return nil
            }
            let style = args.labeled["style"].flatMap { option($0, InjectedRoundedCornerStyle.self, "style") }
            return .roundedRectangle(viewStore: RoundedRectangleViewStore(cornerRadius: radius, style: style))
        case "VStack", "LazyVStack":
            guard let children = children(args.trailing) else { return nil }
            let alignment = args.labeled["alignment"].flatMap { option($0, InjectedHorizontalAlignment.self, "alignment") }
            let spacing = args.labeled["spacing"].flatMap(number)
            let store = VStackViewStore(alignment: alignment, spacing: spacing, children: children)
            return name == "VStack" ? .vStack(viewStore: store) : .lazyVStack(viewStore: store)
        case "HStack", "LazyHStack":
            guard let children = children(args.trailing) else { return nil }
            let alignment = args.labeled["alignment"].flatMap { option($0, InjectedVerticalAlignment.self, "alignment") }
            let spacing = args.labeled["spacing"].flatMap(number)
            let store = HStackViewStore(alignment: alignment, spacing: spacing, children: children)
            return name == "HStack" ? .hStack(viewStore: store) : .lazyHStack(viewStore: store)
        case "ZStack":
            guard let children = children(args.trailing) else { return nil }
            let alignment = args.labeled["alignment"].flatMap { option($0, InjectedAlignment.self, "alignment") }
            return .zStack(viewStore: ZStackViewStore(alignment: alignment, children: children))
        case "Group":
            return children(args.trailing).map { .group(viewStore: GroupViewStore(children: $0)) }
        case "Form":
            return children(args.trailing).map { .form(viewStore: FormViewStore(children: $0)) }
        case "NavigationStack":
            return children(args.trailing).map { .navigationStack(viewStore: NavigationStackViewStore(root: single($0))) }
        case "ScrollView":
            guard let children = children(args.trailing) else { return nil }
            var axes: InjectedAxes?
            if let axisArgument = args.unlabeled.first {
                guard let parsed = scrollAxes(axisArgument) else { return nil }
                axes = parsed
            }
            let indicators = args.labeled["showsIndicators"].flatMap { boolean($0, "showsIndicators") }
            return .scrollView(viewStore: ScrollViewStore(axes: axes, showsIndicators: indicators, children: children))
        case "Section":
            guard let children = children(args.trailing ?? args.closure("content")) else { return nil }
            let title = args.unlabeled.first.flatMap(expression)?.expression
            let header = args.closure("header").flatMap { self.children($0) }.map(single) ?? args.labeled["header"].flatMap(view)
            let footer = args.closure("footer").flatMap { self.children($0) }.map(single) ?? args.labeled["footer"].flatMap(view)
            return .section(viewStore: SectionViewStore(title: title, header: header, footer: footer, children: children))
        default:
            error("'\(name)' isn't supported in v1 (supported: Text, Image, Label, Button, Color, shapes, Spacer, Divider, stacks, Group, Form, Section, ScrollView, NavigationStack)", at: call.calledExpression)
            return nil
        }
    }

    private func button(_ args: Arguments, at call: FunctionCallExprSyntax) -> InjectedView? {
        // Button("Title") { action } · Button("Title", action: {…}) · Button { action } label: { … } · Button(action: {…}) { label }
        let title = args.unlabeled.first
        let actionClosure: ClosureExprSyntax?
        let labelClosure: ClosureExprSyntax?
        if let action = args.closure("action") {
            actionClosure = action
            labelClosure = args.additionalTrailing["label"] ?? (title == nil ? args.trailing : nil)
        } else {
            actionClosure = args.trailing
            labelClosure = args.additionalTrailing["label"]
        }
        guard let actionClosure else {
            error("Button needs an action closure", at: call)
            return nil
        }
        guard let actions = actions(actionClosure) else { return nil }
        let role = args.labeled["role"].flatMap { option($0, InjectedButtonRole.self, "role") }
        if args.labeled["role"] != nil && role == nil { return nil }
        let roleValue = role.flatMap { expr -> InjectedButtonRole? in
            if case .literal(.string(let raw)) = expr { return InjectedButtonRole(rawValue: raw) }
            return nil
        }
        if let labelClosure {
            guard let views = viewList(labelClosure.statements) else { return nil }
            return .button(viewStore: ButtonViewStore(label: single(views), role: roleValue, action: actions))
        }
        guard let title, let typed = expression(title) else {
            if title == nil { error("Button needs a title or a label", at: call) }
            return nil
        }
        return .button(viewStore: ButtonViewStore(title: typed.expression, role: roleValue, action: actions))
    }

    private func scrollAxes(_ syntax: ExprSyntax) -> InjectedAxes? {
        if let array = syntax.as(ArrayExprSyntax.self) {
            let names = Set(array.elements.compactMap { $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text })
            if names == ["horizontal", "vertical"] { return .both }
        } else if let name = syntax.as(MemberAccessExprSyntax.self)?.declName.baseName.text, let axes = InjectedAxes(rawValue: name) {
            return axes
        }
        error("ScrollView axes must be .vertical, .horizontal or [.horizontal, .vertical]", at: syntax)
        return nil
    }

    // MARK: - Argument helpers

    func number(_ syntax: ExprSyntax) -> InjectedExpression? {
        guard let typed = expression(syntax), expectNumber(typed, for: "this argument", at: syntax) else { return nil }
        return typed.expression
    }

    /// A size: a number, or `.infinity` (→ `"infinity"`).
    func dimension(_ syntax: ExprSyntax) -> InjectedExpression? {
        if syntax.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "infinity" {
            return .literal(.string("infinity"))
        }
        return number(syntax)
    }

    func boolean(_ syntax: ExprSyntax, _ what: String) -> InjectedExpression? {
        guard let typed = expression(syntax), expect(typed, .bool, for: what, at: syntax) else { return nil }
        return typed.expression
    }

    /// An option written as `.name` (or `Type.name`), checked against the runtime's enum.
    func option<T: RawRepresentable>(_ syntax: ExprSyntax, _ type: T.Type, _ what: String) -> InjectedExpression? where T.RawValue == String {
        guard let member = syntax.as(MemberAccessExprSyntax.self) else {
            error("\(what) must be written as an option like `.name`", at: syntax)
            return nil
        }
        let name = member.declName.baseName.text
        guard T(rawValue: name) != nil else {
            error("'.\(name)' isn't a supported \(what)", at: member)
            return nil
        }
        return .literal(.string(name))
    }
}
