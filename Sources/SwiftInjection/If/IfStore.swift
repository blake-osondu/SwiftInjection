//
//  IfStore.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 9/4/23.
//

import Foundation
import Combine

class IfStore: ObservableObject {
    var viewStore: IfViewStore
    var stateSignal: StateSignal
    @Published var state: InjectedState
    @Published var condition: Bool = false
    
    init(viewStore: IfViewStore, stateSignal: StateSignal) {
        self.viewStore = viewStore
        self.stateSignal = stateSignal
        self.state = stateSignal.value
        self.condition = Self.evaluate(viewStore, state) ?? false

        self.stateSignal.eraseToAnyPublisher().assign(to: &$state)

        stateSignal.map { state in
            Self.evaluate(viewStore, state)
        }
        .compactMap { $0 }
        .assign(to: &$condition)
    }

    private static func evaluate(_ viewStore: IfViewStore, _ state: InjectedState) -> Bool? {
        guard let condition = viewStore.condition else {
            return findBooleanValue(stateId: state.id, id: viewStore.conditionKey, state: state)
        }
        do {
            return try ExpressionEvaluator().condition(condition, in: state)
        } catch {
            print("SwiftInjection: if '\(viewStore.id)' condition failed: \(error)")
            return false
        }
    }
}
