//
//  AWSSigV4Signer.swift
//  AayushTestAppV1
//
//

import Foundation
import CryptoKit

/// AWS Signature Version 4 (SigV4) signer for authenticating requests to AWS Bedrock.
///
/// **Purpose**: Signs HTTP requests using AWS credentials (access key, secret key, region)
/// to authenticate with AWS Bedrock endpoints that require SigV4 signing.
///
/// **Architecture**: Pure utility class with no dependencies. Implements the AWS SigV4
/// signing algorithm as specified in AWS documentation.
final class AWSSigV4Signer {
    private let accessKey: String
    private let secretKey: String
    private let region: String
    private let service: String = "bedrock"
    
    init(accessKey: String, secretKey: String, region: String) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
    }
    
    /// Signs a URLRequest using AWS SigV4.
    /// - Parameter request: The request to sign
    /// - Returns: A signed copy of the request
    func sign(_ request: URLRequest) throws -> URLRequest {
        guard let url = request.url,
              let host = url.host else {
            throw NSError(domain: "AWSSigV4Signer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var signedRequest = request
        
        // Get current date/time
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateStamp = dateFormatter.string(from: now)
        
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)
        
        // Extract region from host if not provided, or use configured region
        let requestRegion = extractRegion(from: host) ?? region
        
        // Canonical URI
        let canonicalURI = url.path.isEmpty ? "/" : url.path
        
        // Canonical query string
        var canonicalQuerystring = ""
        if let query = url.query {
            let params = query.components(separatedBy: "&").sorted()
            canonicalQuerystring = params.joined(separator: "&")
        }
        
        // Canonical headers
        var headers: [String: String] = [:]
        if let existingHeaders = request.allHTTPHeaderFields {
            for (key, value) in existingHeaders {
                headers[key.lowercased()] = value.trimmingCharacters(in: .whitespaces)
            }
        }
        headers["host"] = host
        headers["x-amz-date"] = amzDate
        
        let sortedHeaders = headers.sorted { $0.key < $1.key }
        let canonicalHeaders = sortedHeaders.map { "\($0.key):\($0.value)" }.joined(separator: "\n") + "\n"
        let signedHeaders = sortedHeaders.map { $0.key }.joined(separator: ";")
        
        // Payload hash (SHA256 of body)
        let payload: Data
        if let body = request.httpBody {
            payload = body
        } else {
            payload = Data()
        }
        let payloadHash = SHA256.hash(data: payload)
        let payloadHashHex = payloadHash.map { String(format: "%02x", $0) }.joined()
        
        // Create canonical request
        let httpMethod = request.httpMethod ?? "GET"
        let canonicalRequest = """
        \(httpMethod)
        \(canonicalURI)
        \(canonicalQuerystring)
        \(canonicalHeaders)
        \(signedHeaders)
        \(payloadHashHex)
        """
        
        // Create string to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(requestRegion)/\(service)/aws4_request"
        let canonicalRequestHash = SHA256.hash(data: canonicalRequest.data(using: .utf8)!)
        let canonicalRequestHashHex = canonicalRequestHash.map { String(format: "%02x", $0) }.joined()
        let stringToSign = """
        \(algorithm)
        \(amzDate)
        \(credentialScope)
        \(canonicalRequestHashHex)
        """
        
        // Calculate signature
        let kDateBytes = hmacSHA256(key: ("AWS4" + secretKey).data(using: .utf8)!, data: dateStamp.data(using: .utf8)!)
        let kDate = Data(kDateBytes)
        let kRegionBytes = hmacSHA256(key: kDate, data: requestRegion.data(using: .utf8)!)
        let kRegion = Data(kRegionBytes)
        let kServiceBytes = hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kService = Data(kServiceBytes)
        let kSigningBytes = hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        let kSigning = Data(kSigningBytes)
        let signatureBytes = hmacSHA256(key: kSigning, data: stringToSign.data(using: .utf8)!)
        let signatureHex = signatureBytes.map { String(format: "%02x", $0) }.joined()
        
        // Create authorization header
        let authorization = """
        \(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signatureHex)
        """
        
        // Add headers to request
        signedRequest.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        signedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        signedRequest.setValue(payloadHashHex, forHTTPHeaderField: "x-amz-content-sha256")
        
        return signedRequest
    }
    
    private func extractRegion(from host: String) -> String? {
        // Extract region from hostname like: bedrock-runtime.us-west-2.amazonaws.com
        let components = host.components(separatedBy: ".")
        if components.count >= 3, components[0] == "bedrock-runtime" {
            return components[1] // e.g., "us-west-2"
        }
        return nil
    }
    
    private func hmacSHA256(key: Data, data: Data) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: key)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Array(hmac)
    }
}
