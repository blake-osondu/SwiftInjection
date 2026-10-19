//
//  Insertable.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/16/23.
//

import Foundation
import SwiftUI
import WebKit
import Combine

public struct Insertable: View {
    
    var stateSignal: StateSignal
    var container: ViewStoresContainer
    var viewStore: InjectedView
    
    public init(stateSignal: StateSignal, container: ViewStoresContainer, viewStore: InjectedView) {
        self.stateSignal = stateSignal
        self.container = container
        self.viewStore = viewStore
    }
    
    @ViewBuilder var render: some View {
        switch viewStore {
            
        case .vStack(let viewStore):
            
            VStackInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .hStack(let viewStore):
            
            HStackInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .zStack(let viewStore):
            
            ZStackInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .list(let viewStore):
            
            ListInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .forEach(let viewStore):
            
            ForEachInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .button(let viewStore):
            
            ButtonInsertable(container: container, store: .init(viewStore: viewStore, stateSignal: stateSignal))
            
        case .text(let viewStore):
            TextInsertable(viewStore: viewStore)

        case .field(let viewStore):
            
            TextFieldInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .secureField(let viewStore):
            
            SecureFieldInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .label(let viewStore):
            LabelInsertable(viewStore: viewStore)

        case .image(let viewStore):
            ImageInsertable(viewStore: viewStore)

        case .tab(let viewStore):
            
            TabInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .navigationStack(let viewStore):
            
            NavigationStackInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .navigationLink(let viewStore):
            
            NavigationLinkInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .color(let viewStore):
            ColorInsertable(viewStore: viewStore)

        case .rectangle(let viewStore):
            RectangleInsertable(viewStore: viewStore)

        case .roundedRectangle(let viewStore):
            RoundedRectangleInsertable(viewStore: viewStore)

        case .circle(let viewStore):
            CircleInsertable(viewStore: viewStore)

        case .ellipse(let viewStore):
            EllipseInsertable(viewStore: viewStore)

        case .capsule(let viewStore):
            CapsuleInsertable(viewStore: viewStore)

        case .spacer(let viewStore):
            SpacerInsertable(viewStore: viewStore)

        case .divider(let viewStore):
            DividerInsertable(viewStore: viewStore)

        case .if(let viewStore):
            
            IfInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .viewStoreReference(let id):
            
            if let viewStore = container.viewStores.first(where: {$0.id == id })  {
                Insertable(stateSignal: stateSignal, container: container, viewStore: viewStore)
            }
            
        case .empty:
            
            EmptyView()
            
        case let .lazyVStack(viewStore):
            
            LazyVStackInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case let .lazyHStack(viewStore):
            
            LazyHStackInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case let .grid(viewStore):
            
            GridInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case let .gridRow(viewStore):
            
            GridRowInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case let .lazyHGrid(viewStore):
            
            LazyHGridInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
        
        case .lazyVGrid(viewStore: let viewStore):
            
            LazyVGridInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .progressView(viewStore: let viewStore):
            
            ProgressViewInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .standardTable(viewStore: let viewStore):
            
            StandardTableInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .customTable(viewStore: let viewStore):
            
            CustomTableInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .group(viewStore: let viewStore):
            
            GroupInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .controlGroup(viewStore: let viewStore):
            
            ControlGroupInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .form(viewStore: let viewStore):
            
            FormInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .section(viewStore: let viewStore):
            
            SectionInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .geometryReader(viewStore: let viewStore):
            
            GeometryReaderInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .picker(viewStore: let viewStore):
            
            PickerInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .datePicker(viewStore: let viewStore):
            
            DatePickerInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .scrollView(viewStore: let viewStore):
            
            ScrollViewInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
        }
    }
    
    public var body: some View {
        render
            .environment(\.viewContainer, container)
            .environment(\.legacyStateSignal, stateSignal)
    }
}
