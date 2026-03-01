import Foundation
import Combine
import SwiftUI

//
// Models.swift
// Version 0.8 - Data models for POST request configuration and persistent storage
// Includes colour support, OTP config, biometric auth, confirmation prompt settings, and spacers
//

// MARK: - Button Item Type (enum to differentiate buttons from spacers)

enum ButtonItemType: String, Codable {
    case button
    case spacer
}

// MARK: - Button Item (wrapper that can be either a button or spacer)

struct ButtonItem: Identifiable, Codable {
    var id = UUID()
    var type: ButtonItemType
    var pageId: UUID?
    
    // Only used if type == .button
    var buttonConfig: PostRequestConfig?
    
    // Only used if type == .spacer
    var spacerHeight: CGFloat = 5.0
    
    // Convenience computed property
    var isSpacer: Bool {
        type == .spacer
    }
    
    init(id: UUID = UUID(), type: ButtonItemType, pageId: UUID?, buttonConfig: PostRequestConfig? = nil, spacerHeight: CGFloat = 5.0) {
        self.id = id
        self.type = type
        self.pageId = pageId
        self.buttonConfig = buttonConfig
        self.spacerHeight = spacerHeight
    }
    
    // Create a button item
    static func button(_ config: PostRequestConfig) -> ButtonItem {
        ButtonItem(id: config.id, type: .button, pageId: config.pageId, buttonConfig: config)
    }
    
    // Create a spacer item
    static func spacer(pageId: UUID, height: CGFloat = 5.0) -> ButtonItem {
        ButtonItem(id: UUID(), type: .spacer, pageId: pageId, buttonConfig: nil, spacerHeight: height)
    }
}

struct PostRequestConfig: Identifiable, Codable {
    var id = UUID()
    var buttonTitle: String
    var url: String
    var headers: [HTTPHeader]
    var body: String
    
    // MARK: - Page Association
    var pageId: UUID?  // Which page this button belongs to
    
    // MARK: - OTP Configuration
    var otpEnabled: Bool = false
    var otpSecret: String = ""
    
    // MARK: - Biometric Authentication
    var requireBiometric: Bool = false
    
    // MARK: - Confirmation Prompt
    var requireConfirmation: Bool = false
    var confirmationMessage: String = "Confirm to send ?"
    
    // MARK: - Response Display
    var showResponse: Bool = true
    /// Auto-dismiss timeout in seconds. 0 means the alert stays until dismissed manually.
    var responseTimeout: Int = 0
    
    // MARK: - Button Color
    // Stored as hex string so it's Codable (e.g. "007AFF" for blue)
    var buttonColorHex: String = "007AFF"
    
    /// Convenience accessor — converts stored hex back to a SwiftUI Color
    var buttonColor: Color {
        Color(hex: buttonColorHex) ?? .blue
    }
    
    struct HTTPHeader: Identifiable, Codable {
        var id = UUID()
        var key: String
        var value: String
    }
    
    init(
        buttonTitle: String = "New Button",
        url: String = "",
        headers: [HTTPHeader] = [],
        body: String = "",
        pageId: UUID? = nil,
        otpEnabled: Bool = false,
        otpSecret: String = "",
        requireBiometric: Bool = false,
        requireConfirmation: Bool = false,
        confirmationMessage: String = "Confirm to send ?",
        showResponse: Bool = true,
        responseTimeout: Int = 0,
        buttonColorHex: String = "007AFF"
    ) {
        self.buttonTitle = buttonTitle
        self.url = url
        self.headers = headers
        self.body = body
        self.pageId = pageId
        self.otpEnabled = otpEnabled
        self.otpSecret = otpSecret
        self.requireBiometric = requireBiometric
        self.requireConfirmation = requireConfirmation
        self.confirmationMessage = confirmationMessage
        self.showResponse = showResponse
        self.responseTimeout = responseTimeout
        self.buttonColorHex = buttonColorHex
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// Initialise a Color from a 6-character hex string, e.g. "FF0000"
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
    
    /// Convert a Color to a 6-character hex string
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Shared Color Swatches

/// The 12 swatches available in the button color picker
let buttonColorSwatches: [(name: String, hex: String)] = [
    ("Blue",        "007AFF"),
    ("Indigo",      "5856D6"),
    ("Purple",      "AF52DE"),
    ("Red",         "FF3B30"),
    ("Orange",      "FF9500"),
    ("Yellow",      "FFCC00"),
    ("Green",       "34C759"),
    ("Mint",        "00C7BE"),
    ("Teal",        "C7B192"),
    ("Brown",       "A2724C"),
    ("DGrey",       "8E8E93"),
    ("Graphite",    "636366")
]

// MARK: - RequestStore

class RequestStore: ObservableObject {
    @Published var requests: [PostRequestConfig] = []
    @Published var buttonItems: [ButtonItem] = []
    
    private let saveKey = "SavedRequests"
    private let itemsKey = "SavedButtonItems"
    
    init() {
        loadRequests()
        
        // Migration: assign any buttons without a pageId to the first available page
        let pageStore = PageStore()
        if let defaultPageId = pageStore.pages.first?.id {
            var needsSave = false
            for i in 0..<requests.count {
                if requests[i].pageId == nil {
                    requests[i].pageId = defaultPageId
                    needsSave = true
                }
            }
            if needsSave {
                saveRequests()
            }
        }
        
        // Migrate old requests to buttonItems if needed
        if buttonItems.isEmpty && !requests.isEmpty {
            buttonItems = requests.map { ButtonItem.button($0) }
            saveButtonItems()
        }
        
        if requests.isEmpty {
            // Create example button on first page
            if let defaultPageId = pageStore.pages.first?.id {
                let exampleButton = PostRequestConfig(
                    buttonTitle: "Example API Call",
                    url: "https://jsonplaceholder.typicode.com/posts",
                    headers: [
                        PostRequestConfig.HTTPHeader(key: "Content-Type", value: "application/json"),
                        PostRequestConfig.HTTPHeader(key: "Accept", value: "application/json")
                    ],
                    body: """
                    {
                        "title": "Test Post",
                        "body": "This is a test",
                        "userId": 1
                    }
                    """,
                    pageId: defaultPageId
                )
                requests = [exampleButton]
                buttonItems = [ButtonItem.button(exampleButton)]
                saveRequests()
                saveButtonItems()
            }
        }
    }
    
    func saveRequests() {
        // Update requests array from buttonItems
        requests = buttonItems.compactMap { $0.buttonConfig }
        
        if let encoded = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func saveButtonItems() {
        if let encoded = try? JSONEncoder().encode(buttonItems) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
        saveRequests()
    }
    
    func loadRequests() {
        // Try loading buttonItems first (new format)
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([ButtonItem].self, from: data) {
            buttonItems = decoded
            requests = buttonItems.compactMap { $0.buttonConfig }
            return
        }
        
        // Fall back to old format
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([PostRequestConfig].self, from: data) {
            requests = decoded
            buttonItems = decoded.map { ButtonItem.button($0) }
        }
    }
    
    func addRequest() {
        let newRequest = PostRequestConfig()
        requests.append(newRequest)
        buttonItems.append(ButtonItem.button(newRequest))
        saveButtonItems()
    }
    
    func addRequest(_ config: PostRequestConfig) {
        requests.append(config)
        buttonItems.append(ButtonItem.button(config))
        saveButtonItems()
    }
    
    func addSpacer(pageId: UUID, height: CGFloat = 5.0, at index: Int? = nil) {
        let spacer = ButtonItem.spacer(pageId: pageId, height: height)
        if let index = index {
            buttonItems.insert(spacer, at: index)
        } else {
            buttonItems.append(spacer)
        }
        saveButtonItems()
    }
    
    func updateItem(_ item: ButtonItem) {
        if let index = buttonItems.firstIndex(where: { $0.id == item.id }) {
            buttonItems[index] = item
            saveButtonItems()
        }
    }
    
    func deleteRequest(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            if index < buttonItems.count {
                buttonItems.remove(at: index)
            }
        }
        saveButtonItems()
    }
    
    func deleteItem(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            if index < buttonItems.count {
                buttonItems.remove(at: index)
            }
        }
        saveButtonItems()
    }
    
    func updateRequest(_ request: PostRequestConfig) {
        if let index = buttonItems.firstIndex(where: { $0.id == request.id }) {
            buttonItems[index].buttonConfig = request
            saveButtonItems()
        }
    }
    
    // MARK: - Reorder Buttons
    func moveRequest(from source: IndexSet, to destination: Int) {
        buttonItems.move(fromOffsets: source, toOffset: destination)
        saveButtonItems()
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        buttonItems.move(fromOffsets: source, toOffset: destination)
        saveButtonItems()
    }
}
