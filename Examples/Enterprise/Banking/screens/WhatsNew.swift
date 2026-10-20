import SwiftUI
import SwiftInjectionAuthoring
import DesignSystem

// Release notes shown as a sheet after sign-in; product updates the copy without an app release.

struct WhatsNew: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's new")
                .font(.largeTitle)
                .bold()
            Feature(symbol: "bolt.fill", title: "Instant transfers", text: "Money between your Northwind accounts now arrives immediately.", tint: .orange)
            Feature(symbol: "chart.pie.fill", title: "Spending insights", text: "See where your money goes each month, by category.", tint: .purple)
            Feature(symbol: "lock.fill", title: "Card controls", text: "Freeze and unfreeze cards from the app in one tap.", tint: .green)
            Spacer()
            PrimaryButton(title: "Continue") { hostAction("dismissWhatsNew") }
        }
        .padding(24)
    }
}

struct Feature: View {
    let symbol: String
    let title: String
    let text: String
    var tint: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundColor(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundColor(.gray)
            }
        }
    }
}
