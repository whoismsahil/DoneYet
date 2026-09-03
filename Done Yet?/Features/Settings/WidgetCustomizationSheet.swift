import SwiftUI

struct WidgetCustomizationSheet: View {
    enum Section {
        case color
        case pets
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseService.self) private var purchaseService
    @Bindable var themeManager: WidgetThemeManager
    let section: Section
    @State private var previewCompleted = false
    @State private var pendingSelection: WidgetTheme
    @State private var pendingPet: WidgetPet
    @State private var pendingUsesEmojiColor: Bool
    @State private var showingPaywall = false

    private let previewEmoji = "💃"

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    init(themeManager: WidgetThemeManager, section: Section = .color) {
        self.themeManager = themeManager
        self.section = section
        _pendingSelection = State(initialValue: themeManager.selection)
        _pendingPet = State(initialValue: themeManager.pet)
        _pendingUsesEmojiColor = State(initialValue: themeManager.usesEmojiColor)
        _previewCompleted = State(initialValue: section == .pets)
    }

    private var hasPendingChanges: Bool {
        switch section {
        case .color:
            pendingSelection != themeManager.selection
                || pendingUsesEmojiColor != themeManager.usesEmojiColor
        case .pets:
            pendingPet != themeManager.pet
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    previewSection
                    switch section {
                    case .color:
                        widgetColorSection
                    case .pets:
                        petsSection
                    }
                }
                .padding()
            }
            .background(AppColors.pageBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(section == .color ? "Color" : "Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.pageBackground, for: .navigationBar)
            .background(AppColors.pageBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pendingSelection = themeManager.selection
                        pendingPet = themeManager.pet
                        pendingUsesEmojiColor = themeManager.usesEmojiColor
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        applyPendingSelection()
                    }
                    .disabled(!hasPendingChanges)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(
                    purchaseService: purchaseService,
                    headline: "Done Yet? Pro",
                    message: section == .color
                        ? "Extra widget colors are included with Pro."
                        : "Extra pets are included with Pro."
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text(
                section == .pets
                    ? "Shows after you tap Done Yet?"
                    : (pendingUsesEmojiColor
                       ? "Automatic. The widget color comes from the reminder’s emoji."
                       : "Palette: \(pendingSelection.title)")
            )
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Spacer(minLength: 0)

                WidgetFace(
                    title: "Locked my Door?",
                    buttonText: "DONE YET?",
                    isCompleted: previewCompleted,
                    theme: pendingSelection,
                    pet: pendingPet,
                    style: .small,
                    showsInteractiveButton: true,
                    onComplete: { previewCompleted = true },
                    iconEmoji: section == .color ? previewEmoji : nil,
                    usesEmojiColor: section == .color && pendingUsesEmojiColor
                )
                .frame(width: WidgetLayout.smallPreviewSize, height: WidgetLayout.smallPreviewSize)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Spacer(minLength: 0)
            }

            if previewCompleted {
                Button("Reset Preview") {
                    previewCompleted = false
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: pendingSelection) { _, _ in
            if section == .color {
                previewCompleted = false
            }
        }
        .onChange(of: pendingUsesEmojiColor) { _, _ in
            if section == .color {
                previewCompleted = false
            }
        }
        .onChange(of: pendingPet) { _, _ in
            if section == .pets {
                previewCompleted = true
            }
        }
    }

    private var widgetColorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle(isOn: $pendingUsesEmojiColor) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Set the widget color from the reminder’s emoji.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .tint(AppColors.accent)

            includedColors
            premiumColors
        }
    }

    private var petsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            includedPets
            premiumPets
        }
    }

    private var includedColors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Included")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text("Used when Automatic is off, or when a reminder has no emoji.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(WidgetTheme.included) { theme in
                    colorSwatch(theme)
                }
            }
        }
    }

    private var premiumColors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text("Included with Pro when limits are on.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(WidgetTheme.premium) { theme in
                    colorSwatch(theme)
                }
            }
        }
    }

    private var includedPets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Included")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text("Shows after you tap Done Yet?")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(WidgetPet.included) { pet in
                    petSwatch(pet)
                }
            }
        }
    }

    private var premiumPets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text("Cat, Dog, and other extras.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(WidgetPet.premium) { pet in
                    petSwatch(pet)
                }
            }
        }
    }

    private func colorSwatch(_ theme: WidgetTheme) -> some View {
        Button {
            pendingUsesEmojiColor = false
            pendingSelection = theme
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.background)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle()
                                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                        }

                    if !pendingUsesEmojiColor, pendingSelection == theme {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .primary)
                            .font(.title3)
                    }

                    if theme.isPremium, pendingSelection != theme {
                        lockBadge
                    }
                }
                .frame(width: 44, height: 44)

                Text(theme.title)
                    .font(.caption)
                    .foregroundStyle(!pendingUsesEmojiColor && pendingSelection == theme ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.isPremium ? "\(theme.title), Premium" : theme.title)
        .accessibilityAddTraits(!pendingUsesEmojiColor && pendingSelection == theme ? .isSelected : [])
    }

    private func petSwatch(_ pet: WidgetPet) -> some View {
        Button {
            pendingPet = pet
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(pendingSelection.background)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle()
                                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                        }

                    if pet.assetName != nil || pet.outlinedSymbol != nil {
                        WidgetPetSprite(pet: pet, color: pendingSelection.text, height: 28)
                    } else {
                        Text(pet.outlinedEmoji)
                            .font(.title3)
                    }

                    if pendingPet == pet {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .primary)
                            .font(.title3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(x: 4, y: -4)
                    }

                    if pet.isPremium, pendingPet != pet {
                        lockBadge
                    }
                }
                .frame(width: 44, height: 44)

                Text(pet.title)
                    .font(.caption)
                    .foregroundStyle(pendingPet == pet ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pet.isPremium ? "\(pet.title), Premium" : pet.title)
        .accessibilityAddTraits(pendingPet == pet ? .isSelected : [])
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.primary)
            .padding(4)
            .background(.regularMaterial, in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .offset(x: 2, y: 2)
    }

    private func applyPendingSelection() {
        switch section {
        case .color:
            if pendingSelection.isPremium, !purchaseService.canUsePremiumTheme(pendingSelection) {
                showingPaywall = true
                return
            }
            themeManager.selection = pendingSelection
            WidgetThemeStore.set(pendingSelection)
            themeManager.usesEmojiColor = pendingUsesEmojiColor
            WidgetThemeStore.setUsesEmojiColor(pendingUsesEmojiColor)
        case .pets:
            if pendingPet.isPremium, !purchaseService.canUsePremiumPet(pendingPet) {
                showingPaywall = true
                return
            }
            themeManager.pet = pendingPet
            WidgetPetStore.set(pendingPet)
        }
        dismiss()
    }
}
