import SwiftUI

/// The bank's design system. Native screens use these directly; remote screens use them as registered
/// SwiftInjection components, so both look the same.
public enum Theme {
    public static let brand = Color(red: 0.07, green: 0.29, blue: 0.62)
    public static let cardGradient = LinearGradient(colors: [brand, Color(red: 0.11, green: 0.49, blue: 0.82)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// An account card.
public struct BankCard: View {
    let name: String
    let last4: String
    let balance: Decimal

    public init(name: String, last4: String, balance: Decimal) {
        self.name = name
        self.last4 = last4
        self.balance = balance
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Text("•••• \(last4)").font(.subheadline.monospacedDigit())
            }
            AmountText(amount: balance, style: .large)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The primary call to action.
public struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brand)
        .controlSize(.large)
    }
}

/// A currency amount: green for credits, monospaced digits.
public struct AmountText: View {
    public enum Style { case regular, large }
    let amount: Decimal
    let style: Style

    public init(amount: Decimal, style: Style = .regular) {
        self.amount = amount
        self.style = style
    }

    public var body: some View {
        Text(amount, format: .currency(code: "USD"))
            .font(style == .large ? .largeTitle.weight(.semibold).monospacedDigit() : .body.monospacedDigit())
            .foregroundStyle(style == .regular && amount > 0 ? Color.green : Color.primary)
    }
}
