//
//  InjectedValue.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/19/23.
//
import Foundation
import SwiftUI


//public enum Key: Codable, Equatable, ExpressibleByStringLiteral {
//    typealias StringLiteralType = String
//
//    case key(id: String)
//
//    init(stringLiteral value: String) {
//        self = .key(id: value)
//    }
//}


protocol Key: ExpressibleByStringLiteral, Equatable, Codable {
    
}
public enum ValueKey: Key {
    case key(id: String)
    public init(stringLiteral value: StringLiteralType) {
        self = .key(id: value)
    }
}

public indirect enum InjectedValue: Codable, Equatable {
    case none
    case string(stateId: String, id: String, value: String)
    case integer(stateId: String, id:String, value: Int)
    case double(stateId: String, id: String, value: Double)
    case boolean(stateId: String, id: String, value: Bool)
    case data(stateId: String, id: String, value: Data)
    case date(stateId: String, id: String, value: Date)
    case state(stateId: String, id: String, value: InjectedState)
    case stateCollection(stateId: String, id: String, value: [String: InjectedState])
    case stringArray(stateId: String, id: String, value: [String])
    case integerArray(stateId: String, id: String, value: [Int])
    case doubleArray(stateId: String, id: String, value: [Double])
    case booleanArray(stateId: String, id: String, value: [Bool])
    case dataArray(stateId: String, id: String, value: [Data])
    case dateArray(stateId: String, id: String, value: [Date])
    case stateArray(stateId: String, id: String, value: [InjectedState])
    var stateId: String {
        switch self {
        case .string(let stateId, _, _),
                .integer(let stateId, _, _),
                .double(let stateId, _, _),
                .boolean(let stateId, _, _),
                .data(let stateId, _, _),
                .date(let stateId, _, _),
                .stringArray(let stateId, _, _),
                .integerArray(let stateId, _, _),
                .doubleArray(let stateId, _, _),
                .booleanArray(let stateId, _, _),
                .dataArray(let stateId, _, _),
                .dateArray(let stateId, _, _),
                .state(let stateId, _, _),
                .stateCollection(let stateId, _, _),
                .stateArray(let stateId, _, _):
            return "\(stateId)"
        case .none:
            return ""
        }
    }
    
    public var id: String {
        switch self {
        case .string(_, let id , _),
                .integer(_, let id , _),
                .double(_, let id , _),
                .boolean(_, let id , _),
                .data(_, let id , _),
                .date(_, let id, _),
                .stringArray(_, let id , _),
                .integerArray(_, let id , _),
                .doubleArray(_, let id , _),
                .booleanArray(_, let id , _),
                .dataArray(_, let id , _),
                .dateArray(_, let id, _),
                .state(_, let id, _),
                .stateCollection(_, let id, _),
                .stateArray(_, let id, _):
            return "\(id)"
        case .none:
            return ""
        }
    }
    var string: String? {
        switch self {
        case .string(_, _, let value):
            return value
        default:
            return nil
        }
    }
    var absoluteString: String {
        string ?? ""
    }
    
    var integer: Int? {
        switch self {
        case .integer(_, _, let value):
            return value
        default:
            return nil
        }
    }
    
    var double: Double? {
        switch self {
        case .double(_, _, let value):
            return value
        default:
            return nil
        }
    }
    
    var boolean: Bool? {
        switch self {
        case .boolean(_, _, let value):
            return value
        default:
            return nil
        }
    }
    
    var data: Data? {
        switch self {
        case .data(_, _, let value):
            return value
        default:
            return nil
        }
    }

    var date: Date? {
        switch self {
        case .date(_, _, let value):
            return value
        default:
            return nil
        }
    }
    
    var state: InjectedState? {
        switch self {
        case .state(_, _, let value):
            return value
        default:
            return nil
        }
    }
    
    var stringArray: [String] {
        switch self {
        case .stringArray(_, _, let value):
            return value
        default:
            return []
        }
    }
    
    var integerArray: [Int] {
        switch self {
        case .integerArray(_, _, let value):
            return value
        default:
            return []
        }
    }
    
    var doubleArray: [Double] {
        switch self {
        case .doubleArray(_, _, let value):
            return value
        default:
            return []
        }
    }
    
    var booleanArray: [Bool] {
        switch self {
        case .booleanArray(_, _, let value):
            return value
        default:
            return []
        }
    }
    
    var dataArray: [Data] {
        switch self {
        case .dataArray(_, _, let value):
            return value
        default:
            return []
        }
    }

    var dateArray: [Date] {
        switch self {
        case .dateArray(_, _, let value):
            return value
        default:
            return []
        }
    }
    
     var stateArray: [InjectedState] {
        switch self {
        //TODO: Should this casee be used?
        case .state(_, _, let value):
            return [value]
        case .stateArray(_, _, let value):
            return value
        default:
            return []
        }
    }
    var stateCollection: [String: InjectedState] {
        switch self {
        case .stateCollection(_, _, let value):
            return value
        default:
            return [:]
        }
    }
    
    var array: [InjectedValue] {
        switch self {
        case let .stringArray(stateId, id, strings):
            return strings.map {
                InjectedValue.string(
                    stateId: "\(stateId).\(UUID().uuidString)",
                    id: "\(id).\(UUID().uuidString)",
                    value: $0)}
        case let .booleanArray(stateId, id, booleans):
            return booleans.map {
                InjectedValue.boolean(
                    stateId:  "\(stateId).\(UUID().uuidString)",
                    id:  "\(id).\(UUID().uuidString)",
                    value: $0)}
        case let .doubleArray(stateId, id, doubles):
            return doubles.map {
                InjectedValue.double(
                    stateId:  "\(stateId).\(UUID().uuidString)",
                    id:  "\(id).\(UUID().uuidString)",
                    value: $0)}
        case let .integerArray(stateId, id, integers):
            return integers.map {
                InjectedValue.integer(
                    stateId:  "\(stateId).\(UUID().uuidString)",
                    id:  "\(id).\(UUID().uuidString)",
                    value: $0)}
        case let .dataArray(stateId, id, data):
            return data.map {
                InjectedValue.data(
                    stateId:  "\(stateId).\(UUID().uuidString)",
                    id:  "\(id).\(UUID().uuidString)",
                    value: $0)}
        case let .dateArray(stateId, id, dates):
            return dates.map {
                InjectedValue.date(
                    stateId:  "\(stateId).\(UUID().uuidString)",
                    id:  "\(id).\(UUID().uuidString)",
                    value: $0)}
        case let .stateArray(stateId, id, states):
            return states.map {
                InjectedValue.state(
                    stateId:  "\(stateId).\(UUID().uuidString)",
                    id:  "\(id).\(UUID().uuidString)",
                    value: $0)}
        default:
            return []
        }
    }

    public func updateStateId(stateId: String) -> InjectedValue {
        switch self {
        case .none:
            return .none
        case let .string(_, id, value):
            return .string(stateId: stateId, id: id, value: value)
        case let .integer(_, id, value):
            return .integer(stateId: stateId, id: id, value: value)
        case let .double(_, id, value):
            return .double(stateId: stateId, id: id, value: value)
        case let .boolean(_, id, value):
            return .boolean(stateId: stateId, id: id, value: value)
        case let .data(_, id, value):
            return .data(stateId: stateId, id:  id, value: value)
        case let .date(_, id, value):
            return .date(stateId: stateId, id:  id, value: value)
        case let .state(_, id, value):
            return .state(stateId: stateId, id: id, value: value)
        case let .stateCollection(_, id: id, value: value):
            return .stateCollection(stateId: stateId, id: id, value: value)
        case let .stringArray(_, id, value):
            return .stringArray(stateId: stateId, id: id, value: value)
        case let .integerArray(_, id, value):
            return .integerArray(stateId: stateId, id: id, value: value)
        case let .doubleArray(_, id, value):
            return .doubleArray(stateId: stateId, id: id, value: value)
        case let .booleanArray(_, id, value):
            return .booleanArray(stateId: stateId, id: id, value: value)
        case let .dataArray(_, id, value):
            return .dataArray(stateId: stateId, id: id, value: value)
        case let .dateArray(_, id, value):
            return .dateArray(stateId: stateId, id: id, value: value)
        case let .stateArray(_, id, value):
            return .stateArray(stateId: stateId, id: id, value: value)
        }
    }
}
