//
//  InjectedModifier.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/17/23.
//

import Foundation

/// A view modifier. Every scalar argument is an expression, so it can be a literal (`8`, `"#FF0000"`,
/// `"leading"`) or read from state (`{"var": "theme.spacing"}`). Omitted arguments use SwiftUI's default.
///
/// JSON: `{"padding": {"edges": "horizontal", "length": 12}}`, `{"bold": {}}`.
/// Presentation modifiers take `isPresented` as a state path so dismissing writes back to state.
public enum InjectedModifier: Codable {
    public typealias Expression = InjectedExpression

    // MARK: Text & fonts
    case systemFont(font: Expression)
    /// `.font(.system(size:weight:design:))` (schema 1.1)
    case systemFontSize(size: Expression, weight: Expression? = nil, design: Expression? = nil)
    case font(name: Expression, size: Expression)
    case fontWeight(weight: Expression)
    case fontDesign(design: Expression)
    case fontWidth(width: Expression)
    case bold(isActive: Expression? = nil)
    case italic(isActive: Expression? = nil)
    case monospaced(isActive: Expression? = nil)
    case monospacedDigit
    case kerning(value: Expression)
    case tracking(value: Expression)
    case strikethrough(isActive: Expression? = nil, pattern: Expression? = nil, color: Expression? = nil)
    case underline(isActive: Expression? = nil, pattern: Expression? = nil, color: Expression? = nil)
    case lineLimit(limit: Expression?)
    case truncationMode(mode: Expression)
    case multilineTextAlignment(alignment: Expression)
    case minimumScaleFactor(factor: Expression)

    // MARK: Layout
    /// Fixed (`width`, `height`) and flexible (`min…`, `ideal…`, `max…`) frames. `"infinity"` is accepted for sizes.
    case frame(width: Expression? = nil, height: Expression? = nil,
               minWidth: Expression? = nil, idealWidth: Expression? = nil, maxWidth: Expression? = nil,
               minHeight: Expression? = nil, idealHeight: Expression? = nil, maxHeight: Expression? = nil,
               alignment: Expression? = nil)
    case padding(edges: Expression? = nil, length: Expression? = nil)
    case position(x: Expression? = nil, y: Expression? = nil)
    case layoutPriority(priority: Expression)
    case fixedSize(horizontal: Expression? = nil, vertical: Expression? = nil)
    case ignoresSafeArea(edges: Expression? = nil)
    /// `ratio` (width ÷ height) or the content's own; `contentMode` "fit" or "fill" (schema 1.1)
    case aspectRatio(ratio: Expression? = nil, contentMode: Expression)

    // MARK: Appearance
    case foregroundColor(color: Expression)
    case background(content: InjectedView, alignment: Expression? = nil)
    case cornerRadius(radius: Expression)
    case border(color: Expression, width: Expression? = nil)
    case opacity(value: Expression)
    case shadow(color: Expression? = nil, radius: Expression? = nil, x: Expression? = nil, y: Expression? = nil)
    case blur(radius: Expression, isOpaque: Expression? = nil)
    case brightness(amount: Expression)
    case blendMode(mode: Expression)
    case colorInvert
    case colorMultiply(color: Expression)
    case symbolRenderingMode(mode: Expression)
    case imageScale(scale: Expression)
    case unredacted
    case animation(animation: Expression, value: Expression)

    // MARK: Presentation
    case sheet(isPresented: String, content: InjectedView)
    case fullScreenCover(isPresented: String, content: InjectedView)
    case popover(isPresented: String, attachmentAnchor: Expression? = nil, arrowEdge: Expression? = nil, content: InjectedView)
    case alert(isPresented: String, alert: InjectedAlert)
    case confirmationDialog(isPresented: String, title: Expression, titleVisibility: Expression? = nil, actions: InjectedView)
    case navigationTitle(title: Expression)
    /// "page" swipes between a tab view's children; `indexDisplayMode` shows the page dots (schema 1.1)
    case tabViewStyle(style: Expression, indexDisplayMode: Expression? = nil)
    /// The page dots' background: "automatic", "always" or "never" (schema 1.1)
    case indexViewStyle(backgroundDisplayMode: Expression)

    // MARK: Controls & input
    case disabled(isDisabled: Expression)
    case buttonStyle(style: Expression)
    case pickerStyle(style: Expression)
    case datePickerStyle(style: Expression)
    case tag(value: Expression)
    case badge(value: Expression)
    case tabItem(content: InjectedView)
    case keyboardType(type: Expression)
    case autocorrectionDisabled(isDisabled: Expression? = nil)
    case textInputAutocapitalization(mode: Expression)
    case textContentType(type: Expression)

    // MARK: Events
    case onAppear(do: [InjectedAction])
    case onDisappear(do: [InjectedAction])
    case onTapGesture(count: Expression? = nil, do: [InjectedAction])
    /// Runs when `of` evaluates to a different value.
    case onChange(of: Expression, do: [InjectedAction])
    case onSubmit(do: [InjectedAction])

    // MARK: Image- and shape-only (applied by Image_Ext / Shape_Ext, ignored elsewhere)
    case antialiased(isActive: Expression)
    case resizable(capInsets: InjectedEdgeInSets? = nil, resizingMode: Expression? = nil)
    case renderingMode(mode: Expression)
    case path(x: Expression? = nil, y: Expression? = nil, width: Expression? = nil, height: Expression? = nil)
}

// String-backed option enums used as modifier arguments.
extension InjectedAlignment: RuntimeConvertible {}
extension InjectedAnimation: RuntimeConvertible {}
extension InjectedBlendMode: RuntimeConvertible {}
extension InjectedButtonStyle: RuntimeConvertible {}
extension InjectedEdge: RuntimeConvertible {}
extension InjectedEdgeSet: RuntimeConvertible {}
extension InjectedFontDesign: RuntimeConvertible {}
extension InjectedFontWeight: RuntimeConvertible {}
extension InjectedFontWidth: RuntimeConvertible {}
extension InjectedImageRenderingMode: RuntimeConvertible {}
extension InjectedImageScale: RuntimeConvertible {}
extension InjectedKeyboardType: RuntimeConvertible {}
extension InjectedPickerStyle: RuntimeConvertible {}
extension InjectedPopoverAttachmentAnchor: RuntimeConvertible {}
extension InjectedRoundedCornerStyle: RuntimeConvertible {}
extension InjectedHorizontalAlignment: RuntimeConvertible {}
extension InjectedVerticalAlignment: RuntimeConvertible {}
extension InjectedResizingMode: RuntimeConvertible {}
extension InjectedSymbolRenderingMode: RuntimeConvertible {}
extension InjectedSystemFont: RuntimeConvertible {}
extension InjectedTextAlignment: RuntimeConvertible {}
extension InjectedTextContentType: RuntimeConvertible {}
extension InjectedTextInputAutoCapitalization: RuntimeConvertible {}
extension InjectedTextLineStylePattern: RuntimeConvertible {}
extension InjectedTextTruncation: RuntimeConvertible {}
extension InjectedVisbility: RuntimeConvertible {}
extension InjectdDatePickerStyle: RuntimeConvertible {}
extension InjectedTabViewStyle: RuntimeConvertible {}
extension InjectedIndexDisplayMode: RuntimeConvertible {}
extension InjectedContentMode: RuntimeConvertible {}
