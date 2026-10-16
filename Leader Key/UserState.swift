import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var isShowingRefreshState: Bool
  @Published var navigationPath: [Group] = []
  /// The config as the panel offers it on this Mac. Settings and saving use `userConfig.root`,
  /// which keeps every key.
  @Published private(set) var visibleRoot: Group = emptyRoot

  var currentGroup: Group? {
    return navigationPath.last
  }

  init(
    userConfig: UserConfig!,
    lastChar: String? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.isShowingRefreshState = isShowingRefreshState
    self.navigationPath = []
  }

  func clear() {
    display = nil
    navigationPath = []
    isShowingRefreshState = false
  }

  func navigateToGroup(_ group: Group) {
    navigationPath.append(group)
  }

  /// `Controller.show()` calls this, so an app installed or removed while Leader Key runs shows
  /// or hides the next time the panel opens.
  func refreshVisibleRoot() {
    visibleRoot = userConfig.root.withoutMissingApps(
      isInstalled: FileManager.default.fileExists(atPath:))
  }
}

extension Group {
  /// This group without the application actions whose configured path `isInstalled` rejects,
  /// and without the subgroups that lose every item to that. A group configured empty stays.
  func withoutMissingApps(isInstalled: (String) -> Bool) -> Group {
    var visible = self
    visible.actions = actions.compactMap { item -> ActionOrGroup? in
      switch item {
      case .action(let action):
        return action.type == .application && !isInstalled(action.value) ? nil : item
      case .group(let group):
        let shown = group.withoutMissingApps(isInstalled: isInstalled)
        return shown.actions.isEmpty && !group.actions.isEmpty ? nil : .group(shown)
      }
    }
    return visible
  }
}
