# SparkleUpdater

`SparkleUpdater` is a tiny wrapper for Sparkle updater project I use for my apps, including a little view for the settings window.

## Requirements

- macOS 13+
- Swift Package Manager

## Add to app

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kapoko/sparkle-updater", branch: "main")
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [
            .product(name: "SparkleUpdater", package: "sparkle-updater")
        ]
    )
]
```

Then import in app code:

```swift
import SparkleUpdater
```

## Wiring example

```swift
import SparkleUpdater

let updateCoordinator = UpdateCoordinator(
    configuration: .init(
        betaUpdatesEnabledProvider: {
            UserDefaults.standard.bool(forKey: UpdateSettings.defaultsKeys().betaUpdatesEnabled)
        }
    )
)

updateCoordinator.initializeUpdater()
updateCoordinator.performStartupCheckIfNeeded()
```

## Required Info.plist keys

Set your Sparkle feed URL in your app's `Info.plist` (key: `SUFeedURL`).

```xml
<key>SUFeedURL</key>
<string>https://example.com/appcast.xml</string>
```

If this key is missing, updates stay unavailable.

## Local development without changing `Package.swift`

Keep your app dependency as URL+branch, then temporarily point it at a local checkout:

```bash
swift package edit sparkle-updater --path ../sparkle-updater
```

Now changes in `../sparkle-updater` are used immediately by your app build.

When done, switch back to normal remote dependency resolution:

```bash
swift package unedit sparkle-updater
```
