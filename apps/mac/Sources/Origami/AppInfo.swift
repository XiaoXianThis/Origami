import Foundation

enum AppInfo {
    static var version: String {
        if let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !value.isEmpty,
           value != "VERSION_PLACEHOLDER" {
            return value
        }
        return "dev"
    }

    static var versionLabel: String {
        "v\(version)"
    }
}
