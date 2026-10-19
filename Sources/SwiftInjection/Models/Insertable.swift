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
            VStackInsertable(viewStore: viewStore)

        case .hStack(let viewStore):
            HStackInsertable(viewStore: viewStore)

        case .zStack(let viewStore):
            ZStackInsertable(viewStore: viewStore)

        case .list(let viewStore):
            
            ListInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .forEach(let viewStore):
            
            ForEachInsertable(
                store: .init(viewStore: viewStore, stateSignal: stateSignal),
                container: container)
            
        case .button(let viewStore):
            ButtonInsertable(viewStore: viewStore)

        case .text(let viewStore):
            TextInsertable(viewStore: viewStore)

        case .field(let viewStore):
            TextFieldInsertable(viewStore: viewStore)

        case .secureField(let viewStore):
            SecureFieldInsertable(viewStore: viewStore)

        case .label(let viewStore):
            LabelInsertable(viewStore: viewStore)

        case .image(let viewStore):
            ImageInsertable(viewStore: viewStore)

        case .tab(let viewStore):
            TabInsertable(viewStore: viewStore)

        case .navigationStack(let viewStore):
            NavigationStackInsertable(viewStore: viewStore)

        case .navigationLink(let viewStore):
            NavigationLinkInsertable(viewStore: viewStore)

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
            
        case .lazyVStack(let viewStore):
            VStackInsertable(viewStore: viewStore, lazy: true)

        case .lazyHStack(let viewStore):
            HStackInsertable(viewStore: viewStore, lazy: true)

        case .grid(let viewStore):
            GridInsertable(viewStore: viewStore)

        case .gridRow(let viewStore):
            GridRowInsertable(viewStore: viewStore)

        case .lazyHGrid(let viewStore):
            LazyHGridInsertable(viewStore: viewStore)

        case .lazyVGrid(let viewStore):
            LazyVGridInsertable(viewStore: viewStore)

        case .progressView(let viewStore):
            ProgressViewInsertable(viewStore: viewStore)

        case .standardTable(viewStore: let viewStore):
            
            StandardTableInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .customTable(viewStore: let viewStore):
            
            CustomTableInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .group(let viewStore):
            GroupInsertable(viewStore: viewStore)

        case .controlGroup(let viewStore):
            ControlGroupInsertable(viewStore: viewStore)

        case .form(let viewStore):
            FormInsertable(viewStore: viewStore)

        case .section(let viewStore):
            SectionInsertable(viewStore: viewStore)

        case .geometryReader(viewStore: let viewStore):
            
            GeometryReaderInsertable(store: .init(viewStore: viewStore, stateSignal: stateSignal), container: container)
            
        case .picker(let viewStore):
            PickerInsertable(viewStore: viewStore)

        case .datePicker(let viewStore):
            DatePickerInsertable(viewStore: viewStore)

        case .scrollView(let viewStore):
            ScrollViewInsertable(viewStore: viewStore)

        }
    }
    
    public var body: some View {
        render
            .environment(\.viewContainer, container)
            .environment(\.legacyStateSignal, stateSignal)
    }
}
