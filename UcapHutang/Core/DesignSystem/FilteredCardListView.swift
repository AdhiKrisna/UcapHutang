//
//  Components.swift
//  UcapHutang
//
//  Created by Cornelius Linux on 12/09/26.
//

import SwiftUI

struct FilterSegmentBar<T: Identifiable & RawRepresentable & CaseIterable & Equatable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let selection: T
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(T.allCases)) { filter in
                Button {
                    onSelect(filter)
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(selection == filter ? Color(.systemGray5) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FilteredCardListView<Item: Identifiable, Filter: Identifiable & RawRepresentable & CaseIterable & Equatable, CardContent: View, EmptyView: View>: View where Filter.RawValue == String, Filter.AllCases: RandomAccessCollection {
    let title: String
    let items: [Item]
    let selectedFilter: Filter
    let onSelectFilter: (Filter) -> Void
    let onSelectItem: (Item.ID) -> Void
    let emptyState: () -> EmptyView
    let cardContent: (Item) -> CardContent

    init(
        title: String,
        items: [Item],
        selectedFilter: Filter,
        onSelectFilter: @escaping (Filter) -> Void,
        onSelectItem: @escaping (Item.ID) -> Void,
        @ViewBuilder emptyState: @escaping () -> EmptyView,
        @ViewBuilder cardContent: @escaping (Item) -> CardContent
    ) {
        self.title = title
        self.items = items
        self.selectedFilter = selectedFilter
        self.onSelectFilter = onSelectFilter
        self.onSelectItem = onSelectItem
        self.emptyState = emptyState
        self.cardContent = cardContent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Title
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Filter Bar
                FilterSegmentBar(
                    selection: selectedFilter,
                    onSelect: onSelectFilter
                )
                .padding(.horizontal, 20)

                // List / Empty State
                if items.isEmpty {
                    emptyState()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            Button {
                                onSelectItem(item.id)
                            } label: {
                                cardContent(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }
}

// Mock Filter Enum
private enum MockFilter: String, CaseIterable, Identifiable {
    case all = "Semua"
    case pending = "Menunggu"
    case processed = "Selesai"

    var id: String { rawValue }
}

// Mock Item Data
private struct MockDraftItem: Identifiable {
    let id: UUID
    let title: String
    let amount: String
    let date: String
    let filterType: MockFilter
}

// Interactive Container for FilteredCardListView Preview
private struct FilteredCardListViewPreviewContainer: View {
    @State private var selectedFilter: MockFilter = .all
    @State private var selectedItemId: UUID?
    
    private let sampleItems: [MockDraftItem] = [
        MockDraftItem(
            id: UUID(),
            title: "Beli token listrik kantor",
            amount: "Rp 150.000",
            date: "Hari ini, 14:20",
            filterType: .pending
        ),
        MockDraftItem(
            id: UUID(),
            title: "Makan siang meeting tim",
            amount: "Rp 320.000",
            date: "Kemarin, 12:45",
            filterType: .pending
        ),
        MockDraftItem(
            id: UUID(),
            title: "Bensin motor operasional",
            amount: "Rp 50.000",
            date: "10 Sep 2026 14:20",
            filterType: .processed
        ),
    ]
    
    private var filteredItems: [MockDraftItem] {
        switch selectedFilter {
        case .all:
            return sampleItems
        case .pending:
            return sampleItems.filter{ $0.filterType == .pending }
        case .processed:
            return sampleItems.filter{ $0.filterType == .processed }
        }
    }
    
    var body: some View {
        NavigationStack {
            FilteredCardListView(
                title: "Catatan hasil rekaman perlu dicek sebelum masuk buku",
                items: filteredItems,
                selectedFilter: selectedFilter,
                onSelectFilter: { newFilter in selectedFilter = newFilter},
                onSelectItem: { id in selectedItemId = id}, emptyState: {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Tidak Ada Data")
                            .font(.headline)
                        Text("Belum ada draft pada kategori filter ini.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()},
                cardContent: { item in
                    // Dummy Card View
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Text(item.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.amount)
                            .font(.callout.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                })
            .navigationTitle("Preview List")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Standalone Preview for FilterSegmentBarPreviewContainer
private struct FilterSegmentBarPreviewContainer: View {
    @State private var activeFilter: MockFilter = .pending
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected: \(activeFilter.rawValue)")
                .font(.caption)
                .foregroundStyle(Color.secondary)
            
            FilterSegmentBar(
                selection: activeFilter,
                onSelect: { activeFilter = $0 }
            )
        }
        .padding(20)
    }
}

#Preview("Full List - Interactive") {
    FilteredCardListViewPreviewContainer()
}

#Preview("Filter Segment Only") {
    FilterSegmentBarPreviewContainer()
}

#Preview("Empty State Preview") {
    FilteredCardListView(
        title: "Daftar Kosong",
        items: [MockDraftItem](),
        selectedFilter: MockFilter.all, onSelectFilter: { _ in }, onSelectItem: { _ in }, emptyState: {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Semua draft selesai!")
                    .font(.headline)
            }
        }, cardContent: { _ in EmptyView()})
}
