import SwiftUI

struct MainView: View {
    private static let authorBilibiliURL = URL(string: "https://space.bilibili.com/12724008")!
    private static let githubProjectURL = URL(string: "https://github.com/XiaoXianThis/Origami")!
    private static let officialWebsiteURL = URL(string: "https://origami.wxian.cc/")!

    @AppStorage(AppSettings.themeKey) private var themeRawValue = AppSettings.defaultTheme.rawValue
    @AppStorage(AppSettings.hideModeKey) private var hideModeRawValue = AppSettings.hideMode.rawValue
    @AppStorage(AppSettings.detachOnDragEnabledKey) private var detachOnDragEnabled = AppSettings.detachOnDragEnabled
    @AppStorage(AppSettings.detachDelayKey) private var detachDelay = AppSettings.detachDelay
    @AppStorage(AppSettings.labelHorizontalAnchorKey) private var labelHorizontalAnchorRawValue = AppSettings.defaultLabelHorizontalAnchor.rawValue
    @AppStorage(AppSettings.labelVerticalAnchorKey) private var labelVerticalAnchorRawValue = AppSettings.defaultLabelVerticalAnchor.rawValue
    @AppStorage(AppSettings.labelPlacementKey) private var labelPlacementRawValue = AppSettings.defaultLabelPlacement.rawValue
    @AppStorage(AppSettings.labelOffsetXKey) private var labelOffsetX = AppSettings.defaultLabelOffsetX
    @AppStorage(AppSettings.labelOffsetYKey) private var labelOffsetY = AppSettings.defaultLabelOffsetY
    @AppStorage(AppSettings.labelMaxWidthKey) private var labelMaxWidth = AppSettings.defaultLabelMaxWidth
    @AppStorage(AppSettings.windowSwitchSizeModeKey) private var windowSwitchSizeModeRawValue = AppSettings.defaultWindowSwitchSizeMode.rawValue
    @AppStorage(AppSettings.restoreOnLaunchKey) private var restoreOnLaunch = AppSettings.defaultRestoreOnLaunch
    @AppStorage(AppSettings.restoreOnExitKey) private var restoreOnExit = AppSettings.defaultRestoreOnExit
    @AppStorage(AppSettings.autoGroupSameAppWindowsKey) private var autoGroupSameAppWindows = AppSettings.defaultAutoGroupSameAppWindows
    @AppStorage(AppSettings.allowCrossAppGroupingKey) private var allowCrossAppGrouping = AppSettings.defaultAllowCrossAppGrouping
    @AppStorage(AppSettings.tabSwitchShortcutKeyCodeKey) private var tabSwitchShortcutKeyCode = Int(TabSwitchShortcut.default.keyCode)
    @AppStorage(AppSettings.tabSwitchShortcutModifiersKey) private var tabSwitchShortcutModifiers = Int(bitPattern: TabSwitchShortcut.default.modifiers)

    @State private var detectedOffscreenWindows: [OffscreenWindowInfo] = []

    private var theme: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRawValue) ?? AppSettings.defaultTheme },
            set: { themeRawValue = $0.rawValue }
        )
    }

    private var preferredColorScheme: ColorScheme? {
        switch theme.wrappedValue {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    private var hideMode: Binding<WindowHideMode> {
        Binding(
            get: { WindowHideMode(rawValue: hideModeRawValue) ?? AppSettings.defaultHideMode },
            set: { hideModeRawValue = $0.rawValue }
        )
    }

    private var labelHorizontalAnchor: Binding<LabelHorizontalAnchor> {
        Binding(
            get: { LabelHorizontalAnchor(rawValue: labelHorizontalAnchorRawValue) ?? AppSettings.defaultLabelHorizontalAnchor },
            set: { labelHorizontalAnchorRawValue = $0.rawValue }
        )
    }

    private var labelVerticalAnchor: Binding<LabelVerticalAnchor> {
        Binding(
            get: { LabelVerticalAnchor(rawValue: labelVerticalAnchorRawValue) ?? AppSettings.defaultLabelVerticalAnchor },
            set: { labelVerticalAnchorRawValue = $0.rawValue }
        )
    }

    private var labelPlacement: Binding<LabelPlacement> {
        Binding(
            get: { LabelPlacement(rawValue: labelPlacementRawValue) ?? AppSettings.defaultLabelPlacement },
            set: { labelPlacementRawValue = $0.rawValue }
        )
    }

    private var windowSwitchSizeMode: Binding<WindowSwitchSizeMode> {
        Binding(
            get: { WindowSwitchSizeMode(rawValue: windowSwitchSizeModeRawValue) ?? AppSettings.defaultWindowSwitchSizeMode },
            set: { windowSwitchSizeModeRawValue = $0.rawValue }
        )
    }

    private var detachDelayBinding: Binding<Double> {
        Binding(
            get: { AppSettings.clampedDetachDelay(detachDelay) },
            set: { detachDelay = AppSettings.clampedDetachDelay($0) }
        )
    }

    private var labelOffsetXBinding: Binding<Double> {
        Binding(
            get: { AppSettings.clampedLabelOffset(labelOffsetX) },
            set: { labelOffsetX = AppSettings.clampedLabelOffset($0) }
        )
    }

    private var labelOffsetYBinding: Binding<Double> {
        Binding(
            get: { AppSettings.clampedLabelOffset(labelOffsetY) },
            set: { labelOffsetY = AppSettings.clampedLabelOffset($0) }
        )
    }

    private var labelMaxWidthBinding: Binding<Double> {
        Binding(
            get: { AppSettings.clampedLabelMaxWidth(labelMaxWidth) },
            set: { labelMaxWidth = AppSettings.clampedLabelMaxWidth($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    themeSection
                    hideModeSection
                    windowSwitchSection
                    groupingSection
                    labelPositionSection
                    detachSection
                    restoreWindowsSection
                    offscreenWindowsSection
                }
                .padding(24)
            }

            authorCreditFooter
        }
        .frame(width: 620, height: 720)
        .preferredColorScheme(preferredColorScheme)
        .onAppear(perform: refreshOffscreenWindows)
        .onChange(of: themeRawValue) { _ in
            AppDelegate.shared?.applyTheme()
            WindowOverlayManager.shared.refreshTheme()
        }
    }

    private var themeSection: some View {
        settingsSection(title: "外观主题") {
            Picker("主题", selection: theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Text("标签栏与设置窗口会同步使用所选主题；跟随系统时会随 macOS 外观自动切换。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var authorCreditFooter: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                Text(verbatim: "© \(String(Calendar.current.component(.year, from: Date()))) Origami")
                footerSeparator
                Text("作者：")
                Link("大不6仙", destination: Self.authorBilibiliURL)
                footerSeparator
                Link(destination: Self.authorBilibiliURL) {
                    Label("B站主页", systemImage: "link")
                        .labelStyle(.titleAndIcon)
                }
                footerSeparator
                Link(destination: Self.githubProjectURL) {
                    Label("GitHub", systemImage: "link")
                        .labelStyle(.titleAndIcon)
                }
                footerSeparator
                Link(destination: Self.officialWebsiteURL) {
                    Label("官方网站", systemImage: "link")
                        .labelStyle(.titleAndIcon)
                }
                footerSeparator
                Text(AppInfo.versionLabel)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var footerSeparator: some View {
        Text("·")
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 30))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text("Origami 设置")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("调整窗口分组切换、标签位置和屏外窗口恢复")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hideModeSection: some View {
        settingsSection(title: "隐藏方式") {
            Picker("隐藏方式", selection: hideMode) {
                ForEach(WindowHideMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Text(hideMode.wrappedValue.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if hideMode.wrappedValue == .transparent {
                Text("如果当前系统或目标 App 不支持透明隐藏，请切换为“最小化”。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if hideMode.wrappedValue == .moveToSpace {
                Text("需要系统里已有至少两个普通桌面；部分 App 或 macOS 版本可能禁止外部进程移动窗口，失败时会自动改用屏外隐藏。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var windowSwitchSection: some View {
        settingsSection(title: "窗口切换") {
            ShortcutRecorderView(
                keyCode: $tabSwitchShortcutKeyCode,
                modifiers: $tabSwitchShortcutModifiers
            )

            Text("在已分组窗口获得焦点时按下快捷键，可切换到组内下一个标签。需至少包含 ⌘ / ⌃ / ⌥ / ⇧ 之一，并在系统设置中授予输入监控权限。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("切换大小", selection: windowSwitchSizeMode) {
                ForEach(WindowSwitchSizeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(windowSwitchSizeMode.wrappedValue.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var groupingSection: some View {
        settingsSection(title: "窗口分组") {
            Toggle("同应用窗口自动归组（实验性）", isOn: $autoGroupSameAppWindows)

            Text(autoGroupSameAppWindows
                ? "同一应用的新窗口会自动加入该应用已有窗口所在的分组。"
                : "关闭后，同一应用的新窗口不会自动合并，需手动拖拽归组。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if autoGroupSameAppWindows {
                Text("部分窗口是子窗口或应用内部弹窗（如系统设置中的对话框），可能与主窗口自动归为一组；主窗口被隐藏时会连带隐藏子窗口。")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("允许不同应用窗口合并成组", isOn: $allowCrossAppGrouping)

            Text(allowCrossAppGrouping
                ? "可以将不同应用的窗口拖拽合并到同一分组。"
                : "关闭后，只能将同一应用的窗口合并到同一分组。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var labelPositionSection: some View {
        settingsSection(title: "标签位置") {
            Picker("水平位置", selection: labelHorizontalAnchor) {
                ForEach(LabelHorizontalAnchor.allCases) { anchor in
                    Text(anchor.title).tag(anchor)
                }
            }
            .pickerStyle(.segmented)

            Picker("垂直位置", selection: labelVerticalAnchor) {
                ForEach(LabelVerticalAnchor.allCases) { anchor in
                    Text(anchor.title).tag(anchor)
                }
            }
            .pickerStyle(.segmented)

            Picker("内外位置", selection: labelPlacement) {
                ForEach(LabelPlacement.allCases) { placement in
                    Text(placement.title).tag(placement)
                }
            }
            .pickerStyle(.segmented)

            offsetSlider(title: "水平偏移", value: labelOffsetXBinding)
            offsetSlider(title: "垂直偏移", value: labelOffsetYBinding)
            labelMaxWidthSlider

            Text("默认是窗口外、顶部居中。偏移会在当前锚点基础上继续调整。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detachSection: some View {
        settingsSection(title: "拖出分组") {
            Toggle("拖出窗口后自动移出当前组", isOn: $detachOnDragEnabled)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("等待时间")
                    Spacer()
                    Text("\(detachDelayBinding.wrappedValue, specifier: "%.1f") 秒")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: detachDelayBinding,
                    in: AppSettings.minDetachDelay...AppSettings.maxDetachDelay,
                    step: 0.1
                )
                .disabled(!detachOnDragEnabled)
            }

            Text(detachOnDragEnabled ? "标签拖出当前组窗口并停留达到等待时间后，会把对应窗口移出当前组。" : "关闭后，拖出窗口不会触发移出当前组。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var restoreWindowsSection: some View {
        settingsSection(title: "窗口复原") {
            Text("复原本工具隐藏的窗口，并将屏外、越界或缩小的窗口移回屏幕内；手动复原还会解散全部分组。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("启动时自动复原窗口位置", isOn: $restoreOnLaunch)
            Toggle("退出时自动复原窗口位置", isOn: $restoreOnExit)

            Button("复原全部窗口", action: restoreAllWindows)
                .buttonStyle(.borderedProminent)
        }
    }

    private var offscreenWindowsSection: some View {
        settingsSection(title: "屏外窗口") {
            HStack {
                Text("根据窗口真实位置检测，不依赖本软件记录。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("刷新检测", action: refreshOffscreenWindows)
            }

            if detectedOffscreenWindows.isEmpty {
                Text("当前没有检测到完全位于屏幕外的窗口。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(detectedOffscreenWindows) { window in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(window.displayTitle)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("\(window.appName) · \(window.frameDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if window.isGrouped {
                                    Text("属于 \(window.groupWindowCount) 个窗口的分组，移回后会从组中移除。")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Button("移回屏幕内") {
                                restoreOffscreenWindow(window.windowID)
                            }
                        }
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var labelMaxWidthSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("标签最大宽度")
                Spacer()
                Text("\(labelMaxWidthBinding.wrappedValue, specifier: "%.0f") px")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: labelMaxWidthBinding,
                in: AppSettings.minLabelMaxWidth...AppSettings.maxLabelMaxWidth,
                step: 1
            )
        }
    }

    private func offsetSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.0f") px")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: value,
                in: AppSettings.minLabelOffset...AppSettings.maxLabelOffset,
                step: 1
            )
        }
    }

    private func refreshOffscreenWindows() {
        detectedOffscreenWindows = WindowOverlayManager.shared.offscreenWindows()
    }

    private func restoreAllWindows() {
        WindowOverlayManager.shared.restoreAllWindowsManually()
        refreshOffscreenWindows()
    }

    private func restoreOffscreenWindow(_ windowID: CGWindowID) {
        _ = WindowOverlayManager.shared.restoreOffscreenWindow(windowID)
        refreshOffscreenWindows()
    }
}