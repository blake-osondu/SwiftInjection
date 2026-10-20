//
//  Array_Ext.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 9/5/23.
//

import Foundation

typealias TenLengthTuple<T> = (T, T?, T?, T?, T?, T?, T?, T?, T?, T?)
public extension Array {
    
    func itemAtIndex(index: Int) -> Self.Element? {
        if count > index {
            return self[index]
        } else {
            return nil
        }
    }
    
    func appending(_ item: Element) -> Array {
        var copy = self
        copy.append(item)
        return copy
    }
    
    var second: Element? {
        itemAtIndex(index: 1)
    }
    var third: Element? {
        itemAtIndex(index: 2)
    }
    var fourth: Element? {
        itemAtIndex(index: 3)
    }
    var fifth: Element? {
        itemAtIndex(index: 4)
    }
    var sixth: Element? {
        itemAtIndex(index: 5)
    }
    var seventh: Element? {
        itemAtIndex(index: 6)
    }
    var eigth: Element? {
        itemAtIndex(index: 7)
    }
    var ninth: Element? {
        itemAtIndex(index: 8)
    }
    var tenth: Element? {
        itemAtIndex(index: 9)
    }
    func toTenLengthTuple() -> (Element, Element?, Element?, Element?, Element?,
                                Element?, Element?, Element?, Element?, Element?) {
        precondition(self.count >= 1)
        
        return (first!, second, third, fourth, fifth, sixth, seventh, eigth, ninth, tenth)
    }
    
}

