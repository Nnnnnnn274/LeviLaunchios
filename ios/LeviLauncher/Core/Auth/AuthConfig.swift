import Foundation

struct AuthConfig {
    let environment: String
    let sandbox: String
    let tokenType: String
    let deviceAuthRP: String
    let userAuthRP: String
    let xstsRP: String
    let siteNameRps: String
    let authMethodRps: String
    let defaultTitleTid: String

    static func productionRetailJwtDefault() -> AuthConfig {
        AuthConfig(
            environment: "Production",
            sandbox: "RETAIL",
            tokenType: "JWT",
            deviceAuthRP: "http://auth.xboxlive.com",
            userAuthRP: "http://auth.xboxlive.com",
            xstsRP: MsftAuthManager.defaultXstsRelyingParty,
            siteNameRps: "user.auth.xboxlive.com",
            authMethodRps: "RPS",
            defaultTitleTid: "1739947436"
        )
    }
}
