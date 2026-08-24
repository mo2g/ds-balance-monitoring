import Foundation

public struct BalanceInfo: Equatable {
    public var currency: String
    public var totalBalance: Double
    public var grantedBalance: Double
    public var toppedUpBalance: Double

    public init(currency: String, totalBalance: Double, grantedBalance: Double, toppedUpBalance: Double) {
        self.currency = currency
        self.totalBalance = totalBalance
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
    }
}

extension BalanceInfo: Decodable {
    private enum CodingKeys: String, CodingKey {
        case currency, totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency = try c.decode(String.self, forKey: .currency)
        totalBalance = try Self.parseAmount(c.decode(String.self, forKey: .totalBalance))
        grantedBalance = try Self.parseAmount(c.decode(String.self, forKey: .grantedBalance))
        toppedUpBalance = try Self.parseAmount(c.decode(String.self, forKey: .toppedUpBalance))
    }

    private static func parseAmount(_ raw: String) throws -> Double {
        guard let value = Double(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid amount: \(raw)"))
        }
        return value
    }
}

public struct BalanceResponse: Equatable, Decodable {
    public var isAvailable: Bool
    public var balanceInfos: [BalanceInfo]

    public init(isAvailable: Bool, balanceInfos: [BalanceInfo]) {
        self.isAvailable = isAvailable
        self.balanceInfos = balanceInfos
    }

    private enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}
