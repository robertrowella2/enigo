import SwiftUI
import UIKit
import UserNotifications

/// Settings — Identity, Matching (LGBTQ+ preference, location, radius,
/// "Order: closest first"), Notifications (messages/unlocks, everything
/// else off always), Account.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    private let radii = [25, 50, 100]
    private let genderOptions = [
        ("men", "Men"), ("women", "Women"), ("nonbinary", "Nonbinary"), ("anyone", "Anyone"),
    ]
    private let communityOptions = [
        ("in_community", "Match me inside the community"),
        ("open", "It matters but I'm open either way"),
        ("not_looking", "Not what I'm looking for"),
        ("rather_not_say", "Rather not say"),
    ]
    @State private var notificationsEnabled = false

    var body: some View {
        EnigoScreen {
            HStack {
                Button(action: { appState.openDashboard() }) {
                    Image(systemName: "chevron.left").foregroundStyle(EnigoColor.body(scheme))
                }
                Spacer()
            }
            ScreenTitle(text: "Settings")

            if let profile = appState.ownProfile {
                section("MATCHING") {
                    // These were set once during onboarding and then had no
                    // way to change. Someone who picked narrowly, or changed
                    // their mind, got no matches for as long as nobody fit —
                    // and the searching screen is where they were left.
                    Text("Match me with").font(EnigoFont.meta).foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                    HStack(spacing: 8) {
                        ForEach(genderOptions, id: \.0) { value, label in
                            SelectableChip(text: label, selected: profile.matchWith.contains(value)) {
                                Task { await appState.patchProfile(ProfilePatch(matchWith: toggled(profile.matchWith, value))) }
                            }
                        }
                    }
                    Text("Show me to").font(EnigoFont.meta).foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                    HStack(spacing: 8) {
                        ForEach(genderOptions, id: \.0) { value, label in
                            SelectableChip(text: label, selected: profile.shownTo.contains(value)) {
                                Task { await appState.patchProfile(ProfilePatch(shownTo: toggled(profile.shownTo, value))) }
                            }
                        }
                    }

                    ForEach(communityOptions, id: \.0) { value, label in
                        SelectableRow(text: label, selected: profile.community == value) {
                            Task { await appState.patchProfile(ProfilePatch(community: value)) }
                        }
                    }
                    Text("Order: closest first").font(EnigoFont.meta).foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                    HStack(spacing: 8) {
                        ForEach(radii, id: \.self) { radius in
                            SelectableChip(text: "\(radius) km", selected: profile.radiusKm == radius) {
                                Task { await appState.patchProfile(ProfilePatch(radiusKm: radius)) }
                            }
                        }
                    }
                }

                section("NOTIFICATIONS") {
                    Toggle(isOn: Binding(
                        get: { profile.notifyMatches },
                        set: { v in Task { await appState.patchProfile(ProfilePatch(notifyMatches: v)) } }
                    )) { Text("New matches").font(EnigoFont.body) }
                    Toggle(isOn: Binding(
                        get: { profile.notifyMessages },
                        set: { v in Task { await appState.patchProfile(ProfilePatch(notifyMessages: v)) } }
                    )) { Text("Messages").font(EnigoFont.body) }
                    Toggle(isOn: Binding(
                        get: { profile.notifyUnlocks },
                        set: { v in Task { await appState.patchProfile(ProfilePatch(notifyUnlocks: v)) } }
                    )) { Text("Unlock moments").font(EnigoFont.body) }
                    Text("Everything else — Off, always").font(EnigoFont.meta).foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                    // Onboarding only asks for push permission once — if it
                    // was skipped, or a device token never made it to the
                    // server for any reason, this is the only other place
                    // to (re-)trigger it, so it's not stuck forever. Once
                    // granted there's nothing more to do (no way to revoke
                    // from within the app anyway — that's an OS Settings
                    // thing), so the button goes inert rather than staying
                    // tappable forever.
                    PrimaryButton(
                        title: notificationsEnabled ? "Notifications enabled" : "Enable notifications on this device",
                        disabled: notificationsEnabled
                    ) {
                        Task {
                            let granted = (try? await UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                            if granted {
                                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
                                notificationsEnabled = true
                            }
                        }
                    }
                }
            }

            section("ACCOUNT") {
                SecondaryLink(title: "Subscription") { appState.openSubscription() }
                SecondaryLink(title: "Send feedback") { appState.step = .feedback }
                SecondaryLink(title: "Change phone number") { appState.step = .changePhone }
                SecondaryLink(title: "Recovery email") { appState.step = .recoveryEmail }
                SecondaryLink(title: "Sign-in help") { appState.step = .signInHelp }
                SecondaryLink(title: "Sign out") { Task { await appState.signOut() } }
                Button("Delete account") { appState.step = .deleteAccountConfirm }
                    .font(EnigoFont.body)
                    .foregroundStyle(EnigoColor.danger(scheme))
            }

            section("LEGAL") {
                SecondaryLink(title: "Terms of Service") { appState.presentedLegalDocument = .terms }
                SecondaryLink(title: "Privacy Policy") { appState.presentedLegalDocument = .privacy }
            }
        }
        .task {
            await appState.loadOwnProfile()
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsEnabled = settings.authorizationStatus == .authorized
        }
    }

    /// Never lets the list empty out — a profile matching nobody is how
    /// someone ends up stuck on the searching screen indefinitely.
    private func toggled(_ current: [String], _ value: String) -> [String] {
        var next = Set(current)
        if next.contains(value) { next.remove(value) } else { next.insert(value) }
        return next.isEmpty ? [value] : Array(next)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title)
            content()
        }
        .padding(.top, 8)
    }
}
