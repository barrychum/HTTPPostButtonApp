import LocalAuthentication
import Foundation

//
// BiometricAuth.swift
// Version 0.7 - Handles biometric and passcode authentication
// Used before sending requests and before editing or adding buttons
//

class BiometricAuth {
    
    /// Check if biometric authentication is available on this device
    /// - Returns: true if Face ID or Touch ID is available
    static func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get the type of biometric authentication available
    /// - Returns: "Face ID", "Touch ID", or "None"
    static func biometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "None"
        }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Biometric"
        }
    }
    
    /// Authenticate user with Face ID or Touch ID, with passcode fallback on failure
    /// - Parameters:
    ///   - reason: The reason for authentication (shown to user)
    ///   - completion: Callback with success/failure
    static func authenticate(reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Allow passcode as fallback by showing "Enter Password" button
        context.localizedFallbackTitle = "Use Passcode"
        
        // Check if any authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(BiometricError.notAvailable))
                }
            }
            return
        }
        
        // Use .deviceOwnerAuthentication which tries biometrics first, then allows passcode
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if let error = authError {
                    completion(.failure(error))
                } else {
                    completion(.failure(BiometricError.unknown))
                }
            }
        }
    }
    
    /// Authenticate with passcode only (no biometrics)
    /// - Parameters:
    ///   - reason: The reason for authentication
    ///   - completion: Callback with success/failure
    static func authenticateWithPasscode(reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(BiometricError.notAvailable))
                }
            }
            return
        }
        
        // Perform authentication with passcode
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if let error = authError {
                    completion(.failure(error))
                } else {
                    completion(.failure(BiometricError.unknown))
                }
            }
        }
    }
}

// MARK: - Biometric Errors

enum BiometricError: LocalizedError {
    case notAvailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .unknown:
            return "Unknown authentication error"
        }
    }
}
