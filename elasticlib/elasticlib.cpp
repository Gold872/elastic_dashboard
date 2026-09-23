// Copyright (c) 2023-2026 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic_dashboard/blob/main/LICENSE

#include "elasticlib.h"

#include <exception>
#include <string>

#include <wpi/nt/NetworkTableInstance.hpp>
#include <wpi/nt/StringTopic.hpp>
#include <wpi/util/json.hpp>
#include <wpi/util/print.hpp>

namespace elastic {

void SendNotification(const Notification& notification) {
  static wpi::nt::StringTopic topic =
      wpi::nt::NetworkTableInstance::GetDefault().GetStringTopic(
          "/Elastic/RobotNotifications");
  static wpi::nt::StringPublisher publisher =
      topic.Publish({.sendAll = true, .keepDuplicates = true});

  try {
    // Convert Notification to JSON string
    wpi::util::json jsonData;

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
    publisher.Set(jsonData.to_string());
  } catch (const std::exception& e) {
    wpi::util::println(stderr, "Error processing JSON: {}", e.what());
  } catch (...) {
    wpi::util::println(stderr, "Unknown error occurred while processing JSON.");
  }
}

void SelectTab(std::string_view tabName) {
  static wpi::nt::StringTopic topic =
      wpi::nt::NetworkTableInstance::GetDefault().GetStringTopic(
          "/Elastic/SelectedTab");
  static wpi::nt::StringPublisher publisher =
      topic.Publish({.keepDuplicates = true});

  publisher.Set(tabName);
}

void SelectTab(int tabIndex) {
  SelectTab(std::to_string(tabIndex));
}

}  // namespace elastic
