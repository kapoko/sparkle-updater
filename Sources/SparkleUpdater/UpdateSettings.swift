import Foundation

public enum UpdateSettings {
  public struct DefaultsKeys {
    public let betaUpdatesEnabled: String
    public let lastCheckedAt: String

    public init(betaUpdatesEnabled: String, lastCheckedAt: String) {
      self.betaUpdatesEnabled = betaUpdatesEnabled
      self.lastCheckedAt = lastCheckedAt
    }
  }

  public static func defaultsKeys(namespace: String = "updates") -> DefaultsKeys {
    DefaultsKeys(
      betaUpdatesEnabled: "\(namespace).beta.enabled",
      lastCheckedAt: "\(namespace).lastCheckedAt"
    )
  }
}
