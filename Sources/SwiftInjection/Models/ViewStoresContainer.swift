//
//  ViewStoresContainer.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/26/23.
//

import Foundation

public struct ViewStoresContainer: Codable {
    var viewStores: [InjectedView] = []

    public init(viewStores: [InjectedView] = []) {
        self.viewStores = viewStores
    }
    public var entry: InjectedView? {
        viewStores.first(where: {$0.id == "entry"})
    }
}
