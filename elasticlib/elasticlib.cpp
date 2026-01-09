// Copyright (c) 2023-2026 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic_dashboard/blob/main/LICENSE

#include "elasticlib.h"

#include <exception>
#include <string>

#include <fmt/core.h>
#include <networktables/NetworkTableInstance.h>
#include <networktables/StringTopic.h>
#include <wpi/json.h>

namespace elastic {

void SendNotification(const Notification& notification) {
  static nt::StringTopic topic =
      nt::NetworkTableInstance::GetDefault().GetStringTopic(
          "/Elastic/RobotNotifications");
  static nt::StringPublisher publisher =
      topic.Publish({.sendAll = true, .keepDuplicates = true});

  try {
    // Convert Notification to JSON string
    wpi::json jsonData;

    if (notification.level == NotificationLevel::INFO) {
      jsonData["level"] = "INFO";
    } else if (notification.level == NotificationLevel::WARNING) {
      jsonData["level"] = "WARNING";
    } else if (notification.level == NotificationLevel::ERROR) {
      jsonData["level"] = "ERROR";
    } else {
      jsonData["level"] = "UNKNOWN";
    }

    jsonData["title"] = notification.title;
    jsonData["description"] = notification.description;
    jsonData["displayTime"] = notification.displayTime.value();
    jsonData["width"] = notification.width;
    jsonData["height"] = notification.height;

    // Publish the JSON string
    publisher.Set(jsonData.dump());
  } catch (const std::exception& e) {
    fmt::println(stderr, "Error processing JSON: {}", e.what());
  } catch (...) {
    fmt::println(stderr, "Unknown error occurred while processing JSON.");
  }
}

void SelectTab(std::string_view tabName) {
  static nt::StringTopic topic =
      nt::NetworkTableInstance::GetDefault().GetStringTopic(
          "/Elastic/SelectedTab");
  static nt::StringPublisher publisher =
      topic.Publish({.keepDuplicates = true});

  publisher.Set(tabName);
}

void SelectTab(int tabIndex) {
  SelectTab(std::to_string(tabIndex));
}

}  // namespace elastic
