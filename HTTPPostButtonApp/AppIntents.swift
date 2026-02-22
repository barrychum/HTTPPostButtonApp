import AppIntents
import Foundation
import LocalAuthentication

//
// AppIntents.swift
// Version 0.7 - iOS Shortcuts integration via App Intents framework
// Exposes each configured button as a shortcut action
// Enforces biometric auth and confirmation prompt even when triggered via Shortcuts or Siri
//

// MARK: - App Shortcuts Provider

/// Registers all available shortcuts with the iOS Shortcuts app
@available(iOS 16.0, *)
struct HTTPPostButtonAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendPostRequestIntent(),
            phrases: [
                "Send request in \(.applicationName)",
                "Trigger button in \(.applicationName)",
                "Run \(\.$buttonName) in \(.applicationName)"
            ],
            shortTitle: "Send POST Request",
            systemImageName: "paperplane.fill"
        )
    }
}

// MARK: - Button Entity (represents each configured button)

/// Represents a single POST request button that can be selected in Shortcuts
@available(iOS 16.0, *)
struct PostButtonEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "POST Button")
    static var defaultQuery = PostButtonQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
    
    var title: String
    var url: String
    var otpEnabled: Bool
    var requireBiometric: Bool
}

// MARK: - Button Query (fetches buttons from storage)

/// Fetches the list of available buttons for Shortcuts to display
@available(iOS 16.0, *)
struct PostButtonQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PostButtonEntity] {
        return loadButtons().filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [PostButtonEntity] {
        return loadButtons()
    }
    
    private func loadButtons() -> [PostButtonEntity] {
        guard let data = UserDefaults.standard.data(forKey: "SavedRequests"),
              let configs = try? JSONDecoder().decode([PostRequestConfig].self, from: data) else {
            return []
        }
        
        return configs.map { config in
            PostButtonEntity(
                id: config.id.uuidString,
                title: config.buttonTitle,
                url: config.url,
                otpEnabled: config.otpEnabled,
                requireBiometric: config.requireBiometric
            )
        }
    }
}

// MARK: - Send POST Request Intent

/// The main Shortcut action - sends a configured POST request
@available(iOS 16.0, *)
struct SendPostRequestIntent: AppIntent {
    static var title: LocalizedStringResource = "Send POST Request"
    static var description = IntentDescription("Sends a configured HTTP POST request button from the app.")
    
    /// The button to trigger - user selects from a list in Shortcuts
    @Parameter(title: "Button", description: "The POST request button to send")
    var buttonName: PostButtonEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$buttonName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Load the full config from storage
        guard let config = loadConfig(for: buttonName.id) else {
            throw IntentError.buttonNotFound
        }
        
        // MARK: - Confirmation Check
        // If this button requires confirmation, use the App Intents dialog mechanism.
        // This presents a system confirmation prompt within Shortcuts/Siri before proceeding.
        if config.requireConfirmation {
            let message = config.confirmationMessage.isEmpty
                ? "Confirm to send ?"
                : config.confirmationMessage
            try await requestConfirmation(
                dialog: IntentDialog(stringLiteral: "\(config.buttonTitle): \(message)")
            )
        }
        
        // MARK: - Biometric / Passcode Check
        // If this button requires biometric auth, enforce it here before sending.
        // This runs even when triggered from Shortcuts or Siri.
        if config.requireBiometric {
            try await authenticateUser(reason: "Authenticate to send \"\(config.buttonTitle)\"")
        }
        
        // MARK: - OTP Generation
        var otp: String? = nil
        if config.otpEnabled {
            // Replace {{KEY}} placeholders in the OTP secret
            let resolvedSecret = SecretsManager.replacePlaceholdersStatic(in: config.otpSecret)
            otp = OTPGenerator.generateTOTP(secret: resolvedSecret)
            if otp == nil {
                throw IntentError.otpFailed
            }
        }
        
        // MARK: - Send the request
        let response = try await sendRequest(config: config, otp: otp)
        return .result(value: response)
    }
    
    // MARK: - Biometric Authentication
    
    /// Performs biometric (Face ID / Touch ID) or passcode authentication.
    /// Throws `IntentError.authenticationFailed` if the user fails or cancels.
    private func authenticateUser(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw IntentError.authenticationFailed(
                reason: policyError?.localizedDescription ?? "Authentication not available on this device."
            )
        }
        
        // Wrap the completion-handler-based LAContext call in a checked throwing continuation
        // so it fits naturally into async/await.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume()
                } else {
                    let message = error?.localizedDescription ?? "Authentication failed."
                    continuation.resume(throwing: IntentError.authenticationFailed(reason: message))
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadConfig(for idString: String) -> PostRequestConfig? {
        guard let data = UserDefaults.standard.data(forKey: "SavedRequests"),
              let configs = try? JSONDecoder().decode([PostRequestConfig].self, from: data),
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return configs.first(where: { $0.id == uuid })
    }
    
    private func sendRequest(config: PostRequestConfig, otp: String?) async throws -> String {
        guard let url = URL(string: config.url) else {
            throw IntentError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add headers with placeholder replacement
        for header in config.headers {
            // Replace {{KEY}} placeholders in header values with secrets
            let headerValue = SecretsManager.replacePlaceholdersStatic(in: header.value)
            request.setValue(headerValue, forHTTPHeaderField: header.key)
        }
        
        if !config.body.isEmpty {
            var bodyText = config.body
            if let otp = otp {
                bodyText = bodyText.replacingOccurrences(of: "{{OTP}}", with: otp)
            }
            
            // Replace {{KEY}} placeholders with secrets (using static method for actor safety)
            bodyText = SecretsManager.replacePlaceholdersStatic(in: bodyText)
            
            request.httpBody = bodyText.data(using: .utf8)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntentError.invalidResponse
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
        
        if (200...299).contains(httpResponse.statusCode) {
            return "Status: \(httpResponse.statusCode)\n\(responseBody)"
        } else {
            throw IntentError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }
    }
}

// MARK: - Intent Errors

@available(iOS 16.0, *)
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case buttonNotFound
    case otpFailed
    case invalidURL
    case invalidResponse
    case authenticationFailed(reason: String)
    case httpError(statusCode: Int, body: String)
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .buttonNotFound:
            return "Button not found. Please re-select the button in your Shortcut."
        case .otpFailed:
            return "Failed to generate OTP. Please check your secret key."
        case .invalidURL:
            return "The button has an invalid URL. Please edit the button and check the URL."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .httpError(let statusCode, let body):
            return "HTTP Error \(statusCode): \(body)"
        }
    }
}
