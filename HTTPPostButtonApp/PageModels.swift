import Foundation
import SwiftUI
import Combine

//
// PageModels.swift
// Version 0.8 - Data models for organizing buttons into pages/tabs
// Supports multiple pages with custom names and icons
//

struct PageConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var iconName: String        // SF Symbol name
    var iconColorHex: String    // Icon color as hex string
    var order: Int              // For tab ordering
    var createdDate: Date
    
    /// Convenience accessor — converts stored hex back to a SwiftUI Color
    var iconColor: Color {
        Color(hex: iconColorHex) ?? .blue
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder.fill",
        iconColorHex: String = "007AFF",
        order: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.order = order
        self.createdDate = createdDate
    }
}

// MARK: - PageStore

class PageStore: ObservableObject {
    @Published var pages: [PageConfig] = []
    
    private let saveKey = "SavedPages"
    private let defaultPageKey = "DefaultPageID"
    
    init() {
        loadPages()
        if pages.isEmpty {
            // Create default page on first launch
            pages = [
                PageConfig(
                    name: "Buttons",
                    iconName: "square.grid.2x2.fill",
                    order: 0
                )
            ]
            savePages()
        }
    }
    
    // MARK: - Persistence
    
    func savePages() {
        if let encoded = try? JSONEncoder().encode(pages) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func loadPages() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([PageConfig].self, from: data) {
            pages = decoded.sorted(by: { $0.order < $1.order })
        }
    }
    
    // MARK: - CRUD Operations
    
    func addPage(_ page: PageConfig) {
        var newPage = page
        newPage.order = pages.count
        pages.append(newPage)
        savePages()
    }
    
    func updatePage(_ page: PageConfig) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            pages[index] = page
            savePages()
        }
    }
    
    func deletePage(at offsets: IndexSet) {
        pages.remove(atOffsets: offsets)
        // Reorder remaining pages
        for (index, _) in pages.enumerated() {
            pages[index].order = index
        }
        savePages()
    }
    
    func deletePage(_ page: PageConfig) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            pages.remove(at: index)
            // Reorder remaining pages
            for (idx, _) in pages.enumerated() {
                pages[idx].order = idx
            }
            savePages()
        }
    }
    
    func movePage(from source: IndexSet, to destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
        // Update order values
        for (index, _) in pages.enumerated() {
            pages[index].order = index
        }
        savePages()
    }
    
    // MARK: - Default Page
    
    func setDefaultPage(_ pageId: UUID) {
        UserDefaults.standard.set(pageId.uuidString, forKey: defaultPageKey)
    }
    
    func getDefaultPageId() -> UUID? {
        if let idString = UserDefaults.standard.string(forKey: defaultPageKey),
           let uuid = UUID(uuidString: idString) {
            return uuid
        }
        return pages.first?.id
    }
    
    func getDefaultPage() -> PageConfig? {
        if let defaultId = getDefaultPageId() {
            return pages.first(where: { $0.id == defaultId })
        }
        return pages.first
    }
}

// MARK: - Available Icons

/// Curated list of SF Symbols suitable for page icons
let availablePageIcons: [(name: String, symbol: String)] = [
    ("Grid", "square.grid.2x2.fill"),
    ("List", "list.bullet"),
    ("Folder", "folder.fill"),
    ("Briefcase", "briefcase.fill"),
    ("House", "house.fill"),
    ("Building", "building.2.fill"),
    ("Gear", "gear"),
    ("Network", "network"),
    ("Server", "server.rack"),
    ("Cloud", "cloud.fill"),
    ("Lock", "lock.fill"),
    ("Key", "key.fill"),
    ("Person", "person.fill"),
    ("People", "person.2.fill"),
    ("Star", "star.fill"),
    ("Heart", "heart.fill"),
    ("Flag", "flag.fill"),
    ("Bookmark", "bookmark.fill"),
    ("Tag", "tag.fill"),
    ("Paperclane", "paperplane.fill"),
    ("Envelope", "envelope.fill"),
    ("Phone", "phone.fill"),
    ("Message", "message.fill"),
    ("Cart", "cart.fill"),
    ("Creditcard", "creditcard.fill"),
    ("Chart", "chart.bar.fill"),
    ("Doc", "doc.fill"),
    ("Tray", "tray.fill"),
    ("Archivebox", "archivebox.fill"),
    ("Cube", "cube.fill")
]

/// Color swatches for page icons (same as button colors for consistency)
let pageIconColorSwatches: [(name: String, hex: String)] = [
    ("Blue",        "007AFF"),
    ("Indigo",      "5856D6"),
    ("Purple",      "AF52DE"),
    ("Pink",        "FF2D55"),
    ("Red",         "FF3B30"),
    ("Orange",      "FF9500"),
    ("Yellow",      "FFCC00"),
    ("Green",       "34C759"),
    ("Teal",        "30B0C7"),
    ("Mint",        "00C7BE"),
    ("Brown",       "A2845E"),
    ("Gray",        "8E8E93")
]
