//
//  InjectedView.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/17/23.
//

import Foundation

/// A view in the payload. JSON: a single-key object naming the component, e.g.
/// `{"text": {"value": "Hello"}}`, `{"vStack": {"children": [...]}}`, `{"ref": "header"}`, `{"empty": {}}`.
indirect public enum InjectedView: Codable, Hashable {

    static public func == (lhs: InjectedView, rhs: InjectedView) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    case vStack(viewStore: VStackViewStore)
    case hStack(viewStore: HStackViewStore)
    case zStack(viewStore: ZStackViewStore)
    case lazyVStack(viewStore: VStackViewStore)
    case lazyHStack(viewStore: HStackViewStore)
    case grid(viewStore: GridViewStore)
    case gridRow(viewStore: GridRowViewStore)
    case lazyHGrid(viewStore: LazyHGridViewStore)
    case lazyVGrid(viewStore: LazyVGridViewStore)
    case list(viewStore: ListViewStore)
    case forEach(viewStore: ForEachViewStore)
    case text(viewStore: TextViewStore)
    case field(viewStore: FieldViewStore)
    case secureField(viewStore: SecureFieldViewStore)
    case label(viewStore: LabelViewStore)
    case button(viewStore: ButtonViewStore)
    case image(viewStore: ImageViewStore)
    case navigationStack(viewStore: NavigationStackViewStore)
    case navigationLink(viewStore: NavigationLinkViewStore)
    case tab(viewStore: TabViewStore)
    case color(viewStore: ColorViewStore)
    case rectangle(viewStore: RectangleViewStore)
    case roundedRectangle(viewStore: RoundedRectangleViewStore)
    case circle(viewStore: CircleViewStore)
    case ellipse(viewStore: EllipseViewStore)
    case capsule(viewStore: CapsuleViewStore)
    case spacer(viewStore: SpacerViewStore)
    case divider(viewStore: DividerViewStore)
    case `if`(viewStore: IfViewStore)
    case progressView(viewStore: ProgressViewStore)
    case table(viewStore: TableViewStore)
    case group(viewStore: GroupViewStore)
    case controlGroup(viewStore: ControlGroupViewStore)
    case form(viewStore: FormViewStore)
    case section(viewStore: SectionViewStore)
    case geometryReader(viewStore: GeometryReaderViewStore)
    case picker(viewStore: PickerViewStore)
    case datePicker(viewStore: DatePickerViewStore)
    case scrollView(viewStore: ScrollViewStore)
    /// A view registered by the host app.
    case custom(viewStore: CustomViewStore)
    case toggle(viewStore: ToggleViewStore)
    /// A view defined once in the container and referenced by id.
    case viewStoreReference(id: String)
    case empty(id: String = "")
    /// A component this runtime doesn't know (from a newer payload). Renders nothing; its JSON is kept.
    case unsupported(name: String, content: RuntimeValue)

    /// The component's model, or nil for references and `empty`.
    public var viewStore: InjectedViewStore? {
        switch self {
        case .vStack(let viewStore): return viewStore
        case .hStack(let viewStore): return viewStore
        case .zStack(let viewStore): return viewStore
        case .lazyVStack(let viewStore): return viewStore
        case .lazyHStack(let viewStore): return viewStore
        case .grid(let viewStore): return viewStore
        case .gridRow(let viewStore): return viewStore
        case .lazyHGrid(let viewStore): return viewStore
        case .lazyVGrid(let viewStore): return viewStore
        case .list(let viewStore): return viewStore
        case .forEach(let viewStore): return viewStore
        case .text(let viewStore): return viewStore
        case .field(let viewStore): return viewStore
        case .secureField(let viewStore): return viewStore
        case .label(let viewStore): return viewStore
        case .button(let viewStore): return viewStore
        case .image(let viewStore): return viewStore
        case .navigationStack(let viewStore): return viewStore
        case .navigationLink(let viewStore): return viewStore
        case .tab(let viewStore): return viewStore
        case .color(let viewStore): return viewStore
        case .rectangle(let viewStore): return viewStore
        case .roundedRectangle(let viewStore): return viewStore
        case .circle(let viewStore): return viewStore
        case .ellipse(let viewStore): return viewStore
        case .capsule(let viewStore): return viewStore
        case .spacer(let viewStore): return viewStore
        case .divider(let viewStore): return viewStore
        case .if(let viewStore): return viewStore
        case .progressView(let viewStore): return viewStore
        case .table(let viewStore): return viewStore
        case .group(let viewStore): return viewStore
        case .controlGroup(let viewStore): return viewStore
        case .form(let viewStore): return viewStore
        case .section(let viewStore): return viewStore
        case .geometryReader(let viewStore): return viewStore
        case .picker(let viewStore): return viewStore
        case .datePicker(let viewStore): return viewStore
        case .scrollView(let viewStore): return viewStore
        case .custom(let viewStore): return viewStore
        case .toggle(let viewStore): return viewStore
        case .viewStoreReference, .empty, .unsupported: return nil
        }
    }

    public var id: String {
        switch self {
        case .viewStoreReference(let id), .empty(let id): return id
        case .unsupported: return ""
        default: return viewStore?.id ?? ""
        }
    }

    public var modifiers: [InjectedModifier] {
        get { viewStore?.modifiers ?? [] }
        set {
            switch self {
            case .vStack(var viewStore): viewStore.modifiers = newValue; self = .vStack(viewStore: viewStore)
            case .hStack(var viewStore): viewStore.modifiers = newValue; self = .hStack(viewStore: viewStore)
            case .zStack(var viewStore): viewStore.modifiers = newValue; self = .zStack(viewStore: viewStore)
            case .lazyVStack(var viewStore): viewStore.modifiers = newValue; self = .lazyVStack(viewStore: viewStore)
            case .lazyHStack(var viewStore): viewStore.modifiers = newValue; self = .lazyHStack(viewStore: viewStore)
            case .grid(var viewStore): viewStore.modifiers = newValue; self = .grid(viewStore: viewStore)
            case .gridRow(var viewStore): viewStore.modifiers = newValue; self = .gridRow(viewStore: viewStore)
            case .lazyHGrid(var viewStore): viewStore.modifiers = newValue; self = .lazyHGrid(viewStore: viewStore)
            case .lazyVGrid(var viewStore): viewStore.modifiers = newValue; self = .lazyVGrid(viewStore: viewStore)
            case .list(var viewStore): viewStore.modifiers = newValue; self = .list(viewStore: viewStore)
            case .forEach(var viewStore): viewStore.modifiers = newValue; self = .forEach(viewStore: viewStore)
            case .text(var viewStore): viewStore.modifiers = newValue; self = .text(viewStore: viewStore)
            case .field(var viewStore): viewStore.modifiers = newValue; self = .field(viewStore: viewStore)
            case .secureField(var viewStore): viewStore.modifiers = newValue; self = .secureField(viewStore: viewStore)
            case .label(var viewStore): viewStore.modifiers = newValue; self = .label(viewStore: viewStore)
            case .button(var viewStore): viewStore.modifiers = newValue; self = .button(viewStore: viewStore)
            case .image(var viewStore): viewStore.modifiers = newValue; self = .image(viewStore: viewStore)
            case .navigationStack(var viewStore): viewStore.modifiers = newValue; self = .navigationStack(viewStore: viewStore)
            case .navigationLink(var viewStore): viewStore.modifiers = newValue; self = .navigationLink(viewStore: viewStore)
            case .tab(var viewStore): viewStore.modifiers = newValue; self = .tab(viewStore: viewStore)
            case .color(var viewStore): viewStore.modifiers = newValue; self = .color(viewStore: viewStore)
            case .rectangle(var viewStore): viewStore.modifiers = newValue; self = .rectangle(viewStore: viewStore)
            case .roundedRectangle(var viewStore): viewStore.modifiers = newValue; self = .roundedRectangle(viewStore: viewStore)
            case .circle(var viewStore): viewStore.modifiers = newValue; self = .circle(viewStore: viewStore)
            case .ellipse(var viewStore): viewStore.modifiers = newValue; self = .ellipse(viewStore: viewStore)
            case .capsule(var viewStore): viewStore.modifiers = newValue; self = .capsule(viewStore: viewStore)
            case .spacer(var viewStore): viewStore.modifiers = newValue; self = .spacer(viewStore: viewStore)
            case .divider(var viewStore): viewStore.modifiers = newValue; self = .divider(viewStore: viewStore)
            case .if(var viewStore): viewStore.modifiers = newValue; self = .if(viewStore: viewStore)
            case .progressView(var viewStore): viewStore.modifiers = newValue; self = .progressView(viewStore: viewStore)
            case .table(var viewStore): viewStore.modifiers = newValue; self = .table(viewStore: viewStore)
            case .group(var viewStore): viewStore.modifiers = newValue; self = .group(viewStore: viewStore)
            case .controlGroup(var viewStore): viewStore.modifiers = newValue; self = .controlGroup(viewStore: viewStore)
            case .form(var viewStore): viewStore.modifiers = newValue; self = .form(viewStore: viewStore)
            case .section(var viewStore): viewStore.modifiers = newValue; self = .section(viewStore: viewStore)
            case .geometryReader(var viewStore): viewStore.modifiers = newValue; self = .geometryReader(viewStore: viewStore)
            case .picker(var viewStore): viewStore.modifiers = newValue; self = .picker(viewStore: viewStore)
            case .datePicker(var viewStore): viewStore.modifiers = newValue; self = .datePicker(viewStore: viewStore)
            case .scrollView(var viewStore): viewStore.modifiers = newValue; self = .scrollView(viewStore: viewStore)
            case .custom(var viewStore): viewStore.modifiers = newValue; self = .custom(viewStore: viewStore)
            case .toggle(var viewStore): viewStore.modifiers = newValue; self = .toggle(viewStore: viewStore)
            case .viewStoreReference, .empty, .unsupported: break
            }
        }
    }

    // MARK: Codable

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ stringValue: String) { self.stringValue = stringValue }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A view must have exactly one key naming its component (got \(container.allKeys.map(\.stringValue).sorted()))"))
        }
        switch key.stringValue {
        case "vStack": self = .vStack(viewStore: try container.decode(VStackViewStore.self, forKey: key))
        case "hStack": self = .hStack(viewStore: try container.decode(HStackViewStore.self, forKey: key))
        case "zStack": self = .zStack(viewStore: try container.decode(ZStackViewStore.self, forKey: key))
        case "lazyVStack": self = .lazyVStack(viewStore: try container.decode(VStackViewStore.self, forKey: key))
        case "lazyHStack": self = .lazyHStack(viewStore: try container.decode(HStackViewStore.self, forKey: key))
        case "grid": self = .grid(viewStore: try container.decode(GridViewStore.self, forKey: key))
        case "gridRow": self = .gridRow(viewStore: try container.decode(GridRowViewStore.self, forKey: key))
        case "lazyHGrid": self = .lazyHGrid(viewStore: try container.decode(LazyHGridViewStore.self, forKey: key))
        case "lazyVGrid": self = .lazyVGrid(viewStore: try container.decode(LazyVGridViewStore.self, forKey: key))
        case "list": self = .list(viewStore: try container.decode(ListViewStore.self, forKey: key))
        case "forEach": self = .forEach(viewStore: try container.decode(ForEachViewStore.self, forKey: key))
        case "text": self = .text(viewStore: try container.decode(TextViewStore.self, forKey: key))
        case "field": self = .field(viewStore: try container.decode(FieldViewStore.self, forKey: key))
        case "secureField": self = .secureField(viewStore: try container.decode(SecureFieldViewStore.self, forKey: key))
        case "label": self = .label(viewStore: try container.decode(LabelViewStore.self, forKey: key))
        case "button": self = .button(viewStore: try container.decode(ButtonViewStore.self, forKey: key))
        case "image": self = .image(viewStore: try container.decode(ImageViewStore.self, forKey: key))
        case "navigationStack": self = .navigationStack(viewStore: try container.decode(NavigationStackViewStore.self, forKey: key))
        case "navigationLink": self = .navigationLink(viewStore: try container.decode(NavigationLinkViewStore.self, forKey: key))
        case "tab": self = .tab(viewStore: try container.decode(TabViewStore.self, forKey: key))
        case "color": self = .color(viewStore: try container.decode(ColorViewStore.self, forKey: key))
        case "rectangle": self = .rectangle(viewStore: try container.decode(RectangleViewStore.self, forKey: key))
        case "roundedRectangle": self = .roundedRectangle(viewStore: try container.decode(RoundedRectangleViewStore.self, forKey: key))
        case "circle": self = .circle(viewStore: try container.decode(CircleViewStore.self, forKey: key))
        case "ellipse": self = .ellipse(viewStore: try container.decode(EllipseViewStore.self, forKey: key))
        case "capsule": self = .capsule(viewStore: try container.decode(CapsuleViewStore.self, forKey: key))
        case "spacer": self = .spacer(viewStore: try container.decode(SpacerViewStore.self, forKey: key))
        case "divider": self = .divider(viewStore: try container.decode(DividerViewStore.self, forKey: key))
        case "if": self = .if(viewStore: try container.decode(IfViewStore.self, forKey: key))
        case "progressView": self = .progressView(viewStore: try container.decode(ProgressViewStore.self, forKey: key))
        case "table": self = .table(viewStore: try container.decode(TableViewStore.self, forKey: key))
        case "group": self = .group(viewStore: try container.decode(GroupViewStore.self, forKey: key))
        case "controlGroup": self = .controlGroup(viewStore: try container.decode(ControlGroupViewStore.self, forKey: key))
        case "form": self = .form(viewStore: try container.decode(FormViewStore.self, forKey: key))
        case "section": self = .section(viewStore: try container.decode(SectionViewStore.self, forKey: key))
        case "geometryReader": self = .geometryReader(viewStore: try container.decode(GeometryReaderViewStore.self, forKey: key))
        case "picker": self = .picker(viewStore: try container.decode(PickerViewStore.self, forKey: key))
        case "datePicker": self = .datePicker(viewStore: try container.decode(DatePickerViewStore.self, forKey: key))
        case "scrollView": self = .scrollView(viewStore: try container.decode(ScrollViewStore.self, forKey: key))
        case "custom": self = .custom(viewStore: try container.decode(CustomViewStore.self, forKey: key))
        case "toggle": self = .toggle(viewStore: try container.decode(ToggleViewStore.self, forKey: key))
        case "ref": self = .viewStoreReference(id: try container.decode(String.self, forKey: key))
        case "empty": self = .empty()
        default:
            decoder.reportPayloadWarning("Skipped unknown component '\(key.stringValue)' at \(decoder.codingPathDescription)")
            self = .unsupported(name: key.stringValue, content: try container.decode(RuntimeValue.self, forKey: key))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .vStack(let viewStore): try container.encode(viewStore, forKey: Key("vStack"))
        case .hStack(let viewStore): try container.encode(viewStore, forKey: Key("hStack"))
        case .zStack(let viewStore): try container.encode(viewStore, forKey: Key("zStack"))
        case .lazyVStack(let viewStore): try container.encode(viewStore, forKey: Key("lazyVStack"))
        case .lazyHStack(let viewStore): try container.encode(viewStore, forKey: Key("lazyHStack"))
        case .grid(let viewStore): try container.encode(viewStore, forKey: Key("grid"))
        case .gridRow(let viewStore): try container.encode(viewStore, forKey: Key("gridRow"))
        case .lazyHGrid(let viewStore): try container.encode(viewStore, forKey: Key("lazyHGrid"))
        case .lazyVGrid(let viewStore): try container.encode(viewStore, forKey: Key("lazyVGrid"))
        case .list(let viewStore): try container.encode(viewStore, forKey: Key("list"))
        case .forEach(let viewStore): try container.encode(viewStore, forKey: Key("forEach"))
        case .text(let viewStore): try container.encode(viewStore, forKey: Key("text"))
        case .field(let viewStore): try container.encode(viewStore, forKey: Key("field"))
        case .secureField(let viewStore): try container.encode(viewStore, forKey: Key("secureField"))
        case .label(let viewStore): try container.encode(viewStore, forKey: Key("label"))
        case .button(let viewStore): try container.encode(viewStore, forKey: Key("button"))
        case .image(let viewStore): try container.encode(viewStore, forKey: Key("image"))
        case .navigationStack(let viewStore): try container.encode(viewStore, forKey: Key("navigationStack"))
        case .navigationLink(let viewStore): try container.encode(viewStore, forKey: Key("navigationLink"))
        case .tab(let viewStore): try container.encode(viewStore, forKey: Key("tab"))
        case .color(let viewStore): try container.encode(viewStore, forKey: Key("color"))
        case .rectangle(let viewStore): try container.encode(viewStore, forKey: Key("rectangle"))
        case .roundedRectangle(let viewStore): try container.encode(viewStore, forKey: Key("roundedRectangle"))
        case .circle(let viewStore): try container.encode(viewStore, forKey: Key("circle"))
        case .ellipse(let viewStore): try container.encode(viewStore, forKey: Key("ellipse"))
        case .capsule(let viewStore): try container.encode(viewStore, forKey: Key("capsule"))
        case .spacer(let viewStore): try container.encode(viewStore, forKey: Key("spacer"))
        case .divider(let viewStore): try container.encode(viewStore, forKey: Key("divider"))
        case .if(let viewStore): try container.encode(viewStore, forKey: Key("if"))
        case .progressView(let viewStore): try container.encode(viewStore, forKey: Key("progressView"))
        case .table(let viewStore): try container.encode(viewStore, forKey: Key("table"))
        case .group(let viewStore): try container.encode(viewStore, forKey: Key("group"))
        case .controlGroup(let viewStore): try container.encode(viewStore, forKey: Key("controlGroup"))
        case .form(let viewStore): try container.encode(viewStore, forKey: Key("form"))
        case .section(let viewStore): try container.encode(viewStore, forKey: Key("section"))
        case .geometryReader(let viewStore): try container.encode(viewStore, forKey: Key("geometryReader"))
        case .picker(let viewStore): try container.encode(viewStore, forKey: Key("picker"))
        case .datePicker(let viewStore): try container.encode(viewStore, forKey: Key("datePicker"))
        case .scrollView(let viewStore): try container.encode(viewStore, forKey: Key("scrollView"))
        case .custom(let viewStore): try container.encode(viewStore, forKey: Key("custom"))
        case .toggle(let viewStore): try container.encode(viewStore, forKey: Key("toggle"))
        case .viewStoreReference(let id): try container.encode(id, forKey: Key("ref"))
        case .empty: try container.encode([String: String](), forKey: Key("empty"))
        case let .unsupported(name, content): try container.encode(content, forKey: Key(name))
        }
    }
}

/// Every component model exposes an id and its modifiers.
public protocol InjectedViewStore: Codable {
    var id: String { get }
    var modifiers: [InjectedModifier] { get set }
}

extension ButtonViewStore: InjectedViewStore {}
extension CapsuleViewStore: InjectedViewStore {}
extension CircleViewStore: InjectedViewStore {}
extension ColorViewStore: InjectedViewStore {}
extension ControlGroupViewStore: InjectedViewStore {}
extension CustomViewStore: InjectedViewStore {}
extension DatePickerViewStore: InjectedViewStore {}
extension DividerViewStore: InjectedViewStore {}
extension EllipseViewStore: InjectedViewStore {}
extension FieldViewStore: InjectedViewStore {}
extension ForEachViewStore: InjectedViewStore {}
extension FormViewStore: InjectedViewStore {}
extension GeometryReaderViewStore: InjectedViewStore {}
extension GridRowViewStore: InjectedViewStore {}
extension GridViewStore: InjectedViewStore {}
extension GroupViewStore: InjectedViewStore {}
extension HStackViewStore: InjectedViewStore {}
extension IfViewStore: InjectedViewStore {}
extension ImageViewStore: InjectedViewStore {}
extension LabelViewStore: InjectedViewStore {}
extension LazyHGridViewStore: InjectedViewStore {}
extension LazyVGridViewStore: InjectedViewStore {}
extension ListViewStore: InjectedViewStore {}
extension NavigationLinkViewStore: InjectedViewStore {}
extension NavigationStackViewStore: InjectedViewStore {}
extension PickerViewStore: InjectedViewStore {}
extension ProgressViewStore: InjectedViewStore {}
extension RectangleViewStore: InjectedViewStore {}
extension RoundedRectangleViewStore: InjectedViewStore {}
extension ScrollViewStore: InjectedViewStore {}
extension SectionViewStore: InjectedViewStore {}
extension SecureFieldViewStore: InjectedViewStore {}
extension SpacerViewStore: InjectedViewStore {}
extension TableViewStore: InjectedViewStore {}
extension TabViewStore: InjectedViewStore {}
extension TextViewStore: InjectedViewStore {}
extension ToggleViewStore: InjectedViewStore {}
extension VStackViewStore: InjectedViewStore {}
extension ZStackViewStore: InjectedViewStore {}
