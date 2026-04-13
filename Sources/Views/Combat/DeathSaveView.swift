import SwiftUI

/// Death save tracker component — embed in character cards when PC has 0 HP.
struct DeathSaveView: View {
    @Bindable var character: PlayerCharacter

    private var isStabilized: Bool { character.deathSaveSuccesses >= 3 }
    private var isDead: Bool { character.deathSaveFailures >= 3 }
    private var isResolved: Bool { isStabilized || isDead }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            Text("DEATH SAVES (DC 10)")
                .font(.caption.bold())
                .foregroundStyle(DMTheme.accentRed)
                .tracking(1)

            // Pips
            HStack(spacing: 16) {
                // Successes
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index < character.deathSaveSuccesses
                                  ? DMTheme.accentGreen
                                  : DMTheme.detail)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(DMTheme.accentGreen.opacity(0.5), lineWidth: 1)
                            )
                    }
                    Text("Pass")
                        .font(.caption2)
                        .foregroundStyle(DMTheme.accentGreen)
                }

                // Failures
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index < character.deathSaveFailures
                                  ? DMTheme.accentRed
                                  : DMTheme.detail)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(DMTheme.accentRed.opacity(0.5), lineWidth: 1)
                            )
                    }
                    Text("Fail")
                        .font(.caption2)
                        .foregroundStyle(DMTheme.accentRed)
                }
            }

            // Terminal state or action buttons
            if isResolved {
                Text(isStabilized ? "STABILIZED" : "DEAD")
                    .font(.headline.bold())
                    .foregroundStyle(isStabilized ? DMTheme.accentGreen : DMTheme.accentRed)
                    .padding(.vertical, 4)

                Button("Reset") {
                    character.deathSaveSuccesses = 0
                    character.deathSaveFailures = 0
                }
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)
                .frame(minHeight: 44)
            } else {
                // Roll on iPad
                Button {
                    rollDeathSave()
                } label: {
                    Label("Roll on iPad (DC 10)", systemImage: "dice")
                        .font(.subheadline)
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.card))
                .frame(minHeight: 44)

                // Manual entry from table roll
                HStack(spacing: 8) {
                    Text("Rolled at table:")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textSecondary)

                    Button("10+ Pass") {
                        character.deathSaveSuccesses = min(3, character.deathSaveSuccesses + 1)
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                    .frame(minHeight: 44)

                    Button("9- Fail") {
                        character.deathSaveFailures = min(3, character.deathSaveFailures + 1)
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.3)))
                    .frame(minHeight: 44)

                    Button("Nat 1") {
                        character.deathSaveFailures = min(3, character.deathSaveFailures + 2)
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.5)))
                    .frame(minHeight: 44)

                    Button("Nat 20") {
                        character.deathSaveSuccesses = 0
                        character.deathSaveFailures = 0
                        character.hpCurrent = 1
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.5)))
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(12)
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DMTheme.accentRed.opacity(0.3), lineWidth: 1)
        )
    }

    private func rollDeathSave() {
        let roll = Int.random(in: 1...20)
        if roll == 1 {
            character.deathSaveFailures = min(3, character.deathSaveFailures + 2)
        } else if roll == 20 {
            character.deathSaveSuccesses = 0
            character.deathSaveFailures = 0
            character.hpCurrent = 1
        } else if roll >= 10 {
            character.deathSaveSuccesses = min(3, character.deathSaveSuccesses + 1)
        } else {
            character.deathSaveFailures = min(3, character.deathSaveFailures + 1)
        }
    }
}
