import WidgetKit

enum WidgetSnapshotService {
    static func update(with items: [DDayItem]) {
        let snapshots = items
            .sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned && !$1.isPinned
                }
                switch ($0.sortIndex, $1.sortIndex) {
                case let (lhs?, rhs?):
                    return lhs < rhs
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return $0.createdAt < $1.createdAt
                }
            }
            .enumerated()
            .map { index, item in
                DaycoWidgetSnapshot(
                    id: item.id,
                    title: item.title,
                    date: item.date,
                    typeRawValue: item.typeRawValue,
                    repeatRuleRawValue: item.repeatRuleRawValue,
                    milestoneDayRawValue: item.milestoneDayRawValue,
                    countStartAsDayOne: item.countStartAsDayOne,
                    displayUnitRawValue: item.displayUnitRawValue,
                    isPinned: item.isPinned,
                    isShared: item.isShared,
                    cardColorRawValue: item.cardColorRawValue,
                    sortIndex: item.sortIndex,
                    listRank: index,
                    updatedAt: item.updatedAt
                )
            }

        DaycoWidgetSnapshotStore.saveSnapshots(snapshots)
        WidgetCenter.shared.reloadTimelines(ofKind: DaycoWidgetConstants.kind)
    }
}
