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
        // Inlined helper views bring their own modifiers; the call site's apply after them.
        view.modifiers += modifiers
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
            guard let value = args.unlabeled.first ?? args.labeled["verbatim"], var typed = expression(value) else {
                if args.unlabeled.isEmpty && args.labeled["verbatim"] == nil { error("Text needs a string", at: call) }
                return nil
            }
            // Text(price, format: .currency(code: "USD"))
            if let style = args.labeled["format"] {
                guard let formatted = formatted(typed, style: style) else { return nil }
                typed = formatted
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
        case "TabView":
            guard var pages = children(args.trailing ?? args.closure("content")) else { return nil }
            var selection: String?
            if let argument = args.labeled["selection"] {
                guard let path = bindingPath(argument) else { return nil }
                selection = path.path
            }
            // Tabs are identified by position, so `.tag(n)` on a page must be its index; it's dropped.
            for index in pages.indices {
                var failed = false
                pages[index].modifiers.removeAll { modifier in
                    guard case .tag(let value) = modifier else { return false }
                    if value != .literal(.number(Double(index))) { failed = true }
                    return true
                }
                if failed {
                    error("TabView pages are identified by position: page \(index) must have `.tag(\(index))` or no tag", at: call)
                    return nil
                }
                if case .forEach = pages[index] {
                    error("ForEach inside TabView isn't supported; list the pages (helper views keep this short)", at: call)
                    return nil
                }
            }
            return .tab(viewStore: TabViewStore(selection: selection, children: pages))
        case "LazyVGrid", "LazyHGrid":
            let itemsLabel = name == "LazyVGrid" ? "columns" : "rows"
            guard let itemsSyntax = args.labeled[itemsLabel] else {
                error("\(name) needs `\(itemsLabel):`", at: call)
                return nil
            }
            guard let items = gridItems(itemsSyntax), let children = children(args.trailing) else { return nil }
            let spacing = args.labeled["spacing"].flatMap(number)
            if name == "LazyVGrid" {
                let alignment = args.labeled["alignment"].flatMap { option($0, InjectedHorizontalAlignment.self, "alignment") }
                return .lazyVGrid(viewStore: LazyVGridViewStore(columns: items, alignment: alignment, spacing: spacing, children: children))
            }
            let alignment = args.labeled["alignment"].flatMap { option($0, InjectedVerticalAlignment.self, "alignment") }
            return .lazyHGrid(viewStore: LazyHGridViewStore(rows: items, alignment: alignment, spacing: spacing, children: children))
        case "Grid":
            guard let children = children(args.trailing) else { return nil }
            let alignment = args.labeled["alignment"].flatMap { option($0, InjectedAlignment.self, "alignment") }
            return .grid(viewStore: GridViewStore(alignment: alignment, horizontalSpacing: args.labeled["horizontalSpacing"].flatMap(number),
                                                  verticalSpacing: args.labeled["verticalSpacing"].flatMap(number), children: children))
        case "GridRow":
            guard let children = children(args.trailing) else { return nil }
            let alignment = args.labeled["alignment"].flatMap { option($0, InjectedVerticalAlignment.self, "alignment") }
            return .gridRow(viewStore: GridRowViewStore(alignment: alignment, children: children))
        case "NavigationLink":
            // NavigationLink("Title") { destination } · NavigationLink { destination } label: { … }
            guard let destinationClosure = args.closure("destination") ?? args.trailing,
                  let destination = viewList(destinationClosure.statements).map(single) else {
                if args.closure("destination") == nil && args.trailing == nil { error("NavigationLink needs a destination closure", at: call) }
                return nil
            }
            let label: InjectedView
            if let labelClosure = args.closure("label") {
                guard let views = viewList(labelClosure.statements) else { return nil }
                label = single(views)
            } else if let title = args.unlabeled.first, let typed = expression(title) {
                label = .text(viewStore: TextViewStore(value: typed.expression))
            } else {
                error("NavigationLink needs a title or a label", at: call)
                return nil
            }
            return .navigationLink(viewStore: NavigationLinkViewStore(destination: destination, label: label))
        case "ForEach":
            return dataSource(args, at: call).map {
                .forEach(viewStore: ForEachViewStore(items: $0.items, itemName: $0.itemName, identity: $0.identity, content: $0.content))
            }
        case "List":
            if args.unlabeled.isEmpty {
                return children(args.trailing).map { .list(viewStore: ListViewStore(children: $0)) }
            }
            return dataSource(args, at: call).map {
                .list(viewStore: ListViewStore(items: $0.items, itemName: $0.itemName, identity: $0.identity, content: $0.content))
            }
        case "TextField", "SecureField":
            guard let text = args.labeled["text"].flatMap(bindingPath) else {
                if args.labeled["text"] == nil { error("\(name) needs `text: $binding`", at: call) }
                return nil
            }
            let title = args.unlabeled.first.flatMap(expression)?.expression
            let prompt = args.labeled["prompt"].flatMap(textValue)
            return name == "TextField"
                ? .field(viewStore: FieldViewStore(text: text.path, title: title, prompt: prompt))
                : .secureField(viewStore: SecureFieldViewStore(text: text.path, title: title, prompt: prompt))
        case "Toggle":
            guard let isOn = args.labeled["isOn"].flatMap(bindingPath) else {
                if args.labeled["isOn"] == nil { error("Toggle needs `isOn: $binding`", at: call) }
                return nil
            }
            let label = args.trailing.flatMap { self.children($0) }.map(single)
            let title = args.unlabeled.first.flatMap(expression)?.expression
            return .toggle(viewStore: ToggleViewStore(isOn: isOn.path, title: title, label: label))
        case "Picker":
            return picker(args, at: call)
        case "DatePicker":
            guard let selection = args.labeled["selection"].flatMap(bindingPath) else {
                if args.labeled["selection"] == nil { error("DatePicker needs `selection: $binding`", at: call) }
                return nil
            }
            if let range = args.labeled["in"] {
                error("DatePicker ranges aren't supported yet", at: range)
                return nil
            }
            var components: [InjectedDatePickerComponents]?
            if let argument = args.labeled["displayedComponents"] {
                let names = argument.as(ArrayExprSyntax.self).map { $0.elements.map(\.expression) } ?? [argument]
                components = []
                for name in names {
                    guard let raw = name.as(MemberAccessExprSyntax.self)?.declName.baseName.text,
                          let component = InjectedDatePickerComponents(rawValue: raw) else {
                        error("displayedComponents must be .date, .hourAndMinute or both", at: name)
                        return nil
                    }
                    components?.append(component)
                }
            }
            let title = args.unlabeled.first.flatMap(expression)?.expression
            return .datePicker(viewStore: DatePickerViewStore(selection: selection.path, title: title, components: components))
        case "ProgressView":
            let title = args.unlabeled.first.flatMap(expression)?.expression
            let value = args.labeled["value"].flatMap(number)
            let total = args.labeled["total"].flatMap(number)
            return .progressView(viewStore: ProgressViewStore(title: title, value: value, total: total))
        default:
            if let helper = helpers[name] {
                return helperView(helper, args, at: call)
            }
            if customComponents.contains(name) {
                return customComponent(name, args, at: call)
            }
            error("'\(name)' isn't supported (supported: Text, Image, Label, Button, Color, shapes, Spacer, Divider, stacks, Group, Form, Section, ScrollView, NavigationStack, NavigationLink, TabView, LazyVGrid, LazyHGrid, Grid, GridRow, ForEach, List, TextField, SecureField, Toggle, Picker, DatePicker, ProgressView, and View structs in this file)", at: call.calledExpression)
            return nil
        }
    }

    // MARK: - Data-driven views

    struct DataSource {
        var items: String
        var itemName: String
        var identity: InjectedExpression?
        var content: InjectedView
    }

    /// `ForEach(todos) { todo in … }`, `ForEach($todos) { $todo in … }`, `ForEach(names, id: \.self) { name in … }`.
    func dataSource(_ args: Arguments, at call: FunctionCallExprSyntax) -> DataSource? {
        guard let data = args.unlabeled.first else {
            error("Expected the data to iterate, e.g. ForEach(todos) { todo in … }", at: call)
            return nil
        }
        if let infix = data.as(InfixOperatorExprSyntax.self),
           ["..<", "..."].contains(infix.operator.as(BinaryOperatorExprSyntax.self)?.operator.text ?? "") {
            error("ForEach/List can iterate @State arrays and their fields (not ranges or computed values)", at: data)
            return nil
        }
        let source: (path: String, type: ValueType)?
        if data.as(DeclReferenceExprSyntax.self)?.baseName.text.hasPrefix("$") == true || data.as(MemberAccessExprSyntax.self)?.base?.trimmedDescription.hasPrefix("$") == true {
            source = bindingPath(data)
        } else if let typed = expression(data), case let .variable(path, nil) = typed.expression {
            source = (path, typed.type)
        } else {
            error("ForEach/List can iterate @State arrays and their fields (not ranges or computed values)", at: data)
            return nil
        }
        guard let source else { return nil }
        guard let closure = args.trailing ?? args.closure("content") else {
            error("Expected a closure: { item in … }", at: call)
            return nil
        }
        guard let parameter = closureParameter(closure) else {
            error("Name the closure's parameter, e.g. { todo in … } ($0 isn't supported)", at: closure)
            return nil
        }
        let itemName = parameter.hasPrefix("$") ? String(parameter.dropFirst()) : parameter
        let elementType = source.type.element

        var identity: InjectedExpression?
        if let keyPath = args.labeled["id"] {
            guard let keyPathSyntax = keyPath.as(KeyPathExprSyntax.self), keyPathSyntax.components.count == 1,
                  case .property(let property)? = keyPathSyntax.components.first?.component else {
                error("id: must be a key path like \\.self or \\.id", at: keyPath)
                return nil
            }
            let field = property.declName.baseName.text
            identity = field == "self" ? .var(itemName) : .var("\(itemName).\(field)")
        } else if case .model(let modelName) = elementType, models[modelName]?.hasID == true {
            identity = .var("\(itemName).id")
        }

        let savedLocals = locals
        locals[itemName] = elementType
        defer { locals = savedLocals }
        guard let views = viewList(closure.statements) else { return nil }
        return DataSource(items: source.path, itemName: itemName, identity: identity, content: single(views))
    }

    func closureParameter(_ closure: ClosureExprSyntax) -> String? {
        switch closure.signature?.parameterClause {
        case .simpleInput(let list)?: return list.first?.name.text
        case .parameterClause(let clause)?: return clause.parameters.first?.firstName.text
        case nil: return nil
        }
    }

    /// The string inside `Text("…")`, used for prompts and alert messages.
    func textValue(_ syntax: ExprSyntax) -> InjectedExpression? {
        guard let call = syntax.as(FunctionCallExprSyntax.self), call.calledExpression.trimmedDescription == "Text",
              let value = Arguments(call).unlabeled.first, let typed = expression(value) else {
            error("Expected Text(\"…\")", at: syntax)
            return nil
        }
        return typed.expression
    }

    /// `Picker("Size", selection: $size) { ForEach(sizes, id: \.self) { size in Text(size).tag(size) } }`, or static
    /// options `Text("Small").tag("s")`, which become synthesized state.
    private func picker(_ args: Arguments, at call: FunctionCallExprSyntax) -> InjectedView? {
        guard let selection = args.labeled["selection"].flatMap(bindingPath) else {
            if args.labeled["selection"] == nil { error("Picker needs `selection: $binding`", at: call) }
            return nil
        }
        guard let content = args.trailing ?? args.closure("content") else {
            error("Picker needs its options in a closure", at: call)
            return nil
        }
        let title = args.unlabeled.first.flatMap(expression)?.expression
        let label = args.closure("label").flatMap { children($0) }.map(single)
        let statements = Array(content.statements)

        if statements.count == 1, case .expr(let expr) = statements[0].item, let forEach = expr.as(FunctionCallExprSyntax.self),
           forEach.calledExpression.trimmedDescription == "ForEach" {
            guard var source = dataSource(Arguments(forEach), at: forEach) else { return nil }
            // The option's `.tag(…)` is the value written to the selection.
            var value: InjectedExpression?
            source.content.modifiers.removeAll { modifier in
                if case .tag(let tag) = modifier { value = tag; return true }
                return false
            }
            return .picker(viewStore: PickerViewStore(selection: selection.path, items: source.items, itemName: source.itemName,
                                                      title: title, label: label, content: source.content, value: value))
        }

        var options: [RuntimeValue] = []
        for statement in statements {
            guard case .expr(let expr) = statement.item, let tagCall = expr.as(FunctionCallExprSyntax.self),
                  let member = tagCall.calledExpression.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "tag",
                  let textCall = member.base?.as(FunctionCallExprSyntax.self), textCall.calledExpression.trimmedDescription == "Text",
                  let labelSyntax = Arguments(textCall).unlabeled.first?.as(StringLiteralExprSyntax.self), let labelText = plainText(labelSyntax),
                  let tagSyntax = Arguments(tagCall).unlabeled.first, let tag = expression(tagSyntax),
                  case .literal(let tagValue) = tag.expression else {
                error("Picker options must be ForEach(…) { … .tag(…) } or Text(\"Label\").tag(literal)", at: statement)
                return nil
            }
            options.append(["label": .string(labelText), "value": tagValue])
        }
        let key = "__options\(syntheticState.count)"
        syntheticState[key] = .array(options)
        return .picker(viewStore: PickerViewStore(selection: selection.path, items: key, itemName: "option", title: title, label: label,
                                                  content: .text(viewStore: TextViewStore(value: .var("option.label"))),
                                                  value: .var("option.value")))
    }

    // MARK: - Grid items

    /// `[GridItem(.adaptive(minimum: 160))]`, `[GridItem(.flexible()), GridItem(.fixed(80), spacing: 8)]`, or
    /// `Array(repeating: GridItem(.flexible()), count: 2)`. Sizes must be literal numbers.
    private func gridItems(_ syntax: ExprSyntax) -> [InjectedGridItem]? {
        if let call = syntax.as(FunctionCallExprSyntax.self), call.calledExpression.trimmedDescription == "Array",
           let repeating = Arguments(call).labeled["repeating"], let countSyntax = Arguments(call).labeled["count"],
           let count = countSyntax.as(IntegerLiteralExprSyntax.self).flatMap({ Int($0.literal.text) }), count > 0 {
            return gridItem(repeating).map { Array(repeating: $0, count: count) }
        }
        guard let array = syntax.as(ArrayExprSyntax.self) else {
            error("Grid columns/rows must be a literal array of GridItem(…), or Array(repeating: GridItem(…), count: n)", at: syntax)
            return nil
        }
        var items: [InjectedGridItem] = []
        for element in array.elements {
            guard let item = gridItem(element.expression) else { return nil }
            items.append(item)
        }
        return items
    }

    private func gridItem(_ syntax: ExprSyntax) -> InjectedGridItem? {
        guard let call = syntax.as(FunctionCallExprSyntax.self), call.calledExpression.trimmedDescription == "GridItem" else {
            error("Expected GridItem(…)", at: syntax)
            return nil
        }
        func literal(_ expr: ExprSyntax?) -> Double? {
            guard let expr else { return nil }
            if let integer = expr.as(IntegerLiteralExprSyntax.self) { return Double(integer.literal.text) }
            if let float = expr.as(FloatLiteralExprSyntax.self) { return Double(float.literal.text) }
            return nil
        }
        let args = Arguments(call)
        var item = InjectedGridItem()
        if let sizeSyntax = args.unlabeled.first {
            guard let sizeCall = sizeSyntax.as(FunctionCallExprSyntax.self),
                  let kind = sizeCall.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text,
                  let size = InjectedGridItem.Size(rawValue: kind) else {
                error("GridItem sizes: .fixed(n), .flexible(minimum:maximum:), .adaptive(minimum:maximum:)", at: sizeSyntax)
                return nil
            }
            let sizeArgs = Arguments(sizeCall)
            item.size = size
            item.value = literal(sizeArgs.unlabeled.first)
            item.minimum = literal(sizeArgs.labeled["minimum"])
            item.maximum = literal(sizeArgs.labeled["maximum"])
        }
        item.spacing = literal(args.labeled["spacing"])
        if let alignment = args.labeled["alignment"]?.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
            guard let parsed = InjectedAlignment(rawValue: alignment) else {
                error("'.\(alignment)' isn't a supported alignment", at: args.labeled["alignment"]!)
                return nil
            }
            item.alignment = parsed
        }
        return item
    }

    // MARK: - Custom components

    /// An app view listed in `components`: `PrimaryButton(title: "Apply") { hostAction("apply", offer.id) }` →
    /// `{"custom": {"name": "PrimaryButton", "props": {"title": "Apply"}, "on": {"action": [...]}}}`.
    /// A trailing closure is the `action` event; labeled closures use their label.
    private func customComponent(_ name: String, _ args: Arguments, at call: FunctionCallExprSyntax) -> InjectedView? {
        guard args.unlabeled.isEmpty else {
            error("Arguments to the custom component '\(name)' must be labeled (they become its props)", at: call)
            return nil
        }
        var props: [String: InjectedExpression] = [:]
        var events: [String: [InjectedAction]] = [:]
        var failed = false
        for (label, argument) in args.labeled {
            if let closure = argument.as(ClosureExprSyntax.self) {
                if let compiled = actions(closure) { events[label] = compiled } else { failed = true }
            } else if let color = color(argument, reportErrors: false) {
                props[label] = color
            } else if let typed = expression(argument) {
                props[label] = typed.expression
            } else {
                failed = true
            }
        }
        if let trailing = args.trailing {
            if let compiled = actions(trailing) { events["action"] = compiled } else { failed = true }
        }
        for (label, closure) in args.additionalTrailing {
            if let compiled = actions(closure) { events[label] = compiled } else { failed = true }
        }
        if failed { return nil }
        customComponentsUsed.insert(name)
        return .custom(viewStore: CustomViewStore(name: name, props: props, on: events))
    }

    // MARK: - Helper views

    /// Another View struct in the file. Without properties it becomes a shared named view (`{"ref": name}`);
    /// with properties it's inlined with its arguments (`@Binding` properties take `$bindings`).
    private func helperView(_ decl: StructDeclSyntax, _ args: Arguments, at call: FunctionCallExprSyntax) -> InjectedView? {
        let name = decl.name.text
        guard !helperStack.contains(name) else {
            error("'\(name)' uses itself; recursive views aren't supported", at: call)
            return nil
        }
        var fields: [(name: String, isBinding: Bool, defaultValue: ExprSyntax?, type: ValueType)] = []
        var body: CodeBlockItemListSyntax?
        for member in decl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self), let binding = variable.bindings.first,
                  let fieldName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
            if fieldName == "body" {
                if case .getter(let statements)? = binding.accessorBlock?.accessors { body = statements }
                continue
            }
            if isState(variable) {
                error("Helper views can't have @State; keep state in the screen and pass it in (with @Binding to change it)", at: variable)
                return nil
            }
            fields.append((fieldName, hasAttribute("Binding", variable), binding.initializer?.value,
                           binding.typeAnnotation.map { valueType(of: $0.type) } ?? .unknown))
        }
        guard let body else {
            error("'\(name)' has no `body`", at: decl.name)
            return nil
        }

        func compileBody(with parameters: [String: Parameter]) -> InjectedView? {
            let saved = (state, locals, self.parameters)
            state = [:]
            locals = [:]
            self.parameters = parameters
            helperStack.append(name)
            defer {
                (state, locals, self.parameters) = saved
                helperStack.removeLast()
            }
            return viewBody(body)
        }

        if fields.isEmpty {
            if !args.unlabeled.isEmpty || !args.labeled.isEmpty {
                error("'\(name)' takes no arguments", at: call)
                return nil
            }
            if namedViews[name] == nil {
                guard let compiled = compileBody(with: [:]) else { return nil }
                namedViews[name] = compiled
            }
            return .viewStoreReference(id: name)
        }

        var parameters: [String: Parameter] = [:]
        for field in fields {
            if let argument = args.labeled[field.name] {
                if field.isBinding {
                    guard let binding = bindingPath(argument) else { return nil }
                    parameters[field.name] = .binding(path: binding.path, type: binding.type)
                } else if field.type == .color {
                    guard let hex = color(argument) else { return nil }
                    parameters[field.name] = .value(Typed(expression: hex, type: .color))
                } else {
                    guard let typed = expression(argument) else { return nil }
                    parameters[field.name] = .value(typed)
                }
            } else if let defaultValue = field.defaultValue, !field.isBinding {
                if field.type == .color {
                    guard let hex = color(defaultValue) else { return nil }
                    parameters[field.name] = .value(Typed(expression: hex, type: .color))
                    continue
                }
                guard let typed = expression(defaultValue) else { return nil }
                parameters[field.name] = .value(typed)
            } else {
                error("Missing argument '\(field.name)' for '\(name)'", at: call)
                return nil
            }
        }
        for label in args.labeled.keys where !fields.contains(where: { $0.name == label }) {
            error("'\(name)' has no property '\(label)'", at: call)
            return nil
        }
        return compileBody(with: parameters)
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
