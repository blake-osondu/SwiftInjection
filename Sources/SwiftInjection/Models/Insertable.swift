//
//  Insertable.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/16/23.
//

import SwiftUI
import SwiftInjectionCore

/// Dispatches a payload view to its component. Use `InjectedContent` to render a child.
struct Insertable: View {
    let viewStore: InjectedView
    @Environment(\.injectedViews) private var views
    @Environment(\.stateStore) private var store

    var body: some View {
        switch viewStore {
        case .vStack(let viewStore):
            VStackInsertable(viewStore: viewStore)
        case .hStack(let viewStore):
            HStackInsertable(viewStore: viewStore)
        case .zStack(let viewStore):
            ZStackInsertable(viewStore: viewStore)
        case .list(let viewStore):
            ListInsertable(viewStore: viewStore)
        case .forEach(let viewStore):
            ForEachInsertable(viewStore: viewStore)
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
            IfInsertable(viewStore: viewStore)
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
        case .table(let viewStore):
            TableInsertable(viewStore: viewStore)
        case .group(let viewStore):
            GroupInsertable(viewStore: viewStore)
        case .controlGroup(let viewStore):
            ControlGroupInsertable(viewStore: viewStore)
        case .form(let viewStore):
            FormInsertable(viewStore: viewStore)
        case .section(let viewStore):
            SectionInsertable(viewStore: viewStore)
        case .geometryReader(let viewStore):
            GeometryReaderInsertable(viewStore: viewStore)
        case .picker(let viewStore):
            PickerInsertable(viewStore: viewStore)
        case .datePicker(let viewStore):
            DatePickerInsertable(viewStore: viewStore)
        case .scrollView(let viewStore):
            ScrollViewInsertable(viewStore: viewStore)
        case .custom(let viewStore):
            CustomInsertable(viewStore: viewStore)
        case .viewStoreReference(let id):
            if let view = views[id] {
                InjectedContent(view)
            } else {
                let _ = store.report(EvaluationError.unknownVariable("view '\(id)'"))
            }
        case .empty:
            EmptyView()
        case .unsupported(let name, _):
            let _ = store.report(PayloadError.invalid("Component '\(name)' isn't supported by this version"))
        }
    }
}
