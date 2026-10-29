import AppKit
import SwiftUI

struct AutoGroupAppListEditor: View {
    let sectionTitle: String
    @Binding var bundleIDs: [String]

    @State private var runningApps: [AutoGroupAppOption] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sectionTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                addAppMenu
            }

            if bundleIDs.isEmpty {
                Text("名单为空。请从正在运行的应用中添加。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(bundleIDs, id: \.self) { bundleID in
                        HStack(spacing: 10) {
                            AutoGroupAppIcon(bundleIdentifier: bundleID)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(AutoGroupAppCatalog.displayName(for: bundleID))
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                remove(bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .help("从名单中移除")
                        }
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .onAppear(perform: refreshRunningApps)
    }

    private var addAppMenu: some View {
        Menu {
            if runningApps.isEmpty {
                Text("没有可添加的应用")
            } else {
                ForEach(runningApps) { app in
                    Button {
                        add(app.bundleIdentifier)
                    } label: {
                        Text(app.displayName)
                    }
                    .disabled(bundleIDs.contains(app.bundleIdentifier))
                }
            }
        } label: {
            Label("添加应用", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onAppear(perform: refreshRunningApps)
    }

    private func refreshRunningApps() {
        runningApps = AutoGroupAppCatalog.runningRegularApps()
    }

    private func add(_ bundleID: String) {
        guard bundleIDs.contains(bundleID) == false else { return }
        bundleIDs.append(bundleID)
        AppSettings.autoGroupAppBundleIDs = bundleIDs
    }

    private func remove(_ bundleID: String) {
        bundleIDs.removeAll { $0 == bundleID }
        AppSettings.autoGroupAppBundleIDs = bundleIDs
    }
}

private struct AutoGroupAppIcon: View {
    let bundleIdentifier: String

    var body: some View {
        if let icon = AutoGroupAppCatalog.icon(for: bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app")
                .foregroundStyle(.secondary)
        }
    }
}

struct AutoGroupAppOption: Identifiable, Equatable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }
}

enum AutoGroupAppCatalog {
    static func runningRegularApps() -> [AutoGroupAppOption] {
        var seen = Set<String>()

        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AutoGroupAppOption? in
                guard let bundleIdentifier = app.bundleIdentifier else { return nil }
                guard seen.insert(bundleIdentifier).inserted else { return nil }
                return AutoGroupAppOption(
                    bundleIdentifier: bundleIdentifier,
                    displayName: app.localizedName ?? bundleIdentifier
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    static func displayName(for bundleIdentifier: String) -> String {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?
            .localizedName ?? bundleIdentifier
    }

    static func icon(for bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
