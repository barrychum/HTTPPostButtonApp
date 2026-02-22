import Foundation

//
// HTTPService.swift
// Version 0.7 - Service for sending HTTP POST requests
// Supports optional OTP placeholder replacement in request body
//

class HTTPService {
    
    // MARK: - Main POST Request (v0.3)
    
    /// Send POST request, optionally replacing {{OTP}} placeholder with actual OTP
    /// and {{KEY}} placeholders with secrets from SecretsManager
    /// - Parameters:
    ///   - config: Request configuration
    ///   - otp: Optional OTP to inject into the request body
    ///   - completion: Callback with result
    static func sendPostRequest(config: PostRequestConfig, otp: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: config.url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add headers with placeholder replacement
        for header in config.headers {
            // Replace {{KEY}} placeholders in header values with secrets
            let headerValue = SecretsManager.replacePlaceholdersStatic(in: header.value)
            request.setValue(headerValue, forHTTPHeaderField: header.key)
        }
        
        // Add body with placeholder replacement
        if !config.body.isEmpty {
            var bodyText = config.body
            
            // Replace {{OTP}} placeholder with the generated OTP code
            if let otp = otp {
                bodyText = bodyText.replacingOccurrences(of: "{{OTP}}", with: otp)
            }
            
            // Replace {{KEY}} placeholders with secrets (using static method for actor safety)
            bodyText = SecretsManager.replacePlaceholdersStatic(in: bodyText)
            
            request.httpBody = bodyText.data(using: .utf8)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Invalid response", code: 500, userInfo: nil)))
                }
                return
            }
            
            let statusCode = httpResponse.statusCode
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
            
            DispatchQueue.main.async {
                if (200...299).contains(statusCode) {
                    completion(.success("Status: \(statusCode)\n\nResponse:\n\(responseBody)"))
                } else {
                    completion(.failure(NSError(
                        domain: "HTTP Error",
                        code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Status: \(statusCode)\n\nResponse:\n\(responseBody)"]
                    )))
                }
            }
        }
        
        task.resume()
    }
}
