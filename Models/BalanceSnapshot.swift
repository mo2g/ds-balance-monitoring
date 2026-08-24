import Foundation
import GRDB

public struct BalanceSnapshot: Equatable {
    public var id: Int64?
    public var timestamp: Date
    public var currency: String
    public var totalBalance: Double
    public var grantedBalance: Double
    public var toppedUpBalance: Double
    public var consumed: Double
    public var isRecharge: Bool

    public init(id: Int64? = nil, timestamp: Date, currency: String,
                totalBalance: Double, grantedBalance: Double, toppedUpBalance: Double,
                consumed: Double, isRecharge: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.currency = currency
        self.totalBalance = totalBalance
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.consumed = consumed
        self.isRecharge = isRecharge
    }
}

extension BalanceSnapshot: FetchableRecord {
    public init(row: Row) {
        id = row["id"]
        timestamp = Date(timeIntervalSince1970: row["timestamp"])
        currency = row["currency"]
        totalBalance = row["total_balance"]
        grantedBalance = row["granted_balance"]
        toppedUpBalance = row["topped_up_balance"]
        consumed = row["consumed"]
        isRecharge = (row["is_recharge"] as Int64) != 0
    }
}
