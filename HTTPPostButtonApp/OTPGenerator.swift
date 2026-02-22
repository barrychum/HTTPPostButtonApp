import Foundation
import CryptoKit

//
// OTPGenerator.swift
// Version 0.7 - Local TOTP/HOTP generation
// Generates time-based one-time passwords using HMAC-SHA1 (RFC 4226/6238)
//

class OTPGenerator {
    
    // MARK: - TOTP Generation
    
    /// Generate a 6-digit TOTP (Time-based One-Time Password)
    /// - Parameters:
    ///   - secret: Base32-encoded secret key
    ///   - timeInterval: Time step in seconds (default 30)
    ///   - digits: Number of digits in OTP (default 6)
    /// - Returns: 6-digit OTP string, or nil if secret is invalid
    static func generateTOTP(secret: String, timeInterval: TimeInterval = 30, digits: Int = 6) -> String? {
        // Decode Base32 secret
        guard let secretData = base32Decode(secret) else {
            return nil
        }
        
        // Get current time counter
        let counter = UInt64(Date().timeIntervalSince1970 / timeInterval)
        
        // Generate HOTP
        return generateHOTP(secret: secretData, counter: counter, digits: digits)
    }
    
    // MARK: - HOTP Generation (RFC 4226)
    
    /// Generate HMAC-based One-Time Password
    private static func generateHOTP(secret: Data, counter: UInt64, digits: Int) -> String {
        // Convert counter to big-endian bytes
        var counterBytes = counter.bigEndian
        let counterData = Data(bytes: &counterBytes, count: MemoryLayout.size(ofValue: counterBytes))
        
        // Calculate HMAC-SHA1
        let hmac = computeHMAC(key: secret, message: counterData)
        
        // Dynamic truncation
        let offset = Int(hmac[hmac.count - 1] & 0x0f)
        let truncatedHash = hmac.subdata(in: offset..<offset+4)
        
        // Convert to integer
        var value: UInt32 = 0
        truncatedHash.withUnsafeBytes { bytes in
            value = bytes.load(as: UInt32.self).bigEndian
        }
        
        // Remove most significant bit
        value = value & 0x7fffffff
        
        // Generate OTP
        let otp = value % UInt32(pow(10, Double(digits)))
        
        // Format with leading zeros
        return String(format: "%0\(digits)d", otp)
    }
    
    // MARK: - HMAC-SHA1
    
    /// Compute HMAC-SHA1
    private static func computeHMAC(key: Data, message: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        key.withUnsafeBytes { keyBytes in
            message.withUnsafeBytes { messageBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1),
                      keyBytes.baseAddress, key.count,
                      messageBytes.baseAddress, message.count,
                      &hmac)
            }
        }
        
        return Data(hmac)
    }
    
    // MARK: - Base32 Decoding
    
    /// Decode Base32 string to Data
    private static func base32Decode(_ string: String) -> Data? {
        // Remove spaces and convert to uppercase
        let cleanString = string.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Base32 alphabet
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        
        var bits = 0
        var buffer = 0
        var output = Data()
        
        for char in cleanString {
            guard let index = alphabet.firstIndex(of: char) else {
                // Invalid character, try treating as hex if it's not base32
                return decodeHexOrRaw(string)
            }
            
            let value = alphabet.distance(from: alphabet.startIndex, to: index)
            buffer = (buffer << 5) | value
            bits += 5
            
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((buffer >> bits) & 0xFF))
            }
        }
        
        return output
    }
    
    /// Try to decode as hex or use raw string bytes
    private static func decodeHexOrRaw(_ string: String) -> Data? {
        // Try hex decoding
        if let hexData = hexDecode(string) {
            return hexData
        }
        
        // Fall back to UTF-8 bytes
        return string.data(using: .utf8)
    }
    
    /// Decode hexadecimal string
    private static func hexDecode(_ string: String) -> Data? {
        let cleanString = string.replacingOccurrences(of: " ", with: "")
        
        guard cleanString.count % 2 == 0 else {
            return nil
        }
        
        var data = Data()
        var index = cleanString.startIndex
        
        while index < cleanString.endIndex {
            let nextIndex = cleanString.index(index, offsetBy: 2)
            let byteString = cleanString[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        return data
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

// Helper for HMAC calculation
private func CCHmac(_ algorithm: CCHmacAlgorithm,
                    _ key: UnsafeRawPointer?,
                    _ keyLength: Int,
                    _ data: UnsafeRawPointer?,
                    _ dataLength: Int,
                    _ macOut: UnsafeMutableRawPointer?) {
    CommonCrypto.CCHmac(algorithm, key, keyLength, data, dataLength, macOut)
}
