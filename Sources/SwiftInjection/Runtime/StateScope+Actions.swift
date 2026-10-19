//
//  StateScope+Actions.swift
//  SwiftInjection
//

import Foundation

extension StateScope {
    /// Runs an action list as one transaction: later actions see earlier writes, the store publishes once,
    /// and if any action fails nothing is applied (including scheduling of `delay` blocks).
    /// Errors are reported to the store.
    public func perform(_ actions: [InjectedAction]) {
        do {
            try performThrowing(actions)
        } catch {
            store.report(error)
        }
    }

    public func performThrowing(_ actions: [InjectedAction]) throws {
        var delayed: [(seconds: Double, actions: [InjectedAction])] = []
        try store.update { draft in
            try run(actions, on: &draft, delayed: &delayed)
        }
        for (seconds, actions) in delayed {
            schedule(actions, after: seconds)
        }
    }

    private func run(_ actions: [InjectedAction],
                     on draft: inout RuntimeValue,
                     delayed: inout [(seconds: Double, actions: [InjectedAction])]) throws {
        for action in actions {
            switch action {
            case let .set(path, expression):
                let value = try evaluator.evaluate(expression, in: DraftScope(root: draft, locals: locals))
                draft = draft.setting(value, at: try locals.writablePath(path.statePath))

            case let .if(condition, then, otherwise):
                let branch = try evaluator.condition(condition, in: DraftScope(root: draft, locals: locals))
                try run(branch ? then : otherwise, on: &draft, delayed: &delayed)

            case let .delay(seconds, actions):
                delayed.append((seconds, actions))

            case let .call(name, args):
                let scope = DraftScope(root: draft, locals: locals)
                let values = try args.map { try evaluator.evaluate($0, in: scope) }
                guard let function = store.functions[name] else {
                    throw EvaluationError.unknownFunction(name)
                }
                _ = try function(values, &draft)
            }
        }
    }

    private func schedule(_ actions: [InjectedAction], after seconds: Double) {
        let locals = self.locals
        let evaluator = self.evaluator
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak store] in
            guard let store else { return }
            var scope = StateScope(store: store, locals: locals)
            scope.evaluator = evaluator
            scope.perform(actions)
        }
    }
}
