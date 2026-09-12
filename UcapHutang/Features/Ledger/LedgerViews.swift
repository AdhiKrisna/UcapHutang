import SwiftUI
import Combine

enum LedgerFilter: String, CaseIterable, Identifiable {
    case all = "Semua"
    case receivable = "Berutang ke kamu"
    case debt = "Kamu berutang"

    var id: String { rawValue }
}

enum DetailFilter: String, CaseIterable, Identifiable {
    case all = "Semua"
    case piutang = "Piutang"
    case utang = "Utang"
    case bayar = "Bayar"

    var id: String { rawValue }
}

@MainActor
final class LedgerListViewModel: ObservableObject {
    @Published private(set) var summaries: [PersonLedgerSummary] = []
    @Published private(set) var entries: [LedgerEntry] = []
    @Published var filter: LedgerFilter = .all
    @Published var searchQuery: String = ""
    @Published var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) { self.repository = repository }

    var totalReceivable: Int64 {
        summaries.filter { $0.balance > 0 }.reduce(0) { $0 + $1.balance }
    }

    var receivableCount: Int {
        summaries.filter { $0.balance > 0 }.count
    }

    var totalDebt: Int64 {
        abs(summaries.filter { $0.balance < 0 }.reduce(0) { $0 + $1.balance })
    }

    var debtCount: Int {
        summaries.filter { $0.balance < 0 }.count
    }

    var filteredSummaries: [PersonLedgerSummary] {
        summaries.filter { person in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .receivable:
                matchesFilter = person.balance > 0
            case .debt:
                matchesFilter = person.balance < 0
            }

            let matchesSearch: Bool
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = person.displayName.localizedCaseInsensitiveContains(searchQuery)
            }

            return matchesFilter && matchesSearch
        }
    }

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

// MARK: - Main Ledger List View
struct LedgerListView: View {
    @StateObject private var viewModel: LedgerListViewModel
    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: LedgerListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title
                        Text("Ringkasan Saldo")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // 2 Metric Summary Cards
                        HStack(spacing: 12) {
                            // Piutang
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.left")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.green)
                                    Text("Piutang")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.green)
                                }

                                Text(formatRupiah(viewModel.totalReceivable))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.green)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("\(viewModel.receivableCount) orang berutang")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // Utang
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                    Text("Utang")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.red)
                                }

                                Text(formatRupiah(viewModel.totalDebt))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.red)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("\(viewModel.debtCount) tanggungan aktif")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 20)

                        // Filter Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LedgerFilter.allCases) { filter in
                                    LedgerFilterPill(
                                        filter: filter,
                                        isSelected: viewModel.filter == filter
                                    ) {
                                        viewModel.filter = filter
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Person Card List
                        if viewModel.filteredSummaries.isEmpty {
                            AppEmptyState(
                                icon: "book.closed",
                                title: "Belum ada riwayat",
                                message: "Data yang sudah dikonfirmasi akan dikelompokkan per orang."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredSummaries) { person in
                                    NavigationLink(value: person) {
                                        PersonCardRow(person: person)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 80)
                }

                // Bottom Search Bar Floating
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)

                    TextField("Cari nama orang", text: $viewModel.searchQuery)
                        .font(.body)

                    Image(systemName: "mic")
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Person Card Row
private struct PersonCardRow: View {
    let person: PersonLedgerSummary

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.displayName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)

                Text("\(person.entryCount) Catatan")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if person.balance == 0 {
                    Text("Lunas")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                } else if person.balance > 0 {
                    Text(formatRupiah(person.balance))
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.green)
                } else {
                    Text(formatRupiah(abs(person.balance)))
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.red)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

// MARK: - Ledger Filter Pill
private struct LedgerFilterPill: View {
    let filter: LedgerFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter == .receivable {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else if filter == .debt {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }

                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Person Ledger Detail View
struct PersonLedgerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var person: PersonLedgerSummary
    @State private var entries: [LedgerEntry]
    let repository: any TransactionRepository
    @State private var showingPayment = false
    @State private var selectedFilter: DetailFilter = .all

    init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository) {
        _person = State(initialValue: person)
        _entries = State(initialValue: entries)
        self.repository = repository
    }

    private var filteredEntries: [LedgerEntry] {
        entries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .piutang:
                return entry.kind == .charge && entry.balanceDelta > 0
            case .utang:
                return entry.kind == .charge && entry.balanceDelta < 0
            case .bayar:
                return entry.kind == .payment
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Hero Saldo Card
                VStack(alignment: .leading, spacing: 12) {
                    // Status Tag
                    HStack(spacing: 6) {
                        Circle()
                            .fill(person.balance >= 0 ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text(person.balance >= 0 ? "Dia berutang padamu" : "Kamu berutang padanya")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(person.balance >= 0 ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((person.balance >= 0 ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())

                    // Big Balance Text
                    Text(formatRupiah(abs(person.balance)))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.primary)

                    // Ingatkan Action Button
                    Button {
                        sendReminderMessage()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.subheadline)
                            Text("Ingatkan lewat iMessage")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(red: 1.0, green: 0.96, blue: 0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Detail Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DetailFilter.allCases) { filter in
                            DetailFilterPill(
                                filter: filter,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Section Title: Riwayat Catatan
                Text("Riwayat Catatan")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                // History Entries List
                LazyVStack(spacing: 10) {
                    ForEach(filteredEntries) { entry in
                        DetailEntryCardRow(entry: entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(person.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Catat Bayar") {
                    showingPayment = true
                }
                .font(.subheadline.weight(.medium))
            }
        }
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

    private func sendReminderMessage() {
        let text = "Halo \(person.displayName), mengingatkan kembali ada catatan saldo \(formatRupiah(abs(person.balance))) di UcapHutang ya."
        if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "sms:&body=\(encoded)") {
            UIApplication.shared.open(url)
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

// MARK: - Detail Entry Card Row
private struct DetailEntryCardRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            // Icon Bubble
            ZStack {
                Circle()
                    .fill(bubbleColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: bubbleIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(bubbleColor)
            }

            // Title & Date
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(formatDate(entry.date))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // Amount
            Text(formatRupiah(abs(entry.balanceDelta)))
                .font(.body.weight(.bold))
                .foregroundStyle(bubbleColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var isPayment: Bool {
        entry.kind == .payment
    }

    private var bubbleColor: Color {
        if isPayment {
            return Color.blue
        } else if entry.balanceDelta >= 0 {
            return Color.green
        } else {
            return Color.red
        }
    }

    private var bubbleIcon: String {
        if isPayment {
            return "creditcard.fill"
        } else if entry.balanceDelta >= 0 {
            return "arrow.down.left"
        } else {
            return "arrow.up.right"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Detail Filter Pill
private struct DetailFilterPill: View {
    let filter: DetailFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter == .piutang {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                } else if filter == .utang {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                } else if filter == .bayar {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                }

                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Currency Helper
private func formatRupiah(_ amount: Int64) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    let numStr = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    return "Rp. \(numStr)"
}

// MARK: - Payment Sheet View
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

#Preview("Ledger List") {
    LedgerListView(repository: MockPreviewRepository())
}

private final class MockPreviewRepository: TransactionRepository {
    func draftsNeedingReview() async throws -> [TransactionDraft] { [] }
    func draft(id: UUID) async throws -> TransactionDraft? { nil }
    func saveDraft(_ draft: TransactionDraft) async throws {}
    func confirmDraft(_ draft: TransactionDraft) async throws {}
    func discardDraft(id: UUID) async throws {}
    func ledgerEntries() async throws -> [LedgerEntry] {
        [
            LedgerEntry(personID: "1", personName: "Budi Santoso", kind: .charge, balanceDelta: 300_000, date: Date(), title: "Makan Siang"),
            LedgerEntry(personID: "2", personName: "Siti Rahma", kind: .charge, balanceDelta: -150_000, date: Date(), title: "Bensin"),
            LedgerEntry(personID: "3", personName: "Andi Wijaya", kind: .charge, balanceDelta: 450_000, date: Date(), title: "Tiket"),
            LedgerEntry(personID: "4", personName: "Rian Pratama", kind: .payment, balanceDelta: 0, date: Date(), title: "Pelunasan"),
            LedgerEntry(personID: "5", personName: "Dewi Lestari", kind: .charge, balanceDelta: 75_000, date: Date(), title: "Kopi")
        ]
    }
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws {}
}

