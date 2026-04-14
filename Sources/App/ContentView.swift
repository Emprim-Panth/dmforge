import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var campaigns: [Campaign]
    @State private var activeCampaign: Campaign?
    @State private var showCampaignPicker = true
    @State private var showQA = false

    var body: some View {
        Group {
            if showQA {
                QARunnerView()
            } else if let campaign = activeCampaign {
                DashboardView(campaign: campaign)
                    .environment(\.campaign, campaign)
                    .transition(.opacity)
            } else {
                CampaignPickerView(
                    campaigns: campaigns,
                    onSelect: { campaign in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeCampaign = campaign
                            showCampaignPicker = false
                        }
                    },
                    onCreate: { name in
                        let campaign = Campaign(name: name)
                        modelContext.insert(campaign)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeCampaign = campaign
                            showCampaignPicker = false
                        }
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Campaign Picker (launch screen)

struct CampaignPickerView: View {
    let campaigns: [Campaign]
    let onSelect: (Campaign) -> Void
    let onCreate: (String) -> Void

    @State private var newName = ""
    @State private var showCreate = false

    var body: some View {
        ZStack {
            // Background gradient instead of flat black
            LinearGradient(
                colors: [
                    Color(hex: "08080e"),
                    Color(hex: "0d0d18"),
                    Color(hex: "12101e")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle radial glow behind title
            RadialGradient(
                colors: [DMTheme.accent.opacity(0.06), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .offset(y: -120)
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App title with ornamental styling
                VStack(spacing: 12) {
                    // Decorative divider
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(DMTheme.accent.opacity(0.3))
                            .frame(width: 40, height: 1)
                        Image(systemName: "shield.fill")
                            .font(.caption)
                            .foregroundStyle(DMTheme.accent.opacity(0.5))
                        Rectangle()
                            .fill(DMTheme.accent.opacity(0.3))
                            .frame(width: 40, height: 1)
                    }

                    Text("DM FORGE")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(DMTheme.accent)
                        .tracking(4)

                    Text("Your table. Your dice. Your story.")
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textSecondary)

                    // Decorative divider
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(DMTheme.accent.opacity(0.3))
                            .frame(width: 40, height: 1)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(DMTheme.accent.opacity(0.5))
                        Rectangle()
                            .fill(DMTheme.accent.opacity(0.3))
                            .frame(width: 40, height: 1)
                    }
                }

                Spacer().frame(height: 20)

                if campaigns.isEmpty {
                    Button("Start Your First Campaign") {
                        showCreate = true
                    }
                    .buttonStyle(DMPrimaryButtonStyle())
                } else {
                    VStack(spacing: DMTheme.cardSpacing) {
                        ForEach(campaigns) { campaign in
                            Button {
                                onSelect(campaign)
                            } label: {
                                HStack(spacing: 16) {
                                    // Campaign icon
                                    Image(systemName: "book.closed.fill")
                                        .font(.title2)
                                        .foregroundStyle(DMTheme.accent)
                                        .frame(width: 44, height: 44)
                                        .background(DMTheme.accent.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(campaign.name)
                                            .font(.headline)
                                            .foregroundStyle(DMTheme.textPrimary)

                                        HStack(spacing: 12) {
                                            Label("\(campaign.party.count) PCs", systemImage: "person.3.fill")
                                                .font(.caption)
                                                .foregroundStyle(DMTheme.textSecondary)
                                            Label("\(campaign.sessions.count) sessions", systemImage: "book.fill")
                                                .font(.caption)
                                                .foregroundStyle(DMTheme.textSecondary)
                                        }

                                        Text("Last played \(campaign.updatedAt.formatted(.relative(presentation: .named)))")
                                            .font(.caption2)
                                            .foregroundStyle(DMTheme.textDim)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.subheadline)
                                        .foregroundStyle(DMTheme.textDim)
                                }
                                .padding(DMTheme.cardPadding)
                                .background(DMTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                                        .stroke(DMTheme.border, lineWidth: 1)
                                )
                                .shadow(color: DMTheme.cardShadow, radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("New Campaign") {
                            showCreate = true
                        }
                        .buttonStyle(DMPrimaryButtonStyle())
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: 480)
                }

                Spacer()

                Text("v2.0 — D&D 5e SRD")
                    .font(.caption2)
                    .foregroundStyle(DMTheme.textDim)
            }
            .padding()
        }
        .alert("New Campaign", isPresented: $showCreate) {
            TextField("Campaign name", text: $newName)
            Button("Create") {
                guard !newName.isEmpty else { return }
                onCreate(newName)
                newName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Debug QA Runner
#if DEBUG
struct QARunnerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var results = "Running tests..."
    
    var body: some View {
        ScrollView {
            Text(results)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DMTheme.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DMTheme.background)
        .onAppear {
            results = QATest.run(modelContext: modelContext)
        }
    }
}
#endif
