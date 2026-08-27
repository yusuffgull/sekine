import XCTest
@testable import Sekine

final class AppUpdateCheckerTests: XCTestCase {

    // MARK: - isNewer (saf karşılaştırma, ağ yok)

    func testIsNewerEqual() {
        XCTAssertFalse(AppUpdateChecker.isNewer("1.5", than: "1.5"))
    }

    func testIsNewerOlder() {
        XCTAssertFalse(AppUpdateChecker.isNewer("1.5", than: "1.6"))
    }

    func testIsNewerNewer() {
        XCTAssertTrue(AppUpdateChecker.isNewer("1.6", than: "1.5"))
    }

    func testIsNewerDoubleDigitMinorNotStringCompared() {
        // "1.10" bir "1.6"'dan sayısal olarak büyük, string karşılaştırmasında küçük olurdu.
        XCTAssertTrue(AppUpdateChecker.isNewer("1.10", than: "1.6"))
    }

    func testIsNewerMajorBumpBeatsHigherMinor() {
        XCTAssertTrue(AppUpdateChecker.isNewer("2.0", than: "1.9.9"))
    }

    func testIsNewerPatchLevelBump() {
        XCTAssertTrue(AppUpdateChecker.isNewer("1.6.1", than: "1.6"))
    }

    func testIsNewerMalformedCandidateIsSafeDefault() {
        XCTAssertFalse(AppUpdateChecker.isNewer("abc", than: "1.5"))
    }

    // MARK: - checkForUpdate (URLProtocol stub ile ağ yolu)

    private func makeChecker(status: Int32 = 200, body: String, error: Error? = nil) -> AppUpdateChecker {
        StubURLProtocol.requestHandler = { request in
            if let error { throw error }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: Int(status), httpVersion: nil, headerFields: nil)!
            return (response, body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return AppUpdateChecker(session: URLSession(configuration: config))
    }

    func testCheckForUpdateReturnsInfoWhenNewer() async throws {
        let checker = makeChecker(body: #"{"results":[{"version":"1.6"}]}"#)
        let info = try await checker.checkForUpdate(currentVersion: "1.5")
        XCTAssertEqual(info?.latestVersion, "1.6")
    }

    func testCheckForUpdateReturnsNilWhenUpToDate() async throws {
        let checker = makeChecker(body: #"{"results":[{"version":"1.5"}]}"#)
        let info = try await checker.checkForUpdate(currentVersion: "1.5")
        XCTAssertNil(info)
    }

    func testCheckForUpdateThrowsOnEmptyResults() async {
        let checker = makeChecker(body: #"{"results":[]}"#)
        do {
            _ = try await checker.checkForUpdate(currentVersion: "1.5")
            XCTFail("emptyResult bekleniyordu")
        } catch AppUpdateCheckError.emptyResult {
            // beklenen
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
    }

    func testCheckForUpdateThrowsOnMalformedJSON() async {
        let checker = makeChecker(body: "not json")
        do {
            _ = try await checker.checkForUpdate(currentVersion: "1.5")
            XCTFail("decoding hatası bekleniyordu")
        } catch AppUpdateCheckError.decoding {
            // beklenen
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
    }

    func testCheckForUpdateThrowsOnNetworkFailure() async {
        let checker = makeChecker(body: "", error: URLError(.notConnectedToInternet))
        do {
            _ = try await checker.checkForUpdate(currentVersion: "1.5")
            XCTFail("network hatası bekleniyordu")
        } catch AppUpdateCheckError.network {
            // beklenen
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
    }
}

// MARK: - URLProtocol stub

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
