package com.enigo.app.ui.account

/**
 * Placeholder-but-shippable legal copy. This has NOT been reviewed by an
 * attorney — in particular the AI-assisted-matching disclosure in
 * [LegalContent.termsSections] (Terms section 3) touches a live regulatory
 * area (several US states now require clear disclosure when a user is
 * conversing with an AI in a way that could be mistaken for a human) and
 * should get real legal review before this ships to the Play Store.
 *
 * Mirrors ios/Enigo/Account/Legal.swift content (kept as plain text here,
 * without the iOS file's inline markdown emphasis, since Compose's Text
 * doesn't interpret markdown by default).
 */
enum class LegalDocument(val title: String) {
    TERMS("Terms of Service"),
    PRIVACY("Privacy Policy"),
}

data class LegalSection(val heading: String, val body: String)

object LegalContent {
    const val lastUpdated = "August 22, 2026"
    const val contactEmail = "robertrowella2@gmail.com"

    fun sections(document: LegalDocument): List<LegalSection> = when (document) {
        LegalDocument.TERMS -> termsSections
        LegalDocument.PRIVACY -> privacySections
    }

    private val termsSections = listOf(
        LegalSection(
            "Eligibility",
            "You must be at least 18 years old to use Enigo. By using the app you represent that you are 18 or older and have the legal capacity to enter into these Terms."
        ),
        LegalSection(
            "Your Account",
            "You're responsible for the accuracy of the information you provide and for keeping your account secure. You may not create more than one account, impersonate another person, or use a photo that isn't genuinely of you."
        ),
        LegalSection(
            "How Matching Works, Including AI-Assisted Conversations",
            "Enigo pairs you with one match at a time and reveals more about them gradually, as your conversation progresses. Two important things to know:\n\n" +
                "Automatic upgrades — if you're placed with a match and a better or more compatible real person becomes available, Enigo may end that match and connect you with the new one automatically.\n\n" +
                "AI conversational partner — when no compatible real person is available yet, Enigo may temporarily connect you with an AI-generated conversational partner rather than leave you with nothing to do. This partner is not a real person — it is software designed to hold a conversation in a similar style to how a real match would. Enigo automatically ends this AI-assisted match and replaces it with a real person as soon as one becomes available, at no cost to you and without losing your progress toward that match's unlocks. You can turn off AI-assisted matching in Settings."
        ),
        LegalSection(
            "Acceptable Use",
            "You agree not to:\n\n" +
                "• Send phone numbers, external contact handles, or images/photos through in-app messages (the app automatically blocks these to keep the early conversation focused, and repeated attempts to bypass this may result in suspension)\n" +
                "• Harass, threaten, or send unwanted sexual content to another user\n" +
                "• Use the app for any commercial solicitation, scam, or fraud\n" +
                "• Misrepresent your age, identity, or intentions\n\n" +
                "Violations may result in warnings, suspension, or permanent account termination, and are reportable in-app."
        ),
        LegalSection(
            "Content You Share",
            "You retain ownership of the photos, bio, and messages you provide. You grant Enigo a limited license to store, transmit, and display that content solely to operate the matching and messaging features of the app for you and your matches."
        ),
        LegalSection(
            "Subscriptions & Purchases",
            "Enigo offers optional paid features (an ongoing subscription tier and one-time boosts), billed through Google Play. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period, and are managed through your Google account settings, not within the app. Prices are shown at time of purchase and may vary by region. No refunds are provided by Enigo directly; refund requests go through Google Play per its standard policies."
        ),
        LegalSection(
            "Safety",
            "Enigo is not a background-check or identity-verification service. Use good judgment when meeting anyone in person, meet in public places, and tell a friend where you're going. Report any user who makes you feel unsafe."
        ),
        LegalSection(
            "Termination",
            "You may delete your account at any time from Settings, which permanently removes your profile, matches, and message history. We may suspend or terminate your account for violating these Terms or applicable law."
        ),
        LegalSection(
            "Disclaimers",
            "The app is provided \"as is.\" Enigo does not guarantee you will find a match, that any match will meet your expectations, or that the app will be uninterrupted or error-free."
        ),
        LegalSection(
            "Limitation of Liability",
            "To the maximum extent permitted by law, Enigo and its operators are not liable for indirect, incidental, or consequential damages arising from your use of the app, including your interactions with other users or with the AI-assisted matching feature described above."
        ),
        LegalSection(
            "Governing Law",
            "These Terms are governed by the laws of the jurisdiction in which Enigo is operated, without regard to conflict-of-law principles."
        ),
        LegalSection(
            "Changes to These Terms",
            "We may update these Terms from time to time. Continued use of the app after a change constitutes acceptance of the updated Terms."
        ),
        LegalSection("Contact", "Questions about these Terms: $contactEmail"),
    )

    private val privacySections = listOf(
        LegalSection(
            "Information We Collect",
            "Phone number — used to sign in and verify you're a real person, via our SMS provider (Twilio).\n\n" +
                "Profile information — the photo, bio, interests, gender, matching preferences, and question answers you provide.\n\n" +
                "Approximate location — used only to find matches near you and show distance; stored as coordinates you control via Settings and can be removed by disabling location.\n\n" +
                "Messages — stored so your conversation history is available to you and your match, and scanned automatically (not by a human reviewer under normal operation) to block phone numbers and images before they're sent, and to detect content that violates our Acceptable Use policy.\n\n" +
                "Purchase records — subscription and boost status, verified against Google Play's servers.\n\n" +
                "Device push token — used only to deliver notifications you've opted into (new messages, unlocks); never sold or used for advertising."
        ),
        LegalSection(
            "How We Use It",
            "To operate matching, messaging, notifications, and billing; to enforce our Terms of Service and keep the community safe; and to improve the app. We do not sell your personal information."
        ),
        LegalSection(
            "Third-Party Services We Use",
            "Twilio — delivers SMS verification codes.\n\n" +
                "Anthropic (Claude) — powers the AI-assisted conversational partner described in the Terms of Service; message content sent to an AI-assisted match is processed by Anthropic's API to generate replies.\n\n" +
                "Google — processes in-app purchases and delivers push notifications.\n\n" +
                "Supabase — our backend hosting provider; stores app data on our behalf under its own security commitments."
        ),
        LegalSection(
            "Data Retention",
            "We retain your data for as long as your account is active. If you delete your account, your profile, matches, and messages are permanently removed from our systems."
        ),
        LegalSection(
            "Your Rights",
            "You can export a copy of your data or permanently delete your account at any time from Settings > Account. If you're in a jurisdiction with additional data rights (e.g. GDPR, CCPA), you may also have the right to correct or restrict our use of your data — contact us to exercise these."
        ),
        LegalSection(
            "Children's Privacy",
            "Enigo is not directed at, and may not be used by, anyone under 18. We do not knowingly collect data from anyone under 18."
        ),
        LegalSection(
            "Security",
            "We use industry-standard measures (encryption in transit, access controls, row-level database security) to protect your data, but no system is perfectly secure."
        ),
        LegalSection(
            "Changes to This Policy",
            "We may update this Privacy Policy from time to time; material changes will be reflected here with an updated date."
        ),
        LegalSection("Contact", "Questions about this policy or your data: $contactEmail"),
    )
}
