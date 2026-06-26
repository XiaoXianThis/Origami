import AppKit
import SwiftUI

// MARK: - 拖拽类型标识

let tabDragType = NSPasteboard.PasteboardType("com.origami.tabdrag")

struct TabDragPayload {
    let windowID: CGWindowID
    let groupID: UUID

    init(windowID: CGWindowID, groupID: UUID) {
        self.windowID = windowID
        self.groupID = groupID
    }

    init?(string: String) {
        let parts = string.split(separator: "|")
        guard parts.count == 2,
              let windowIDValue = UInt32(parts[0]),
              let groupID = UUID(uuidString: String(parts[1])) else { return nil }
        self.windowID = CGWindowID(windowIDValue)
        self.groupID = groupID
    }

    var stringValue: String {
        "\(windowID)|\(groupID.uuidString)"
    }
}

// MARK: - 数据模型（传给 View）

struct TabBarModel: Equatable {
    var groupID: UUID
    var windowIDs: [CGWindowID]
    var activeIndex: Int
    var titles: [CGWindowID: String]
}

struct TabBarColors {
    let activeBackground: NSColor
    let inactiveBackground: NSColor
    let border: NSColor
    let activeText: NSColor
    let inactiveText: NSColor

    static func colors(isDark: Bool) -> TabBarColors {
        if isDark {
            TabBarColors(
                activeBackground: NSColor(calibratedWhite: 0.38, alpha: 1),
                inactiveBackground: NSColor(calibratedWhite: 0.22, alpha: 1),
                border: NSColor.white.withAlphaComponent(0.12),
                activeText: NSColor.white,
                inactiveText: NSColor(calibratedWhite: 0.72, alpha: 1)
            )
        } else {
            TabBarColors(
                activeBackground: NSColor.white,
                inactiveBackground: NSColor(calibratedWhite: 0.88, alpha: 1),
                border: NSColor.black.withAlphaComponent(0.08),
                activeText: NSColor.labelColor,
                inactiveText: NSColor.secondaryLabelColor
            )
        }
    }
}

struct TabBarLayout {
    static let tabGap: CGFloat = 4
    static let tabHorizontalPadding: CGFloat = 20
    static let tabHeight: CGFloat = 22
    static let barHeight: CGFloat = 26
    static let tabFont = NSFont.systemFont(ofSize: 12, weight: .medium)

    static func tabMinWidth() -> CGFloat {
        CGFloat(AppSettings.defaultTabMinWidth)
    }

    static func labelMaxWidth() -> CGFloat {
        CGFloat(AppSettings.labelMaxWidth)
    }

    static func tabWidth(for title: String, maxWidth: CGFloat = labelMaxWidth()) -> CGFloat {
        let font = tabFont
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let contentWidth = textWidth + tabHorizontalPadding
        return max(tabMinWidth(), min(contentWidth, maxWidth))
    }

    static func barWidth(for titles: [String], maxTabWidth: CGFloat = labelMaxWidth()) -> CGFloat {
        let tabTotal = titles.reduce(CGFloat(0)) { partialResult, title in
            partialResult + tabWidth(for: title, maxWidth: maxTabWidth)
        }
        let gapTotal = CGFloat(max(titles.count - 1, 0)) * tabGap
        return tabTotal + gapTotal
    }
}

// MARK: - NSView 实现（支持跨 panel 拖拽）

final class TabBarNSView: NSView {
    var model: TabBarModel {
        didSet {
            if oldValue.windowIDs != model.windowIDs {
                rebuildTrackingAreas()
            }
            if oldValue != model {
                needsDisplay = true
            }
        }
    }

    /// 当用户点击某个标签时的回调
    var onActivate: ((CGWindowID) -> Void)?
    /// 当拖拽完成时的回调（source windowID, target 命中的 groupID）
    var onDrop: ((CGWindowID, UUID) -> Void)?
    /// 拖拽结束但没有命中标签栏时的回调（source windowID, screen point）
    var onDragEndedOutsideTabBar: ((CGWindowID, NSPoint) -> Void)?
    /// 拖拽过程中的回调（source windowID, screen point）
    var onDragMoved: ((CGWindowID, NSPoint) -> Void)?
    /// 拖拽结束后的统一清理回调（source windowID）
    var onDragFinished: ((CGWindowID) -> Void)?

    private var mouseDownPoint: NSPoint?
    private var pendingDragWindowID: CGWindowID?
    private var isDraggingTab = false

    private var tabRects: [CGWindowID: NSRect] = [:]
    private var myTrackingAreas: [NSTrackingArea] = []
    private var cachedColors: (isDark: Bool, colors: TabBarColors)?

    init(model: TabBarModel) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        layer?.isOpaque = false
        registerForDraggedTypes([tabDragType])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        cachedColors = nil
        needsDisplay = true
    }

    private func currentColors() -> TabBarColors {
        let isDark = AppSettings.isDarkMode(for: effectiveAppearance)
        if let cached = cachedColors, cached.isDark == isDark { return cached.colors }
        let colors = TabBarColors.colors(isDark: isDark)
        cachedColors = (isDark, colors)
        return colors
    }

    // MARK: - Layout helpers

    private func buildTabRects() -> [CGWindowID: NSRect] {
        var rects: [CGWindowID: NSRect] = [:]
        var x: CGFloat = 0
        for wid in model.windowIDs {
            let title = model.titles[wid] ?? "窗口"
            let width = TabBarLayout.tabWidth(for: title)
            rects[wid] = NSRect(x: x, y: 0, width: width, height: TabBarLayout.tabHeight)
            x += width + TabBarLayout.tabGap
        }
        return rects
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        tabRects = buildTabRects()

        for wid in model.windowIDs {
            guard let rect = tabRects[wid] else { continue }
            let isActive = wid == model.windowIDs[safe: model.activeIndex]
            let title = model.titles[wid] ?? "窗口"

            let colors = currentColors()
            let bg = isActive ? colors.activeBackground : colors.inactiveBackground
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 1), xRadius: 7, yRadius: 7)
            bg.setFill()
            path.fill()

            colors.border.setStroke()
            path.lineWidth = 0.5
            path.stroke()

            // 文字
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.lineBreakMode = .byTruncatingTail
            let attr: [NSAttributedString.Key: Any] = [
                .font: TabBarLayout.tabFont,
                .foregroundColor: isActive ? colors.activeText : colors.inactiveText,
                .paragraphStyle: para
            ]
            let textInset = TabBarLayout.tabHorizontalPadding / 2
            let textRect = rect.insetBy(dx: textInset, dy: 3)
            (title as NSString).draw(in: textRect, withAttributes: attr)
        }
    }

    // MARK: - Mouse: click → activate

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        mouseDownPoint = pt
        pendingDragWindowID = tabRects.first { _, rect in rect.contains(pt) }?.key
        isDraggingTab = false
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            pendingDragWindowID = nil
            isDraggingTab = false
        }
        guard !isDraggingTab,
              let wid = pendingDragWindowID else { return }
        if let index = model.windowIDs.firstIndex(of: wid), index != model.activeIndex {
            model.activeIndex = index
        }
        onActivate?(wid)
    }

    // MARK: - Mouse: drag start

    override func mouseDragged(with event: NSEvent) {
        guard !isDraggingTab,
              let wid = pendingDragWindowID,
              let startPoint = mouseDownPoint else { return }

        let pt = convert(event.locationInWindow, from: nil)
        let dx = pt.x - startPoint.x
        let dy = pt.y - startPoint.y
        guard hypot(dx, dy) >= 4 else { return }
        isDraggingTab = true

        let payload = TabDragPayload(windowID: wid, groupID: model.groupID)
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(payload.stringValue, forType: tabDragType)

        // 拖拽图像：当前标签快照
        let tabRect = tabRects[wid] ?? NSRect(x: pt.x - 30, y: 0, width: 60, height: TabBarLayout.tabHeight)
        let img = NSImage(size: tabRect.size)
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.translateBy(x: -tabRect.origin.x, y: -tabRect.origin.y)
            draw(tabRect)
        }
        img.unlockFocus()

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(tabRect, contents: img)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: - Tracking areas（用于 hover，可扩展）

    private func rebuildTrackingAreas() {
        for ta in myTrackingAreas { removeTrackingArea(ta) }
        myTrackingAreas.removeAll()
        let ta = NSTrackingArea(rect: bounds,
                                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
                                owner: self, userInfo: nil)
        addTrackingArea(ta)
        myTrackingAreas = [ta]
    }
}

// MARK: - NSDraggingSource

extension TabBarNSView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard let wid = pendingDragWindowID else { return }
        onDragMoved?(wid, screenPoint)
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        let wid = pendingDragWindowID
        defer {
            if let wid { onDragFinished?(wid) }
            mouseDownPoint = nil
            pendingDragWindowID = nil
            isDraggingTab = false
        }
        guard let wid else { return }
        onDragEndedOutsideTabBar?(wid, screenPoint)
    }
}

// MARK: - NSDraggingDestination

extension TabBarNSView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let str = sender.draggingPasteboard.string(forType: tabDragType),
              let payload = TabDragPayload(string: str),
              payload.groupID != model.groupID else { return [] }
        return .move
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let str = sender.draggingPasteboard.string(forType: tabDragType),
              let payload = TabDragPayload(string: str),
              payload.groupID != model.groupID else { return false }

        onDrop?(payload.windowID, model.groupID)
        return true
    }
}

// MARK: - SwiftUI Wrapper

struct TabBarView: NSViewRepresentable {
    var model: TabBarModel
    var onActivate: (CGWindowID) -> Void
    var onDrop: (CGWindowID, UUID) -> Void
    var onDragEndedOutsideTabBar: (CGWindowID, NSPoint) -> Void
    var onDragMoved: (CGWindowID, NSPoint) -> Void
    var onDragFinished: (CGWindowID) -> Void

    func makeNSView(context: Context) -> TabBarNSView {
        let v = TabBarNSView(model: model)
        v.onActivate = onActivate
        v.onDrop = onDrop
        v.onDragEndedOutsideTabBar = onDragEndedOutsideTabBar
        v.onDragMoved = onDragMoved
        v.onDragFinished = onDragFinished
        return v
    }

    func updateNSView(_ nsView: TabBarNSView, context: Context) {
        if nsView.model != model {
            nsView.model = model
        }
        nsView.onActivate = onActivate
        nsView.onDrop = onDrop
        nsView.onDragEndedOutsideTabBar = onDragEndedOutsideTabBar
        nsView.onDragMoved = onDragMoved
        nsView.onDragFinished = onDragFinished
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}