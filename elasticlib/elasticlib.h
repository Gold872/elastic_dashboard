// Copyright (c) 2023-2026 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic_dashboard/blob/main/LICENSE

#pragma once

#include <string>

#include <units/time.h>

namespace elastic {

/**
 * Defines severity levels for notifications.
 */
enum class NotificationLevel { INFO, WARNING, ERROR };

/**
 * Represents an notification with various display properties.
 */
struct Notification {
  /// Set the display time to this value to disable the auto-dismiss behavior.
  static constexpr units::millisecond_t NO_AUTO_DISMISS{0_s};

  // Set the height to this value to have the dashboard automatically determine
  // the height.
  static constexpr int AUTOMATIC_HEIGHT = -1;

  /// Notification severity level.
  NotificationLevel level = NotificationLevel::INFO;

  /// Title of the notification.
  std::string title;

  /// Description of the notification.
  std::string description;

  /// Display time.
  units::millisecond_t displayTime{3_s};

  /// Display width in pixels.
  int width = 350;

  /// Display height in pixels.
  int height = AUTOMATIC_HEIGHT;
};

/**
 * Publishes an notification as a JSON string to the NetworkTables topic.
 *
 * @param notification The notification to send.
 */
void SendNotification(const Notification& notification);

/**
 * Selects the tab of the dashboard with the given name. If no tab matches the
 * name, this will have no effect on the widgets or tabs in view.
 *
 * If the given name is a number, Elastic will select the tab whose index
 * equals the number provided.
 *
 * @param tabName the name of the tab to select
 */
void SelectTab(std::string_view tabName);

/**
 * Selects the tab of the dashboard at the given index. If this index is greater
 * than or equal to the number of tabs, this will have no effect.
 *
 * @param tabIndex the index of the tab to select.
 */
void SelectTab(int tabIndex);

}  // namespace elastic
