import SwiftUI

struct SmartContactCardView: View {
    let participant: DraftParticipantUIModel
    var onConfirmTypo: (() -> Void)?
    var onRejectTypo: (() -> Void)?
    var onOpenPicker: (() -> Void)?

    init(
        participant: DraftParticipantUIModel,
        onConfirmTypo: (() -> Void)? = nil,
        onRejectTypo: (() -> Void)? = nil,
        onOpenPicker: (() -> Void)? = nil
    ) {
        self.participant = participant
        self.onConfirmTypo = onConfirmTypo
        self.onRejectTypo = onRejectTypo
        self.onOpenPicker = onOpenPicker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch participant.linkState {
            case .autoLinked:
                // State A: Terhubung otomatis
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Terhubung otomatis ke kontak")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        onOpenPicker?()
                    } label: {
                        Text("Bukan dia?")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

            case .typoSuggestion(let suggestedName, _):
                // State B: Nama Orang Typo
                VStack(alignment: .leading, spacing: 8) {
                    Text(participant.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Mirip kontak \"\(suggestedName)\" — Typo?")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 8) {
                        Button {
                            onConfirmTypo?()
                        } label: {
                            Text("Ya, hubungkan")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onRejectTypo?()
                        } label: {
                            Text("Bukan, ganti")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .unlinked:
                // State C: Orangnya belum terhubung
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Belum terhubung")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        onOpenPicker?()
                    } label: {
                        Text("Hubungkan")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview("3 States") {
    VStack(spacing: 16) {
        // State A
        SmartContactCardView(
            participant: DraftParticipantUIModel(
                name: "Dito",
                linkState: .autoLinked(matchedContactName: "Andito Rizkika")
            )
        )

        // State B
        SmartContactCardView(
            participant: DraftParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .typoSuggestion(suggestedName: "Dito Rizkika", originalName: "Dito Rizkaka")
            )
        )

        // State C
        SmartContactCardView(
            participant: DraftParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .unlinked
            )
        )
    }
    .padding()
}
