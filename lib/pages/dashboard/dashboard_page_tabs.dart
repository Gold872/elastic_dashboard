import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

mixin DashboardPageTabs on DashboardPageViewModel {
  @override
  void createDefaultTabs() {
    if (tabData.isEmpty) {
      logger.info('Creating default Teleoperated and Autonomous tabs');

      tabData.addAll([
        TabData(
          name: 'Teleoperated',
          tabGrid: TabGridModel(
            ntConnection: ntConnection,
            preferences: preferences,
            onAddWidgetPressed: displayAddWidgetDialog,
          ),
        ),
        TabData(
          name: 'Autonomous',
          tabGrid: TabGridModel(
            ntConnection: ntConnection,
            preferences: preferences,
            onAddWidgetPressed: displayAddWidgetDialog,
          ),
        ),
      ]);
      notifyListeners();
    }
  }

  @override
  void showTabCloseConfirmation(
    BuildContext context,
    String tabName,
    Function() onClose,
  ) {
    logger.info('Showing tab close confirmation for tab: $tabName');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              logger.debug('Closing tab: $tabName');
              Navigator.of(context).pop();
              onClose.call();
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              logger.debug(
                'Ignoring tab close for tab: $tabName, user canceled the request.',
              );
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
        content: Text('Do you want to close the tab "$tabName"?'),
        title: const Text('Confirm Tab Close'),
      ),
    );
  }

  @override
  void switchToTab(int tabIndex) {
    currentTabIndex = tabIndex;
    notifyListeners();
  }

  @override
  void moveTabLeft() {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    if (currentTabIndex <= 0) {
      logger.debug(
        'Ignoring move tab left, tab index is already $currentTabIndex',
      );
      return;
    }

    logger.info('Moving current tab at index $currentTabIndex to the left');

    // Swap the tabs
    TabData tempData = tabData[currentTabIndex - 1];
    tabData[currentTabIndex - 1] = tabData[currentTabIndex];
    tabData[currentTabIndex] = tempData;

    currentTabIndex -= 1;
    notifyListeners();
  }

  @override
  void moveTabRight() {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    if (currentTabIndex >= tabData.length - 1) {
      logger.debug(
        'Ignoring move tab left, tab index is already $currentTabIndex',
      );
      return;
    }

    logger.info('Moving current tab at index $currentTabIndex to the right');

    // Swap the tabs
    TabData tempData = tabData[currentTabIndex + 1];
    tabData[currentTabIndex + 1] = tabData[currentTabIndex];
    tabData[currentTabIndex] = tempData;

    currentTabIndex += 1;

    notifyListeners();
  }

  @override
  void moveToNextTab() {
    int moveIndex = currentTabIndex + 1;

    if (moveIndex >= tabData.length) {
      moveIndex = 0;
    }

    switchToTab(moveIndex);
  }

  @override
  void moveToPreviousTab() {
    int moveIndex = currentTabIndex - 1;

    if (moveIndex < 0) {
      moveIndex = tabData.length - 1;
    }

    switchToTab(moveIndex);
  }
}
