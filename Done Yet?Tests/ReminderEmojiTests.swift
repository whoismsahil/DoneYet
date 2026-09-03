import Testing

@testable import Done_Yet_

struct ReminderEmojiSuggestionTests {
    @Test func runningPicksRunner() {
        #expect(ReminderEmojiSuggestion.emoji(for: "Running") == "🏃")
        #expect(ReminderEmojiSuggestion.emoji(for: "Morning run") == "🏃")
    }

    @Test func flyingPicksPlane() {
        #expect(ReminderEmojiSuggestion.emoji(for: "flying") == "✈️")
        #expect(ReminderEmojiSuggestion.emoji(for: "Catch my flight") == "✈️")
    }

    @Test func travelPicksVehicle() {
        #expect(ReminderEmojiSuggestion.emoji(for: "taxi") == "🚕")
        #expect(ReminderEmojiSuggestion.emoji(for: "Call a cab") == "🚕")
        #expect(ReminderEmojiSuggestion.emoji(for: "bus") == "🚌")
        #expect(ReminderEmojiSuggestion.emoji(for: "catch the buses") == "🚌")
        #expect(ReminderEmojiSuggestion.emoji(for: "uber home") == "🚕")
        #expect(ReminderEmojiSuggestion.emoji(for: "subway") == "🚇")
    }

    @Test func unmatchedTitleHasNoSuggestion() {
        #expect(ReminderEmojiSuggestion.emoji(for: "xyzzy") == nil)
        #expect(ReminderEmojiSuggestion.emoji(for: "") == nil)
    }
}

struct ReminderEmojiStyleTests {
    @Test func everyCatalogEmojiProducesAPalette() {
        for category in EmojiCatalog.categories {
            for emoji in category.emojis {
                let palette = ReminderEmojiStyle.palette(for: emoji)
                #expect(palette != nil, "Expected a palette for \(emoji)")
            }
        }
    }

    @Test func pandaDoesNotFallBackToNil() {
        #expect(ReminderEmojiStyle.palette(for: "🐼") != nil)
        #expect(ReminderEmojiStyle.palette(for: "🖤") != nil)
        #expect(ReminderEmojiStyle.palette(for: "🤍") != nil)
    }
}
