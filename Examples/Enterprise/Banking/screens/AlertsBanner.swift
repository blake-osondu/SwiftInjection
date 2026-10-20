import SwiftUI
import SwiftInjectionAuthoring

// A remote fragment inside the native Accounts screen: operations can announce maintenance or incidents in
// minutes. Shown only while the `maintenance_notice` feature flag is on.

struct AlertsBanner: View {
    var body: some View {
        if hostValue("featureEnabled", "maintenance_notice", placeholder: true) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.orange)
                Text("Scheduled maintenance Sunday 2–4 AM ET. Transfers made then may arrive late.")
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(12)
        }
    }
}
