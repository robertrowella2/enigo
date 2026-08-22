import Foundation

// Copy lifted verbatim from Enigo.dc.html's QUESTIONS/INTERESTS arrays per
// the handoff doc: "Full copy is in the prototype's QUESTIONS array — treat
// it as final."

struct Question {
    let category: String
    let text: String
    let options: [String]
}

enum ContentData {
    static let questions: [Question] = [
        Question(category: "VALUES", text: "When life gets full, what quietly gets protected first?", options: ["Time with people I love", "Work I believe in", "Rest and quiet", "Whatever I promised someone"]),
        Question(category: "VALUES", text: "Which would you rather be told you are?", options: ["Kind", "Interesting", "Reliable", "Honest"]),
        Question(category: "CONFLICT", text: "A misunderstanding is sitting between you. What's the fastest way out?", options: ["Ask, don't assume", "Give it a night, then talk", "Say sorry first, sort it after", "Write it down properly"]),
        Question(category: "CONFLICT", text: "Someone raises their voice in a disagreement. You…", options: ["Get quieter", "Match the energy", "Name it out loud", "Leave the room and come back"]),
        Question(category: "RESPONSIVENESS", text: "A friend texts something heavy at a bad moment. You…", options: ["Reply badly but fast", "Wait and reply properly", "Call instead", "Send something small, then more later"]),
        Question(category: "RESPONSIVENESS", text: "How quickly do you usually write back?", options: ["Within minutes, most days", "Once or twice a day", "When I have something to say", "It really depends on the person"]),
        Question(category: "OPENNESS", text: "How soon do you tell someone something real about yourself?", options: ["Early — it saves time", "Once it feels safe", "Slowly, in pieces", "When they ask well"]),
        Question(category: "CONVERSATION", text: "Pick something you could talk about for an hour.", options: ["Places and how they feel", "What people believe and why", "Something you're making", "The plot of your week"]),
        Question(category: "CONVERSATION", text: "What makes a message good?", options: ["A real question", "A story", "Something that made them think of me", "Honesty about a bad day"]),
        Question(category: "RHYTHM", text: "An ideal free evening looks like…", options: ["Long conversation, one person", "A room full of people", "Alone, on purpose", "Out walking somewhere"]),
        Question(category: "PATIENCE", text: "Enigo takes weeks to show you a face. How does that sit?", options: ["That's exactly why I'm here", "I'm curious, a little impatient", "I'll try it and see", "I'd rather it were faster"]),
    ]

    static let interests: [String] = [
        "Long walks", "Hiking", "Running", "Cycling", "Climbing", "Swimming", "Cold water", "Yoga", "Football", "Skiing", "Sailing", "Camping",
        "Cooking", "Baking", "Coffee", "Wine", "Eating out", "Markets", "Gardening", "Houseplants", "Dogs", "Cats", "Birds", "Long drives",
        "Live music", "Making music", "Singing", "Vinyl", "Film", "Theatre", "Stand-up", "Dancing", "Festivals", "Karaoke",
        "Secondhand books", "Poetry", "Writing", "Podcasts", "Languages", "History", "Philosophy", "Astronomy", "Museums", "Galleries",
        "Painting", "Drawing", "Photography", "Pottery", "Knitting", "Woodwork", "Sewing", "Restoring things",
        "Board games", "Chess", "Video games", "Puzzles", "Trivia", "Maps", "Trains", "Travelling slowly", "Volunteering", "Activism",
        "Meditation", "Journalling", "Thrifting", "Interiors", "Architecture", "Design", "Coding", "Investing", "Cars", "Motorcycles",
        "Fishing", "Foraging", "Beekeeping", "Star-gazing", "Sunday papers", "Radio", "True crime", "Sci-fi",
    ]

    static let introSlides: [(art: String, title: String, body: String, cta: String)] = [
        ("NO FACES", "No photos. No swiping.", "You match on how you answer, not how you look. A photo is the very last thing that unlocks.", "Go on"),
        ("ELEVEN ANSWERS", "Matched on answers, not faces.", "Eleven short questions about values, conflict, and rhythm decide who you meet — not a browse.", "Go on"),
        ("SEALED ENVELOPE", "Things unlock as you show up.", "Interests, then a bio, then a rough location — and eventually, a photo. Both of you have to be here for it.", "Go on"),
        ("SLOW LIGHT", "It's slow on purpose.", "Enigo is built for people who'd rather wait for someone real than swipe past a hundred maybes.", "Create an account"),
    ]
}

enum UsernameGenerator {
    private static let adjectives = ["quiet", "slow", "warm", "wren", "amber", "salt", "low", "soft", "still", "far"]
    private static let nouns = ["andfog", "andrain", "andcedar", "light", "harbor", "meadow", "orchard", "tide", "ember", "willow"]

    static func generate() -> String {
        "\(adjectives.randomElement()!)\(nouns.randomElement()!)"
    }
}
