import XCTest
@testable import RewordCore

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let handler = Self.handler else { fatalError("no handler set") }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

/// URLProtocol delivers the body via httpBodyStream — read it back out.
func bodyData(of request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

final class AnthropicProviderTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    private func makeProvider(key: String? = "sk-test") -> AnthropicProvider {
        AnthropicProvider(session: session, apiKey: { key }, model: { "claude-opus-4-8" })
    }

    private static func response(_ status: Int, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testSendsCorrectRequest() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        nonisolated(unsafe) var capturedBody: Data?
        MockURLProtocol.handler = { request in
            captured = request
            capturedBody = bodyData(of: request)
            let json = #"{"content":[{"type":"text","text":"better text"}]}"#
            return (Self.response(200, url: request.url!), Data(json.utf8))
        }

        let result = try await makeProvider().transform(text: "helo wrld", prompt: "Fix grammar.")

        XCTAssertEqual(result, "better text")
        XCTAssertEqual(captured?.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(captured?.httpMethod, "POST")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any]
        )
        XCTAssertEqual(body["model"] as? String, "claude-opus-4-8")
        XCTAssertEqual(body["system"] as? String, "Fix grammar.")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "helo wrld")
    }

    func testMissingKeyThrowsBeforeNetworking() async {
        MockURLProtocol.handler = { _ in fatalError("must not hit network") }
        do {
            _ = try await makeProvider(key: nil).transform(text: "x", prompt: "y")
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? AIError, .missingAPIKey)
        }
    }

    func testStatusCodeMapping() async {
        let cases: [(Int, AIError)] = [
            (401, .authenticationFailed),
            (403, .authenticationFailed),
            (429, .rateLimited),
            (400, .badRequest),
            (500, .serverError),
            (529, .serverError),
        ]
        for (status, expected) in cases {
            MockURLProtocol.handler = { request in
                (Self.response(status, url: request.url!), Data("{}".utf8))
            }
            do {
                _ = try await makeProvider().transform(text: "x", prompt: "y")
                XCTFail("expected throw for \(status)")
            } catch {
                XCTAssertEqual(error as? AIError, expected, "status \(status)")
            }
        }
    }

    func testGarbageResponseThrowsInvalidResponse() async {
        MockURLProtocol.handler = { request in
            (Self.response(200, url: request.url!), Data("not json".utf8))
        }
        do {
            _ = try await makeProvider().transform(text: "x", prompt: "y")
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? AIError, .invalidResponse)
        }
    }
}
