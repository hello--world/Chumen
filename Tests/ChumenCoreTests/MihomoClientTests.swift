import XCTest
@testable import ChumenCore

final class MihomoClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testReadsVersionAndSendsAuthorizationHeader() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/version")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"version":"1.2.3","meta":true}"#.data(using: .utf8)!)
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "token", session: mockSession())
        let version = try await client.version()

        XCTAssertEqual(version.version, "1.2.3")
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testSetModeSendsPatchBody() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/configs")
            XCTAssertEqual(request.httpMethod, "PATCH")
            let body = Self.requestBody(from: request)
            XCTAssertTrue(String(data: body, encoding: .utf8)?.contains("\"mode\":\"global\"") == true)
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        try await client.setMode(.global)

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testSelectProxyEncodesGroupNameAndSendsNodeName() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path(percentEncoded: true), "/proxies/Auto%20Group")
            XCTAssertEqual(request.httpMethod, "PUT")
            let body = Self.requestBody(from: request)
            XCTAssertTrue(String(data: body, encoding: .utf8)?.contains("\"name\":\"Node A\"") == true)
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        try await client.selectProxy(group: "Auto Group", name: "Node A")

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testCloseAllConnectionsUsesDeleteEndpoint() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/connections")
            XCTAssertEqual(request.httpMethod, "DELETE")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        try await client.closeAllConnections()

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testConnectionsTreatsNullConnectionsAsEmptyList() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/connections")
            let body = #"{"downloadTotal":0,"uploadTotal":0,"connections":null,"memory":0}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        let response = try await client.connections()

        XCTAssertEqual(response.downloadTotal, 0)
        XCTAssertEqual(response.uploadTotal, 0)
        XCTAssertEqual(response.connections, [])
    }

    func testFlushFakeIPCacheUsesPostEndpoint() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/cache/fakeip/flush")
            XCTAssertEqual(request.httpMethod, "POST")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        try await client.flushFakeIPCache()

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testReloadConfigSendsForceQueryAndPathPayload() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/configs")
            XCTAssertEqual(request.url?.query, "force=true")
            XCTAssertEqual(request.httpMethod, "PUT")
            let body = try JSONDecoder().decode(MihomoPathPayload.self, from: Self.requestBody(from: request))
            XCTAssertEqual(body.path, "/tmp/runtime.yaml")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        try await client.reloadConfig(path: "/tmp/runtime.yaml")

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testDelayGroupUsesGroupEndpointWithExpectedStatus() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path(percentEncoded: true), "/group/Auto%20Group/delay")
            XCTAssertTrue(request.url?.query?.contains("timeout=3000") == true)
            XCTAssertTrue(request.url?.query?.contains("expected=200-299") == true)
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"Node A":42}"#.data(using: .utf8)!)
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        let response = try await client.delayGroup(name: "Auto Group", timeout: 3000, expected: "200-299")

        XCTAssertEqual(response, .object(["Node A": .number(42)]))
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testStoragePutEncodesArbitraryJSONValue() async throws {
        let expectation = expectation(description: "request")
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/storage/ui-state")
            XCTAssertEqual(request.httpMethod, "PUT")
            let body = String(data: Self.requestBody(from: request), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("\"active\":true"))
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = MihomoClient(baseURL: URL(string: "http://127.0.0.1:9097")!, secret: "", session: mockSession())
        try await client.putStorage(key: "ui-state", value: .object(["active": .bool(true)]))

        await fulfillment(of: [expectation], timeout: 1)
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func requestBody(from request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: ChumenError.commandFailed("Missing test handler"))
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
