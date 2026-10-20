import Foundation

/// A token and the moment it stops working.
///
/// Strava's access tokens last six hours. The refresh token lasts much
/// longer and is the thing worth keeping.
public struct OAuthToken: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date

    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// Whether the token has run out, with a little margin so a request is
    /// not sent with a token that expires while it is in flight.
    public func isExpired(now: Date = Date(), margin: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(now) <= margin
    }
}

/// The result of exchanging an authorisation code for a token.
public struct StravaTokenResponse: Decodable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Int
    public var athlete: Athlete?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }

    /// The brief description of the person who authorised the app.
    public struct Athlete: Decodable, Sendable {
        public var id: Int
        public var firstName: String
        public var lastName: String
    }

    public func asToken(now: Date = Date()) -> OAuthToken {
        OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAt))
        )
    }
}
