import AppKit
import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "浅色"
        case .dark: "深色"
        case .system: "跟随系统"
        }
    }
}

enum WindowHideMode: String, CaseIterable, Identifiable {
    case minimize
    case transparent
    case stackBehind
    case moveOffscreen
    case moveToSpace
    case shrink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimize: "最小化"
        case .transparent: "透明隐藏"
        case .stackBehind: "底层跟随"
        case .moveOffscreen: "移动到屏外"
        case .moveToSpace: "移动到其他桌面"
        case .shrink: "缩到极小"
        }
    }

    var description: String {
        switch self {
        case .minimize:
            "兼容性最好，但切换时会有最小化/恢复痕迹。"
        case .transparent:
            "更无痕，不进入 Dock 最小化区；不同 macOS 版本和 App 可能存在兼容差异。"
        case .stackBehind:
            "把非当前窗口移动到当前窗口底层，缩小到 90% 并居中跟随当前窗口。"
        case .moveOffscreen:
            "把非当前窗口移到屏幕外，切换时再移动回当前窗口位置。"
        case .moveToSpace:
            "把非当前窗口临时移到另一个 macOS 桌面 Space；需要至少两个普通桌面，不可用时回退到屏外移动。"
        case .shrink:
            "把非当前窗口缩到极小尺寸，切换时再恢复到当前窗口大小。"
        }
    }
}

enum LabelHorizontalAnchor: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "左"
        case .center: "居中"
        case .right: "右"
        }
    }
}

enum LabelVerticalAnchor: String, CaseIterable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: "上"
        case .center: "居中"
        case .bottom: "下"
        }
    }
}

enum LabelPlacement: String, CaseIterable, Identifiable {
    case inside
    case outside

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inside: "窗口内"
        case .outside: "窗口外"
        }
    }
}

struct TabSwitchShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    static let `default` = TabSwitchShortcut(
        keyCode: 48,
        modifiers: NSEvent.ModifierFlags.shift.rawValue
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    /// 与 CGEventTap 捕获的全局按键比对，只比较 Command / Control / Option / Shift。
    func matches(_ event: CGEvent) -> Bool {
        let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return false }

        let relevantFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        let eventFlags = event.flags.intersection(relevantFlags)
        let requiredFlags = CGEventFlags(rawValue: UInt64(modifiers))
        return eventFlags == requiredFlags
    }

    var displayString: String {
        ShortcutDisplay.string(keyCode: keyCode, modifiers: modifierFlags)
    }
}

enum WindowSwitchSizeMode: String, CaseIterable, Identifiable {
    case matchCurrent
    case keepOriginal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .matchCurrent: "匹配当前窗口"
        case .keepOriginal: "保留原窗口大小"
        }
    }

    var description: String {
        switch self {
        case .matchCurrent:
            "切换时把目标窗口移动到当前窗口位置，并调整为相同大小。"
        case .keepOriginal:
            "切换时把目标窗口移动到当前窗口位置，但保留它自己的大小。"
        }
    }
}

enum AppSettings {
    static let themeKey = "Origami.theme"
    static let hideModeKey = "Origami.hideMode"
    static let detachOnDragEnabledKey = "Origami.detachOnDragEnabled"
    static let detachDelayKey = "Origami.detachDelay"
    static let labelHorizontalAnchorKey = "Origami.labelHorizontalAnchor"
    static let labelVerticalAnchorKey = "Origami.labelVerticalAnchor"
    static let labelPlacementKey = "Origami.labelPlacement"
    static let labelOffsetXKey = "Origami.labelOffsetX"
    static let labelOffsetYKey = "Origami.labelOffsetY"
    static let labelMaxWidthKey = "Origami.labelMaxWidth"
    static let windowSwitchSizeModeKey = "Origami.windowSwitchSizeMode"
    static let restoreOnLaunchKey = "Origami.restoreOnLaunch"
    static let restoreOnExitKey = "Origami.restoreOnExit"
    static let autoGroupSameAppWindowsKey = "Origami.autoGroupSameAppWindows"
    static let allowCrossAppGroupingKey = "Origami.allowCrossAppGrouping"
    static let tabSwitchShortcutKeyCodeKey = "Origami.tabSwitchShortcutKeyCode"
    static let tabSwitchShortcutModifiersKey = "Origami.tabSwitchShortcutModifiers"

    static let defaultDetachDelay: Double = 2
    static let minDetachDelay: Double = 0
    static let maxDetachDelay: Double = 5

    static let defaultLabelHorizontalAnchor = LabelHorizontalAnchor.center
    static let defaultLabelVerticalAnchor = LabelVerticalAnchor.top
    static let defaultLabelPlacement = LabelPlacement.outside
    static let defaultLabelOffsetX: Double = 0
    static let defaultLabelOffsetY: Double = 0
    static let defaultTheme = AppTheme.system
    static let defaultHideMode = WindowHideMode.moveOffscreen
    static let defaultWindowSwitchSizeMode = WindowSwitchSizeMode.matchCurrent
    static let defaultRestoreOnLaunch = true
    static let defaultRestoreOnExit = true
    static let defaultAutoGroupSameAppWindows = false
    static let defaultAllowCrossAppGrouping = true
    static let defaultTabMinWidth: Double = 120
    static let defaultLabelMaxWidth: Double = 120
    static let minLabelOffset: Double = -200
    static let maxLabelOffset: Double = 200
    static let minLabelMaxWidth: Double = 120
    static let maxLabelMaxWidth: Double = 240

    static var theme: AppTheme {
        get {
            let rawValue = UserDefaults.standard.string(forKey: themeKey) ?? defaultTheme.rawValue
            return AppTheme(rawValue: rawValue) ?? defaultTheme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
        }
    }

    /// 用户显式选择的 NSAppearance；跟随系统时返回 nil，由窗口自行继承。
    static func resolvedNSAppearance() -> NSAppearance? {
        switch theme {
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        case .system:
            nil
        }
    }

    static func isDarkMode(for appearance: NSAppearance = NSApp.effectiveAppearance) -> Bool {
        switch theme {
        case .light:
            false
        case .dark:
            true
        case .system:
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    static var hideMode: WindowHideMode {
        get {
            migrateLegacySettingsIfNeeded()
            let rawValue = UserDefaults.standard.string(forKey: hideModeKey) ?? defaultHideMode.rawValue
            return WindowHideMode(rawValue: rawValue) ?? defaultHideMode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: hideModeKey)
        }
    }

    static func migrateLegacySettingsIfNeeded() {
        guard UserDefaults.standard.string(forKey: hideModeKey) == "overlaySwitch" else { return }
        UserDefaults.standard.set(WindowHideMode.moveOffscreen.rawValue, forKey: hideModeKey)
    }

    static var detachOnDragEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: detachOnDragEnabledKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: detachOnDragEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: detachOnDragEnabledKey)
        }
    }

    static var detachDelay: TimeInterval {
        get {
            guard UserDefaults.standard.object(forKey: detachDelayKey) != nil else { return defaultDetachDelay }
            return clampedDetachDelay(UserDefaults.standard.double(forKey: detachDelayKey))
        }
        set {
            UserDefaults.standard.set(clampedDetachDelay(newValue), forKey: detachDelayKey)
        }
    }

    static var labelHorizontalAnchor: LabelHorizontalAnchor {
        get {
            let rawValue = UserDefaults.standard.string(forKey: labelHorizontalAnchorKey) ?? defaultLabelHorizontalAnchor.rawValue
            return LabelHorizontalAnchor(rawValue: rawValue) ?? defaultLabelHorizontalAnchor
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: labelHorizontalAnchorKey)
        }
    }

    static var labelVerticalAnchor: LabelVerticalAnchor {
        get {
            let rawValue = UserDefaults.standard.string(forKey: labelVerticalAnchorKey) ?? defaultLabelVerticalAnchor.rawValue
            return LabelVerticalAnchor(rawValue: rawValue) ?? defaultLabelVerticalAnchor
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: labelVerticalAnchorKey)
        }
    }

    static var labelPlacement: LabelPlacement {
        get {
            let rawValue = UserDefaults.standard.string(forKey: labelPlacementKey) ?? defaultLabelPlacement.rawValue
            return LabelPlacement(rawValue: rawValue) ?? defaultLabelPlacement
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: labelPlacementKey)
        }
    }

    static var labelOffsetX: Double {
        get {
            guard UserDefaults.standard.object(forKey: labelOffsetXKey) != nil else { return defaultLabelOffsetX }
            return clampedLabelOffset(UserDefaults.standard.double(forKey: labelOffsetXKey))
        }
        set {
            UserDefaults.standard.set(clampedLabelOffset(newValue), forKey: labelOffsetXKey)
        }
    }

    static var labelOffsetY: Double {
        get {
            guard UserDefaults.standard.object(forKey: labelOffsetYKey) != nil else { return defaultLabelOffsetY }
            return clampedLabelOffset(UserDefaults.standard.double(forKey: labelOffsetYKey))
        }
        set {
            UserDefaults.standard.set(clampedLabelOffset(newValue), forKey: labelOffsetYKey)
        }
    }

    static var labelMaxWidth: Double {
        get {
            guard UserDefaults.standard.object(forKey: labelMaxWidthKey) != nil else { return defaultLabelMaxWidth }
            return clampedLabelMaxWidth(UserDefaults.standard.double(forKey: labelMaxWidthKey))
        }
        set {
            UserDefaults.standard.set(clampedLabelMaxWidth(newValue), forKey: labelMaxWidthKey)
        }
    }

    static var windowSwitchSizeMode: WindowSwitchSizeMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: windowSwitchSizeModeKey) ?? defaultWindowSwitchSizeMode.rawValue
            return WindowSwitchSizeMode(rawValue: rawValue) ?? defaultWindowSwitchSizeMode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: windowSwitchSizeModeKey)
        }
    }

    static var restoreOnLaunch: Bool {
        get {
            guard UserDefaults.standard.object(forKey: restoreOnLaunchKey) != nil else { return defaultRestoreOnLaunch }
            return UserDefaults.standard.bool(forKey: restoreOnLaunchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: restoreOnLaunchKey)
        }
    }

    static var restoreOnExit: Bool {
        get {
            guard UserDefaults.standard.object(forKey: restoreOnExitKey) != nil else { return defaultRestoreOnExit }
            return UserDefaults.standard.bool(forKey: restoreOnExitKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: restoreOnExitKey)
        }
    }

    static var autoGroupSameAppWindows: Bool {
        get {
            guard UserDefaults.standard.object(forKey: autoGroupSameAppWindowsKey) != nil else {
                return defaultAutoGroupSameAppWindows
            }
            return UserDefaults.standard.bool(forKey: autoGroupSameAppWindowsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoGroupSameAppWindowsKey)
        }
    }

    static var allowCrossAppGrouping: Bool {
        get {
            guard UserDefaults.standard.object(forKey: allowCrossAppGroupingKey) != nil else {
                return defaultAllowCrossAppGrouping
            }
            return UserDefaults.standard.bool(forKey: allowCrossAppGroupingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: allowCrossAppGroupingKey)
        }
    }

    static var tabSwitchShortcut: TabSwitchShortcut {
        get {
            let keyCode: UInt16
            if UserDefaults.standard.object(forKey: tabSwitchShortcutKeyCodeKey) != nil {
                keyCode = UInt16(clamping: UserDefaults.standard.integer(forKey: tabSwitchShortcutKeyCodeKey))
            } else {
                keyCode = TabSwitchShortcut.default.keyCode
            }

            let modifiers: UInt
            if UserDefaults.standard.object(forKey: tabSwitchShortcutModifiersKey) != nil {
                modifiers = UInt(UserDefaults.standard.integer(forKey: tabSwitchShortcutModifiersKey))
            } else {
                modifiers = TabSwitchShortcut.default.modifiers
            }

            return TabSwitchShortcut(keyCode: keyCode, modifiers: modifiers)
        }
        set {
            UserDefaults.standard.set(Int(newValue.keyCode), forKey: tabSwitchShortcutKeyCodeKey)
            UserDefaults.standard.set(Int(newValue.modifiers), forKey: tabSwitchShortcutModifiersKey)
        }
    }

    static func clampedDetachDelay(_ value: Double) -> Double {
        min(max(value, minDetachDelay), maxDetachDelay)
    }

    static func clampedLabelOffset(_ value: Double) -> Double {
        min(max(value, minLabelOffset), maxLabelOffset)
    }

    static func clampedLabelMaxWidth(_ value: Double) -> Double {
        min(max(value, minLabelMaxWidth), maxLabelMaxWidth)
    }
}
