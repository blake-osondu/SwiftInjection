import SwiftUI
import SwiftInjectionAuthoring

// The whole event page, served remotely. Edit the details, agenda or form and publish: the app picks it up
// without a release. Compiled by Examples/scripts/publish-local.sh.

struct Session: Identifiable {
    var id = UUID()
    var time: String
    var title: String
    var speaker = ""
}

struct EventScreen: View {
    @State private var startsAt = "2026-11-19T18:00:00-05:00"
    @State private var agenda = [
        Session(time: "6:00", title: "Doors open, pizza"),
        Session(time: "6:30", title: "Shipping SwiftUI without waiting on review", speaker: "Blake O."),
        Session(time: "7:15", title: "Lightning talks"),
    ]
    @State private var name = ""
    @State private var email = ""
    @State private var guests = 0
    @State private var guestOptions = [0, 1, 2, 3]
    @State private var diet = "none"
    @State private var wantsUpdates = true
    @State private var confirming = false
    @State private var isGoing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SwiftUI Meetup")
                            .font(.title)
                            .bold()
                        Label("Thursday, Nov 19 · 6:00 PM", systemImage: "calendar")
                        Label("The Foundry, 12 Main St", systemImage: "mappin.and.ellipse")
                        Text(script("countdown", startsAt))
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }

                Section("Agenda") {
                    ForEach(agenda) { session in
                        HStack(alignment: .top, spacing: 12) {
                            Text(session.time)
                                .monospacedDigit()
                                .foregroundColor(.gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                if !session.speaker.isEmpty {
                                    Text(session.speaker)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }

                if isGoing {
                    Section {
                        Label("You're going, \(name)! We'll see you there.", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Button("Change my RSVP") { isGoing = false }
                    }
                } else {
                    Section("RSVP") {
                        TextField("Name", text: $name)
                        TextField("Email", text: $email)
                        Picker("Guests", selection: $guests) {
                            ForEach(guestOptions, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        Picker("Dietary needs", selection: $diet) {
                            Text("None").tag("none")
                            Text("Vegetarian").tag("vegetarian")
                            Text("Vegan").tag("vegan")
                            Text("Gluten-free").tag("gluten-free")
                        }
                        Toggle("Email me updates", isOn: $wantsUpdates)
                        Button("RSVP") { confirming = true }
                            .disabled(name.isEmpty || email.isEmpty)
                    }
                }
            }
            .navigationTitle("You're invited")
            .alert("Confirm your RSVP", isPresented: $confirming) {
                Button("Confirm") {
                    isGoing = true
                    hostAction("submitRSVP", name, email, guests, diet, wantsUpdates)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("We'll save a spot for you and \(guests) guest(s).")
            }
        }
    }
}
