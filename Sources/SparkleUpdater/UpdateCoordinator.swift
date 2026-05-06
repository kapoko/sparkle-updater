import Foundation
import Sparkle

@MainActor
public final class UpdateCoordinator: NSObject, ObservableObject {
  public struct Configuration {
    public let defaults: UserDefaults
    public let defaultsKeys: UpdateSettings.DefaultsKeys
    public let feedURLStringProvider: () -> String?
    public let betaUpdatesEnabledProvider: () -> Bool

    public init(
      defaults: UserDefaults = .standard,
      defaultsKeys: UpdateSettings.DefaultsKeys = UpdateSettings.defaultsKeys(),
      feedURLStringProvider: @escaping () -> String?,
      betaUpdatesEnabledProvider: @escaping () -> Bool = { false }
    ) {
      self.defaults = defaults
      self.defaultsKeys = defaultsKeys
      self.feedURLStringProvider = feedURLStringProvider
      self.betaUpdatesEnabledProvider = betaUpdatesEnabledProvider
    }
  }

  @Published public private(set) var state: UpdateState = .idle
  @Published public private(set) var lastCheckedAt: Date?
  @Published public var automaticallyChecksForUpdates: Bool = true {
    didSet {
      guard automaticallyChecksForUpdates != oldValue else {
        return
      }

      guard let updater = updaterController?.updater else {
        return
      }

      updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates

      if !automaticallyChecksForUpdates {
        state = .idle
      }
    }
  }

  @Published public var automaticallyDownloadsUpdates: Bool = false {
    didSet {
      guard automaticallyDownloadsUpdates != oldValue else {
        return
      }

      guard let updater = updaterController?.updater else {
        return
      }

      updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
    }
  }

  private var updaterController: SPUStandardUpdaterController?
  private let configuration: Configuration
  private let defaults: UserDefaults
  private static let lastCheckedDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  public init(configuration: Configuration) {
    self.configuration = configuration
    defaults = configuration.defaults
    lastCheckedAt = defaults.object(forKey: configuration.defaultsKeys.lastCheckedAt) as? Date
    super.init()
  }

  private var betaUpdatesEnabled: Bool {
    configuration.betaUpdatesEnabledProvider()
  }

  public var statusText: String {
    let baseStatus = state.statusText
    guard let lastCheckedAt else {
      return baseStatus
    }

    return
      "\(baseStatus) • Last checked \(Self.lastCheckedDateFormatter.string(from: lastCheckedAt))"
  }

  public var isAvailable: Bool {
    updaterController != nil
  }

  public func initializeUpdater() {
    if updaterController != nil {
      return
    }

    guard isAppBundle else {
      state = .unavailable(message: "Updates are available in app bundle builds")
      return
    }

    if let configurationIssue = sparkleConfigurationIssue() {
      state = .unavailable(message: configurationIssue)
      return
    }

    let controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
      userDriverDelegate: nil
    )

    controller.startUpdater()
    _ = controller.updater.clearFeedURLFromUserDefaults()

    updaterController = controller
    automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates
    state = .idle
  }

  public func performStartupCheckIfNeeded() {
    guard let updater = updaterController?.updater else {
      return
    }

    guard updater.automaticallyChecksForUpdates else {
      state = .idle
      return
    }

    state = .checking
    updater.checkForUpdatesInBackground()
  }

  public func checkForUpdates() {
    guard let updater = updaterController?.updater else {
      return
    }

    state = .checking
    updater.checkForUpdates()
  }

  private var isAppBundle: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  private func sparkleConfigurationIssue() -> String? {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]

    let feedURLValue = infoDictionary["SUFeedURL"] as? String
    let feedURL = feedURLValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    if feedURL?.isEmpty != false {
      return "Updates unavailable: SUFeedURL is not configured"
    }

    let publicKeyValue = infoDictionary["SUPublicEDKey"] as? String
    let publicKey = publicKeyValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    if publicKey?.isEmpty != false || publicKey == "__SPARKLE_PUBLIC_ED_KEY__" {
      return "Updates unavailable: Sparkle signing key is not configured"
    }

    return nil
  }

  private func markLastCheckedNow() {
    let timestamp = Date()
    lastCheckedAt = timestamp
    defaults.set(timestamp, forKey: configuration.defaultsKeys.lastCheckedAt)
  }
}

extension UpdateCoordinator: SPUUpdaterDelegate {
  private func isNoUpdateError(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == SUSparkleErrorDomain
      && nsError.code == Int(SUError.noUpdateError.rawValue)
  }

  public func feedURLString(for updater: SPUUpdater) -> String? {
    configuration.feedURLStringProvider()
  }

  public func allowedChannels(for updater: SPUUpdater) -> Set<String> {
    if betaUpdatesEnabled {
      return Set(["beta"])
    }

    return Set()
  }

  public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    state = .updateAvailable(version: item.displayVersionString)
    markLastCheckedNow()
  }

  public func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    state = .upToDate
    markLastCheckedNow()
  }

  public func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    state = .upToDate
    markLastCheckedNow()
  }

  public func updater(
    _ updater: SPUUpdater,
    willDownloadUpdate item: SUAppcastItem,
    with request: NSMutableURLRequest
  ) {
    state = .downloading
  }

  public func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
    state = .downloading
  }

  public func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
    state = .installing
  }

  public func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    if isNoUpdateError(error) {
      state = .upToDate
      markLastCheckedNow()
      return
    }

    state = .failed(message: error.localizedDescription)
    markLastCheckedNow()
  }

  public func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: Error?
  ) {
    if let error {
      if isNoUpdateError(error) {
        state = .upToDate
        markLastCheckedNow()
        return
      }

      state = .failed(message: error.localizedDescription)
      markLastCheckedNow()
      return
    }

    if case .checking = state {
      state = .upToDate
      markLastCheckedNow()
    }
  }
}
