//
//  DatePickerViewStore.swift
//  SwiftInjection
//

import Foundation

/// The date at `selection` is stored as an ISO 8601 string. `minimum`/`maximum` bound the range.
/// `{"datePicker": {"title": "Due", "selection": "task.due", "components": ["date"], "minimum": {"var": "today"}}}`
public struct DatePickerViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var selection: String
    public var title: InjectedExpression?
    public var label: InjectedView?
    /// Default: date and time.
    public var components: [InjectedDatePickerComponents]?
    public var minimum: InjectedExpression?
    public var maximum: InjectedExpression?

    public init(id: String = "", modifiers: [InjectedModifier] = [], selection: String, title: InjectedExpression? = nil,
                label: InjectedView? = nil, components: [InjectedDatePickerComponents]? = nil,
                minimum: InjectedExpression? = nil, maximum: InjectedExpression? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.selection = selection
        self.title = title
        self.label = label
        self.components = components
        self.minimum = minimum
        self.maximum = maximum
    }
}
