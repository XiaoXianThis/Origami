import AppKit
import CoreGraphics

/// 一个窗口组：包含若干 CGWindowID，activeIndex 指向当前前台窗口
struct WindowGroup {
    var windowIDs: [CGWindowID]
    var activeIndex: Int = 0

    var activeWindowID: CGWindowID { windowIDs[activeIndex] }
}

struct WindowRemovalChange {
    let groupID: UUID
    let removedWindowIDs: Set<CGWindowID>
    let removedActiveWindowID: CGWindowID?
    let remainingGroup: WindowGroup?
}

/// 全局分组状态，所有操作必须在主线程执行
final class GroupStore {
    static let shared = GroupStore()

    // groupID → group
    private(set) var groups: [UUID: WindowGroup] = [:]
    // windowID → groupID（快速反查）
    private(set) var windowToGroup: [CGWindowID: UUID] = [:]

    private init() {}

    // MARK: - 查询

    func group(for windowID: CGWindowID) -> (id: UUID, group: WindowGroup)? {
        guard let gid = windowToGroup[windowID], let g = groups[gid] else { return nil }
        return (gid, g)
    }

    func groupID(for windowID: CGWindowID) -> UUID? {
        windowToGroup[windowID]
    }

    /// 返回某个组的"代表窗口"（active window）
    func representativeWindowID(for groupID: UUID) -> CGWindowID? {
        groups[groupID]?.activeWindowID
    }

    // MARK: - 注册单窗口（首次发现时调用）

    /// 如果 windowID 没有归属组，创建一个单元素组
    @discardableResult
    func registerIfNeeded(_ windowID: CGWindowID) -> UUID {
        if let gid = windowToGroup[windowID] { return gid }
        let gid = UUID()
        groups[gid] = WindowGroup(windowIDs: [windowID])
        windowToGroup[windowID] = gid
        return gid
    }

    // MARK: - 合并

    /// 将 sourceWindowID 所在的组合并进 targetWindowID 所在的组
    /// 合并后 source 组解散，source 的所有窗口加入 target 组末尾
    @discardableResult
    func merge(sourceWindowID: CGWindowID, intoGroupOf targetWindowID: CGWindowID) -> UUID? {
        guard let sourceGID = windowToGroup[sourceWindowID],
              let targetGID = windowToGroup[targetWindowID] else { return nil }

        guard sourceGID != targetGID else {
            activate(windowID: sourceWindowID, in: targetGID)
            return targetGID
        }

        let sourceGroup = groups[sourceGID]!
        var targetGroup = groups[targetGID]!
        let incomingWindowIDs = sourceGroup.windowIDs.filter { !targetGroup.windowIDs.contains($0) }
        targetGroup.windowIDs.append(contentsOf: incomingWindowIDs)

        if let activeIndex = targetGroup.windowIDs.firstIndex(of: sourceWindowID) {
            targetGroup.activeIndex = activeIndex
        } else {
            targetGroup.activeIndex = max(targetGroup.windowIDs.count - 1, 0)
        }

        groups[targetGID] = targetGroup

        for wid in sourceGroup.windowIDs {
            windowToGroup[wid] = targetGID
        }
        groups.removeValue(forKey: sourceGID)
        return targetGID
    }

    // MARK: - 激活（组内切换）

    func activate(windowID: CGWindowID, in groupID: UUID) {
        guard let idx = groups[groupID]?.windowIDs.firstIndex(of: windowID) else { return }
        groups[groupID]?.activeIndex = idx
    }

    // MARK: - 分离

    /// 将窗口从当前多窗口组中分离为新的单窗口组
    @discardableResult
    func detach(windowID: CGWindowID) -> (oldGroupID: UUID, newGroupID: UUID)? {
        detachForRestore(windowID: windowID).map { result in
            (oldGroupID: result.oldGroupID, newGroupID: result.newGroupID)
        }
    }

    @discardableResult
    func detachForRestore(windowID: CGWindowID) -> (oldGroupID: UUID, newGroupID: UUID, oldGroup: WindowGroup?, newGroup: WindowGroup)? {
        guard let oldGroupID = windowToGroup[windowID],
              var oldGroup = groups[oldGroupID],
              oldGroup.windowIDs.count > 1,
              let removedIndex = oldGroup.windowIDs.firstIndex(of: windowID) else { return nil }

        let wasActive = removedIndex == oldGroup.activeIndex
        oldGroup.windowIDs.remove(at: removedIndex)

        if wasActive {
            oldGroup.activeIndex = min(removedIndex, oldGroup.windowIDs.count - 1)
        } else if removedIndex < oldGroup.activeIndex {
            oldGroup.activeIndex -= 1
        }

        groups[oldGroupID] = oldGroup

        let newGroupID = UUID()
        let newGroup = WindowGroup(windowIDs: [windowID])
        groups[newGroupID] = newGroup
        windowToGroup[windowID] = newGroupID
        return (oldGroupID, newGroupID, oldGroup, newGroup)
    }

    // MARK: - 移除消失的窗口

    @discardableResult
    func removeWindows(_ disappeared: Set<CGWindowID>) -> [WindowRemovalChange] {
        guard !disappeared.isEmpty else { return [] }

        let affectedGroupIDs = Set(disappeared.compactMap { windowToGroup[$0] })
        var changes: [WindowRemovalChange] = []

        for gid in affectedGroupIDs {
            guard var group = groups[gid] else { continue }
            let originalWindowIDs = group.windowIDs
            let removedWindowIDs = Set(originalWindowIDs.filter { disappeared.contains($0) })
            guard !removedWindowIDs.isEmpty else { continue }

            let previousActiveWindowID = originalWindowIDs.indices.contains(group.activeIndex)
                ? originalWindowIDs[group.activeIndex]
                : nil
            let removedActiveWindowID = previousActiveWindowID.flatMap {
                removedWindowIDs.contains($0) ? $0 : nil
            }

            for wid in removedWindowIDs {
                windowToGroup.removeValue(forKey: wid)
            }

            group.windowIDs.removeAll { removedWindowIDs.contains($0) }

            if group.windowIDs.isEmpty {
                groups.removeValue(forKey: gid)
                changes.append(
                    WindowRemovalChange(
                        groupID: gid,
                        removedWindowIDs: removedWindowIDs,
                        removedActiveWindowID: removedActiveWindowID,
                        remainingGroup: nil
                    )
                )
                continue
            }

            if let previousActiveWindowID,
               let newActiveIndex = group.windowIDs.firstIndex(of: previousActiveWindowID) {
                group.activeIndex = newActiveIndex
            } else {
                let nextActiveWindowID = originalWindowIDs.enumerated().first { index, wid in
                    index > group.activeIndex && removedWindowIDs.contains(wid) == false
                }?.element ?? originalWindowIDs.enumerated().reversed().first { index, wid in
                    index < group.activeIndex && removedWindowIDs.contains(wid) == false
                }?.element
                group.activeIndex = nextActiveWindowID.flatMap { group.windowIDs.firstIndex(of: $0) } ?? 0
            }

            groups[gid] = group
            changes.append(
                WindowRemovalChange(
                    groupID: gid,
                    removedWindowIDs: removedWindowIDs,
                    removedActiveWindowID: removedActiveWindowID,
                    remainingGroup: group
                )
            )
        }

        return changes
    }

    /// 将所有窗口拆成单窗口组，彻底解散现有分组。
    func dissolveAllGroups() {
        let allWindowIDs = Array(windowToGroup.keys)
        groups.removeAll()
        windowToGroup.removeAll()

        for wid in allWindowIDs {
            let gid = UUID()
            groups[gid] = WindowGroup(windowIDs: [wid])
            windowToGroup[wid] = gid
        }
    }
}