import SwiftUI
import Combine

@MainActor
final class LedgerListViewModel: ObservableObject {
    @Published private(set) var summaries: [PersonLedgerSummary] = []
    @Published private(set) var entries: [LedgerEntry] = []
    @Published var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) { self.repository = repository }

    func load() async {
        do {
            entries = try await repository.ledgerEntries()
            summaries = Self.summarize(entries)
        } catch { errorMessage = error.localizedDescription }
    }

    func entries(for person: PersonLedgerSummary) -> [LedgerEntry] {
        entries.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
    }

    private static func summarize(_ entries: [LedgerEntry]) -> [PersonLedgerSummary] {
        Dictionary(grouping: entries, by: \.personID).compactMap { id, values in
            guard let latest = values.max(by: { $0.date < $1.date }) else { return nil }
            return PersonLedgerSummary(
                id: id,
                displayName: latest.personName,
                balance: values.reduce(0) { $0 + $1.balanceDelta },
                entryCount: values.count,
                lastActivity: latest.date
            )
        }
        .sorted { $0.lastActivity > $1.lastActivity }
    }
}

struct LedgerListView: View {
    @StateObject private var viewModel: LedgerListViewModel
    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: LedgerListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.summaries.isEmpty {
                    AppEmptyState(icon: "book.closed", title: "Belum ada riwayat", message: "Data yang sudah dikonfirmasi akan dikelompokkan per orang.")
                } else {
                    List(viewModel.summaries) { person in
                        NavigationLink(value: person) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(person.displayName).font(.headline)
                                    Text("\(person.entryCount) aktivitas").font(.caption).foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(abs(person.balance).rupiahFormatted).fontWeight(.bold)
                                    Text(person.balance >= 0 ? "Dia berutang" : "Kamu berutang")
                                        .font(.caption)
                                        .foregroundStyle(person.balance >= 0 ? AppColors.receivable : AppColors.debt)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Riwayat")
            .navigationDestination(for: PersonLedgerSummary.self) { person in
                PersonLedgerDetailView(person: person, entries: viewModel.entries(for: person), repository: repository)
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.load() }
            }
        }
    }
}

struct PersonLedgerDetailView: View {
    @State private var person: PersonLedgerSummary
    @State private var entries: [LedgerEntry]
    let repository: any TransactionRepository
    @State private var showingPayment = false

    init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository) {
        _person = State(initialValue: person)
        _entries = State(initialValue: entries)
        self.repository = repository
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: AppSpacing.small) {
                    Text(abs(person.balance).rupiahFormatted).font(.system(size: 34, weight: .bold))
                    Text(person.balance >= 0 ? "Total yang perlu dibayar ke kamu" : "Total yang perlu kamu bayar")
                        .font(.subheadline).foregroundStyle(AppColors.textSecondary)
                    if person.balance != 0 {
                        Button("Catat Pembayaran") { showingPayment = true }
                            .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section("Riwayat") {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.title).font(.headline)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Text(entry.balanceDelta.rupiahFormatted)
                            .foregroundStyle(entry.balanceDelta >= 0 ? AppColors.receivable : AppColors.debt)
                    }
                }
            }
        }
        .navigationTitle(person.displayName)
        .sheet(isPresented: $showingPayment) {
            PaymentView(person: person, repository: repository) {
                showingPayment = false
                Task { await reload() }
            }
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        guard let allEntries = try? await repository.ledgerEntries() else { return }
        let currentEntries = allEntries.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
        let latestName = currentEntries.first?.personName ?? person.displayName
        entries = currentEntries
        person = PersonLedgerSummary(
            id: person.id,
            displayName: latestName,
            balance: currentEntries.reduce(Int64(0)) { $0 + $1.balanceDelta },
            entryCount: currentEntries.count,
            lastActivity: currentEntries.first?.date ?? person.lastActivity
        )
    }
}

struct PaymentView: View {
    let person: PersonLedgerSummary
    let repository: any TransactionRepository
    let onSaved: () -> Void

    @State private var amount: Int64 = 0
    @State private var date = Date()
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Pembayaran dilakukan di luar aplikasi. UcapHutang hanya mencatat pelunasan.", systemImage: "info.circle")
                }
                Section("Pembayaran") {
                    TextField("Nominal", value: $amount, format: .number).keyboardType(.numberPad)
                    DatePicker("Tanggal & Waktu", selection: $date)
                    TextField("Catatan (opsional)", text: $notes)
                }
                Section {
                    Button("Simpan Log Bayar") { save() }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(amount <= 0 || amount > abs(person.balance) || isSaving)
                }
            }
            .navigationTitle("Catat Pembayaran")
            .alert("Tidak Dapat Menyimpan", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Terjadi kesalahan.") }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer {
                Task { @MainActor in isSaving = false }
            }
            do {
                try await repository.recordPayment(for: person, amount: amount, date: date, notes: notes.isEmpty ? nil : notes)
                await MainActor.run { onSaved() }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
