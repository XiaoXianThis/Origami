import AppKit
import CoreGraphics
import Darwin
import IOKit.hid

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

private final class WindowAlphaController {
    static let shared = WindowAlphaController()

    private typealias ConnectionFunction = @convention(c) () -> UInt32
    private typealias SingleWindowAlphaFunction = @convention(c) (UInt32, CGWindowID, Float) -> Int32
    private typealias WindowListAlphaFunction = @convention(c) (UInt32, UnsafePointer<CGWindowID>, Int32, Float) -> Int32

    private let connectionID: UInt32
    private let singleWindowAlphaFunctions: [SingleWindowAlphaFunction]
    private let windowListAlphaFunctions: [WindowListAlphaFunction]

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
            ?? dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) else {
            connectionID = 0
            singleWindowAlphaFunctions = []
            windowListAlphaFunctions = []
            return
        }

        let connectionSymbol = dlsym(handle, "SLSMainConnectionID")
            ?? dlsym(handle, "CGSMainConnectionID")
            ?? dlsym(handle, "_CGSDefaultConnection")

        guard let connectionSymbol else {
            connectionID = 0
            singleWindowAlphaFunctions = []
            windowListAlphaFunctions = []
            return
        }

        let connection = unsafeBitCast(connectionSymbol, to: ConnectionFunction.self)
        connectionID = connection()

        singleWindowAlphaFunctions = ["SLSSetWindowAlpha", "CGSSetWindowAlpha"].compactMap { name in
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: SingleWindowAlphaFunction.self)
        }

        windowListAlphaFunctions = ["SLSSetWindowListAlpha", "CGSSetWindowListAlpha"].compactMap { name in
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: WindowListAlphaFunction.self)
        }
    }

    @discardableResult
    func setAlpha(_ alpha: CGFloat, for windowID: CGWindowID) -> Bool {
        guard connectionID != 0 else { return false }
        let floatAlpha = Float(alpha)
        var targetWindowID = windowID

        for setWindowListAlpha in windowListAlphaFunctions {
            if setWindowListAlpha(connectionID, &targetWindowID, 1, floatAlpha) == 0 {
                return true
            }
        }

        for setSingleWindowAlpha in singleWindowAlphaFunctions {
            if setSingleWindowAlpha(connectionID, windowID, floatAlpha) == 0 {
                return true
            }
        }

        return false
    }
}

private final class WindowTransformController {
    static let shared = WindowTransformController()

    private typealias ConnectionFunction = @convention(c) () -> UInt32
    private typealias SetWindowTransformFunction = @convention(c) (UInt32, CGWindowID, CGAffineTransform) -> Int32

    private let connectionID: UInt32
    private let setWindowTransformFunctions: [SetWindowTransformFunction]

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
            ?? dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) else {
            connectionID = 0
            setWindowTransformFunctions = []
            return
        }

        let connectionSymbol = dlsym(handle, "SLSMainConnectionID")
            ?? dlsym(handle, "CGSMainConnectionID")
            ?? dlsym(handle, "_CGSDefaultConnection")

        guard let connectionSymbol else {
            connectionID = 0
            setWindowTransformFunctions = []
            return
        }

        let connection = unsafeBitCast(connectionSymbol, to: ConnectionFunction.self)
        connectionID = connection()

        setWindowTransformFunctions = ["SLSSetWindowTransform", "CGSSetWindowTransform"].compactMap { name in
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: SetWindowTransformFunction.self)
        }
    }

    @discardableResult
    func resetTransform(for windowID: CGWindowID) -> Bool {
        setTransform(.identity, for: windowID)
    }

    @discardableResult
    private func setTransform(_ transform: CGAffineTransform, for windowID: CGWindowID) -> Bool {
        guard connectionID != 0 else { return false }

        for setWindowTransform in setWindowTransformFunctions {
            if setWindowTransform(connectionID, windowID, transform) == 0 {
                return true
            }
        }

        return false
    }
}

private final class WindowSpaceController {
    static let shared = WindowSpaceController()

    private typealias ConnectionFunction = @convention(c) () -> UInt32
    private typealias CopyManagedDisplaySpacesFunction = @convention(c) (UInt32) -> Unmanaged<CFArray>?
    private typealias ActiveSpaceFunction = @convention(c) (UInt32) -> UInt64
    private typealias MoveWindowsToManagedSpaceFunction = @convention(c) (UInt32, CFArray, UInt64) -> Int32

    private let connectionID: UInt32
    private let copyManagedDisplaySpacesFunctions: [CopyManagedDisplaySpacesFunction]
    private let activeSpaceFunctions: [ActiveSpaceFunction]
    private let moveWindowsToManagedSpaceFunctions: [MoveWindowsToManagedSpaceFunction]

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
            ?? dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) else {
            connectionID = 0
            copyManagedDisplaySpacesFunctions = []
            activeSpaceFunctions = []
            moveWindowsToManagedSpaceFunctions = []
            return
        }

        let connectionSymbol = dlsym(handle, "SLSMainConnectionID")
            ?? dlsym(handle, "CGSMainConnectionID")
            ?? dlsym(handle, "_CGSDefaultConnection")

        guard let connectionSymbol else {
            connectionID = 0
            copyManagedDisplaySpacesFunctions = []
            activeSpaceFunctions = []
            moveWindowsToManagedSpaceFunctions = []
            return
        }

        let connection = unsafeBitCast(connectionSymbol, to: ConnectionFunction.self)
        connectionID = connection()

        copyManagedDisplaySpacesFunctions = ["SLSCopyManagedDisplaySpaces", "CGSCopyManagedDisplaySpaces"].compactMap { name in
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: CopyManagedDisplaySpacesFunction.self)
        }

        activeSpaceFunctions = ["SLSGetActiveSpace", "CGSGetActiveSpace"].compactMap { name in
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: ActiveSpaceFunction.self)
        }

        moveWindowsToManagedSpaceFunctions = ["SLSMoveWindowsToManagedSpace", "CGSMoveWindowsToManagedSpace"].compactMap { name in
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: MoveWindowsToManagedSpaceFunction.self)
        }
    }

    var isAvailable: Bool {
        connectionID != 0
            && copyManagedDisplaySpacesFunctions.isEmpty == false
            && activeSpaceFunctions.isEmpty == false
            && moveWindowsToManagedSpaceFunctions.isEmpty == false
    }

    func activeSpaceID() -> UInt64? {
        guard connectionID != 0 else { return nil }

        for getActiveSpace in activeSpaceFunctions {
            let spaceID = getActiveSpace(connectionID)
            if spaceID != 0 { return spaceID }
        }

        return managedDisplaySpaces()
            .compactMap { currentSpaceID(in: $0) }
            .first
    }

    func hidingSpaceID() -> UInt64? {
        guard isAvailable else { return nil }
        let currentID = activeSpaceID()
        let displays = managedDisplaySpaces()

        if let currentID,
           let currentDisplay = displays.first(where: { currentSpaceID(in: $0) == currentID }),
           let sameDisplayTarget = ordinarySpaceIDs(in: currentDisplay).first(where: { $0 != currentID }) {
            return sameDisplayTarget
        }

        return displays
            .flatMap(ordinarySpaceIDs)
            .first { spaceID in
                guard let currentID else { return true }
                return spaceID != currentID
            }
    }

    @discardableResult
    func moveWindow(_ windowID: CGWindowID, to spaceID: UInt64) -> Bool {
        guard isAvailable, spaceID != 0 else { return false }
        let windows = [NSNumber(value: UInt32(windowID))] as CFArray

        for moveWindowsToManagedSpace in moveWindowsToManagedSpaceFunctions {
            if moveWindowsToManagedSpace(connectionID, windows, spaceID) == 0 {
                return true
            }
        }

        return false
    }

    private func managedDisplaySpaces() -> [[String: Any]] {
        guard connectionID != 0 else { return [] }

        for copyManagedDisplaySpaces in copyManagedDisplaySpacesFunctions {
            guard let spacesRef = copyManagedDisplaySpaces(connectionID) else { continue }
            return spacesRef.takeRetainedValue() as? [[String: Any]] ?? []
        }

        return []
    }

    private func currentSpaceID(in display: [String: Any]) -> UInt64? {
        guard let currentSpace = display["Current Space"] as? [String: Any] else { return nil }
        return spaceID(from: currentSpace)
    }

    private func ordinarySpaceIDs(in display: [String: Any]) -> [UInt64] {
        guard let spaces = display["Spaces"] as? [[String: Any]] else { return [] }
        return spaces.compactMap { space in
            guard spaceType(from: space) == 0 else { return nil }
            return spaceID(from: space)
        }
    }

    private func spaceID(from space: [String: Any]) -> UInt64? {
        if let number = space["id64"] as? NSNumber { return number.uint64Value }
        if let value = space["id64"] as? UInt64 { return value }
        if let value = space["id64"] as? Int { return UInt64(value) }
        if let number = space["ManagedSpaceID"] as? NSNumber { return number.uint64Value }
        if let value = space["ManagedSpaceID"] as? UInt64 { return value }
        if let value = space["ManagedSpaceID"] as? Int { return UInt64(value) }
        return nil
    }

    private func spaceType(from space: [String: Any]) -> Int {
        if let number = space["type"] as? NSNumber { return number.intValue }
        if let value = space["type"] as? Int { return value }
        return -1
    }
}

private final class WindowDropHighlightView: NSView {
    var onDrop: ((CGWindowID) -> Bool)?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([tabDragType])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 6, dy: 6)
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)

        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        path.fill()

        NSColor.systemBlue.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.string(forType: tabDragType) != nil else { return [] }
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.string(forType: tabDragType) != nil else { return [] }
        return .move
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let str = sender.draggingPasteboard.string(forType: tabDragType),
              let payload = TabDragPayload(string: str) else { return false }
        return onDrop?(payload.windowID) ?? false
    }
}

struct OffscreenWindowInfo: Identifiable, Equatable {
    let windowID: CGWindowID
    let appName: String
    let title: String
    let frame: NSRect
    let groupWindowCount: Int

    var id: CGWindowID { windowID }
    var isGrouped: Bool { groupWindowCount > 1 }

    var displayTitle: String {
        title.isEmpty ? appName : title
    }

    var frameDescription: String {
        "x \(Int(frame.minX)), y \(Int(frame.minY)), w \(Int(frame.width)), h \(Int(frame.height))"
    }
}

private struct WindowBoundsKey: Hashable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init(bounds: [String: CGFloat]) {
        x = Int((bounds["X"] ?? 0).rounded())
        y = Int((bounds["Y"] ?? 0).rounded())
        width = Int((bounds["Width"] ?? 0).rounded())
        height = Int((bounds["Height"] ?? 0).rounded())
    }
}

final class WindowOverlayManager {
    static let shared = WindowOverlayManager()

    private var timer: DispatchSourceTimer?
    private var shortcutEventTap: CFMachPort?
    private var shortcutEventSource: CFRunLoopSource?
    // groupID → overlay panel
    private var overlays: [UUID: NSPanel] = [:]
    private var dropHighlightPanel: NSPanel?
    private var highlightedDropWindowID: CGWindowID?
    private var lastDropHighlightFrame: NSRect?
    private var pendingDetachWorkItem: DispatchWorkItem?
    private var pendingDetachToken: UUID?
    private var pendingDetachWindowID: CGWindowID?
    private var pendingDetachGroupID: UUID?
    private var pendingDetachScreenPoint: NSPoint?
    private var activeDragWindowID: CGWindowID?
    private var lastDragScreenPoint: NSPoint?
    private var completedDragWindowID: CGWindowID?
    /// 正在移动（或缩放）的窗口；对应标签组在移动期间隐藏
    private var movingWindowIDs = Set<CGWindowID>()
    /// 上一 tick 的窗口 frame，用于检测任意原因的位置/尺寸变化
    private var previousTickWindowFrames: [CGWindowID: NSRect] = [:]
    /// 窗口停止变化后开始计时，用于判定「稳定停止」
    private var windowMovementStableSince: [CGWindowID: Date] = [:]
    private let movementStableDuration: TimeInterval = 0.15
    private var missingActiveWindowTicks: [CGWindowID: Int] = [:]
    // groupID → 上次 frame（用于避免无谓刷新）
    private var lastFrames: [UUID: NSRect] = [:]
    // groupID → 标签栏视图（直接 NSView，避免 SwiftUI 托管开销）
    private var tabBarViews: [UUID: TabBarNSView] = [:]
    // groupID → 上次窗口 frame（用于 active 窗口被临时隐藏时维持标签位置）
    private var lastWindowFrames: [UUID: NSRect] = [:]
    // 被本工具暂时隐藏的窗口不会因为不在屏幕列表里被移出分组
    private var hiddenWindowIDs = Set<CGWindowID>()
    private var windowPIDCache: [CGWindowID: pid_t] = [:]
    private var lastKnownWindowPIDs: [CGWindowID: pid_t] = [:]
    private var lastKnownWindowFrames: [CGWindowID: NSRect] = [:]
    private var lastKnownAXWindowFrames: [CGWindowID: NSRect] = [:]
    private var hiddenOriginalAXFrames: [CGWindowID: NSRect] = [:]
    private var hiddenOriginalSpaceIDs: [CGWindowID: UInt64] = [:]
    private var lastAppliedHideMode = AppSettings.hideMode
    private var lastAppliedTheme = AppSettings.theme
    private var lastResolvedIsDark = AppSettings.isDarkMode()
    /// 组内切换进行中时跳过外部焦点同步，避免与标签栏切换互相抢焦点
    private var isGroupSwitchInProgress = false
    /// 组内切换结束后短暂抑制移动检测，避免 hide/restore 触发的 frame 变化误隐藏标签
    private var groupSwitchSuppressedMovementUntil: [UUID: Date] = [:]
    private let groupSwitchMovementSuppressDuration: TimeInterval = 0.5
    /// 快速连切时只保留最后一次目标，避免并发 hide/restore 互相覆盖
    private var pendingGroupSwitch: (wid: CGWindowID, gid: UUID)?
    /// 取消过期的屏外移动补刀回调，防止已恢复窗口被再次移出屏幕
    private var offscreenMoveGeneration: [CGWindowID: UInt64] = [:]
    /// 取消过期的组内切换收尾回调
    private var groupSwitchGeneration: [UUID: UInt64] = [:]
    private var lastObservedFocusedWindowID: CGWindowID?
    private var workspaceActivationObserver: NSObjectProtocol?
    private let ownProcessID = getpid()

    /// 窗口列表短期缓存，避免 tick 内外重复调用 CGWindowListCopyWindowInfo
    private var cachedAllWindowList: [[String: Any]]?
    private var cachedAllWindowListAt = Date.distantPast
    private let windowListCacheTTL: TimeInterval = 0.05
    /// 最小化状态缓存，避免每帧 AX 查询
    private var minimizedWindowCache: [CGWindowID: Bool] = [:]
    private var lastMinimizedCheckAt = Date.distantPast
    private let minimizedCheckInterval: TimeInterval = 0.5
    /// 外部焦点同步节流
    private var lastFocusCheckAt = Date.distantPast
    private let focusCheckInterval: TimeInterval = 0.1
    /// 屏幕高度缓存（tick 内复用）
    private var cachedScreenHeight: CGFloat = 0
    /// 当前已应用的 tick 频率
    private var lastAppliedTickRate = 60
    /// 自适应模式：当前实际 tick 频率（1~60）
    private var currentAdaptiveTickRate = 1
    /// 自适应模式：高频率保持截止时间
    private var adaptiveHighRateUntil = Date.distantPast

    private let minLabelWindowWidth: CGFloat = 200
    private let minLabelWindowHeight: CGFloat = 120
    private let titleRefreshInterval: TimeInterval = 1

    // 窗口标题缓存（windowID → title），每 1s 刷新一次
    private var titleCache: [CGWindowID: String] = [:]
    private var lastTitleRefreshAt = Date.distantPast

    private init() {}

    func start() {
        if AppSettings.restoreOnLaunch {
            restoreAllWindowsOnScreen()
        }
        requestAccessibilityPermissionIfNeeded()
        requestKeyboardMonitoringPermissionIfNeeded()
        startShortcutEventTap()
        registerWorkspaceActivationObserverIfNeeded()
        guard timer == nil else { return }
        lastAppliedTickRate = resolvedTickRate()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: tickInterval(for: lastAppliedTickRate))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        self.timer = t
    }

    func refreshTickInterval() {
        guard timer != nil else { return }
        currentAdaptiveTickRate = 1
        adaptiveHighRateUntil = .distantPast
        applyTickIntervalIfNeeded()
    }

    private func resolvedTickRate() -> Int {
        switch AppSettings.overlayTickRate {
        case .adaptive:
            currentAdaptiveTickRate
        default:
            AppSettings.overlayTickRate.ticksPerSecond ?? 60
        }
    }

    private func tickInterval(for rate: Int) -> DispatchTimeInterval {
        let clamped = max(rate, 1)
        return .nanoseconds(1_000_000_000 / clamped)
    }

    private func applyTickIntervalIfNeeded() {
        let rate = resolvedTickRate()
        guard rate != lastAppliedTickRate, let timer else { return }
        lastAppliedTickRate = rate
        timer.schedule(deadline: .now(), repeating: tickInterval(for: rate))
    }

    private func updateAdaptiveTickRate(now: Date) {
        guard AppSettings.overlayTickRate == .adaptive else { return }

        let needsHighRate = !movingWindowIDs.isEmpty
            || activeDragWindowID != nil
            || pendingDetachWindowID != nil
            || isGroupSwitchInProgress
            || dropHighlightPanel != nil

        if needsHighRate {
            adaptiveHighRateUntil = now.addingTimeInterval(0.35)
            currentAdaptiveTickRate = 60
        } else if now < adaptiveHighRateUntil {
            currentAdaptiveTickRate = 60
        } else {
            currentAdaptiveTickRate = 1
        }

        applyTickIntervalIfNeeded()
    }

    func refreshTheme() {
        applyThemeChangeIfNeeded(force: true)
    }

    func stop() {
        stopShortcutEventTap()
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
            self.workspaceActivationObserver = nil
        }
        timer?.cancel()
        timer = nil
        isGroupSwitchInProgress = false
        pendingGroupSwitch = nil
        groupSwitchSuppressedMovementUntil.removeAll()
        lastObservedFocusedWindowID = nil
        clearDragState()
        if AppSettings.restoreOnExit {
            restoreAllWindowsOnScreen()
        }
        overlays.values.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        lastFrames.removeAll()
        lastWindowFrames.removeAll()
        tabBarViews.removeAll()
        hiddenWindowIDs.removeAll()
        windowPIDCache.removeAll()
        lastKnownWindowPIDs.removeAll()
        lastKnownWindowFrames.removeAll()
        lastKnownAXWindowFrames.removeAll()
        hiddenOriginalAXFrames.removeAll()
        hiddenOriginalSpaceIDs.removeAll()
        missingActiveWindowTicks.removeAll()
        movingWindowIDs.removeAll()
        previousTickWindowFrames.removeAll()
        windowMovementStableSince.removeAll()
    }

    /// 恢复本工具隐藏的窗口，并将屏外、越界或缩小的窗口移回屏幕内（可在设置中分别开启启动/退出时自动调用）。
    func restoreAllWindowsOnScreen() {
        let hiddenIDs = Set(hiddenWindowIDs)
        for wid in hiddenIDs {
            _ = restoreWindow(wid)
        }

        var entriesByID: [CGWindowID: RestorableWindowEntry] = [:]
        for entry in restorableWindowEntries() {
            entriesByID[entry.windowID] = entry
        }

        var windowIDs = Set(entriesByID.keys)
        windowIDs.formUnion(hiddenIDs)

        for wid in windowIDs {
            if hiddenIDs.contains(wid) {
                WindowAlphaController.shared.setAlpha(1, for: wid)
                WindowTransformController.shared.resetTransform(for: wid)
                _ = restoreWindowToCurrentSpaceIfNeeded(wid)
            }

            let currentCGFrame = cgFrame(wid: wid)
                ?? entriesByID[wid]?.cgFrame
                ?? lastKnownWindowFrames[wid]
            guard let currentCGFrame, needsMoveToScreenCenterOnExit(currentCGFrame) else { continue }

            let targetCGFrame = restoreFrameInsideScreen(from: currentCGFrame)
            setWindowFrame(wid: wid, frame: axStyleFrame(fromCGFrame: targetCGFrame))

            if let pid = windowPID(wid), let win = axWindow(pid: pid, wid: wid) {
                AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            }
        }
    }

    /// 手动复原：恢复窗口位置/可见性，并解散全部分组。
    func restoreAllWindowsManually() {
        let oldGroupIDs = Set(GroupStore.shared.groups.keys)
        let allGroupedWindowIDs = Array(GroupStore.shared.windowToGroup.keys)

        restoreAllWindowsOnScreen()

        for wid in allGroupedWindowIDs {
            restoreWindow(wid)
        }

        GroupStore.shared.dissolveAllGroups()

        for gid in oldGroupIDs {
            removeOverlay(for: gid)
        }

        hiddenOriginalAXFrames.removeAll()
        hiddenWindowIDs.removeAll()
        isGroupSwitchInProgress = false
        pendingGroupSwitch = nil
        groupSwitchSuppressedMovementUntil.removeAll()
        offscreenMoveGeneration.removeAll()
        groupSwitchGeneration.removeAll()
        tick()
    }

    private struct RestorableWindowEntry {
        let windowID: CGWindowID
        let cgFrame: NSRect
        let appName: String
        let title: String
    }

    /// 枚举当前可操作的普通窗口（不限分组）。
    private func restorableWindowEntries() -> [RestorableWindowEntry] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]],
              let screenHeight = NSScreen.screens.first?.frame.height else { return [] }

        return list.compactMap { info -> RestorableWindowEntry? in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
            guard isOwnProcessWindow(info) == false else { return nil }
            guard isIgnoredSystemWindow(info) == false else { return nil }
            guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { return nil }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }

            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            guard width >= minLabelWindowWidth && height >= minLabelWindowHeight else { return nil }

            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let frame = NSRect(x: x, y: screenHeight - y - height, width: width, height: height)

            if let pid = info[kCGWindowOwnerPID as String] as? pid_t {
                windowPIDCache[wid] = pid
                lastKnownWindowPIDs[wid] = pid
            }
            let appName = info[kCGWindowOwnerName as String] as? String ?? "未知 App"
            let title = info[kCGWindowName as String] as? String ?? ""
            lastKnownWindowFrames[wid] = frame
            lastKnownAXWindowFrames[wid] = NSRect(x: x, y: y, width: width, height: height)

            return RestorableWindowEntry(windowID: wid, cgFrame: frame, appName: appName, title: title)
        }
    }

    /// 窗口是否完整落在任一屏幕的可视区域内。
    private func isFullyInsideVisibleArea(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.contains(frame) }
    }

    /// 完全在屏外、部分越界或被缩到极小尺寸时，退出前需要移回屏幕中心。
    private func needsMoveToScreenCenterOnExit(_ frame: NSRect) -> Bool {
        if frame.width < minLabelWindowWidth || frame.height < minLabelWindowHeight {
            return true
        }
        return isFullyInsideVisibleArea(frame) == false
    }

    func offscreenWindows() -> [OffscreenWindowInfo] {
        restorableWindowEntries()
            .filter { intersectsAnyScreen($0.cgFrame) == false }
            .map { entry in
                OffscreenWindowInfo(
                    windowID: entry.windowID,
                    appName: entry.appName,
                    title: entry.title,
                    frame: entry.cgFrame,
                    groupWindowCount: GroupStore.shared.group(for: entry.windowID)?.group.windowIDs.count ?? 0
                )
            }
            .sorted { lhs, rhs in
                lhs.appName == rhs.appName
                    ? lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
                    : lhs.appName.localizedStandardCompare(rhs.appName) == .orderedAscending
            }
    }

    @discardableResult
    func restoreOffscreenWindow(_ wid: CGWindowID) -> Bool {
        let cgFrameValue = cgFrame(wid: wid) ?? lastKnownWindowFrames[wid]
        let axFrameValue = axFrame(wid: wid) ?? lastKnownAXWindowFrames[wid] ?? cgFrameValue.map(axStyleFrame(fromCGFrame:))
        guard let baseFrame = cgFrameValue ?? axFrameValue.map(cgStyleFrame(fromAXFrame:)) else { return false }

        let restoredCGFrame = restoreFrameInsideScreen(from: baseFrame)
        let restoredAXFrame = axStyleFrame(fromCGFrame: restoredCGFrame)
        WindowAlphaController.shared.setAlpha(1, for: wid)
        WindowTransformController.shared.resetTransform(for: wid)
        setWindowFrame(wid: wid, frame: restoredAXFrame)
        hiddenWindowIDs.remove(wid)
        hiddenOriginalAXFrames.removeValue(forKey: wid)
        lastKnownWindowFrames[wid] = restoredCGFrame
        lastKnownAXWindowFrames[wid] = restoredAXFrame

        if let pid = windowPID(wid),
           let win = axWindow(pid: pid, wid: wid) {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }

        if let result = GroupStore.shared.detachForRestore(windowID: wid) {
            refreshGroupsAfterDetach(
                oldGroupID: result.oldGroupID,
                newGroupID: result.newGroupID,
                oldGroup: result.oldGroup,
                newGroup: result.newGroup,
                restoredFrame: restoredCGFrame
            )
        } else {
            let gid = GroupStore.shared.registerIfNeeded(wid)
            lastWindowFrames[gid] = restoredCGFrame
            if let group = GroupStore.shared.groups[gid] {
                updateTabBarView(gid: gid, group: group)
            }
        }

        activateFrontmostWindow(wid)
        return true
    }

    // MARK: - 主循环

    private func tick() {
        let now = Date()
        let shouldRefreshTitles = now.timeIntervalSince(lastTitleRefreshAt) >= titleRefreshInterval
        if shouldRefreshTitles {
            lastTitleRefreshAt = now
        }

        guard let allWindowList = allWindowList(forceRefresh: true) else { return }

        cachedScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let screenHeight = cachedScreenHeight
        guard screenHeight > 0 else { return }

        if shouldRefreshTitles {
            refreshTitleCache(from: allWindowList)
        }

        applyHideModeChangeIfNeeded()
        applyThemeChangeIfNeeded()
        finishDragIfMouseReleased()
        observeExternalWindowFocus(now: now)

        let stageManagerBlockingOverlayBounds = stageManagerBlockingOverlayBounds(in: allWindowList)

        // 本轮所有有效 windowID + 位置
        var visibleWindowIDs = Set<CGWindowID>()
        var knownExistingWindowIDs = Set<CGWindowID>()
        var ignoredExistingWindowIDs = Set<CGWindowID>()
        var windowFrames: [CGWindowID: NSRect] = [:]  // 窗口自身 NSRect（非 label）

        refreshMinimizedCacheIfNeeded(now: now)

        for info in allWindowList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard isOwnProcessWindow(info) == false else { continue }
            guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard isIgnoredSystemWindow(info) == false else {
                ignoredExistingWindowIDs.insert(wid)
                continue
            }
            knownExistingWindowIDs.insert(wid)
            if let pid = info[kCGWindowOwnerPID as String] as? pid_t {
                windowPIDCache[wid] = pid
                lastKnownWindowPIDs[wid] = pid
            }

            guard windowListEntryIsOnScreen(info) else { continue }
            guard isStageManagerThumbnail(info, matching: stageManagerBlockingOverlayBounds) == false else { continue }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }

            let w = bounds["Width"] ?? 0
            let h = bounds["Height"] ?? 0
            guard w >= minLabelWindowWidth && h >= minLabelWindowHeight else { continue }
            guard isWindowMinimizedCached(wid) == false else { continue }

            let cgX = bounds["X"] ?? 0
            let cgY = bounds["Y"] ?? 0
            let nsY = screenHeight - cgY - h
            let frame = NSRect(x: cgX, y: nsY, width: w, height: h)
            let axFrame = NSRect(x: cgX, y: cgY, width: w, height: h)
            visibleWindowIDs.insert(wid)
            windowFrames[wid] = frame
            lastKnownWindowFrames[wid] = frame
            lastKnownAXWindowFrames[wid] = axFrame
        }

        // 1. 注册新出现的可见窗口
        var newlyRegisteredWindowIDs = Set<CGWindowID>()
        for wid in visibleWindowIDs where hiddenWindowIDs.contains(wid) == false {
            if GroupStore.shared.groupID(for: wid) == nil {
                newlyRegisteredWindowIDs.insert(wid)
            }
            GroupStore.shared.registerIfNeeded(wid)
        }

        // 1b. 同应用新窗口自动并入已有分组，并切换到新窗口
        if AppSettings.autoGroupSameAppWindows {
            for wid in newlyRegisteredWindowIDs {
                autoGroupSameAppWindowIfNeeded(wid)
            }
        }

        // 2. 移除真正不存在的窗口；被隐藏但仍存在的窗口继续保留在组内
        let closedActiveWindowIDs = detectClosedActiveWindowIDs(
            visibleWindowIDs: visibleWindowIDs,
            knownExistingWindowIDs: knownExistingWindowIDs
        )
        let allKnown = Set(GroupStore.shared.windowToGroup.keys)
        let disappeared = Set(allKnown.filter {
            closedActiveWindowIDs.contains($0)
                || ignoredExistingWindowIDs.contains($0)
                || windowStillExists($0, knownExistingWindowIDs: knownExistingWindowIDs) == false
        })
        let removalChanges = GroupStore.shared.removeWindows(disappeared)
        hiddenWindowIDs.formIntersection(Set(GroupStore.shared.windowToGroup.keys))
        applyWindowRemovalChanges(removalChanges)
        cleanupDisappearedWindows(disappeared)
        updateMovingWindowState(windowFrames: windowFrames, now: now)

        // 3. 计算每个 group 对应的 overlay frame（以 active 窗口为锚点）
        let groups = GroupStore.shared.groups

        // 已存在组的 ID 集合
        let activeGroupIDs = Set(groups.keys)

        // 移除不再存在的 overlay
        for gid in Set(overlays.keys).subtracting(activeGroupIDs) {
            removeOverlay(for: gid)
        }

        // 为每个 group 创建或更新 overlay
        for (gid, group) in groups {
            let activeWID = group.activeWindowID
            guard visibleWindowIDs.contains(activeWID),
                  let winFrame = windowFrames[activeWID] else {
                overlays[gid]?.orderOut(nil)
                lastFrames.removeValue(forKey: gid)
                continue
            }
            lastWindowFrames[gid] = winFrame

            let labelFrame = labelFrame(for: winFrame, group: group)
            let hideTabWhileMoving = group.windowIDs.contains { movingWindowIDs.contains($0) }

            if let existing = overlays[gid] {
                let changed = lastFrames[gid] != labelFrame
                if changed {
                    existing.setFrame(labelFrame, display: false)
                    if let tabBar = tabBarViews[gid] {
                        tabBar.frame = NSRect(origin: .zero, size: labelFrame.size)
                    }
                    lastFrames[gid] = labelFrame
                }
                if shouldRefreshTitles {
                    updateTabBarView(gid: gid, group: group)
                }
                if hideTabWhileMoving {
                    existing.orderOut(nil)
                } else if changed || !existing.isVisible {
                    placeOverlay(existing, above: activeWID)
                }
            } else {
                let panel = makePanel(frame: labelFrame, gid: gid, group: group, activeWID: activeWID)
                overlays[gid] = panel
                lastFrames[gid] = labelFrame
                if hideTabWhileMoving {
                    panel.orderOut(nil)
                }
            }
        }

        updateAdaptiveTickRate(now: now)
    }

    /// 检测窗口 frame 变化（主动拖动、被动动画、缩放等），移动中隐藏标签组，稳定停止后再显示
    private func updateMovingWindowState(windowFrames: [CGWindowID: NSRect], now: Date) {
        groupSwitchSuppressedMovementUntil = groupSwitchSuppressedMovementUntil.filter { $0.value > now }

        if isGroupSwitchInProgress {
            previousTickWindowFrames = windowFrames
            return
        }

        let visibleWIDs = Set(windowFrames.keys)
        movingWindowIDs.formIntersection(visibleWIDs)
        windowMovementStableSince = windowMovementStableSince.filter { visibleWIDs.contains($0.key) }

        for (wid, frame) in windowFrames {
            if isMovementDetectionSuppressed(for: wid, now: now) {
                previousTickWindowFrames[wid] = frame
                movingWindowIDs.remove(wid)
                windowMovementStableSince.removeValue(forKey: wid)
                continue
            }

            guard let previous = previousTickWindowFrames[wid] else { continue }

            if windowFrameChanged(from: previous, to: frame) {
                let wasMoving = movingWindowIDs.contains(wid)
                movingWindowIDs.insert(wid)
                windowMovementStableSince.removeValue(forKey: wid)
                if !wasMoving {
                    if AppSettings.overlayTickRate == .adaptive {
                        adaptiveHighRateUntil = now.addingTimeInterval(0.35)
                        currentAdaptiveTickRate = 60
                        applyTickIntervalIfNeeded()
                    }
                    hideOverlayForGroupContaining(windowID: wid)
                }
            } else if movingWindowIDs.contains(wid) {
                if let stableSince = windowMovementStableSince[wid] {
                    if now.timeIntervalSince(stableSince) >= movementStableDuration {
                        movingWindowIDs.remove(wid)
                        windowMovementStableSince.removeValue(forKey: wid)
                    }
                } else {
                    windowMovementStableSince[wid] = now
                }
            }
        }

        previousTickWindowFrames = windowFrames
    }

    private func isMovementDetectionSuppressed(for wid: CGWindowID, now: Date) -> Bool {
        guard let gid = GroupStore.shared.groupID(for: wid),
              let until = groupSwitchSuppressedMovementUntil[gid] else { return false }
        return now < until
    }

    private func suppressMovementDetectionForGroup(_ gid: UUID) {
        let until = Date().addingTimeInterval(groupSwitchMovementSuppressDuration)
        groupSwitchSuppressedMovementUntil[gid] = until
        guard let group = GroupStore.shared.groups[gid] else { return }
        for wid in group.windowIDs {
            movingWindowIDs.remove(wid)
            windowMovementStableSince.removeValue(forKey: wid)
            if let frame = lastKnownWindowFrames[wid] {
                previousTickWindowFrames[wid] = frame
            }
        }
    }

    private func hideOverlayForGroupContaining(windowID wid: CGWindowID) {
        guard let gid = GroupStore.shared.groupID(for: wid) else { return }
        overlays[gid]?.orderOut(nil)
    }

    private func windowFrameChanged(from previous: NSRect, to current: NSRect) -> Bool {
        abs(previous.origin.x - current.origin.x) > 0.5
            || abs(previous.origin.y - current.origin.y) > 0.5
            || abs(previous.width - current.width) > 0.5
            || abs(previous.height - current.height) > 0.5
    }

    // MARK: - 标题缓存

    private func applyHideModeChangeIfNeeded() {
        let currentMode = AppSettings.hideMode
        guard currentMode != lastAppliedHideMode else { return }
        hiddenWindowIDs.forEach { _ = restoreWindow($0) }
        hiddenWindowIDs = hiddenWindowIDs.filter { hiddenOriginalSpaceIDs[$0] != nil }
        lastAppliedHideMode = currentMode
    }

    private func applyThemeChangeIfNeeded(force: Bool = false) {
        let currentTheme = AppSettings.theme
        let currentIsDark = AppSettings.isDarkMode()
        guard force || currentTheme != lastAppliedTheme || currentIsDark != lastResolvedIsDark else { return }

        lastAppliedTheme = currentTheme
        lastResolvedIsDark = currentIsDark
        let appearance = AppSettings.resolvedNSAppearance()

        for (gid, panel) in overlays {
            panel.appearance = appearance
            if let group = GroupStore.shared.groups[gid] {
                updateTabBarView(gid: gid, group: group)
            }
        }
    }

    private func refreshTitleCache(from list: [[String: Any]]) {
        var cache: [CGWindowID: String] = [:]
        for info in list {
            guard isOwnProcessWindow(info) == false else { continue }
            guard isIgnoredSystemWindow(info) == false else { continue }
            guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            let name = info[kCGWindowOwnerName as String] as? String ?? ""
            let title = info[kCGWindowName as String] as? String ?? ""
            cache[wid] = title.isEmpty ? name : title
        }
        titleCache = cache
    }

    private func allWindowList(forceRefresh: Bool) -> [[String: Any]]? {
        let now = Date()
        if !forceRefresh,
           let cached = cachedAllWindowList,
           now.timeIntervalSince(cachedAllWindowListAt) < windowListCacheTTL {
            return cached
        }
        guard let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        cachedAllWindowList = list
        cachedAllWindowListAt = now
        return list
    }

    private func windowListEntryIsOnScreen(_ info: [String: Any]) -> Bool {
        if let onScreen = info[kCGWindowIsOnscreen as String] as? Int {
            return onScreen == 1
        }
        if let onScreen = info[kCGWindowIsOnscreen as String] as? Bool {
            return onScreen
        }
        return false
    }

    private func refreshMinimizedCacheIfNeeded(now: Date) {
        guard now.timeIntervalSince(lastMinimizedCheckAt) >= minimizedCheckInterval else { return }
        lastMinimizedCheckAt = now
        minimizedWindowCache.removeAll()
    }

    private func isWindowMinimizedCached(_ wid: CGWindowID) -> Bool {
        if let cached = minimizedWindowCache[wid] { return cached }
        let minimized = isWindowMinimized(wid)
        minimizedWindowCache[wid] = minimized
        return minimized
    }

    private func title(for wid: CGWindowID) -> String {
        titleCache[wid] ?? "窗口"
    }

    private func isOwnProcessWindow(_ info: [String: Any]) -> Bool {
        (info[kCGWindowOwnerPID as String] as? pid_t) == ownProcessID
    }

    private func isIgnoredSystemWindow(_ info: [String: Any]) -> Bool {
        let owner = info[kCGWindowOwnerName as String] as? String ?? ""
        let title = info[kCGWindowName as String] as? String ?? ""
        return owner == "WindowManager"
            || owner == "Dock"
            || title == "Gesture Blocking Overlay"
            || title == "App Icon Window"
    }

    private func stageManagerBlockingOverlayBounds(in list: [[String: Any]]) -> Set<WindowBoundsKey> {
        Set(list.compactMap { info in
            guard isIgnoredSystemWindow(info),
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  owner == "WindowManager",
                  let title = info[kCGWindowName as String] as? String,
                  title == "Gesture Blocking Overlay",
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            return WindowBoundsKey(bounds: bounds)
        })
    }

    private func isStageManagerThumbnail(_ info: [String: Any], matching overlayBounds: Set<WindowBoundsKey>) -> Bool {
        guard overlayBounds.isEmpty == false else { return false }
        guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
        let width = bounds["Width"] ?? 0
        let height = bounds["Height"] ?? 0
        guard width > 0, height > 0 else { return false }
        guard width < minLabelWindowWidth || height < minLabelWindowHeight else { return false }
        return overlayBounds.contains(WindowBoundsKey(bounds: bounds))
    }

    private func isWindowMinimized(_ wid: CGWindowID) -> Bool {
        guard let pid = windowPID(wid),
              let win = axWindow(pid: pid, wid: wid) else { return false }
        var minimizedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimizedRef) == .success else { return false }
        return (minimizedRef as? Bool) ?? false
    }

    private func placeOverlay(_ panel: NSPanel, above windowID: CGWindowID) {
        panel.level = .normal
        panel.order(.above, relativeTo: Int(windowID))
    }

    private func windowStillExists(_ wid: CGWindowID, knownExistingWindowIDs: Set<CGWindowID>) -> Bool {
        if knownExistingWindowIDs.contains(wid) { return true }
        guard let pid = windowPID(wid) else { return false }
        return axWindow(pid: pid, wid: wid) != nil
    }

    private func cleanupDisappearedWindows(_ disappeared: Set<CGWindowID>) {
        guard !disappeared.isEmpty else { return }
        for wid in disappeared {
            windowPIDCache.removeValue(forKey: wid)
            lastKnownWindowPIDs.removeValue(forKey: wid)
            lastKnownWindowFrames.removeValue(forKey: wid)
            lastKnownAXWindowFrames.removeValue(forKey: wid)
            hiddenOriginalAXFrames.removeValue(forKey: wid)
            hiddenOriginalSpaceIDs.removeValue(forKey: wid)
            hiddenWindowIDs.remove(wid)
            offscreenMoveGeneration.removeValue(forKey: wid)
            titleCache.removeValue(forKey: wid)
            if pendingDetachWindowID == wid {
                cancelPendingDetach()
            }
            missingActiveWindowTicks.removeValue(forKey: wid)
            movingWindowIDs.remove(wid)
            previousTickWindowFrames.removeValue(forKey: wid)
            windowMovementStableSince.removeValue(forKey: wid)
        }
    }

    private func detectClosedActiveWindowIDs(
        visibleWindowIDs: Set<CGWindowID>,
        knownExistingWindowIDs: Set<CGWindowID>
    ) -> Set<CGWindowID> {
        var closed = Set<CGWindowID>()
        let activeWindowIDs = Set(GroupStore.shared.groups.values.compactMap { group -> CGWindowID? in
            group.windowIDs.count > 1 ? group.activeWindowID : nil
        })

        for wid in activeWindowIDs {
            if visibleWindowIDs.contains(wid) {
                missingActiveWindowTicks.removeValue(forKey: wid)
                continue
            }
            if hiddenWindowIDs.contains(wid) || hiddenOriginalSpaceIDs[wid] != nil {
                missingActiveWindowTicks.removeValue(forKey: wid)
                continue
            }
            let count = (missingActiveWindowTicks[wid] ?? 0) + 1
            missingActiveWindowTicks[wid] = count
            if count >= 2 {
                closed.insert(wid)
            }
        }

        missingActiveWindowTicks = missingActiveWindowTicks.filter { activeWindowIDs.contains($0.key) }
        return closed
    }

    private func applyWindowRemovalChanges(_ changes: [WindowRemovalChange]) {
        guard !changes.isEmpty else { return }

        for change in changes {
            for wid in change.removedWindowIDs {
                missingActiveWindowTicks.removeValue(forKey: wid)
            }

            guard let group = change.remainingGroup else {
                removeOverlay(for: change.groupID)
                continue
            }

            updateTabBarView(gid: change.groupID, group: group)

            guard let removedActiveWindowID = change.removedActiveWindowID else { continue }
            let targetAXFrame = lastKnownAXWindowFrames[removedActiveWindowID]
                ?? lastKnownWindowFrames[removedActiveWindowID].map(axStyleFrame(fromCGFrame:))
            restoreReplacementWindow(
                group: group,
                groupID: change.groupID,
                targetAXFrame: targetAXFrame
            )
        }
    }

    private func restoreReplacementWindow(group: WindowGroup, groupID: UUID, targetAXFrame: NSRect?) {
        let replacementWID = group.activeWindowID
        let resolvedAXFrame = targetAXFrame.map { switchTargetFrame(slotFrame: $0, for: replacementWID) }

        if let resolvedAXFrame {
            revealIncomingWindowForSwitch(wid: replacementWID, slotFrame: resolvedAXFrame)
            lastKnownAXWindowFrames[replacementWID] = resolvedAXFrame
            let targetCGFrame = cgStyleFrame(fromAXFrame: resolvedAXFrame)
            lastKnownWindowFrames[replacementWID] = targetCGFrame
            lastWindowFrames[groupID] = targetCGFrame
        } else {
            restoreWindow(replacementWID)
        }

        activateFrontmostWindow(replacementWID)
        hideWindowsForSwitch(group.windowIDs.filter { $0 != replacementWID })

        for delay in [0.04, 0.12, 0.24] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      let currentGroup = GroupStore.shared.groups[groupID],
                      currentGroup.activeWindowID == replacementWID else { return }

                if let resolvedAXFrame {
                    self.revealIncomingWindowForSwitch(wid: replacementWID, slotFrame: resolvedAXFrame)
                } else {
                    self.restoreWindow(replacementWID)
                }
                self.activateFrontmostWindow(replacementWID)
                self.hideWindowsForSwitch(currentGroup.windowIDs.filter { $0 != replacementWID })
            }
        }
    }

    /// 根据切换大小策略，把目标窗口 frame 解析为最终应使用的 AX 坐标。
    private func switchTargetFrame(slotFrame: NSRect, for wid: CGWindowID) -> NSRect {
        switch AppSettings.windowSwitchSizeMode {
        case .matchCurrent:
            return slotFrame
        case .keepOriginal:
            let originalSize = hiddenOriginalAXFrames[wid]?.size
                ?? lastKnownAXWindowFrames[wid]?.size
                ?? axFrame(wid: wid)?.size
                ?? slotFrame.size
            return NSRect(origin: slotFrame.origin, size: originalSize)
        }
    }

    private func removeOverlay(for gid: UUID) {
        overlays[gid]?.orderOut(nil)
        overlays.removeValue(forKey: gid)
        lastFrames.removeValue(forKey: gid)
        lastWindowFrames.removeValue(forKey: gid)
        tabBarViews.removeValue(forKey: gid)
    }

    private func refreshGroupsAfterDetach(
        oldGroupID: UUID,
        newGroupID: UUID,
        oldGroup: WindowGroup?,
        newGroup: WindowGroup,
        restoredFrame: NSRect
    ) {
        if let oldGroup {
            updateTabBarView(gid: oldGroupID, group: oldGroup)
            if let frame = cgFrame(wid: oldGroup.activeWindowID) ?? lastWindowFrames[oldGroupID] {
                lastWindowFrames[oldGroupID] = frame
            }
        } else {
            removeOverlay(for: oldGroupID)
        }

        lastWindowFrames[newGroupID] = restoredFrame
        updateTabBarView(gid: newGroupID, group: newGroup)
    }

    // MARK: - Model

    private func makeModel(gid: UUID, group: WindowGroup) -> TabBarModel {
        var titles: [CGWindowID: String] = [:]
        for wid in group.windowIDs { titles[wid] = title(for: wid) }
        return TabBarModel(
            groupID: gid,
            windowIDs: group.windowIDs,
            activeIndex: group.activeIndex,
            titles: titles
        )
    }

    private func updateTabBarView(gid: UUID, group: WindowGroup) {
        guard let tabBar = tabBarViews[gid] else { return }
        let model = makeModel(gid: gid, group: group)
        if tabBar.model != model {
            tabBar.model = model
        }
    }

    private func labelFrame(for winFrame: NSRect, group: WindowGroup) -> NSRect {
        let titles = group.windowIDs.map { title(for: $0) }
        let size = NSSize(width: TabBarLayout.barWidth(for: titles), height: TabBarLayout.barHeight)
        let horizontalAnchor = AppSettings.labelHorizontalAnchor
        let verticalAnchor = AppSettings.labelVerticalAnchor
        let placement = AppSettings.labelPlacement
        let outsideGap: CGFloat = 4
        let offsetX = CGFloat(AppSettings.labelOffsetX)
        let offsetY = CGFloat(AppSettings.labelOffsetY)

        let baseX: CGFloat
        switch horizontalAnchor {
        case .left:
            baseX = placement == .outside && verticalAnchor == .center
                ? winFrame.minX - size.width - outsideGap
                : winFrame.minX
        case .center:
            baseX = winFrame.midX - size.width / 2
        case .right:
            baseX = placement == .outside && verticalAnchor == .center
                ? winFrame.maxX + outsideGap
                : winFrame.maxX - size.width
        }
        let x = baseX + offsetX

        let baseY: CGFloat
        switch verticalAnchor {
        case .top:
            baseY = placement == .inside
                ? winFrame.maxY - size.height
                : winFrame.maxY + outsideGap
        case .center:
            baseY = winFrame.midY - size.height / 2
        case .bottom:
            baseY = placement == .inside
                ? winFrame.minY
                : winFrame.minY - size.height - outsideGap
        }
        let y = baseY + offsetY

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    // MARK: - Panel 工厂

    private func makePanel(frame: NSRect, gid: UUID, group: WindowGroup, activeWID: CGWindowID) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // 允许鼠标事件（拖拽需要）
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.appearance = AppSettings.resolvedNSAppearance()

        let model = makeModel(gid: gid, group: group)
        let tabBar = TabBarNSView(model: model)
        tabBar.frame = NSRect(origin: .zero, size: frame.size)
        tabBar.autoresizingMask = [.width, .height]
        tabBar.onActivate = { [weak self] wid in self?.handleActivate(wid: wid, gid: gid) }
        tabBar.onDrop = { [weak self] srcWID, targetGID in _ = self?.handleDrop(srcWID: srcWID, targetGID: targetGID) }
        tabBar.onDragEndedOutsideTabBar = { [weak self] srcWID, point in self?.handleDragEndedOutsideTabBar(srcWID: srcWID, screenPoint: point) }
        tabBar.onDragMoved = { [weak self] srcWID, point in self?.handleDragMoved(srcWID: srcWID, screenPoint: point) }
        tabBar.onDragFinished = { [weak self] _ in self?.clearDragState() }
        panel.contentView = tabBar
        tabBarViews[gid] = tabBar

        placeOverlay(panel, above: activeWID)
        return panel
    }

    // MARK: - 拖拽目标高亮

    private func handleDragMoved(srcWID: CGWindowID, screenPoint: NSPoint) {
        if isLeftMouseButtonReleased {
            guard activeDragWindowID != nil || completedDragWindowID != srcWID else { return }
            activeDragWindowID = srcWID
            lastDragScreenPoint = screenPoint
            finishHighlightedDropIfNeeded(srcWID: srcWID, screenPoint: screenPoint)
            return
        }

        if activeDragWindowID != srcWID {
            completedDragWindowID = nil
        }
        activeDragWindowID = srcWID
        lastDragScreenPoint = screenPoint
        guard completedDragWindowID != srcWID else { return }
        guard let sourceGroup = GroupStore.shared.group(for: srcWID) else {
            cancelPendingDetach()
            clearDropHighlight()
            return
        }

        if isInsideSourceDragRegion(groupID: sourceGroup.id,
                                    activeWindowID: sourceGroup.group.activeWindowID,
                                    screenPoint: screenPoint) {
            cancelPendingDetach()
            clearDropHighlight()
            return
        }

        if let target = dropTarget(srcWID: srcWID,
                                   sourceGroupID: sourceGroup.id,
                                   sourceActiveWID: sourceGroup.group.activeWindowID,
                                   screenPoint: screenPoint),
           let targetFrame = cgFrame(wid: target.windowID) ?? lastKnownWindowFrames[target.windowID] {
            cancelPendingDetach()
            showDropHighlight(windowID: target.windowID, frame: targetFrame)
            return
        }

        clearDropHighlight()

        guard AppSettings.detachOnDragEnabled else {
            cancelPendingDetach()
            return
        }

        guard sourceGroup.group.windowIDs.count > 1 else {
            cancelPendingDetach()
            return
        }

        scheduleDetachIfNeeded(srcWID: srcWID, groupID: sourceGroup.id, screenPoint: screenPoint)
    }

    private func isInsideSourceDragRegion(groupID: UUID, activeWindowID: CGWindowID, screenPoint: NSPoint) -> Bool {
        guard var sourceFrame = cgFrame(wid: activeWindowID) ?? lastWindowFrames[groupID] else { return false }
        if let labelFrame = overlays[groupID]?.frame ?? lastFrames[groupID] {
            sourceFrame = sourceFrame.union(labelFrame.insetBy(dx: -8, dy: -8))
        }
        return sourceFrame.contains(screenPoint)
    }

    private func dropTarget(srcWID: CGWindowID,
                            sourceGroupID: UUID,
                            sourceActiveWID: CGWindowID,
                            screenPoint: NSPoint) -> (windowID: CGWindowID, groupID: UUID)? {
        let blockingWindowIDs = Set([srcWID, sourceActiveWID])
        if let targetWID = windowID(at: screenPoint, excluding: blockingWindowIDs),
           let targetGID = GroupStore.shared.groupID(for: targetWID),
           targetGID != sourceGroupID,
           canMergeWindows(source: srcWID, target: targetWID) {
            return (targetWID, targetGID)
        }

        if let highlightedDropWindowID,
           let targetGID = GroupStore.shared.groupID(for: highlightedDropWindowID),
           targetGID != sourceGroupID,
           canMergeWindows(source: srcWID, target: highlightedDropWindowID),
           let frame = cgFrame(wid: highlightedDropWindowID) ?? lastDropHighlightFrame,
           frame.contains(screenPoint) {
            return (highlightedDropWindowID, targetGID)
        }

        return nil
    }

    private func highlightedDropTarget(sourceGroupID: UUID, sourceWID: CGWindowID) -> (windowID: CGWindowID, groupID: UUID)? {
        guard let highlightedDropWindowID,
              let targetGID = GroupStore.shared.groupID(for: highlightedDropWindowID),
              targetGID != sourceGroupID,
              canMergeWindows(source: sourceWID, target: highlightedDropWindowID) else { return nil }
        return (highlightedDropWindowID, targetGID)
    }

    private func showDropHighlight(windowID: CGWindowID, frame: NSRect) {
        guard frame.width > 8, frame.height > 8 else {
            clearDropHighlight()
            return
        }

        if let panel = dropHighlightPanel {
            if highlightedDropWindowID != windowID || lastDropHighlightFrame != frame {
                panel.setFrame(frame, display: true)
                panel.contentView?.frame = NSRect(origin: .zero, size: frame.size)
                panel.contentView?.needsDisplay = true
                placeOverlay(panel, above: windowID)
                highlightedDropWindowID = windowID
                lastDropHighlightFrame = frame
            }
            if let highlightView = panel.contentView as? WindowDropHighlightView {
                highlightView.onDrop = { [weak self] srcWID in
                    self?.dropHighlightedWindow(srcWID: srcWID, targetWindowID: windowID) ?? false
                }
            }
            return
        }

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let highlightView = WindowDropHighlightView(frame: NSRect(origin: .zero, size: frame.size))
        highlightView.onDrop = { [weak self] srcWID in
            self?.dropHighlightedWindow(srcWID: srcWID, targetWindowID: windowID) ?? false
        }
        panel.contentView = highlightView

        dropHighlightPanel = panel
        highlightedDropWindowID = windowID
        lastDropHighlightFrame = frame
        placeOverlay(panel, above: windowID)
    }

    private func clearDropHighlight() {
        dropHighlightPanel?.orderOut(nil)
        dropHighlightPanel = nil
        highlightedDropWindowID = nil
        lastDropHighlightFrame = nil
    }

    private func clearDragState() {
        cancelPendingDetach()
        clearDropHighlight()
        activeDragWindowID = nil
        lastDragScreenPoint = nil
    }

    private func cancelPendingDetach() {
        pendingDetachWorkItem?.cancel()
        pendingDetachWorkItem = nil
        pendingDetachToken = nil
        pendingDetachWindowID = nil
        pendingDetachGroupID = nil
        pendingDetachScreenPoint = nil
    }

    private func scheduleDetachIfNeeded(srcWID: CGWindowID, groupID: UUID, screenPoint: NSPoint) {
        if pendingDetachWindowID == srcWID, pendingDetachGroupID == groupID {
            pendingDetachScreenPoint = screenPoint
            return
        }

        cancelPendingDetach()

        let token = UUID()
        pendingDetachToken = token
        pendingDetachWindowID = srcWID
        pendingDetachGroupID = groupID
        pendingDetachScreenPoint = screenPoint

        let delay = AppSettings.detachDelay
        if delay <= 0 {
            detachIfStillOutsideWindow(srcWID: srcWID, groupID: groupID, token: token)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.detachIfStillOutsideWindow(srcWID: srcWID, groupID: groupID, token: token)
        }
        pendingDetachWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func detachIfStillOutsideWindow(srcWID: CGWindowID, groupID: UUID, token: UUID) {
        guard AppSettings.detachOnDragEnabled,
              completedDragWindowID != srcWID,
              pendingDetachToken == token,
              pendingDetachWindowID == srcWID,
              pendingDetachGroupID == groupID,
              let screenPoint = pendingDetachScreenPoint,
              let sourceGroup = GroupStore.shared.group(for: srcWID),
              sourceGroup.id == groupID,
              sourceGroup.group.windowIDs.count > 1,
              isInsideSourceDragRegion(groupID: groupID,
                                       activeWindowID: sourceGroup.group.activeWindowID,
                                       screenPoint: screenPoint) == false,
              dropTarget(srcWID: srcWID,
                         sourceGroupID: groupID,
                         sourceActiveWID: sourceGroup.group.activeWindowID,
                         screenPoint: screenPoint) == nil else {
            cancelPendingDetach()
            return
        }

        detachFromGroup(srcWID: srcWID, oldGroupID: groupID, screenPoint: screenPoint)
        completedDragWindowID = srcWID
        cancelPendingDetach()
    }

    private func detachFromGroup(srcWID: CGWindowID, oldGroupID: UUID, screenPoint: NSPoint) {
        let currentAXFrame = hiddenOriginalAXFrames[srcWID] ?? axFrame(wid: srcWID) ?? lastKnownAXWindowFrames[srcWID]
        restoreWindow(srcWID)

        guard let result = GroupStore.shared.detach(windowID: srcWID),
              let oldGroup = GroupStore.shared.groups[result.oldGroupID],
              let newGroup = GroupStore.shared.groups[result.newGroupID] else { return }

        let detachFrame = detachedWindowFrame(for: srcWID, at: screenPoint, fallback: currentAXFrame)
        setWindowFrame(wid: srcWID, frame: detachFrame)
        lastKnownAXWindowFrames[srcWID] = detachFrame
        lastKnownWindowFrames[srcWID] = cgStyleFrame(fromAXFrame: detachFrame)
        lastWindowFrames[result.newGroupID] = cgStyleFrame(fromAXFrame: detachFrame)

        for wid in oldGroup.windowIDs where wid != oldGroup.activeWindowID {
            minimizeWindow(wid)
        }
        restoreWindow(oldGroup.activeWindowID)
        activateFrontmostWindow(srcWID)

        updateTabBarView(gid: result.oldGroupID, group: oldGroup)
        updateTabBarView(gid: result.newGroupID, group: newGroup)
    }

    private func detachedWindowFrame(for wid: CGWindowID, at screenPoint: NSPoint, fallback: NSRect?) -> NSRect {
        let size = fallback?.size ?? lastKnownAXWindowFrames[wid]?.size ?? NSSize(width: 800, height: 600)
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let axPoint = NSPoint(x: screenPoint.x - size.width / 2, y: screenHeight - screenPoint.y - 40)
        return NSRect(origin: axPoint, size: size)
    }

    private func cgStyleFrame(fromAXFrame frame: NSRect) -> NSRect {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: frame.minX, y: screenHeight - frame.minY - frame.height, width: frame.width, height: frame.height)
    }

    // MARK: - 事件处理

    @discardableResult
    private func activateNextTabFromFocusedWindow() -> Bool {
        guard let focusedWID = focusedWindowID(),
              let groupInfo = GroupStore.shared.group(for: focusedWID),
              groupInfo.group.windowIDs.count > 1 else { return false }

        let windowIDs = groupInfo.group.windowIDs
        let currentIndex = windowIDs.firstIndex(of: focusedWID) ?? groupInfo.group.activeIndex
        let nextWID = windowIDs[(currentIndex + 1) % windowIDs.count]
        guard nextWID != focusedWID else { return false }

        handleActivate(wid: nextWID, gid: groupInfo.id)
        return true
    }

    /// Dock / 状态栏 / Cmd-Tab 等外部方式激活窗口时，同步组内 active 标签
    private func observeExternalWindowFocus(now: Date = Date()) {
        guard activeDragWindowID == nil, pendingDetachWindowID == nil else { return }
        guard now.timeIntervalSince(lastFocusCheckAt) >= focusCheckInterval else { return }
        lastFocusCheckAt = now
        guard let focusedWID = focusedWindowID() else { return }
        guard focusedWID != lastObservedFocusedWindowID else { return }
        lastObservedFocusedWindowID = focusedWID
        syncActiveWindowFromExternalFocus(focusedWID: focusedWID)
    }

    private func registerWorkspaceActivationObserverIfNeeded() {
        guard workspaceActivationObserver == nil else { return }
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.processIdentifier != self.ownProcessID else { return }
            // 等待系统完成窗口前置后再读取焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.lastObservedFocusedWindowID = nil
                self.observeExternalWindowFocus()
            }
        }
    }

    private func syncActiveWindowFromExternalFocus(focusedWID: CGWindowID) {
        guard isGroupSwitchInProgress == false else { return }
        guard let groupInfo = GroupStore.shared.group(for: focusedWID),
              groupInfo.group.windowIDs.count > 1 else { return }
        guard focusedWID != groupInfo.group.activeWindowID else { return }
        handleActivate(wid: focusedWID, gid: groupInfo.id)
    }

    /// 组内切换 active 窗口
    private func handleActivate(wid: CGWindowID, gid: UUID) {
        if isGroupSwitchInProgress {
            pendingGroupSwitch = (wid, gid)
            return
        }
        performGroupSwitch(wid: wid, gid: gid)
    }

    private func completeGroupSwitch(for gid: UUID, generation: UInt64) {
        guard groupSwitchGeneration[gid] == generation else { return }
        isGroupSwitchInProgress = false
        suppressMovementDetectionForGroup(gid)
        guard let pending = pendingGroupSwitch else { return }
        pendingGroupSwitch = nil
        guard GroupStore.shared.groups[pending.gid]?.windowIDs.contains(pending.wid) == true else { return }
        performGroupSwitch(wid: pending.wid, gid: pending.gid)
    }

    private func performGroupSwitch(wid: CGWindowID, gid: UUID) {
        guard let currentGroup = GroupStore.shared.groups[gid] else { return }
        isGroupSwitchInProgress = true
        suppressMovementDetectionForGroup(gid)
        let switchGeneration = groupSwitchGeneration[gid, default: 0] &+ 1
        groupSwitchGeneration[gid] = switchGeneration
        let finishGroupSwitch = { [weak self] in
            self?.completeGroupSwitch(for: gid, generation: switchGeneration)
        }
        let currentWID = currentGroup.activeWindowID
        let currentOverlayFrame = cgFrame(wid: currentWID) ?? lastWindowFrames[gid]
        let currentAXFrame = axFrame(wid: currentWID) ?? lastKnownAXWindowFrames[currentWID]
        let targetAXFrame = currentAXFrame.map { switchTargetFrame(slotFrame: $0, for: wid) }
        let hideMode = AppSettings.hideMode

        GroupStore.shared.activate(windowID: wid, in: gid)

        guard let group = GroupStore.shared.groups[gid] else {
            finishGroupSwitch()
            return
        }
        updateTabBarView(gid: gid, group: group)
        let prevWIDs = group.windowIDs.filter { $0 != wid }
        let slotBasedSwitch = hideMode != .transparent

        if hideMode == .transparent {
            WindowAlphaController.shared.setAlpha(0, for: wid)
        } else if slotBasedSwitch {
            if let targetAXFrame {
                revealIncomingWindowForSwitch(wid: wid, slotFrame: targetAXFrame)
            } else {
                restoreWindow(wid)
            }
            activateFrontmostWindow(wid)
            hideWindowsForSwitch(prevWIDs)
        } else {
            restoreWindow(wid)
        }
        if let targetAXFrame {
            lastKnownAXWindowFrames[wid] = targetAXFrame

            let finishSwitch = { [weak self] in
                guard let self else { return }
                guard self.groupSwitchGeneration[gid] == switchGeneration else { return }
                self.activateFrontmostWindow(wid)
                finishGroupSwitch()
            }

            finishSwitch()
        } else {
            activateFrontmostWindow(wid)
            if slotBasedSwitch == false {
                hideWindowsForSwitch(prevWIDs)
            }
            finishGroupSwitch()
        }
        let targetOverlayFrame = targetAXFrame.map(cgStyleFrame(fromAXFrame:)) ?? currentOverlayFrame
        if let targetOverlayFrame {
            lastWindowFrames[gid] = targetOverlayFrame
            lastKnownWindowFrames[wid] = targetOverlayFrame
        }
    }

    /// 拖到窗口主体：按鼠标落点命中目标窗口
    private func handleDragEndedOutsideTabBar(srcWID: CGWindowID, screenPoint: NSPoint) {
        finishHighlightedDropIfNeeded(srcWID: srcWID, screenPoint: screenPoint)
    }

    private var isLeftMouseButtonReleased: Bool {
        NSEvent.pressedMouseButtons & 1 == 0
    }

    private func finishDragIfMouseReleased() {
        guard isLeftMouseButtonReleased else { return }
        finishActiveDrag()
    }

    private func finishActiveDrag() {
        guard let srcWID = activeDragWindowID else { return }
        finishHighlightedDropIfNeeded(srcWID: srcWID, screenPoint: lastDragScreenPoint ?? NSEvent.mouseLocation)
    }

    private func finishHighlightedDropIfNeeded(srcWID: CGWindowID, screenPoint: NSPoint) {
        defer {
            cancelPendingDetach()
            clearDropHighlight()
            activeDragWindowID = nil
            lastDragScreenPoint = nil
        }
        guard completedDragWindowID != srcWID,
              let sourceGroup = GroupStore.shared.group(for: srcWID) else { return }

        let target = highlightedDropTarget(sourceGroupID: sourceGroup.id, sourceWID: srcWID)
            ?? dropTarget(srcWID: srcWID,
                          sourceGroupID: sourceGroup.id,
                          sourceActiveWID: sourceGroup.group.activeWindowID,
                          screenPoint: screenPoint)
        guard let target else { return }

        _ = handleDrop(srcWID: srcWID, targetGID: target.groupID)
    }

    private func dropHighlightedWindow(srcWID: CGWindowID, targetWindowID: CGWindowID) -> Bool {
        guard completedDragWindowID != srcWID,
              let sourceGroup = GroupStore.shared.group(for: srcWID),
              let targetGID = GroupStore.shared.groupID(for: targetWindowID),
              targetGID != sourceGroup.id,
              canMergeWindows(source: srcWID, target: targetWindowID) else {
            clearDragState()
            return false
        }

        let didDrop = handleDrop(srcWID: srcWID, targetGID: targetGID)
        activeDragWindowID = nil
        lastDragScreenPoint = nil
        return didDrop
    }

    /// 拖拽合并：srcWID 所在的组 → targetGID
    private func handleDrop(srcWID: CGWindowID, targetGID: UUID) -> Bool {
        cancelPendingDetach()
        clearDropHighlight()
        defer { completedDragWindowID = srcWID }
        guard let targetGroup = GroupStore.shared.groups[targetGID] else { return false }
        let targetWID = targetGroup.activeWindowID
        return performMerge(sourceWID: srcWID, targetGID: targetGID, targetWID: targetWID, activateSource: true)
    }

    private func sameApp(_ lhs: CGWindowID, _ rhs: CGWindowID) -> Bool {
        guard let lhsPID = windowPID(lhs), let rhsPID = windowPID(rhs) else { return false }
        return lhsPID == rhsPID
    }

    private func canMergeWindows(source: CGWindowID, target: CGWindowID) -> Bool {
        AppSettings.allowCrossAppGrouping || sameApp(source, target)
    }

    /// 若该应用已有窗口在分组中，把新窗口自动并入该组并切换到新窗口。
    private func autoGroupSameAppWindowIfNeeded(_ wid: CGWindowID) {
        guard let pid = windowPID(wid),
              let sourceGID = GroupStore.shared.groupID(for: wid) else { return }

        let bundleIdentifier = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        guard AppSettings.shouldAutoGroup(bundleIdentifier: bundleIdentifier) else { return }

        var bestTarget: (windowID: CGWindowID, groupID: UUID, groupSize: Int)?

        for (existingWID, existingGID) in GroupStore.shared.windowToGroup where existingWID != wid {
            guard existingGID != sourceGID,
                  windowPID(existingWID) == pid,
                  let targetGroup = GroupStore.shared.groups[existingGID] else { continue }

            let candidate = (
                windowID: targetGroup.activeWindowID,
                groupID: existingGID,
                groupSize: targetGroup.windowIDs.count
            )
            if bestTarget == nil || candidate.groupSize > bestTarget!.groupSize {
                bestTarget = candidate
            }
        }

        guard let bestTarget else { return }

        _ = performMerge(
            sourceWID: wid,
            targetGID: bestTarget.groupID,
            targetWID: bestTarget.windowID,
            activateSource: true
        )
    }

    @discardableResult
    private func performMerge(
        sourceWID: CGWindowID,
        targetGID: UUID,
        targetWID: CGWindowID,
        activateSource: Bool
    ) -> Bool {
        guard sourceWID != targetWID else { return false }
        guard canMergeWindows(source: sourceWID, target: targetWID) else { return false }

        if activateSource {
            isGroupSwitchInProgress = true
        }
        defer {
            if activateSource {
                isGroupSwitchInProgress = false
            }
        }

        let targetOverlayFrame = cgFrame(wid: targetWID) ?? lastWindowFrames[targetGID]
        let targetSlotAXFrame = (axFrame(wid: targetWID) ?? lastKnownAXWindowFrames[targetWID])
            .map { switchTargetFrame(slotFrame: $0, for: sourceWID) }
        if let targetSlotAXFrame {
            setWindowFrame(wid: sourceWID, frame: targetSlotAXFrame)
        }

        guard let mergedGID = GroupStore.shared.merge(sourceWindowID: sourceWID, intoGroupOf: targetWID),
              let mergedGroup = GroupStore.shared.groups[mergedGID] else { return false }

        if let targetOverlayFrame {
            lastWindowFrames[mergedGID] = targetOverlayFrame
            lastKnownWindowFrames[sourceWID] = targetOverlayFrame
        }
        if let targetSlotAXFrame {
            lastKnownAXWindowFrames[sourceWID] = targetSlotAXFrame
        }

        if AppSettings.hideMode == .transparent {
            WindowAlphaController.shared.setAlpha(0, for: sourceWID)
        } else {
            if let targetSlotAXFrame {
                revealIncomingWindowForSwitch(wid: sourceWID, slotFrame: targetSlotAXFrame)
            } else {
                restoreWindow(sourceWID)
            }
            activateFrontmostWindow(sourceWID)
            hideWindowsForSwitch(mergedGroup.windowIDs.filter { $0 != sourceWID })
        }

        updateTabBarView(gid: mergedGID, group: GroupStore.shared.groups[mergedGID] ?? mergedGroup)
        return true
    }

    private func requestKeyboardMonitoringPermissionIfNeeded() {
        guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted else { return }
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    private func startShortcutEventTap() {
        guard shortcutEventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<WindowOverlayManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleShortcutEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else { return }

        guard let eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return
        }

        shortcutEventTap = eventTap
        shortcutEventSource = eventSource
        CFRunLoopAddSource(CFRunLoopGetMain(), eventSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func stopShortcutEventTap() {
        if let shortcutEventSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), shortcutEventSource, .commonModes)
        }
        if let shortcutEventTap {
            CGEvent.tapEnable(tap: shortcutEventTap, enable: false)
            CFMachPortInvalidate(shortcutEventTap)
        }
        shortcutEventSource = nil
        shortcutEventTap = nil
    }

    private func handleShortcutEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let shortcutEventTap {
                CGEvent.tapEnable(tap: shortcutEventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            if type == .leftMouseUp {
                finishActiveDrag()
            }
            return Unmanaged.passUnretained(event)
        }

        guard AppSettings.tabSwitchShortcut.matches(event) else {
            return Unmanaged.passUnretained(event)
        }

        return activateNextTabFromFocusedWindow() ? nil : Unmanaged.passUnretained(event)
    }

    private func focusedWindowID() -> CGWindowID? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontmostApplication.processIdentifier
        guard pid != ownProcessID else { return nil }

        let app = AXUIElementCreateApplication(pid)
        var focusedWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
           let focusedWindowRef {
            return axWindowID(focusedWindowRef as! AXUIElement)
        }

        return frontmostWindowID(for: pid)
    }

    private func frontmostWindowID(for pid: pid_t) -> CGWindowID? {
        guard let list = allWindowList(forceRefresh: false) else { return nil }

        let stageManagerBlockingOverlayBounds = stageManagerBlockingOverlayBounds(in: list)
        for info in list {
            guard isOwnProcessWindow(info) == false else { continue }
            guard isIgnoredSystemWindow(info) == false else { continue }
            guard isStageManagerThumbnail(info, matching: stageManagerBlockingOverlayBounds) == false else { continue }
            guard windowListEntryIsOnScreen(info) else { continue }
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid else { continue }
            guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            return wid
        }
        return nil
    }

    // MARK: - Accessibility 操作

    private func requestAccessibilityPermissionIfNeeded() {
        guard AXIsProcessTrusted() == false else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func windowPID(_ wid: CGWindowID) -> pid_t? {
        if let pid = windowPIDCache[wid] ?? lastKnownWindowPIDs[wid], pid != ownProcessID { return pid }
        guard let list = allWindowList(forceRefresh: false) else { return nil }
        for info in list {
            guard isOwnProcessWindow(info) == false else { continue }
            guard isIgnoredSystemWindow(info) == false else { continue }
            guard let w = info[kCGWindowNumber as String] as? CGWindowID, w == wid else { continue }
            let pid = info[kCGWindowOwnerPID as String] as? pid_t
            if let pid {
                windowPIDCache[wid] = pid
                lastKnownWindowPIDs[wid] = pid
            }
            return pid
        }
        return nil
    }

    private func rememberOriginalFrameIfNeeded(for wid: CGWindowID, preferCurrent: Bool = false) -> NSRect? {
        if preferCurrent == false, let frame = hiddenOriginalAXFrames[wid] {
            return frame
        }
        guard let frame = axFrame(wid: wid) ?? lastKnownAXWindowFrames[wid] else { return nil }
        hiddenOriginalAXFrames[wid] = frame
        return frame
    }

    private func beginOffscreenMove(for wid: CGWindowID) -> UInt64 {
        let generation = offscreenMoveGeneration[wid, default: 0] &+ 1
        offscreenMoveGeneration[wid] = generation
        return generation
    }

    private func invalidateOffscreenMove(for wid: CGWindowID) {
        offscreenMoveGeneration[wid, default: 0] &+= 1
    }

    /// 从屏外恢复到槽位时，先落位再显示，避免窗口穿越屏幕
    private func shouldDeferAlphaOnSlotRestore(for wid: CGWindowID, slotFrame: NSRect?) -> Bool {
        guard slotFrame != nil, hiddenWindowIDs.contains(wid) else { return false }
        switch AppSettings.hideMode {
        case .moveOffscreen, .moveToSpace:
            return true
        default:
            return false
        }
    }

    /// 窗口仍应处于隐藏态时才继续屏外补刀，避免快速切换后误伤已恢复的前台窗口
    private func shouldKeepWindowOffscreen(_ wid: CGWindowID) -> Bool {
        guard hiddenWindowIDs.contains(wid) else { return false }
        if let groupInfo = GroupStore.shared.group(for: wid),
           groupInfo.group.activeWindowID == wid {
            return false
        }
        return true
    }

    private func offscreenFrame(from frame: NSRect) -> NSRect {
        let screensFrame = unionScreenFrame()
        let horizontalGap: CGFloat = max(3_000, frame.width * 2)
        let verticalGap: CGFloat = max(3_000, frame.height * 2)
        let offscreenY = max(screensFrame.maxY + frame.height + verticalGap, 30_000)
        return NSRect(
            x: screensFrame.minX - frame.width - horizontalGap,
            y: offscreenY,
            width: frame.width,
            height: frame.height
        )
    }

    private func unionScreenFrame() -> NSRect {
        NSScreen.screens.map(\.frame).reduce(NSScreen.main?.frame ?? .zero) { partialResult, frame in
            partialResult.union(frame)
        }
    }

    private func intersectsAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    private func restoreFrameInsideScreen(from frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main ?? NSScreen.screens.first
        let safeFrame = screen?.visibleFrame ?? screen?.frame ?? NSRect(x: 80, y: 80, width: 1200, height: 800)
        let width = min(max(frame.width, minLabelWindowWidth), max(safeFrame.width - 40, minLabelWindowWidth))
        let height = min(max(frame.height, minLabelWindowHeight), max(safeFrame.height - 40, minLabelWindowHeight))
        let x = min(max(safeFrame.midX - width / 2, safeFrame.minX + 20), safeFrame.maxX - width - 20)
        let y = min(max(safeFrame.midY - height / 2, safeFrame.minY + 20), safeFrame.maxY - height - 20)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func axStyleFrame(fromCGFrame frame: NSRect) -> NSRect {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: frame.minX, y: screenHeight - frame.minY - frame.height, width: frame.width, height: frame.height)
    }

    private func offscreenCGFrame(fromAXFrame frame: NSRect) -> NSRect {
        cgStyleFrame(fromAXFrame: frame)
    }

    private func shrinkFrame(from frame: NSRect) -> NSRect {
        NSRect(x: frame.minX, y: frame.minY, width: 1, height: 1)
    }

    private func setWindowFrame(wid: CGWindowID, frame: NSRect) {
        setWindowSize(wid: wid, size: frame.size)
        setWindowPosition(wid: wid, origin: frame.origin)
        lastKnownAXWindowFrames[wid] = frame
    }

    private func setWindowSize(wid: CGWindowID, size: NSSize) {
        guard let pid = windowPID(wid),
              let win = axWindow(pid: pid, wid: wid) else { return }
        var mutableSize = size
        if let value = AXValueCreate(.cgSize, &mutableSize) {
            AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, value)
        }
    }

    private func setWindowPosition(wid: CGWindowID, origin: NSPoint) {
        guard let pid = windowPID(wid),
              let win = axWindow(pid: pid, wid: wid) else { return }
        var mutableOrigin = origin
        if let value = AXValueCreate(.cgPoint, &mutableOrigin) {
            AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, value)
        }
    }

    /// 组内切换：不可见状态下先缩放到槽位大小并贴位，再显示；避免用户看到窗口缩放或穿越屏幕
    private func applyWindowFrameWhileHidden(wid: CGWindowID, frame: NSRect) {
        setWindowSize(wid: wid, size: frame.size)
        setWindowPosition(wid: wid, origin: frame.origin)
        setWindowSize(wid: wid, size: frame.size)
        lastKnownAXWindowFrames[wid] = frame
    }

    @discardableResult
    private func revealIncomingWindowForSwitch(wid: CGWindowID, slotFrame: NSRect) -> Bool {
        invalidateOffscreenMove(for: wid)

        let needsSpaceRestore = hiddenOriginalSpaceIDs[wid] != nil
        let spaceRestored = restoreWindowToCurrentSpaceIfNeeded(wid)
        guard needsSpaceRestore == false || spaceRestored else { return false }

        WindowAlphaController.shared.setAlpha(0, for: wid)
        WindowTransformController.shared.resetTransform(for: wid)
        _ = hiddenOriginalAXFrames.removeValue(forKey: wid)

        applyWindowFrameWhileHidden(wid: wid, frame: slotFrame)

        var unminimized = false
        if let pid = windowPID(wid),
           let win = axWindow(pid: pid, wid: wid) {
            unminimized = AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef) == .success
        }

        let revealed = WindowAlphaController.shared.setAlpha(1, for: wid)
        hiddenWindowIDs.remove(wid)
        return revealed || unminimized
    }

    private func hideWindowsForSwitch(_ windowIDs: [CGWindowID]) {
        for wid in windowIDs {
            minimizeWindow(wid)
        }
    }

    private func axWindow(pid: pid_t, wid: CGWindowID) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return nil }

        return windows.first { win in
            axWindowID(win) == wid
        }
    }

    private func axWindowID(_ win: AXUIElement) -> CGWindowID? {
        var wid = CGWindowID(0)
        let error = _AXUIElementGetWindow(win, &wid)
        guard error == .success, wid != 0 else { return nil }
        return wid
    }

    private func axFrame(wid: CGWindowID) -> NSRect? {
        guard let pid = windowPID(wid) else { return lastKnownAXWindowFrames[wid] }
        guard let frame = axFrame(pid: pid, wid: wid) else { return lastKnownAXWindowFrames[wid] }
        lastKnownAXWindowFrames[wid] = frame
        return frame
    }

    private func axFrame(pid: pid_t, wid: CGWindowID) -> NSRect? {
        axWindow(pid: pid, wid: wid).flatMap { axGetFrame($0) }
    }

    private func axGetFrame(_ win: AXUIElement) -> NSRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return NSRect(origin: origin, size: size)
    }

    private func moveWindowFullyOffscreen(_ wid: CGWindowID, from frame: NSRect) {
        let generation = beginOffscreenMove(for: wid)
        let targetFrame = offscreenFrame(from: frame)
        setWindowFrame(wid: wid, frame: targetFrame)
        let targetCGFrame = offscreenCGFrame(fromAXFrame: targetFrame)
        lastKnownWindowFrames[wid] = targetCGFrame

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.ensureWindowFullyOffscreen(
                wid,
                targetAXFrame: targetFrame,
                targetCGFrame: targetCGFrame,
                generation: generation
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.ensureWindowFullyOffscreen(
                wid,
                targetAXFrame: targetFrame,
                targetCGFrame: targetCGFrame,
                generation: generation
            )
        }
    }

    private func ensureWindowFullyOffscreen(
        _ wid: CGWindowID,
        targetAXFrame: NSRect,
        targetCGFrame: NSRect,
        generation: UInt64
    ) {
        guard offscreenMoveGeneration[wid] == generation else { return }
        guard shouldKeepWindowOffscreen(wid) else { return }

        let currentFrame = cgFrame(wid: wid) ?? targetCGFrame
        guard intersectsAnyScreen(currentFrame) else { return }

        setWindowFrame(wid: wid, frame: targetAXFrame)
        lastKnownWindowFrames[wid] = targetCGFrame

        let verifiedFrame = cgFrame(wid: wid) ?? targetCGFrame
        if intersectsAnyScreen(verifiedFrame), shouldKeepWindowOffscreen(wid) {
            WindowAlphaController.shared.setAlpha(0, for: wid)
        }
    }

    private func moveWindowToHidingSpace(_ wid: CGWindowID) -> Bool {
        let spaceController = WindowSpaceController.shared
        guard let originalSpaceID = spaceController.activeSpaceID(),
              let hidingSpaceID = spaceController.hidingSpaceID(),
              hidingSpaceID != originalSpaceID else { return false }
        guard spaceController.moveWindow(wid, to: hidingSpaceID) else { return false }
        hiddenOriginalSpaceIDs[wid] = originalSpaceID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.hiddenOriginalSpaceIDs[wid] != nil else { return }
            guard self.isWindowOnScreen(wid) else { return }
            guard let frame = self.hiddenOriginalAXFrames[wid] ?? self.axFrame(wid: wid) ?? self.lastKnownAXWindowFrames[wid] else { return }
            self.moveWindowFullyOffscreen(wid, from: frame)
            self.hiddenOriginalSpaceIDs.removeValue(forKey: wid)
        }

        return true
    }

    private func restoreWindowToCurrentSpaceIfNeeded(_ wid: CGWindowID) -> Bool {
        guard hiddenOriginalSpaceIDs[wid] != nil else { return false }
        guard let currentSpaceID = WindowSpaceController.shared.activeSpaceID() else { return false }
        guard WindowSpaceController.shared.moveWindow(wid, to: currentSpaceID) else { return false }
        hiddenOriginalSpaceIDs.removeValue(forKey: wid)
        return true
    }

    /// 隐藏目标窗口：按设置选择隐藏策略
    @discardableResult
    private func minimizeWindow(_ wid: CGWindowID) -> Bool {
        switch AppSettings.hideMode {
        case .transparent:
            guard WindowAlphaController.shared.setAlpha(0, for: wid) else { return false }
            hiddenWindowIDs.insert(wid)
            return true
        case .moveOffscreen:
            WindowAlphaController.shared.setAlpha(0, for: wid)
            guard let frame = rememberOriginalFrameIfNeeded(for: wid, preferCurrent: true) else { return false }
            moveWindowFullyOffscreen(wid, from: frame)
            hiddenWindowIDs.insert(wid)
            return true
        case .minimize:
            guard let pid = windowPID(wid),
                  let win = axWindow(pid: pid, wid: wid) else { return false }
            let error = AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
            guard error == .success else { return false }
            _ = rememberOriginalFrameIfNeeded(for: wid)
            hiddenWindowIDs.insert(wid)
            return true
        case .moveToSpace:
            _ = rememberOriginalFrameIfNeeded(for: wid)
            if moveWindowToHidingSpace(wid) {
                hiddenWindowIDs.insert(wid)
                return true
            }
            guard let frame = rememberOriginalFrameIfNeeded(for: wid) else { return false }
            moveWindowFullyOffscreen(wid, from: frame)
            hiddenWindowIDs.insert(wid)
            return true
        case .shrink:
            guard let frame = rememberOriginalFrameIfNeeded(for: wid) else { return false }
            setWindowFrame(wid: wid, frame: shrinkFrame(from: frame))
            hiddenWindowIDs.insert(wid)
            return true
        }
    }

    @discardableResult
    private func restoreWindow(_ wid: CGWindowID, toSlotFrame slotFrame: NSRect? = nil) -> Bool {
        invalidateOffscreenMove(for: wid)
        let needsSpaceRestore = hiddenOriginalSpaceIDs[wid] != nil
        let deferAlphaRestore = shouldDeferAlphaOnSlotRestore(for: wid, slotFrame: slotFrame)
        if deferAlphaRestore {
            WindowAlphaController.shared.setAlpha(0, for: wid)
        }
        let transformRestored = WindowTransformController.shared.resetTransform(for: wid)
        let alphaRestored = deferAlphaRestore
            ? false
            : WindowAlphaController.shared.setAlpha(1, for: wid)
        let spaceRestored = restoreWindowToCurrentSpaceIfNeeded(wid)
        guard needsSpaceRestore == false || spaceRestored else { return false }

        var minimizedRestored = false
        var frameRestored = false

        let cachedFrame = hiddenOriginalAXFrames.removeValue(forKey: wid)
        if let slotFrame {
            // 组内切换：直接落到当前槽位，避免先闪到过期缓存坐标
            setWindowFrame(wid: wid, frame: slotFrame)
            frameRestored = true
        } else if let cachedFrame {
            setWindowFrame(wid: wid, frame: cachedFrame)
            frameRestored = true
        }

        if let pid = windowPID(wid),
           let win = axWindow(pid: pid, wid: wid) {
            minimizedRestored = AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef) == .success
        }

        let deferredAlphaRestored = deferAlphaRestore && WindowAlphaController.shared.setAlpha(1, for: wid)
        guard alphaRestored || deferredAlphaRestored || transformRestored || spaceRestored || minimizedRestored || frameRestored else { return false }
        hiddenWindowIDs.remove(wid)
        return true
    }

    /// 激活并前置某窗口
    private func activateFrontmostWindow(_ wid: CGWindowID) {
        let needsSpaceRestore = hiddenOriginalSpaceIDs[wid] != nil
        let spaceRestored = restoreWindowToCurrentSpaceIfNeeded(wid)
        WindowAlphaController.shared.setAlpha(1, for: wid)

        guard let pid = windowPID(wid) else { return }
        let app = NSRunningApplication(processIdentifier: pid)
        app?.activate(options: .activateIgnoringOtherApps)

        if let win = axWindow(pid: pid, wid: wid) {
            if AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef) == .success,
               needsSpaceRestore == false || spaceRestored {
                hiddenWindowIDs.remove(wid)
            }
            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        }
    }

    private func windowID(at screenPoint: NSPoint, excluding excluded: Set<CGWindowID>) -> CGWindowID? {
        let screenHeight = cachedScreenHeight > 0
            ? cachedScreenHeight
            : (NSScreen.screens.first?.frame.height ?? 0)
        guard let list = allWindowList(forceRefresh: false),
              screenHeight > 0 else { return nil }

        let stageManagerBlockingOverlayBounds = stageManagerBlockingOverlayBounds(in: list)

        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard isOwnProcessWindow(info) == false else { continue }
            guard isIgnoredSystemWindow(info) == false else { continue }
            guard windowListEntryIsOnScreen(info) else { continue }
            guard isStageManagerThumbnail(info, matching: stageManagerBlockingOverlayBounds) == false else { continue }
            guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }

            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            guard width >= minLabelWindowWidth && height >= minLabelWindowHeight else { continue }
            guard isWindowMinimizedCached(wid) == false else { continue }

            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let frame = NSRect(x: x, y: screenHeight - y - height, width: width, height: height)
            guard frame.contains(screenPoint) else { continue }

            if excluded.contains(wid) {
                return nil
            }
            return wid
        }
        return nil
    }

    private func isWindowOnScreen(_ wid: CGWindowID) -> Bool {
        guard let list = allWindowList(forceRefresh: false) else { return false }

        let stageManagerBlockingOverlayBounds = stageManagerBlockingOverlayBounds(in: list)

        return list.contains { info in
            guard isOwnProcessWindow(info) == false else { return false }
            guard isIgnoredSystemWindow(info) == false else { return false }
            guard windowListEntryIsOnScreen(info) else { return false }
            guard isStageManagerThumbnail(info, matching: stageManagerBlockingOverlayBounds) == false else { return false }
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID else { return false }
            guard windowID == wid else { return false }
            return isWindowMinimizedCached(wid) == false
        }
    }

    private func cgFrame(wid: CGWindowID) -> NSRect? {
        let screenHeight = cachedScreenHeight > 0
            ? cachedScreenHeight
            : (NSScreen.screens.first?.frame.height ?? 0)
        guard let list = allWindowList(forceRefresh: false),
              screenHeight > 0 else { return lastKnownWindowFrames[wid] }
        for info in list {
            guard isOwnProcessWindow(info) == false else { continue }
            guard isIgnoredSystemWindow(info) == false else { continue }
            guard let w = info[kCGWindowNumber as String] as? CGWindowID, w == wid else { continue }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let x = bounds["X"] ?? 0, y = bounds["Y"] ?? 0
            let width = bounds["Width"] ?? 0, height = bounds["Height"] ?? 0
            let frame = NSRect(x: x, y: screenHeight - y - height, width: width, height: height)
            let axFrame = NSRect(x: x, y: y, width: width, height: height)
            lastKnownWindowFrames[wid] = frame
            lastKnownAXWindowFrames[wid] = axFrame
            return frame
        }
        return lastKnownWindowFrames[wid]
    }
}