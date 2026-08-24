import Foundation
import GRDB

public final class BalanceRepository {
    public let dbQueue: DatabaseQueue
    public var calendar: Calendar

    public init(dbQueue: DatabaseQueue, calendar: Calendar = .current) {
        self.dbQueue = dbQueue
        self.calendar = calendar
        try? dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS error_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp INTEGER NOT NULL,
                    message TEXT NOT NULL
                )
                """)
        }
    }

    public static func inMemory() throws -> BalanceRepository {
        try BalanceRepository(dbQueue: DatabaseQueue())
    }

    public static func open(at url: URL) throws -> BalanceRepository {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        return BalanceRepository(dbQueue: queue)
    }

    public func tableName(for year: Int) -> String { "balance_samples_\(year)" }

    public func ensureYearTable(_ year: Int) throws {
        let table = tableName(for: year)
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS "\(table)" (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp INTEGER NOT NULL,
                    currency TEXT NOT NULL,
                    total_balance REAL NOT NULL,
                    granted_balance REAL NOT NULL,
                    topped_up_balance REAL NOT NULL,
                    consumed REAL NOT NULL,
                    is_recharge INTEGER NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS "idx_\(table)_ts_currency"
                ON "\(table)" (timestamp, currency)
                """)
        }
    }

    public func record(balances: [BalanceInfo], at timestamp: Date) throws {
        let year = calendar.component(.year, from: timestamp)
        try ensureYearTable(year)
        try dbQueue.write { db in
            for info in balances {
                let previous = try lastSnapshot(currency: info.currency, inYear: year, db: db)
                let consumed: Double
                let isRecharge: Bool
                if let previous {
                    if info.totalBalance < previous.totalBalance {
                        consumed = previous.totalBalance - info.totalBalance
                        isRecharge = false
                    } else if info.totalBalance > previous.totalBalance {
                        consumed = 0
                        isRecharge = true
                    } else {
                        consumed = 0
                        isRecharge = false
                    }
                } else {
                    consumed = 0
                    isRecharge = false
                }
                let table = tableName(for: year)
                try db.execute(
                    sql: """
                    INSERT INTO "\(table)"
                        (timestamp, currency, total_balance, granted_balance, topped_up_balance, consumed, is_recharge)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(timestamp, currency) DO UPDATE SET
                        total_balance = excluded.total_balance,
                        granted_balance = excluded.granted_balance,
                        topped_up_balance = excluded.topped_up_balance,
                        consumed = excluded.consumed,
                        is_recharge = excluded.is_recharge
                    """,
                    arguments: [Int64(timestamp.timeIntervalSince1970), info.currency,
                                info.totalBalance, info.grantedBalance, info.toppedUpBalance,
                                consumed, isRecharge ? 1 : 0])
            }
        }
    }

    private func lastSnapshot(currency: String, inYear year: Int, db: Database) throws -> BalanceSnapshot? {
        if let found = try fetchLast(currency: currency, year: year, db: db) { return found }
        return try fetchLast(currency: currency, year: year - 1, db: db)
    }

    private func fetchLast(currency: String, year: Int, db: Database) throws -> BalanceSnapshot? {
        let table = tableName(for: year)
        let exists = try db.tableExists(table)
        guard exists else { return nil }
        return try BalanceSnapshot.fetchOne(db, sql: """
            SELECT id, timestamp, currency, total_balance, granted_balance, topped_up_balance, consumed, is_recharge
            FROM "\(table)"
            WHERE currency = ?
            ORDER BY timestamp DESC, id DESC
            LIMIT 1
            """, arguments: [currency])
    }

    public func rawSnapshots(currency: String?, year: Int, range: DateInterval?) throws -> [BalanceSnapshot] {
        try dbQueue.read { db in
            let table = tableName(for: year)
            guard try db.tableExists(table) else { return [] }
            var sql = """
                SELECT id, timestamp, currency, total_balance, granted_balance, topped_up_balance, consumed, is_recharge
                FROM "\(table)"
                """
            var arguments: [DatabaseValueConvertible?] = []
            var conditions: [String] = []
            if let currency {
                conditions.append("currency = ?")
                arguments.append(currency)
            }
            if let range {
                // Half-open `[start, end)` so adjacent pages never double-count
                // the boundary bucket and never leave a gap between pages.
                conditions.append("timestamp >= ? AND timestamp < ?")
                arguments.append(Int64(range.start.timeIntervalSince1970))
                arguments.append(Int64(range.end.timeIntervalSince1970))
            }
            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }
            sql += " ORDER BY timestamp ASC, id ASC"
            return try BalanceSnapshot.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }

    public func availableYears() throws -> [Int] {
        try dbQueue.read { db in
            let names = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'balance_samples_%'
                """)
            return names.compactMap { name in
                guard name.hasPrefix("balance_samples_"), let year = Int(name.dropFirst("balance_samples_".count)) else { return nil }
                return year
            }
        }
    }

    /// Newest sample timestamp in a year table, optionally filtered by currency.
    /// Returns nil when the table does not exist or has no matching rows.
    public func latestTimestamp(currency: String?, year: Int) throws -> Date? {
        let raw: Int64? = try dbQueue.read { db -> Int64? in
            let table = self.tableName(for: year)
            guard try db.tableExists(table) else { return nil }
            var sql = "SELECT MAX(timestamp) FROM \"\(table)\""
            var arguments: [DatabaseValueConvertible?] = []
            if let currency {
                sql += " WHERE currency = ?"
                arguments.append(currency)
            }
            return try Int64.fetchOne(db, sql: sql, arguments: StatementArguments(arguments))
        }
        guard let raw else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(raw))
    }

    /// Whether the year table holds any sample strictly before `before`,
    /// optionally filtered by currency.
    public func hasSnapshotsBefore(currency: String?, year: Int, before: Date) throws -> Bool {
        try dbQueue.read { db in
            let table = self.tableName(for: year)
            guard try db.tableExists(table) else { return false }
            var sql = "SELECT EXISTS(SELECT 1 FROM \"\(table)\" WHERE timestamp < ?"
            var arguments: [DatabaseValueConvertible?] = [Int64(before.timeIntervalSince1970)]
            if let currency {
                sql += " AND currency = ?"
                arguments.append(currency)
            }
            sql += ")"
            return try Bool.fetchOne(db, sql: sql, arguments: StatementArguments(arguments)) ?? false
        }
    }

    public func latestSnapshot(currency: String) throws -> BalanceSnapshot? {
        let years = try availableYears()
        guard !years.isEmpty else { return nil }
        for year in years.sorted(by: >) {
            if let found = try rawSnapshots(currency: currency, year: year, range: nil).last {
                return found
            }
        }
        return nil
    }

    public func logError(_ message: String, at timestamp: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO error_log (timestamp, message) VALUES (?, ?)",
                           arguments: [Int64(timestamp.timeIntervalSince1970), message])
        }
    }

    public func recentErrors(limit: Int = 20) throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT message FROM error_log ORDER BY id DESC LIMIT ?
                """, arguments: [limit])
        }
    }
}
