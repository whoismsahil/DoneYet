import SwiftUI

struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(EmojiCatalog.categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    Button {
                                        onSelect(emoji)
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(maxWidth: .infinity, minHeight: 40)
                                            .background(
                                                current == emoji ? AppColors.hover : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(emoji)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.pageBackground)
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !current.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Remove") {
                            onSelect("")
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

enum EmojiCatalog {
    struct Category: Identifiable {
        let id: String
        let title: String
        let emojis: [String]
    }

    static let categories: [Category] = [
        Category(id: "people", title: "People", emojis: [
            "😀", "😁", "😂", "🥰", "😎", "🤔", "😴", "🥳",
            "💃", "🕺", "🏃", "🚶", "🧘", "🏋️", "🚴", "🧑‍💻",
            "👩‍🍳", "👨‍🍳", "🧑‍🎓", "👩‍⚕️", "🦷", "👶", "🙋", "🙌"
        ]),
        Category(id: "nature", title: "Nature & Animals", emojis: [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
            "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
            "🐧", "🐦", "🐤", "🦆", "🦉", "🐝", "🦋", "🐢",
            "🌸", "🌼", "🌻", "🌺", "🌿", "🍀", "🌳", "☀️"
        ]),
        Category(id: "food", title: "Food & Drink", emojis: [
            "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇",
            "🍓", "🫐", "🍑", "🍒", "🥭", "🍍", "🥥", "🥝",
            "🍔", "🍟", "🍕", "🌭", "🥪", "🌮", "🍣", "🍩",
            "🍪", "🎂", "☕", "🍵", "🧋", "🥤", "🍺", "🍷"
        ]),
        Category(id: "activity", title: "Activity", emojis: [
            "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🎱", "🏓",
            "🏸", "🥊", "⛳️", "🎯", "🎮", "🎲", "🧩", "🎨",
            "🎭", "🎬", "🎤", "🎧", "🎹", "🎸", "🥁", "📚"
        ]),
        Category(id: "travel", title: "Travel", emojis: [
            "🚗", "🚕", "🚙", "🚌", "🚎", "🚐", "🚓", "🚑",
            "🚒", "🚚", "🚜", "🛵", "🏍️", "🚲", "🛴", "✈️",
            "🚀", "🚁", "🚆", "🚇", "🚊", "🚉", "⛵️", "⛴️"
        ]),
        Category(id: "objects", title: "Objects", emojis: [
            "⌚️", "📱", "💻", "⌨️", "🖥", "📷", "💡", "🔦",
            "🏠", "🏢", "📖", "✏️", "📌", "📎", "🔒", "🔑", "💊", "💉",
            "🧹", "🧺", "🛏", "🚪", "🪟", "🪞", "🛁", "🚽",
            "⏰", "📅", "📬", "📦", "🎁", "🧸", "🛍", "💰"
        ]),
        Category(id: "symbols", title: "Symbols", emojis: [
            "✅", "❌", "⚠️", "❓", "❗️", "💯", "🔔", "🔕",
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
            "⭐️", "🌟", "🔥", "💧", "🌙", "⚡️", "🌈", "❄️"
        ])
    ]
}
