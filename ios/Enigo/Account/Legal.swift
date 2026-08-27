import Foundation

/// Placeholder-but-shippable legal copy. This has NOT been reviewed by an
/// attorney — in particular the AI-assisted-matching disclosure in
/// `LegalContent.termsSections` (Terms §3) touches a live regulatory area
/// (several US states now require clear disclosure when a user is
/// conversing with an AI in a way that could be mistaken for a human) and
/// should get real legal review before this ships to the App Store.
enum LegalDocument: String, Identifiable, Equatable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .terms: return LegalContent.termsSections
        case .privacy: return LegalContent.privacySections
        }
    }
}

struct LegalSection: Identifiable {
    let heading: String
    let body: String
    var id: String { heading }
}

enum LegalContent {
    static let lastUpdated = "August 22, 2026"
    static let contactEmail = "enigoapp@gmail.com"

    static let termsSections: [LegalSection] = [
        LegalSection(heading: "Eligibility", body:
            "You must be at least 18 years old to use Enigo. By using the app you represent that you are 18 or older and have the legal capacity to enter into these Terms."),
        LegalSection(heading: "Your Account", body:
            "You're responsible for the accuracy of the information you provide and for keeping your account secure. You may not create more than one account, impersonate another person, or use a photo that isn't genuinely of you."),
        LegalSection(heading: "How Matching Works, Including AI-Assisted Conversations", body:
            "Enigo pairs you with one match at a time and reveals more about them gradually, as your conversation progresses. Two important things to know:\n\n" +
            "Automatic upgrades — if you're placed with a match and a better or more compatible real person becomes available, Enigo may end that match and connect you with the new one automatically.\n\n" +
            "AI conversational partner — when no compatible real person is available yet, Enigo may temporarily connect you with an AI-generated conversational partner rather than leave you with nothing to do. This partner is not a real person — it is software designed to hold a conversation in a similar style to how a real match would. Enigo automatically ends this AI-assisted match and replaces it with a real person as soon as one becomes available, at no cost to you and without losing your progress toward that match's unlocks. You can turn off AI-assisted matching in Settings."),
        LegalSection(heading: "Acceptable Use", body:
            "You agree not to:\n\n" +
            "• Send phone numbers, external contact handles, or images/photos through in-app messages (the app automatically blocks these to keep the early conversation focused, and repeated attempts to bypass this may result in suspension)\n" +
            "• Harass, threaten, or send unwanted sexual content to another user\n" +
            "• Use the app for any commercial solicitation, scam, or fraud\n" +
            "• Misrepresent your age, identity, or intentions\n\n" +
            "Violations may result in warnings, suspension, or permanent account termination, and are reportable in-app."),
        LegalSection(heading: "Content You Share", body:
            "You retain ownership of the photos, bio, and messages you provide. You grant Enigo a limited license to store, transmit, and display that content solely to operate the matching and messaging features of the app for you and your matches."),
        LegalSection(heading: "Subscriptions & Purchases", body:
            "Enigo offers optional paid features (an ongoing subscription tier and one-time boosts), billed through the Apple App Store. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period, and are managed through your Apple ID settings, not within the app. Prices are shown at time of purchase and may vary by region. No refunds are provided by Enigo directly; refund requests go through Apple per its standard policies."),
        LegalSection(heading: "Safety and Meeting in Person", body:
            "Enigo is not a background-check, identity-verification, or safety-screening service, and we do not investigate, endorse, or guarantee any user. You are solely responsible for your own safety and conduct in your interactions with other users, including any decision to communicate outside the app or to meet someone in person.\n\n" +
            "If you choose to meet another user in person, you do so entirely at your own risk. We strongly recommend meeting in a public place, telling a friend or family member where you're going and who you're meeting, arranging your own transportation, and never sending money or financial information to someone you haven't met in person and verified.\n\n" +
            "To the fullest extent permitted by law, Enigo and its operators are not responsible or liable for the conduct of any user, on or off the app, and are not liable for any injury, loss, or damage of any kind — including personal injury, death, or property loss — arising from your interactions with other users or from meeting in person, including if someone's identity, statements, or conduct turns out to be different from what they represented in the app.\n\n" +
            "Report any user who makes you feel unsafe, and contact local law enforcement immediately if you are ever in danger."),
        LegalSection(heading: "Termination", body:
            "You may delete your account at any time from Settings, which permanently removes your profile, matches, and message history. We may suspend or terminate your account for violating these Terms or applicable law."),
        LegalSection(heading: "Disclaimers", body:
            "The app is provided \u{201c}as is.\u{201d} Enigo does not guarantee you will find a match, that any match will meet your expectations, or that the app will be uninterrupted or error-free."),
        LegalSection(heading: "Limitation of Liability", body:
            "To the fullest extent permitted by law, Enigo and its operators are not liable for any indirect, incidental, special, or consequential damages, or for any injury, death, or loss of any kind, arising from your use of the app — including your interactions with other users, any in-person meeting arranged through the app, or the AI-assisted matching feature described above. This applies whether the claim is based on warranty, contract, tort (including negligence), or any other legal theory, and whether or not Enigo has been advised of the possibility of such damages."),
        LegalSection(heading: "Governing Law", body:
            "These Terms are governed by the laws of the jurisdiction in which Enigo is operated, without regard to conflict-of-law principles."),
        LegalSection(heading: "Changes to These Terms", body:
            "We may update these Terms from time to time. Continued use of the app after a change constitutes acceptance of the updated Terms."),
        LegalSection(heading: "Contact", body:
            "Questions about these Terms: \(contactEmail)"),
    ]

    static let privacySections: [LegalSection] = [
        LegalSection(heading: "Information We Collect", body:
            "Phone number — used to sign in and verify you're a real person, via our SMS provider (Twilio).\n\n" +
            "Profile information — the photo, bio, interests, gender, matching preferences, and question answers you provide.\n\n" +
            "Approximate location — used only to find matches near you and show distance; stored as coordinates you control via Settings and can be removed by disabling location.\n\n" +
            "Messages — stored so your conversation history is available to you and your match, and scanned automatically (not by a human reviewer under normal operation) to block phone numbers and images before they're sent, and to detect content that violates our Acceptable Use policy.\n\n" +
            "Purchase records — subscription and boost status, verified against Apple's servers.\n\n" +
            "Device push token — used only to deliver notifications you've opted into (new messages, unlocks); never sold or used for advertising."),
        LegalSection(heading: "How We Use It", body:
            "To operate matching, messaging, notifications, and billing; to enforce our Terms of Service and keep the community safe; and to improve the app. We do not sell your personal information."),
        LegalSection(heading: "Third-Party Services We Use", body:
            "Twilio — delivers SMS verification codes.\n\n" +
            "Anthropic (Claude) — powers the AI-assisted conversational partner described in the Terms of Service; message content sent to an AI-assisted match is processed by Anthropic's API to generate replies.\n\n" +
            "Apple — processes in-app purchases.\n\n" +
            "Supabase — our backend hosting provider; stores app data on our behalf under its own security commitments."),
        LegalSection(heading: "Data Retention", body:
            "We retain your data for as long as your account is active. If you delete your account, your profile, matches, and messages are permanently removed from our systems."),
        LegalSection(heading: "Your Rights", body:
            "You can export a copy of your data or permanently delete your account at any time from Settings \u{2192} Account. If you're in a jurisdiction with additional data rights (e.g. GDPR, CCPA), you may also have the right to correct or restrict our use of your data — contact us to exercise these."),
        LegalSection(heading: "Children's Privacy", body:
            "Enigo is not directed at, and may not be used by, anyone under 18. We do not knowingly collect data from anyone under 18."),
        LegalSection(heading: "Security", body:
            "We use industry-standard measures (encryption in transit, access controls, row-level database security) to protect your data, but no system is perfectly secure."),
        LegalSection(heading: "Changes to This Policy", body:
            "We may update this Privacy Policy from time to time; material changes will be reflected here with an updated date."),
        LegalSection(heading: "Contact", body:
            "Questions about this policy or your data: \(contactEmail)"),
    ]
}
