import 'package:github/github.dart';
import 'package:version/version.dart';

import 'package:elastic_dashboard/services/log.dart';

extension on Release {
  Version? getVersion() {
    if (tagName == null) return null;

    String versionName = tagName!.substring(1);
    try {
      return Version.parse(versionName);
    } catch (_) {
      return null;
    }
  }
}

class UpdateChecker {
  final GitHub _github;
  final String currentVersion;

  UpdateChecker({required this.currentVersion}) : _github = GitHub();

  Future<UpdateCheckerResponse> isUpdateAvailable() async {
    logger.info('Checking for updates');

    try {
      Version current = Version.parse(currentVersion);

      final List<Release> releases = await _github.repositories
          .listReleases(
            RepositorySlug('Gold872', 'elastic_dashboard'),
          )
          .toList();

      final Iterable<Release> yearReleases = releases.where((release) {
        Version? latest = release.getVersion();

        if (latest == null) return false;
        if (latest.major != current.major) return false;

        return true;
      });

      Release? latestRelease = yearReleases.firstOrNull;
      if (latestRelease == null) {
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: false,
        );
      }

      String? tagName = latestRelease.tagName;

      if (tagName == null) {
        logger.error('Release tag not found in git repository');
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: true,
          errorMessage: 'Release tag not found',
        );
      }
      Version? latest = latestRelease.getVersion();

      if (!tagName.startsWith('v') || latest == null) {
        logger.error('Invalid version name: $tagName');
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: true,
          errorMessage: 'Invalid version name: \'$tagName\'',
        );
      }

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
