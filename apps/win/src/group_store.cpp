#include "group_store.h"

#include <algorithm>

void GroupStore::Sync(const std::vector<HWND>& alive) {
    const auto is_alive = [&alive](HWND hwnd) {
        return std::find(alive.begin(), alive.end(), hwnd) != alive.end();
    };

    for (Group& group : groups_) {
        const HWND active = group.ActiveWindow();
        std::vector<HWND> kept;
        kept.reserve(group.windows.size());
        for (HWND hwnd : group.windows) {
            if (is_alive(hwnd)) {
                kept.push_back(hwnd);
            }
        }
        group.windows = std::move(kept);
        if (!group.windows.empty()) {
            const auto pos = std::find(group.windows.begin(), group.windows.end(), active);
            group.active = pos != group.windows.end() ? static_cast<std::size_t>(pos - group.windows.begin()) : 0;
        }
    }
    groups_.erase(std::remove_if(groups_.begin(), groups_.end(),
                                 [](const Group& group) { return group.windows.empty(); }),
                  groups_.end());

    for (HWND hwnd : alive) {
        if (FindByWindow(hwnd) != nullptr) {
            continue;
        }
        Group group;
        group.id = next_id_++;
        group.windows.push_back(hwnd);
        groups_.push_back(std::move(group));
    }
}

Group* GroupStore::Find(GroupId id) {
    for (Group& group : groups_) {
        if (group.id == id) {
            return &group;
        }
    }
    return nullptr;
}

Group* GroupStore::FindByWindow(HWND hwnd) {
    for (Group& group : groups_) {
        if (std::find(group.windows.begin(), group.windows.end(), hwnd) != group.windows.end()) {
            return &group;
        }
    }
    return nullptr;
}

bool GroupStore::Merge(HWND window, GroupId into) {
    Group* target = Find(into);
    if (target == nullptr) {
        return false;
    }
    if (std::find(target->windows.begin(), target->windows.end(), window) != target->windows.end()) {
        return false;
    }
    Group* source = FindByWindow(window);
    if (source == nullptr || source == target) {
        return false;
    }

    const HWND source_active = source->ActiveWindow();
    source->windows.erase(std::remove(source->windows.begin(), source->windows.end(), window),
                          source->windows.end());
    if (source->windows.empty()) {
        const GroupId empty_id = source->id;
        groups_.erase(std::remove_if(groups_.begin(), groups_.end(),
                                     [empty_id](const Group& group) { return group.id == empty_id; }),
                      groups_.end());
    } else {
        const auto pos = std::find(source->windows.begin(), source->windows.end(), source_active);
        source->active = pos != source->windows.end() ? static_cast<std::size_t>(pos - source->windows.begin()) : 0;
    }

    // Erasing above may have reallocated the vector, so look the target up again.
    target = Find(into);
    if (target == nullptr) {
        return false;
    }
    target->windows.push_back(window);
    target->active = target->windows.size() - 1;
    return true;
}

void GroupStore::Detach(HWND window) {
    Group* source = FindByWindow(window);
    if (source == nullptr || source->windows.size() < 2) {
        return;
    }
    const HWND source_active = source->ActiveWindow();
    source->windows.erase(std::remove(source->windows.begin(), source->windows.end(), window),
                          source->windows.end());
    const auto pos = std::find(source->windows.begin(), source->windows.end(), source_active);
    source->active = pos != source->windows.end() ? static_cast<std::size_t>(pos - source->windows.begin()) : 0;

    Group group;
    group.id = next_id_++;
    group.windows.push_back(window);
    groups_.push_back(std::move(group));
}

void GroupStore::DissolveAll() {
    groups_.clear();
}
