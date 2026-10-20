import SwiftUI
import Networking
import DesignSystem

/// Holds the signed-in session.
@MainActor
public final class AuthService: ObservableObject {
    @Published public private(set) var session: UserSession?
    private let api: BankAPI

    public init(api: BankAPI) { self.api = api }

    public func login(username: String, password: String) async throws {
        session = try await api.login(username: username, password: password)
    }

    public func logout() { session = nil }
}

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var username = ""
    @Published public var password = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    private let auth: AuthService

    public init(auth: AuthService) { self.auth = auth }

    public var canSubmit: Bool { !username.isEmpty && !password.isEmpty && !isLoading }

    public func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await auth.login(username: username, password: password)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Native sign-in. Authentication never goes through a payload.
public struct LoginView: View {
    @StateObject private var model: LoginViewModel

    public init(auth: AuthService) {
        _model = StateObject(wrappedValue: LoginViewModel(auth: auth))
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.brand)
            Text("Northwind Bank").font(.largeTitle.bold())
            VStack(spacing: 12) {
                TextField("Username", text: $model.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $model.password)
                    .textContentType(.password)
            }
            .textFieldStyle(.roundedBorder)
            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
            PrimaryButton(title: model.isLoading ? "Signing in…" : "Sign in") {
                Task { await model.submit() }
            }
            .disabled(!model.canSubmit)
            Text("Demo: any username, a password of 4+ characters.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
