import Foundation
import Security
import Combine

//
// SecretsManager.swift
// Version 0.7 - Secure storage and management of key-value secrets
// Secrets are stored in the iOS Keychain for security
// Can be referenced in POST request bodies using {{KEY}} placeholder syntax
//

struct SecretItem: Identifiable, Codable {
    var id = UUID()
    var key: String
    var value: String
    
    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }
}

class SecretsManager: ObservableObject {
    @Published var secrets: [SecretItem] = []
    
    private let serviceIdentifier = "com.qikpost.secrets"
    private let secretsListKey = "SecretsList"
    
    init() {
        loadSecrets()
    }
    
    // MARK: - Public Methods
    
    /// Load all secrets from Keychain
    func loadSecrets() {
        // First, load the list of secret IDs and keys from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: secretsListKey),
              let secretsList = try? JSONDecoder().decode([SecretMetadata].self, from: data) else {
            secrets = []
            return
        }
        
        // Then, load each secret's value from Keychain
        secrets = secretsList.compactMap { metadata in
            guard let value = getKeychainValue(for: metadata.id.uuidString) else {
                return nil
            }
            return SecretItem(id: metadata.id, key: metadata.key, value: value)
        }
    }
    
    /// Save all secrets to Keychain
    func saveSecrets() {
        // Save the list of secret metadata to UserDefaults
        let metadata = secrets.map { SecretMetadata(id: $0.id, key: $0.key) }
        if let encoded = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(encoded, forKey: secretsListKey)
        }
        
        // Save each secret's value to Keychain
        for secret in secrets {
            setKeychainValue(secret.value, for: secret.id.uuidString)
        }
    }
    
    /// Add a new secret
    func addSecret() {
        secrets.append(SecretItem())
        saveSecrets()
    }
    
    /// Add a new secret with provided data
    func addSecret(_ secret: SecretItem) {
        secrets.append(secret)
        saveSecrets()
    }
    
    /// Delete secrets at the given offsets
    func deleteSecret(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            let secret = secrets[index]
            deleteKeychainValue(for: secret.id.uuidString)
            secrets.remove(at: index)
        }
        saveSecrets()
    }
    
    /// Update an existing secret
    func updateSecret(_ secret: SecretItem) {
        if let index = secrets.firstIndex(where: { $0.id == secret.id }) {
            secrets[index] = secret
            saveSecrets()
        }
    }
    
    /// Replace placeholders in text with actual secret values
    /// - Parameter text: The text containing {{KEY}} placeholders
    /// - Returns: Text with placeholders replaced by secret values
    func replacePlaceholders(in text: String) -> String {
        var result = text
        
        for secret in secrets where !secret.key.isEmpty {
            let placeholder = "{{\(secret.key)}}"
            result = result.replacingOccurrences(of: placeholder, with: secret.value)
        }
        
        return result
    }
    
    /// Get a dictionary of all secrets for reference
    func getSecretsDict() -> [String: String] {
        var dict: [String: String] = [:]
        for secret in secrets where !secret.key.isEmpty {
            dict[secret.key] = secret.value
        }
        return dict
    }
    
    // MARK: - Static Methods for Non-MainActor Contexts
    
    /// Load secrets from storage without MainActor isolation (for use in AppIntents)
    /// - Returns: Dictionary of key-value pairs
    nonisolated static func loadSecretsDict() -> [String: String] {
        let serviceIdentifier = "com.qikpost.secrets"
        let secretsListKey = "SecretsList"
        
        guard let data = UserDefaults.standard.data(forKey: secretsListKey),
              let secretsList = try? JSONDecoder().decode([SecretMetadata].self, from: data) else {
            return [:]
        }
        
        var dict: [String: String] = [:]
        for metadata in secretsList {
            if let value = getKeychainValueStatic(for: metadata.id.uuidString, service: serviceIdentifier) {
                dict[metadata.key] = value
            }
        }
        
        return dict
    }
    
    /// Replace placeholders using static method (for use in AppIntents)
    /// - Parameter text: The text containing {{KEY}} placeholders
    /// - Returns: Text with placeholders replaced by secret values
    nonisolated static func replacePlaceholdersStatic(in text: String) -> String {
        var result = text
        let secrets = loadSecretsDict()
        
        for (key, value) in secrets where !key.isEmpty {
            let placeholder = "{{\(key)}}"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        
        return result
    }
    
    // MARK: - Private Keychain Methods
    
    /// Store a value in the Keychain
    private func setKeychainValue(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // First, try to delete any existing item
        deleteKeychainValue(for: key)
        
        // Create a new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// Retrieve a value from the Keychain
    private func getKeychainValue(for key: String) -> String? {
        Self.getKeychainValueStatic(for: key, service: serviceIdentifier)
    }
    
    /// Retrieve a value from the Keychain (static version)
    nonisolated private static func getKeychainValueStatic(for key: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    /// Delete a value from the Keychain
    private func deleteKeychainValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Secret Metadata

/// Lightweight metadata stored in UserDefaults (keys only, values in Keychain)
private struct SecretMetadata: Codable {
    var id: UUID
    var key: String
}
