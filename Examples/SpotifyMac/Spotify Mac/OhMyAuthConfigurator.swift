import OhMyAuth
import Sugar

public struct OhMyAuthConfigurator: Configurator {

  public func configure() {
    let name = "spots"
    if let service = AuthContainer.serviceNamed(name) {
      service.config.clientId = "a73161d177934f639fe3b3506d5a1005"
      service.config.accessTokenUrl = NSURL(string: "https://accounts.spotify.com/api/token")!
      return
    }

    guard let data = "a73161d177934f639fe3b3506d5a1005:64b887abc0ed48729d2c41b2ad10ade0".dataUsingEncoding(NSUTF8StringEncoding) else { return }
    let credential = data.base64EncodedStringWithOptions([])

    let config = AuthConfig(
      clientId: "a73161d177934f639fe3b3506d5a1005",
      accessTokenUrl: NSURL(string: "https://accounts.spotify.com/api/token")!,
      accessGrantType: "authorization_code",
      redirectURI: "spots://callback",
      headers: ["Authorization" :"Basic \(credential)"])


    let locker = UserDefaultsLocker(name: name)
    let service = AuthService(name: name, config: config, locker: locker)
    AuthContainer.addService(service)

    AuthConfig.parse = { response in
      return response["error"] as? JSONDictionary
    }
  }
}
