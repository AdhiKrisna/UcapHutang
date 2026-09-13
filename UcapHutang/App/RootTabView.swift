import SwiftUI
import Combine

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

enum AppTab: Hashable {
    case draft
    case capture
    case ledger
}

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @AppStorage("hasAskedAboutCatatWidget") private var hasAskedAboutCatatWidget = false
    @State private var selectedTab: AppTab = .draft
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?
    @State private var showsWidgetPrompt = false
    @State private var showsWidgetInstructions = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DraftListView(repository: container.repository) { draftID in
                reviewDraftItem = IdentifiableUUID(draftID)
            }
            .tabItem {
                Label("Draft", systemImage: "exclamationmark.triangle")
            }
            .tag(AppTab.draft)

            CatatFlowChooserView { flow in
                selectedCaptureFlow = flow
            }
            .tabItem {
                Label("Catat", systemImage: "mic.fill")
            }
            .tag(AppTab.capture)

            LedgerListView(repository: container.repository)
                .tabItem {
                    Label("Riwayat", systemImage: "book.closed")
                }
                .tag(AppTab.ledger)
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewView(draftID: item.id, repository: container.repository)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
        .sheet(isPresented: $showsWidgetInstructions) {
            WidgetSetupInstructionsView()
        }
        .alert("Catat lebih cepat dengan Widget?", isPresented: $showsWidgetPrompt) {
            Button("Ya, Mau") {
                hasAskedAboutCatatWidget = true
                showsWidgetInstructions = true
            }
            Button("Nanti Saja", role: .cancel) {
                hasAskedAboutCatatWidget = true
            }
        } message: {
            Text("Apakah kamu mau memakai widget untuk mencatat utang, piutang, atau Split Bill secara instan dari Home Screen?")
        }
        .task {
            guard !hasAskedAboutCatatWidget else { return }
            showsWidgetPrompt = true
        }
        .onOpenURL { url in
            guard AppDeepLink(url: url) == .catatChooser else { return }
            selectedCaptureFlow = nil
            selectedTab = .capture
        }
    }
}

private struct WidgetSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.accent)

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Tambahkan Widget UcapHutang")
                        .font(.title2.weight(.bold))
                    Text("iOS mengharuskan widget ditambahkan sendiri dari Home Screen. Setelah dipasang, sekali tap akan langsung membuka tab Catat untuk memilih Utang/Piutang atau Split Bill.")
                        .foregroundStyle(AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    instruction(number: 1, text: "Tekan dan tahan area kosong di Home Screen.")
                    instruction(number: 2, text: "Pilih Edit, lalu Tambah Widget.")
                    instruction(number: 3, text: "Cari UcapHutang dan pilih widget Catat Cepat.")
                    instruction(number: 4, text: "Tambahkan widget ke Home Screen.")
                }

                Spacer()

                Button("Mengerti") { dismiss() }
                    .buttonStyle(AppPrimaryButtonStyle())
            }
            .padding(24)
            .background(AppColors.background)
            .navigationTitle("Widget Catat Cepat")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func instruction(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppColors.accent)
                .clipShape(Circle())
            Text(text)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, 3)
        }
    }
}
