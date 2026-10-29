#pragma once

#include <windows.h>

#include <cstdint>
#include <vector>

using GroupId = std::uint64_t;

struct Group {
    GroupId id = 0;
    std::vector<HWND> windows;
    std::size_t active = 0;

    HWND ActiveWindow() const {
        if (windows.empty()) {
            return nullptr;
        }
        return windows[active < windows.size() ? active : 0];
    }
};

// Which windows belong to which group. Every window starts in its own group;
// merging is what a tab dragged onto another group's bar does.
class GroupStore {
public:
    // Add unknown windows as new groups, drop windows that no longer exist,
    // and drop groups that became empty.
    void Sync(const std::vector<HWND>& alive);

    Group* Find(GroupId id);
    Group* FindByWindow(HWND hwnd);
    std::vector<Group>& All() { return groups_; }

    // Move `window` into the group `into`, making it that group's active window.
    bool Merge(HWND window, GroupId into);

    // Move `window` out of its group into a group of its own.
    void Detach(HWND window);

    void DissolveAll();

private:
    std::vector<Group> groups_;
    GroupId next_id_ = 1;
};
