import XCTest
@testable import DSBalanceMonitor

final class BalanceModelsTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/balance_response.json")
        return try Data(contentsOf: url)
    }

    func testDecodesBalanceResponseWithStringAmounts() throws {
        let decoded = try JSONDecoder().decode(BalanceResponse.self, from: try fixtureData())
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertEqual(decoded.balanceInfos.count, 2)
        let cny = decoded.balanceInfos[0]
        XCTAssertEqual(cny.currency, "CNY")
        XCTAssertEqual(cny.totalBalance, 110.0, accuracy: 0.001)
        XCTAssertEqual(cny.grantedBalance, 10.0, accuracy: 0.001)
        XCTAssertEqual(cny.toppedUpBalance, 100.0, accuracy: 0.001)
    }

    func testDecodingRejectsMissingFields() {
        let json = Data(#"{ "is_available": true, "balance_infos": [ { "currency": "CNY" } ] }"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(BalanceResponse.self, from: json))
    }
}

final class BalanceAPIClientTests: XCTestCase {
    func testClientBuildsRequestAndDecodesResponse() async throws {
        let sent = URL(string: "https://unit.test/user/balance")!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url, sent)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            let body = Data(#"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"9.50","granted_balance":"0.00","topped_up_balance":"9.50"}]}"#.utf8)
            return (HTTPURLResponse(url: sent, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = DeepSeekBalanceClient(baseURL: URL(string: "https://unit.test")!,
                                           apiKeyProvider: { "test-key" },
                                           session: URLSession(configuration: config))
        let response = try await client.fetchBalance()
        XCTAssertEqual(response.balanceInfos.first?.totalBalance, 9.5)
    }

    func testClientThrowsMissingAPIKeyWhenUnconfigured() async {
        let client = DeepSeekBalanceClient(baseURL: URL(string: "https://unit.test")!,
                                           apiKeyProvider: { nil })
        do {
            _ = try await client.fetchBalance()
            XCTFail("expected error")
        } catch let error as BalanceAPIError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testClientThrowsOn401() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { _ in
            let url = URL(string: "https://unit.test/user/balance")!
            return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"error":{"message":"Authentication Fails"}}"#.utf8))
        }
        let client = DeepSeekBalanceClient(baseURL: URL(string: "https://unit.test")!,
                                           apiKeyProvider: { "bad" },
                                           session: URLSession(configuration: config))
        do {
            _ = try await client.fetchBalance()
            XCTFail("expected error")
        } catch let error as BalanceAPIError {
            XCTAssertEqual(error, .httpStatus(401))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
