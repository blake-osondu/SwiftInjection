//
//  InjectedFunctionBuilder.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/19/23.
//

import Foundation
import Combine

@resultBuilder
public struct InjectedFunctionBuilder {
    
    var stateSignal: StateSignal?
    var operation: InjectedOperation
    static var cancellables = Set<AnyCancellable>()
    
    public static func buildBlock(_ components: InjectedFunctionBuilder...) -> InjectedFunctionBuilder {
        return components.reduce(InjectedFunctionBuilder(stateSignal: nil, operation: .noOperation)) { partialResult, next in
            if let stateSignal = partialResult.stateSignal ?? next.stateSignal {
                performOperation(stateSignal: stateSignal, operation: next.operation)
                return InjectedFunctionBuilder(stateSignal: stateSignal, operation: next.operation)
            }
            return InjectedFunctionBuilder(stateSignal: nil, operation: next.operation)
        }
    }
    
    static func performOperation(stateSignal: StateSignal, operation: InjectedOperation) {
        switch operation {
        case .asyncAfter(let operation, let delay):
            Future<InjectedState, Never> { promise in
                promise(.success(provideStateTransformedByOperation(state: stateSignal.value, operation: operation)))
            }.delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                case .finished:
                    break
                }
            } receiveValue: { futureState in
                stateSignal.value = futureState
            }.store(in: &cancellables)
        
        case .async(let operation):
            Future<InjectedState, Never> { promise in
                promise(.success(provideStateTransformedByOperation(state: stateSignal.value, operation: operation)))
            }.sink { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                case .finished:
                    break
                }
            } receiveValue: { futureState in
                stateSignal.value = futureState
            }.store(in: &cancellables)
        default:
            stateSignal.send(provideStateTransformedByOperation(state: stateSignal.value, operation: operation))
        }
    }
    
    static func provideStateUpdatedByValue(_ state: InjectedState, _ updatedValue: InjectedValue) -> InjectedState {
        state |> prop(state.keyValue(for: updatedValue.id)) ({_ in
            updatedValue
        })
    }
    
    static func provideStateTransformedByOperation(state: InjectedState, operation: InjectedOperation) -> InjectedState {
        switch operation {
        case .multiplyByInteger(let key, let multiple):
            if let value = state.map(key: key) {
                switch value {
                case let .double(stateId, id, double):
                    let updateValue = InjectedValue.double(stateId: stateId, id: id, value: double * Double(multiple))
                    return provideStateUpdatedByValue(state, updateValue)
                case let .integer(stateId, id, integer):
                    let updateValue = InjectedValue.integer(stateId: stateId, id: id, value: integer * multiple)
                    return provideStateUpdatedByValue(state, updateValue)
                default:
                    return state
                }
            }
        case .divideByInteger(let key, let quotient):
            if let value = state.map(key:key) {
                switch value {
                case let .double(stateId, id, double):
                    let updateValue = InjectedValue.double(stateId: stateId, id: id, value: double / Double(quotient))
                    return provideStateUpdatedByValue(state, updateValue)
                case let .integer(stateId, id, integer):
                    let updateValue = InjectedValue.integer(stateId: stateId, id: id, value: integer / quotient)
                    return provideStateUpdatedByValue(state, updateValue)
                default:
                    return state
                }
            }
        case .assign(_, let value):
            return provideStateUpdatedByValue(state, value)
        case .noOperation:
            return state
        default:
            return state
        }
        return state
    }
}

