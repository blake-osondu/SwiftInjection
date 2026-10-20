//
//  ModifierStore.swift
//
//
//  Created by Blake Osonduagwueki on 9/30/23.
//

import Foundation
import SwiftUI
import SwiftInjectionCore

struct ModifierStore: ViewModifier {
    var modifier: InjectedModifier
    var scope: StateScope

    func body(content: Content) -> some View {
        render(content)
    }

    private func nested(_ view: InjectedView) -> some View {
        InjectedContent(view)
    }

    private func color(_ expression: InjectedExpression?) -> Color? {
        scope.resolve(expression, as: String.self).map { Color(uiColor: UIColor.hex($0)) }
    }

    private func length(_ expression: InjectedExpression?) -> CGFloat? {
        scope.resolve(expression, as: CGFloat.self)
    }

    private func render(_ content: Content) -> AnyView {
        let plain = AnyView(content)
        /// Applies `transform` when `value` resolved, otherwise leaves the view unmodified.
        func when<T>(_ value: T?, _ transform: (T) -> AnyView) -> AnyView {
            value.map(transform) ?? plain
        }

        switch modifier {
        // Applied to the concrete Image / Shape before erasure; see Image_Ext and Shape_Ext.
        case .antialiased, .resizable, .renderingMode, .path:
            return plain

        // MARK: Text & fonts
        case let .systemFont(font):
            return when(scope.resolve(font, as: InjectedSystemFont.self)) { AnyView(content.font($0.font)) }
        case let .font(name, size):
            guard let name = scope.resolve(name, as: String.self), let size = length(size) else { return plain }
            return AnyView(content.font(.custom(name, size: size)))
        case let .fontWeight(weight):
            return when(scope.resolve(weight, as: InjectedFontWeight.self)) { AnyView(content.fontWeight($0.render)) }
        case let .fontDesign(design):
            guard #available(iOS 16.1, *) else { return plain }
            return when(scope.resolve(design, as: InjectedFontDesign.self)) { AnyView(content.fontDesign($0.render)) }
        case let .fontWidth(width):
            return when(scope.resolve(width, as: InjectedFontWidth.self)) { AnyView(content.fontWidth($0.render)) }
        case let .bold(isActive):
            return AnyView(content.bold(scope.resolve(isActive, as: Bool.self) ?? true))
        case let .italic(isActive):
            return AnyView(content.italic(scope.resolve(isActive, as: Bool.self) ?? true))
        case let .monospaced(isActive):
            return AnyView(content.monospaced(scope.resolve(isActive, as: Bool.self) ?? true))
        case .monospacedDigit:
            return AnyView(content.monospacedDigit())
        case let .kerning(value):
            return when(length(value)) { AnyView(content.kerning($0)) }
        case let .tracking(value):
            return when(length(value)) { AnyView(content.tracking($0)) }
        case let .strikethrough(isActive, pattern, color):
            return AnyView(content.strikethrough(
                scope.resolve(isActive, as: Bool.self) ?? true,
                pattern: scope.resolve(pattern, as: InjectedTextLineStylePattern.self)?.render ?? .solid,
                color: self.color(color)))
        case let .underline(isActive, pattern, color):
            return AnyView(content.underline(
                scope.resolve(isActive, as: Bool.self) ?? true,
                pattern: scope.resolve(pattern, as: InjectedTextLineStylePattern.self)?.render ?? .solid,
                color: self.color(color)))
        case let .lineLimit(limit):
            return AnyView(content.lineLimit(scope.resolve(limit, as: Int.self)))
        case let .truncationMode(mode):
            return when(scope.resolve(mode, as: InjectedTextTruncation.self)) { AnyView(content.truncationMode($0.render)) }
        case let .multilineTextAlignment(alignment):
            return when(scope.resolve(alignment, as: InjectedTextAlignment.self)) { AnyView(content.multilineTextAlignment($0.render)) }
        case let .minimumScaleFactor(factor):
            return when(length(factor)) { AnyView(content.minimumScaleFactor($0)) }

        // MARK: Layout
        case let .frame(width, height, minWidth, idealWidth, maxWidth, minHeight, idealHeight, maxHeight, alignment):
            let alignment = scope.resolve(alignment, as: InjectedAlignment.self)?.render ?? .center
            var view = plain
            let (width, height) = (length(width), length(height))
            if width != nil || height != nil {
                view = AnyView(view.frame(width: width, height: height, alignment: alignment))
            }
            let flexible = [minWidth, idealWidth, maxWidth, minHeight, idealHeight, maxHeight].map(length)
            if flexible.contains(where: { $0 != nil }) {
                view = AnyView(view.frame(minWidth: flexible[0], idealWidth: flexible[1], maxWidth: flexible[2],
                                          minHeight: flexible[3], idealHeight: flexible[4], maxHeight: flexible[5],
                                          alignment: alignment))
            }
            return view
        case let .padding(edges, amount):
            let edges = scope.resolve(edges, as: InjectedEdgeSet.self)?.render ?? .all
            return AnyView(content.padding(edges, length(amount)))
        case let .position(x, y):
            let (x, y) = (length(x), length(y))
            guard x != nil || y != nil else { return plain }
            return AnyView(content.position(x: x ?? 0, y: y ?? 0))
        case let .layoutPriority(priority):
            return when(scope.resolve(priority, as: Double.self)) { AnyView(content.layoutPriority($0)) }
        case let .fixedSize(horizontal, vertical):
            let (horizontal, vertical) = (scope.resolve(horizontal, as: Bool.self), scope.resolve(vertical, as: Bool.self))
            guard horizontal != nil || vertical != nil else { return AnyView(content.fixedSize()) }
            return AnyView(content.fixedSize(horizontal: horizontal ?? false, vertical: vertical ?? false))
        case let .ignoresSafeArea(edges):
            return AnyView(content.ignoresSafeArea(.container, edges: scope.resolve(edges, as: InjectedEdgeSet.self)?.render ?? .all))

        // MARK: Appearance
        case let .foregroundColor(color):
            return when(self.color(color)) { AnyView(content.foregroundColor($0)) }
        case let .background(view, alignment):
            let alignment = scope.resolve(alignment, as: InjectedAlignment.self)?.render ?? .center
            return AnyView(content.background(nested(view), alignment: alignment))
        case let .cornerRadius(radius):
            return when(length(radius)) { AnyView(content.cornerRadius($0)) }
        case let .border(color, width):
            return when(self.color(color)) { AnyView(content.border($0, width: length(width) ?? 1)) }
        case let .opacity(value):
            return when(scope.resolve(value, as: Double.self)) { AnyView(content.opacity($0)) }
        case let .shadow(color, radius, x, y):
            let (color, radius, x, y) = (self.color(color), length(radius), length(x), length(y))
            guard color != nil || radius != nil || x != nil || y != nil else { return plain }
            return AnyView(content.shadow(color: color ?? Color(.sRGBLinear, white: 0, opacity: 0.33),
                                          radius: radius ?? 0, x: x ?? 0, y: y ?? 0))
        case let .blur(radius, isOpaque):
            return when(length(radius)) { AnyView(content.blur(radius: $0, opaque: scope.resolve(isOpaque, as: Bool.self) ?? false)) }
        case let .brightness(amount):
            return when(scope.resolve(amount, as: Double.self)) { AnyView(content.brightness($0)) }
        case let .blendMode(mode):
            return when(scope.resolve(mode, as: InjectedBlendMode.self)) { AnyView(content.blendMode($0.render)) }
        case .colorInvert:
            return AnyView(content.colorInvert())
        case let .colorMultiply(color):
            return when(self.color(color)) { AnyView(content.colorMultiply($0)) }
        case let .symbolRenderingMode(mode):
            return when(scope.resolve(mode, as: InjectedSymbolRenderingMode.self)) { AnyView(content.symbolRenderingMode($0.render)) }
        case let .imageScale(scale):
            return when(scope.resolve(scale, as: InjectedImageScale.self)) { AnyView(content.imageScale($0.render)) }
        case .unredacted:
            return AnyView(content.unredacted())
        case let .animation(animation, value):
            return when(scope.resolve(animation, as: InjectedAnimation.self)) {
                AnyView(content.animation($0.render, value: scope.evaluate(value) ?? .null))
            }

        // MARK: Presentation
        case let .sheet(isPresented, view):
            return AnyView(content.sheet(isPresented: scope.boolBinding(isPresented)) { nested(view) })
        case let .fullScreenCover(isPresented, view):
            return AnyView(content.fullScreenCover(isPresented: scope.boolBinding(isPresented)) { nested(view) })
        case let .popover(isPresented, anchor, edge, view):
            return AnyView(content.popover(
                isPresented: scope.boolBinding(isPresented),
                attachmentAnchor: scope.resolve(anchor, as: InjectedPopoverAttachmentAnchor.self)?.render ?? .rect(.bounds),
                arrowEdge: scope.resolve(edge, as: InjectedEdge.self)?.render ?? .top) { nested(view) })
        case let .alert(isPresented, alert):
            return AnyView(content.alert(scope.string(alert.title), isPresented: scope.boolBinding(isPresented)) {
                ForEach(Array(alert.buttons.enumerated()), id: \.offset) { _, button in
                    Button(scope.string(button.label), role: button.role?.render) {
                        scope.perform(button.action)
                    }
                }
            } message: {
                if let message = alert.message {
                    Text(scope.string(message))
                }
            })
        case let .confirmationDialog(isPresented, title, visibility, actions):
            return AnyView(content.confirmationDialog(
                scope.string(title),
                isPresented: scope.boolBinding(isPresented),
                titleVisibility: scope.resolve(visibility, as: InjectedVisbility.self)?.render ?? .automatic) { nested(actions) })

        // MARK: Events
        case let .onAppear(actions):
            return AnyView(content.onAppear { scope.perform(actions) })
        case let .onDisappear(actions):
            return AnyView(content.onDisappear { scope.perform(actions) })
        case let .onTapGesture(count, actions):
            return AnyView(content.onTapGesture(count: scope.resolve(count, as: Int.self) ?? 1) { scope.perform(actions) })
        case let .onChange(value, actions):
            return AnyView(content.onChange(of: scope.evaluate(value) ?? .null) { _ in scope.perform(actions) })
        case let .onSubmit(actions):
            return AnyView(content.onSubmit { scope.perform(actions) })

        case let .navigationTitle(title):
            return AnyView(content.navigationTitle(Text(scope.string(title))))

        // MARK: Controls & input
        case let .disabled(isDisabled):
            return when(scope.resolve(isDisabled, as: Bool.self)) { AnyView(content.disabled($0)) }
        case let .buttonStyle(style):
            return when(scope.resolve(style, as: InjectedButtonStyle.self)) { $0.apply(to: content) }
        case let .pickerStyle(style):
            return when(scope.resolve(style, as: InjectedPickerStyle.self)) { $0.apply(to: content) }
        case let .datePickerStyle(style):
            return when(scope.resolve(style, as: InjectdDatePickerStyle.self)) { $0.apply(to: content) }
        case let .tag(value):
            switch scope.evaluate(value) {
            case .number(let number)?: return when(Int(exactly: number)) { AnyView(content.tag($0)) }
            case .string(let string)?: return AnyView(content.tag(string))
            default: return plain
            }
        case let .badge(value):
            switch scope.evaluate(value) {
            case .number(let number)?: return when(Int(exactly: number)) { AnyView(content.badge($0)) }
            case .string(let string)?: return AnyView(content.badge(Text(string)))
            default: return plain
            }
        case let .tabItem(view):
            return AnyView(content.tabItem { nested(view) })
        case let .keyboardType(type):
            return when(scope.resolve(type, as: InjectedKeyboardType.self)) { AnyView(content.keyboardType($0.render)) }
        case let .autocorrectionDisabled(isDisabled):
            return AnyView(content.autocorrectionDisabled(scope.resolve(isDisabled, as: Bool.self) ?? true))
        case let .textInputAutocapitalization(mode):
            return when(scope.resolve(mode, as: InjectedTextInputAutoCapitalization.self)) { AnyView(content.textInputAutocapitalization($0.render)) }
        case let .textContentType(type):
            return when(scope.resolve(type, as: InjectedTextContentType.self)) { AnyView(content.textContentType($0.render)) }
        }
    }
}
