//
//  ProgressViewStore.swift
//  SwiftInjection
//

import Foundation

/// Determinate with `value` (and `total`, default 1), a timer with `timerStart`/`timerEnd` (ISO 8601),
/// or indeterminate when neither is given.
public struct ProgressViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var title: InjectedExpression?
    public var label: InjectedView?
    public var currentValueLabel: InjectedView?
    public var value: InjectedExpression?
    public var total: InjectedExpression?
    public var timerStart: InjectedExpression?
    public var timerEnd: InjectedExpression?
    public var countsDown: InjectedExpression?

    public init(id: String = "", modifiers: [InjectedModifier] = [], title: InjectedExpression? = nil,
                label: InjectedView? = nil, currentValueLabel: InjectedView? = nil, value: InjectedExpression? = nil,
                total: InjectedExpression? = nil, timerStart: InjectedExpression? = nil,
                timerEnd: InjectedExpression? = nil, countsDown: InjectedExpression? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.title = title
        self.label = label
        self.currentValueLabel = currentValueLabel
        self.value = value
        self.total = total
        self.timerStart = timerStart
        self.timerEnd = timerEnd
        self.countsDown = countsDown
    }
}
