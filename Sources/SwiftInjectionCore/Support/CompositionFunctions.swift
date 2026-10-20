//
//  CompositionFunctions.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/21/23.
//

import Foundation

/// Curry function to compose functions
///
/// - Parameter f: (A,B) ->
/// - Returns: (A) -> (B) -> C
public func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    return { a in { b in f(a, b) } }
}
/// Flip curried function
///
/// - Parameter f: (A) -> (B) -> C
/// - Returns: (B) -> (A) -> C
public func flip<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C {
    return { b in { a in f(a)(b) } }
}
/// Flips curried function composed of only two types
///
/// - Parameter f: (A) -> () -> C
/// - Returns: () -> (A) -> C
public func flip<A, C>(_ f: @escaping (A) -> () -> C) -> () -> (A) -> C {
    return { { a in f(a)() } }
}
/// Resolves a void parameter function into a value
///
/// - Parameter f: () -> A
/// - Returns: A
public func zurry<A>(_ f: () -> A) -> A {
    return f()
}
/// Maps a generic type
///
/// - Parameter f: (A) -> B
/// - Returns: ([A]) -> [B]
public func map<A, B>(_ f: @escaping (A) -> B) -> ([A]) -> [B] {
    return { $0.map(f) }
}
public func forEach<A>(_ f: @escaping (A) -> Void) -> ([A]) -> Void {
    return { sequence in
        sequence.forEach { f($0) }
    }
}
public func reduce<A,B>(_ initial: B, _ f: @escaping (B, A) -> B) -> ([A]) -> B {
    var accum: B = initial
    return { array in
        array.forEach({ (a) in
            accum = f(accum, a)
        })
        return accum
    }
}
/// Filters a generic type, using generic evaluation
///
/// - Parameter p: (A) -> Bool
/// - Returns: ([A]) -> [A]
public func filter<A>(_ p: @escaping (A) -> Bool) -> ([A]) -> [A] {
    return { $0.filter(p) }
}
/// Fetches and modifies properties of root
///
/// - Parameter kp: WritableKeyPath<Root, Value>
/// - Returns: (Value) -> Value -> (Root) -> Root
public func prop<Root, Value>(_ kp: WritableKeyPath<Root, Value>)
    -> (@escaping (Value) -> Value)
    -> (Root)
    -> Root {
        return { update in
            { root in
                var copy = root
                copy[keyPath: kp] = update(copy[keyPath: kp])
                return copy
            }
        }
}
/// Fetches a value of type using key path
///
/// - Parameter kp: KeyPath<Root, Value>
/// - Returns: (Root) -> Value
public func get<Root, Value>(_ kp: KeyPath<Root, Value>) -> (Root) -> Value {
    return { root in
        root[keyPath: kp]
    }
}
/// Fetches properties of a types, evaluates values
///
/// - Parameters:
///   - f: (Root) -> Value
///   - g: (Value, Value) -> Bool
/// - Returns: (Root, Root) -> Bool
public func their<Root, Value>(
    _ f: @escaping (Root) -> Value,
    _ g: @escaping (Value, Value) -> Bool
    )
    -> (Root, Root)
    -> Bool {
        return { g(f($0), f($1)) }
}
/// Given Root value comparison for sorting
///
/// - Parameter f: (Root) -> Value
/// - Returns: (Root, Root) -> Bool
public func their<Root, Value: Comparable>(
    _ f: @escaping (Root) -> Value
    )
    -> (Root, Root)
    -> Bool {
        return their(f, <)
}
/// Provide value combined from properties of root
///
/// - Parameters:
///   - f: (Root) -> Value
///   - g: (Value, Value) -> Value
/// - Returns: (Value, Root) -> Value
public func combining<Root, Value>(
    _ f: @escaping (Root) -> Value,
    by g: @escaping (Value, Value) -> Value
    )
    -> (Value, Root)
    -> Value {
        return { value, root in
            g(value, f(root)) }
}
