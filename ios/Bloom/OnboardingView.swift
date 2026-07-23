// OnboardingView.swift — say hi → account (optional) → name → plant the first skill.
// Port of maybeOnboard() in main.js.
import SwiftUI

struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Bindable var store: AppStore

    @State private var step = 0            // 0 account · 1 code · 2 name · 3 first plant
    @State private var email = ""
    @State private var code = ""
    @State private var busy = false
    @State private var message = ""
    @State private var name = ""
    @State private var skillName = ""
    @State private var species = "bloom"
    @State private var previewColor = PALETTE[0]

    private static let suggestions = ["Math", "Reading", "Piano", "Spanish", "Gym", "Art", "Coding"]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 40)
                    PlantView(spec: PlantSpec(id: step == 3 ? "onboard-first" : "onboard-plant", colorHex: previewColor, species: step == 3 ? species : nil),
                              level: step == 3 ? (skillName.isEmpty ? 1 : 2) : 8, sway: true)
                        .frame(height: 130)
                    switch step {
                    case 0: accountStep
                    case 1: codeStep
                    case 2: nameStep
                    default: plantStep
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if !Cloud.configured || CloudSync.shared.signedIn { step = 2 }
        }
    }

    // MARK: step 0 — account first, the garden follows you everywhere

    private var accountStep: some View {
        VStack(spacing: 12) {
            BloomTitle(prefix: "Welcome to ", em: "Bloom", size: 25)
            Text("Your focus grows a garden — and an account keeps it safe on every device. Plants, tasks, calendar, notes and your name, always with you.")
                .font(.quicksand(13.5)).foregroundColor(theme.muted)
                .multilineTextAlignment(.center)
            TextField("you@example.com", text: $email)
                .textFieldStyle(BloomFieldStyle())
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(busy ? "Sending your code…" : "Create account / Sign in") {
                sendCode()
            }
            .buttonStyle(PillButtonStyle(kind: .primaryBig))
            .disabled(busy)
            if !message.isEmpty {
                Text(message).font(.quicksand(12)).foregroundColor(theme.coralStrong)
            }
            Button("just try it first — no account yet") { step = 2 }
                .buttonStyle(.plain)
                .font(.quicksandBold(12.5))
                .foregroundColor(theme.olive2)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 12) {
            BloomTitle(prefix: "Check your ", em: "email", size: 25)
            Text("We wrote to \(email) — type the code from it here.")
                .font(.quicksand(13.5)).foregroundColor(theme.muted)
                .multilineTextAlignment(.center)
            TextField("code from your email", text: $code)
                .textFieldStyle(BloomFieldStyle())
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
            Button(busy ? "Checking…" : "Sign in") { verify() }
                .buttonStyle(PillButtonStyle(kind: .primaryBig))
                .disabled(busy)
            if !message.isEmpty {
                Text(message).font(.quicksand(12)).foregroundColor(theme.coralStrong)
            }
            Button("different email") { step = 0; message = "" }
                .buttonStyle(.plain)
                .font(.quicksandBold(12.5))
                .foregroundColor(theme.olive2)
        }
    }

    // MARK: step 2 — name

    private var nameStep: some View {
        VStack(spacing: 12) {
            BloomTitle(prefix: "Welcome to ", em: "Bloom", size: 25)
            Text("Tasks, calendar, notes and a focus timer — all feeding one little garden. Do the work, and watch your skills grow, level by level.")
                .font(.quicksand(13.5)).foregroundColor(theme.muted)
                .multilineTextAlignment(.center)
            TextField("What should we call you?", text: $name)
                .textFieldStyle(BloomFieldStyle())
                .onSubmit(nextFromName)
            Button("Next") { nextFromName() }
                .buttonStyle(PillButtonStyle(kind: .primaryBig))
        }
    }

    private func nextFromName() {
        store.state.settings.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "friend" : name.trimmingCharacters(in: .whitespaces)
        store.save(silent: true)
        step = 3
    }

    // MARK: step 3 — first plant

    private var plantStep: some View {
        VStack(spacing: 12) {
            BloomTitle(prefix: "Plant your first ", em: "plant", size: 24)
            Text("What do you want to spend more time on, \(store.state.settings.name)? Every minute you give it makes this little plant grow.")
                .font(.quicksand(13.5)).foregroundColor(theme.muted)
                .multilineTextAlignment(.center)
            FlowChips(spacing: 6) {
                ForEach(Self.suggestions, id: \.self) { s in
                    Button {
                        skillName = s
                        Sfx.shared.click()
                    } label: {
                        Chip(text: s, selected: skillName == s)
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("e.g. Piano, Math, Spanish…", text: $skillName)
                .textFieldStyle(BloomFieldStyle())
            HStack(spacing: 6) {
                ForEach(PLANT_SPECIES, id: \.key) { key, label in
                    Button {
                        species = key
                        Sfx.shared.click()
                    } label: {
                        VStack(spacing: 2) {
                            PlantView(spec: PlantSpec(id: "ob-\(key)", colorHex: previewColor, species: key), level: 6)
                                .frame(height: 40)
                            Text(label).font(.quicksand(9)).foregroundColor(theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(species == key ? theme.oliveSoft : theme.card2.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(species == key ? theme.olive : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                finish(skillName.trimmingCharacters(in: .whitespaces))
            } label: {
                HStack(spacing: 6) { Ic(name: "pot", size: 14); Text("Plant it") }
            }
            .buttonStyle(PillButtonStyle(kind: .primaryBig))
            Button("skip for now") { finish(nil) }
                .buttonStyle(.plain)
                .font(.quicksandBold(12.5))
                .foregroundColor(theme.olive2)
        }
    }

    // MARK: plumbing

    private func sendCode() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard e.contains("@"), e.contains(".") else { Sfx.shared.uhoh(); return }
        email = e
        busy = true
        message = ""
        Task {
            do {
                try await CloudSync.shared.requestCode(email: e)
                busy = false
                step = 1
            } catch {
                message = error.localizedDescription
                busy = false
            }
        }
    }

    private func verify() {
        let c = code.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { Sfx.shared.uhoh(); return }
        busy = true
        message = "Checking…"
        Task {
            do {
                try await CloudSync.shared.verifyCode(email: email, code: c)
                Sfx.shared.chime()
                busy = false
                message = ""
                // returning gardener — their whole garden just came down from the cloud
                if !store.state.settings.name.isEmpty || !store.state.skills.isEmpty {
                    store.state.settings.onboarded = true
                    store.save()
                    store.toast("Welcome back\(store.state.settings.name.isEmpty ? "" : ", " + store.state.settings.name)!", "flower")
                } else {
                    step = 2
                }
            } catch {
                message = error.localizedDescription
                busy = false
            }
        }
    }

    private func finish(_ skill: String?) {
        store.state.settings.onboarded = true
        if let skill, !skill.isEmpty {
            let pretty = skill.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
            _ = store.addSkill(name: pretty, icon: guessIcon(pretty), color: store.nextColor(), species: species, quiet: true)
            store.toast("\(pretty) planted! Focus on it to make it grow", "pot")
        } else {
            store.toast("Welcome, \(store.state.settings.name)!", "flower")
        }
        store.save()
    }
}
