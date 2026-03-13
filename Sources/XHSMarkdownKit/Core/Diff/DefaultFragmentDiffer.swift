import Foundation

public struct DefaultFragmentDiffer: FragmentDiffing {

    public init() {}

    public func diff(old: [RenderFragment], new: [RenderFragment]) -> [FragmentChange] {
        var changes: [FragmentChange] = []
        let oldIds = old.map(\.fragmentId)
        let newIds = new.map(\.fragmentId)
        let oldSet = Set(oldIds)
        let newSet = Set(newIds)
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.fragmentId, $0) })
        let oldIndexMap = Dictionary(uniqueKeysWithValues: old.enumerated().map { ($0.element.fragmentId, $0.offset) })
        let newIndexMap = Dictionary(uniqueKeysWithValues: new.enumerated().map { ($0.element.fragmentId, $0.offset) })

        for (index, fragment) in new.enumerated() {
            if !oldSet.contains(fragment.fragmentId) {
                changes.append(.insert(fragment: fragment, at: index))
            }
        }

        for (index, fragment) in old.enumerated() {
            if !newSet.contains(fragment.fragmentId) {
                changes.append(.remove(fragmentId: fragment.fragmentId, at: index))
            }
        }

        for fragmentId in newIds where oldSet.contains(fragmentId) {
            guard let oldIndex = oldIndexMap[fragmentId], let newIndex = newIndexMap[fragmentId], oldIndex != newIndex else {
                continue
            }
            changes.append(.move(fragmentId: fragmentId, from: oldIndex, to: newIndex))
        }

        for newFragment in new {
            guard let oldFragment = oldMap[newFragment.fragmentId] else { continue }

            var childChanges: [FragmentChange]?
            if let oldContainer = oldFragment as? ContainerFragment,
               let newContainer = newFragment as? ContainerFragment {
                let subDiff = diff(old: oldContainer.childFragments, new: newContainer.childFragments)
                if !subDiff.isEmpty {
                    childChanges = subDiff
                }
            }

            let contentChanged = !fragmentContentEqual(oldFragment, newFragment)
            if contentChanged || childChanges != nil {
                changes.append(.update(old: oldFragment, new: newFragment, childChanges: childChanges))
            }
        }

        return changes
    }

    private func fragmentContentEqual(_ a: RenderFragment, _ b: RenderFragment) -> Bool {
        a.isContentEqual(to: b)
    }
}
