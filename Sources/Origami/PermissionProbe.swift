import AppKit
import ApplicationServices
import IOKit.hid
import Security

/// 检测辅助功能 / 输入监控权限，并做一次只读/无副作用的控制能力探测。
enum PermissionProbe {
    struct Report: Equatable {
        var accessibilityTrusted: Bool
        var inputMonitoringGranted: Bool
        var canReadFocusedWindow: Bool
        var canReadWindowFrame: Bool
        var canToggleMinimizedAttribute: Bool
        var notes: [String]
        var fixSteps: [String]
        var executablePath: String
        var bundlePath: String
        var bundleIdentifier: String
        var codeSignatureSummary: String

        var allCriticalOK: Bool {
            accessibilityTrusted && canReadFocusedWindow && canReadWindowFrame
        }
    }

    static func currentReport() -> Report {
        var notes: [String] = []
        var fixSteps: [String] = []
        let accessibilityTrusted = AXIsProcessTrusted()
        let inputMonitoringGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted

        let bundlePath = Bundle.main.bundleURL.path
        let executablePath = Bundle.main.executableURL?.path
            ?? CommandLine.arguments.first
            ?? "(未知)"
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "(未知)"
        let codeSignatureSummary = codeSignatureDescription(for: Bundle.main.bundleURL)

        if !accessibilityTrusted {
            notes.append("系统 API（AXIsProcessTrusted）返回：当前这份 Origami 未被信任。")
            notes.append("这和「系统设置里看起来已经打开」经常不一致：列表里勾选的可能是旧路径/旧签名，当前运行的是另一份。")
            notes.append("常见原因：从 GitHub 安装后又本地重打包、反复 ad-hoc 签名、同时存在调试版与 /Applications 版。")
            fixSteps = [
                "打开「系统设置 → 隐私与安全性 → 辅助功能」",
                "删除列表中所有 Origami / com.xiaoxianthis.origami 条目（旧条目即使勾选也无效）",
                "点击「+」，重新添加：\(bundlePath)",
                "打开开关后，完全退出 Origami（菜单栏图标 → 退出），再重新打开",
                "回到本页点「测试权限」确认变为已授权"
            ]
        }
        if !inputMonitoringGranted {
            notes.append("未获得「输入监控」权限：全局标签切换快捷键不可用（不影响鼠标点标签切换）。")
        }

        var canReadFocusedWindow = false
        var canReadWindowFrame = false
        var canToggleMinimizedAttribute = false

        if accessibilityTrusted {
            if let probe = probeFrontmostWindow() {
                canReadFocusedWindow = true
                canReadWindowFrame = probe.canReadFrame
                canToggleMinimizedAttribute = probe.canWriteMinimized
                if !probe.canReadFrame {
                    notes.append("已有辅助功能权限，但无法读取前台窗口 frame（部分 App 会拒绝）。")
                }
                if !probe.canWriteMinimized {
                    notes.append("无法写入最小化属性：当前「最小化」隐藏方式可能对该 App 无效，建议改用「移动到屏外」。")
                }
                if let title = probe.title, !title.isEmpty {
                    notes.append("探测窗口：\(probe.appName) — \(title)")
                } else {
                    notes.append("探测窗口：\(probe.appName)")
                }
            } else {
                notes.append("辅助功能已开启，但当前没有可探测的前台普通窗口。请先点开一个 App 窗口后再测。")
            }
        }

        notes.append("Bundle ID：\(bundleIdentifier)")
        notes.append("App 路径：\(bundlePath)")
        notes.append("可执行文件：\(executablePath)")
        notes.append("代码签名：\(codeSignatureSummary)")

        return Report(
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringGranted: inputMonitoringGranted,
            canReadFocusedWindow: canReadFocusedWindow,
            canReadWindowFrame: canReadWindowFrame,
            canToggleMinimizedAttribute: canToggleMinimizedAttribute,
            notes: notes,
            fixSteps: fixSteps,
            executablePath: executablePath,
            bundlePath: bundlePath,
            bundleIdentifier: bundleIdentifier,
            codeSignatureSummary: codeSignatureSummary
        )
    }

    static func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoringPrompt() {
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted { return }
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openAccessibilitySettings() {
        openPrivacyPane(candidates: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility"
        ])
    }

    static func openInputMonitoringSettings() {
        openPrivacyPane(candidates: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_ListenEvent"
        ])
    }

    static func copyBundlePathToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Bundle.main.bundleURL.path, forType: .string)
    }

    // MARK: - Private

    private struct WindowProbeResult {
        let appName: String
        let title: String?
        let canReadFrame: Bool
        let canWriteMinimized: Bool
    }

    private static func codeSignatureDescription(for url: URL) -> String {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard status == errSecSuccess, let staticCode else {
            return "无法读取签名"
        }

        var signingInfo: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )
        guard infoStatus == errSecSuccess, let info = signingInfo as? [String: Any] else {
            return "未签名或签名信息不可用"
        }

        let team = info[kSecCodeInfoTeamIdentifier as String] as? String
        let identifier = info[kSecCodeInfoIdentifier as String] as? String
        let cdHashes = info[kSecCodeInfoCdHashes as String] as? [Data]
        let cdHash = cdHashes?.first

        // ad-hoc 通常没有 Team ID；每次 --sign - 重签后 CDHash 变化，辅助功能授权会失效
        var parts: [String] = []
        if team == nil {
            parts.append("ad-hoc（每次重签都会变，系统常需重新授权）")
        } else {
            parts.append("Team \(team!)")
        }
        if let identifier {
            parts.append(identifier)
        }
        if let cdHash {
            let hex = cdHash.map { String(format: "%02x", $0) }.joined()
            parts.append("CDHash \(hex.prefix(16))…")
        }
        return parts.joined(separator: " · ")
    }

    private static func probeFrontmostWindow() -> WindowProbeResult? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return nil }

        let pid = app.processIdentifier
        let appName = app.localizedName ?? "未知 App"
        let axApp = AXUIElementCreateApplication(pid)

        var focusedRef: CFTypeRef?
        var win: AXUIElement?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
           let focusedRef {
            win = (focusedRef as! AXUIElement)
        } else {
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement],
               let first = windows.first {
                win = first
            }
        }

        guard let win else { return nil }

        var title: String?
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success {
            title = titleRef as? String
        }

        var canReadFrame = false
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
           AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success {
            canReadFrame = true
        }

        var canWriteMinimized = false
        var minimizedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimizedRef) == .success {
            let current = (minimizedRef as? Bool) ?? false
            canWriteMinimized = AXUIElementSetAttributeValue(
                win,
                kAXMinimizedAttribute as CFString,
                current as CFTypeRef
            ) == .success
        }

        return WindowProbeResult(
            appName: appName,
            title: title,
            canReadFrame: canReadFrame,
            canWriteMinimized: canWriteMinimized
        )
    }

    private static func openPrivacyPane(candidates: [String]) {
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}
