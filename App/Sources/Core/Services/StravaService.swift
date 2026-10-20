import AuthenticationServices
import Foundation
import Observation
import UIKit

/// Talks to Strava on the reader's behalf.
///
/// The app never sends a password to Strava and never sees one. The reader
/// allows the app in a system sheet, Strava hands back a code, and the app
/// exchanges that for a token. The token lives in the keychain.
///
/// Nothing here runs until the reader asks for it: importing is something
/// they do, not something the app does on its own.
@MainActor
@Observable
public final class StravaService {
    /// What the app knows about the connection.
    public enum State: Equatable {
        /// The app has no Strava keys, so it cannot talk to Strava at all.
        case notConfigured
        /// The app has keys but nobody has allowed it yet.
        case signedOut
        /// The system sheet is open, or a request is in flight.
        case working
        /// Somebody allowed the app.
        case connected(athleteName: String?)
        /// Something went wrong, and the reader is told what.
        case failed(String)
    }

    public private(set) var state: State
    public private(set) var token: OAuthToken?

    private let configuration: StravaConfiguration
    private let keychain: KeychainStore
    private let session: URLSession
    private let tokenKey = "strava.token"

    public init(
        configuration: StravaConfiguration = .fromBundle(),
        keychain: KeychainStore = KeychainStore(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.keychain = keychain
        self.session = session
        self.state = configuration.isConfigured ? .signedOut : .notConfigured
        self.token = keychain.get(tokenKey).flatMap(Self.readToken)
    }

    // MARK: - Connecting

    /// Asks the reader to allow the app, then exchanges the answer for a
    /// token.
    public func connect(presenter: UIViewController) async {
        guard configuration.isConfigured else {
            state = .notConfigured
            return
        }
        state = .working

        // The nonce is checked on the way back, so a page that is not
        // Strava's cannot slip an authorisation code into the app.
        let nonce = UUID().uuidString
        guard let url = configuration.authorisationURL(state: nonce) else {
            state = .failed("The Strava address could not be built.")
            return
        }

        do {
            let code = try await StravaAuthorisationSession.authorise(
                url: url,
                nonce: nonce,
                presenter: presenter
            )
            let newToken = try await exchange(code: code)
            try store(newToken)
            state = .connected(athleteName: nil)
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    /// Exchanges an authorisation code for a token.
    private func exchange(code: String) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ])

        let data = try await send(request)
        return try JSONDecoder().decode(StravaTokenResponse.self, from: data).asToken()
    }

    /// A fresh token, refreshing the old one if it has run out.
    public func validToken() async throws -> OAuthToken {
        guard let token else { throw StravaError.notConnected }
        if !token.isExpired() { return token }

        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "refresh_token": token.refreshToken,
            "grant_type": "refresh_token",
        ])

        let data = try await send(request)
        let refreshed = try JSONDecoder().decode(StravaTokenResponse.self, from: data).asToken()
        try store(refreshed)
        return refreshed
    }

    /// Fetches the athlete's recent activities.
    public func activities(limit: Int = 30) async throws -> [StravaActivity] {
        let current = try await validToken()
        var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        components.queryItems = [URLQueryItem(name: "per_page", value: String(min(limit, 100)))]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(current.accessToken)", forHTTPHeaderField: "Authorization")

        let data = try await send(request)
        return try JSONDecoder().decode([StravaActivity].self, from: data)
    }

    /// Forgets the connection.
    public func disconnect() {
        keychain.remove(tokenKey)
        token = nil
        state = configuration.isConfigured ? .signedOut : .notConfigured
    }

    // MARK: - Plumbing

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StravaError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw StravaError.server(status: http.statusCode, message: message)
        }
        return data
    }

    private func store(_ token: OAuthToken) throws {
        let data = try JSONEncoder().encode(token)
        guard let encoded = String(data: data, encoding: .utf8), keychain.set(encoded, for: tokenKey) else {
            throw StravaError.couldNotStoreToken
        }
        self.token = token
    }

    private static func readToken(_ string: String) -> OAuthToken? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(OAuthToken.self, from: data)
    }

    private static func describe(_ error: Error) -> String {
        if let stravaError = error as? StravaError { return stravaError.message }
        return error.localizedDescription
    }
}

/// What can go wrong when talking to Strava.
enum StravaError: LocalizedError {
    case notConfigured
    case notConnected
    case cancelled
    case badResponse
    case couldNotStoreToken
    case server(status: Int, message: String?)

    var message: String {
        switch self {
        case .notConfigured:
            "This build has no Strava keys, so it cannot connect."
        case .notConnected:
            "Connect to Strava first."
        case .cancelled:
            "The authorisation was cancelled."
        case .badResponse:
            "Strava sent something that could not be read."
        case .couldNotStoreToken:
            "The token could not be kept on this device."
        case .server(let status, let message):
            message ?? "Strava returned an error (\(status))."
        }
    }
}

/// The system sheet that asks Strava for permission.
///
/// The sheet lives in a browser that belongs to the system, so the reader can
/// see which address they are entering their password into. The app only ever
/// sees the code that comes back.
@MainActor
private final class StravaAuthorisationSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<String, Error>?
    private weak var presenter: UIViewController?

    /// Opens the sheet and waits for Strava to send the reader back.
    static func authorise(url: URL, nonce: String, presenter: UIViewController) async throws -> String {
        let sheet = StravaAuthorisationSession()
        sheet.presenter = presenter
        return try await sheet.run(url: url, nonce: nonce)
    }

    private func run(url: URL, nonce: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "milemark") { [weak self] callback, error in
                Task { @MainActor in
                    self?.finish(callback: callback, error: error, nonce: nonce)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    private func finish(callback: URL?, error: Error?, nonce: String) {
        guard let continuation else { return }
        self.continuation = nil
        session = nil

        if let error {
            continuation.resume(throwing: error)
            return
        }
        guard let callback,
              let components = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        else {
            continuation.resume(throwing: StravaError.cancelled)
            return
        }

        let items = components.queryItems ?? []
        if let returned = items.first(where: { $0.name == "state" })?.value, returned != nonce {
            // The answer did not come from the request that was made, so it
            // is not trusted.
            continuation.resume(throwing: StravaError.cancelled)
            return
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            continuation.resume(throwing: StravaError.cancelled)
            return
        }
        continuation.resume(returning: code)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presenter?.view.window ?? ASPresentationAnchor()
    }
}
