import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var campaigns: [Campaign]
    @State private var activeCampaign: Campaign?
    @State private var showCampaignPicker = true

    var body: some View {
        Group {
            if let campaign = activeCampaign {
                DashboardView(campaign: campaign)
                    .environment(\.campaign, campaign)
            } else {
                CampaignPickerView(
                    campaigns: campaigns,
                    onSelect: { campaign in
                        activeCampaign = campaign
                        showCampaignPicker = false
                    },
                    onCreate: { name in
                        let campaign = Campaign(name: name)
                        modelContext.insert(campaign)
                        activeCampaign = campaign
                        showCampaignPicker = false
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
        VStack(spacing: 32) {
            Spacer()

            Text("DM FORGE")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .foregroundStyle(DMTheme.accent)

            Text("Your table. Your dice. Your story.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 20)

            if campaigns.isEmpty {
                Button("Start Your First Campaign") {
                    showCreate = true
                }
                .buttonStyle(DMButtonStyle())
            } else {
                VStack(spacing: 12) {
                    ForEach(campaigns) { campaign in
                        Button {
                            onSelect(campaign)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(campaign.name)
                                        .font(.headline)
                                    Text(campaign.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(DMTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Button("New Campaign") {
                        showCreate = true
                    }
                    .buttonStyle(DMButtonStyle(color: DMTheme.accent))
                }
                .frame(maxWidth: 400)
            }

            Spacer()

            Text("v2.0 — D&D 5e SRD")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DMTheme.background)
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
