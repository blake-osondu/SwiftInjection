//
//  Operators_Ext.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/21/23.
//

import Foundation

precedencegroup ForwardApplication {
    associativity: left
}
precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication
}
precedencegroup BackwardsComposition {
    associativity: left
}
precedencegroup SingleTypeComposition {
    associativity: left
    higherThan: ForwardApplication
}
infix operator  |>: ForwardApplication

/// The infix Pipe forward operator place a value before the function and the function accepts the value
/// ex: 2 |> increment
/// - Parameters:
///   - a: Some value of any type 'A'
///   - f: fx (A) -> B
/// - Returns: Some value of any type 'B'
public func |> <A, B>(a: A, f: (A) -> B) -> B {
    return f(a)
}
/// A Single Pipe forward infix operator that expects only one type and returns void
///
/// - Parameters:
///   - a: Some variable value of any type 'A'
///   - f: (inout A) -> Void
public func |> <A>( a: inout A, f: (inout A) -> Void) -> Void {
    f(&a)
}

infix operator >>>: ForwardComposition

/// Forward Composition infix operator, proivide function composed of two functions
///
/// - Parameters:
///   - f: (A) -> B
///   - g: (B) -> C
/// - Returns: (A) -> C
public func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> (A) -> C {
    return { a in
        return g(f(a))
    }
}
infix operator <>: SingleTypeComposition

/// Single composition infix operator, utilizes single type
///
/// - Parameters:
///   - f: (A) -> A
///   - g: (A) -> A
/// - Returns: (A) -> A
public func <> <A>(f: @escaping (A) -> A, g: @escaping (A) -> A) -> (A) -> A {
    return f >>> g
}

/// Single composition infix operator utilizing inout value
///
/// - Parameters:
///   - f: (inout A) -> A
///   - g: (inout A) -> A
/// - Returns: (inout A) -> Void
public func <> <A>(f: @escaping (inout A) -> Void, g: @escaping (inout A) -> Void) -> (inout A) -> Void {
    return { a in
        f(&a)
        g(&a)
    }
}

infix operator <<<: BackwardsComposition

/// Backwards composition infix operator to simplify visualization of composition
///
/// - Parameters:
///   - g: (B) -> C
///   - f: (A) -> B
/// - Returns: (A) -> C
public func <<< <A, B, C>(g: @escaping (B) -> C, f: @escaping (A) -> B) -> (A) -> C {
    return { x in
        g(f(x))
    }
}
prefix operator ^

/// Keypath value getter prefix operator, fetches properties using key path
///
/// - Parameter kp: KeyPath<Root, Value>
/// - Returns: (Root) -> Value
public prefix func ^ <Root, Value>(kp: KeyPath<Root, Value>) -> (Root) -> Value {
    return get(kp)
}
