import 'package:github/github.dart';
import 'package:version/version.dart';

import 'package:elastic_dashboard/services/log.dart';

class UpdateChecker {
  final GitHub _github;
  final String currentVersion;

  UpdateChecker({required this.currentVersion}) : _github = GitHub();

  Future<UpdateCheckerResponse> isUpdateAvailable() async {
    logger.info('Checking for updates');

    try {
      Release latestRelease = await _github.repositories.getLatestRelease(
        RepositorySlug('Gold872', 'elastic_dashboard'),
      );

      String? tagName = latestRelease.tagName;

      if (tagName == null) {
        logger.error('Release tag not found in git repository');
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: true,
          errorMessage: 'Release tag not found',
        );
      }
      if (!tagName.startsWith('v')) {
        logger.error('Invalid version name: $tagName');
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: true,
          errorMessage: 'Invalid version name: \'$tagName\'',
        );
      }

      String versionName = tagName.substring(1);

      Version current = Version.parse(currentVersion);
      Version latest = Version.parse(versionName);

      bool updateAvailable = current < latest;

      return UpdateCheckerResponse(
        updateAvailable: updateAvailable,
        latestVersion: latest.toString(),
        error: false,
      );
    } catch (error) {
      logger.error('Failed to check for updates', error);
      return UpdateCheckerResponse(
        updateAvailable: false,
        error: true,
        errorMessage: error.toString(),
      );
    }
  }
}

class UpdateCheckerResponse {
  final bool updateAvailable;
  final String? latestVersion;
  final bool error;
  final String? errorMessage;

  bool get onLatestVersion => !updateAvailable && !error;

  UpdateCheckerResponse({
    required this.updateAvailable,
    this.latestVersion,
    required this.error,
    this.errorMessage,
  });
}
