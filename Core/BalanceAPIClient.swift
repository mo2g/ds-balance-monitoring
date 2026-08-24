import Foundation

public enum BalanceAPIError: Error, Equatable {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int)
    case decoding(String)
    case network(String)
}

extension BalanceAPIError: LocalizedError {
    public var errorDescription: String? {
        Localization.localized(error: self, language: LanguageManager.shared.resolved)
    }
}

public protocol BalanceProviding: Sendable {
    func fetchBalance() async throws -> BalanceResponse
}

public struct DeepSeekBalanceClient: BalanceProviding {
    public let baseURL: URL
    private let apiKeyProvider: @Sendable () -> String?
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://api.deepseek.com")!,
                apiKeyProvider: @escaping @Sendable () -> String?,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    public func fetchBalance() async throws -> BalanceResponse {
        guard let key = apiKeyProvider(), !key.isEmpty else {
            throw BalanceAPIError.missingAPIKey
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("user/balance"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BalanceAPIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw BalanceAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BalanceAPIError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(BalanceResponse.self, from: data)
        } catch {
            throw BalanceAPIError.decoding(error.localizedDescription)
        }
    }
}
