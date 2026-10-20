import Foundation

/// The Strava settings the app needs in order to talk to Strava at all.
///
/// Strava issues these when an application is created at
/// strava.com/settings/api. They are build settings rather than values in
/// the repository, so a fork does not inherit someone else's application.
///
/// The app works without them. It says so plainly rather than failing with
/// an error the reader cannot act on.
public struct StravaConfiguration: Sendable, Equatable {
    public let clientID: String
    public let clientSecret: String

    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    /// Reads the configuration from the app's own information property list.
    public static func fromBundle(_ bundle: Bundle = .main) -> StravaConfiguration {
        StravaConfiguration(
            clientID: (bundle.object(forInfoDictionaryKey: "StravaClientID") as? String) ?? "",
            clientSecret: (bundle.object(forInfoDictionaryKey: "StravaClientSecret") as? String) ?? ""
        )
    }

    /// Whether the app has been given the keys it needs.
    public var isConfigured: Bool {
        !clientID.isEmpty && !clientSecret.isEmpty
    }

    /// Where Strava sends the reader back to after they have allowed the app.
    ///
    /// This has to match the redirect URI registered with the application
    /// exactly, or Strava refuses the authorisation.
    public static let redirectURI = "milemark://strava/callback"

    /// The address of the authorisation page.
    public func authorisationURL(state: String) -> URL? {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:read_all"),
            URLQueryItem(name: "state", value: state),
        ]
        return components?.url
    }
}
