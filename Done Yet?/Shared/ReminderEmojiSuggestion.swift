import Foundation

enum ReminderEmojiSuggestion {
    static func emoji(for title: String) -> String? {
        let haystack = normalize(title)
        guard !haystack.isEmpty else { return nil }

        for (phrase, emoji) in phrases where haystack.contains(phrase) {
            return emoji
        }

        let tokens = haystack.split(separator: " ").map(String.init)
        var best: (score: Int, emoji: String)?
        for token in tokens {
            guard let emoji = emoji(forToken: token) else { continue }
            let score = relevance(for: token)
            if best == nil || score > best!.score {
                best = (score, emoji)
            }
        }
        return best?.emoji
    }

    private static func relevance(for token: String) -> Int {
        let weak: Set<String> = [
            "morning", "night", "sunny", "love", "home", "work", "reminder"
        ]
        if weak.contains(token) { return token.count }
        return 20 + token.count
    }

    private static func emoji(forToken token: String) -> String? {
        if let emoji = keywords[token] { return emoji }

        let suffixes = ["ings", "ing", "ers", "ies", "es", "ed", "er", "s"]
        for suffix in suffixes where token.hasSuffix(suffix) {
            let stemLength = token.count - suffix.count
            guard stemLength >= 3 else { continue }
            let stem = String(token.dropLast(suffix.count))
            if let emoji = keywords[stem] { return emoji }
            if suffix == "ies", let emoji = keywords[stem + "y"] { return emoji }
        }
        return nil
    }

    private static func normalize(_ title: String) -> String {
        title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : " "
            }
            .reduce(into: "") { partial, character in
                if character == " ", partial.last == " " { return }
                partial.append(character)
            }
            .trimmingCharacters(in: .whitespaces)
    }

    private static let phrases: [(String, String)] = [
        ("lock the door", "🚪"),
        ("locked the door", "🚪"),
        ("take out trash", "🧺"),
        ("take the trash", "🧺"),
        ("take meds", "💊"),
        ("drink water", "💧"),
        ("brush teeth", "🦷"),
        ("feed the dog", "🐶"),
        ("feed the cat", "🐱"),
        ("pick up", "📦")
    ]

    private static let keywords: [String: String] = {
        var map: [String: String] = [:]
        func add(_ emoji: String, _ words: String...) {
            for word in words {
                map[word] = emoji
            }
        }

        add("🚕", "taxi", "cab", "uber", "lyft", "rideshare")
        add("🚌", "bus", "coach")
        add("🚎", "trolley")
        add("🚐", "van", "shuttle")
        add("🚗", "car", "drive", "driving", "ride")
        add("🚙", "suv")
        add("🚓", "police")
        add("🚑", "ambulance")
        add("🚒", "firetruck")
        add("🚚", "truck", "delivery")
        add("🚛", "lorry")
        add("🚜", "tractor")
        add("🛵", "scooter")
        add("🏍️", "motorcycle", "motorbike")
        add("🚲", "bicycle", "cycle")
        add("🚴", "cycling", "biking", "bike")
        add("🛴", "scooter")
        add("✈️", "flying", "flight", "airplane", "aeroplane", "airport", "plane", "fly", "pilot")
        add("🚀", "rocket")
        add("🚁", "helicopter")
        add("🚆", "train", "railway")
        add("🚇", "metro", "subway", "underground")
        add("🚊", "tram", "streetcar")
        add("🚉", "station")
        add("⛵️", "sail", "sailing", "yacht")
        add("🚢", "ship", "cruise")
        add("⛴️", "ferry")
        add("🚤", "boat")
        add("🏠", "home", "house", "apartment")
        add("🏢", "office", "work")
        add("🏫", "school", "class", "college", "university")
        add("🏥", "hospital", "clinic")
        add("⛽️", "gas", "petrol", "fuel")
        add("🅿️", "parking", "parked")

        add("🏃", "running", "runner", "jogging", "jog", "run", "sprint")
        add("🚶", "walking", "walk", "stroll")
        add("💃", "dancing", "dance")
        add("🧘", "yoga", "meditate", "meditation", "mindful")
        add("🏋️", "workout", "lifting", "gym", "weights", "exercise")
        add("🧑‍💻", "coding", "code", "program", "developer", "laptop")
        add("👩‍🍳", "cooking", "cook", "chef", "kitchen")
        add("📚", "study", "studying", "reading", "read", "homework", "book", "library")
        add("🧑‍🎓", "student", "exam", "test")
        add("😴", "sleep", "sleeping", "nap", "tired", "bedtime")
        add("🛏", "bed")
        add("☕", "coffee", "caffeine", "espresso", "latte")
        add("🍵", "tea", "matcha")
        add("🧋", "boba")
        add("💧", "water", "hydrate", "hydrating", "rain")
        add("🥤", "drink", "soda")
        add("🍺", "beer", "pub")
        add("🍷", "wine")
        add("💊", "pill", "pills", "meds", "medicine", "vitamin", "prescription")
        add("💉", "vaccine", "injection", "shot")
        add("👩‍⚕️", "doctor", "appointment")
        add("🦷", "dentist", "teeth", "tooth", "floss")
        add("🛁", "shower", "bath")
        add("🚽", "toilet", "bathroom")
        add("🚪", "door")
        add("🔒", "lock", "locked")
        add("🔑", "keys", "key")
        add("⏰", "alarm", "wake", "wakeup")
        add("📅", "calendar", "meeting", "schedule")
        add("📦", "package", "parcel", "amazon")
        add("📬", "mail", "email", "letter", "post")
        add("🧺", "trash", "laundry", "hamper")
        add("🧹", "clean", "cleaning", "chore", "vacuum", "sweep")
        add("💰", "money", "pay", "paid", "bill", "bills", "rent", "budget")
        add("🎁", "gift", "present", "birthday")
        add("🛍", "shop", "shopping", "groceries", "grocery", "store", "market")
        add("📱", "phone", "call", "text", "message")
        add("💻", "computer")
        add("📷", "camera", "photo", "photos", "picture")
        add("💡", "light", "lights", "lamp")
        add("🔔", "remind", "reminder", "bell")

        add("🐶", "dog", "puppy", "walkies")
        add("🐱", "cat", "kitten")
        add("🐼", "panda")
        add("🐻", "bear")
        add("🐦", "bird")
        add("🐠", "fish")
        add("🐰", "rabbit", "bunny")
        add("🦊", "fox")
        add("🦁", "lion")
        add("🐮", "cow")
        add("🐷", "pig")
        add("🐸", "frog")
        add("🐵", "monkey")
        add("🐝", "bee")
        add("🦋", "butterfly")
        add("🌿", "plant", "plants")
        add("🌸", "flower", "flowers")
        add("🌳", "tree", "trees")
        add("☀️", "sun", "sunny", "morning")
        add("🌙", "moon", "night")
        add("❄️", "snow")
        add("⚡️", "electric", "charge", "charger")
        add("🌈", "rainbow")
        add("🔥", "fire", "burn")
        add("❤️", "heart", "love")
        add("⭐️", "star")
        add("🥳", "party")
        add("👶", "baby", "infant")

        add("🍎", "apple")
        add("🍌", "banana")
        add("🍓", "strawberry")
        add("🍕", "pizza")
        add("🍔", "burger")
        add("🌮", "taco")
        add("🍣", "sushi")
        add("🥪", "lunch", "sandwich")
        add("🍽️", "dinner", "supper")
        add("🍳", "breakfast", "eggs")
        add("🍩", "donut", "doughnut")
        add("🎂", "cake")

        add("⚽️", "soccer", "football")
        add("🏀", "basketball")
        add("🎾", "tennis")
        add("⛳️", "golf")
        add("🎮", "game", "gaming", "xbox", "playstation")
        add("🎧", "music", "podcast", "headphones")
        add("🎸", "guitar")
        add("🎹", "piano")
        add("🎬", "movie", "film", "netflix")
        add("🎨", "art", "paint", "drawing")
        add("🎤", "sing", "karaoke")

        return map
    }()
}
