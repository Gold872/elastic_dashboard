# Contributing to Elastic

Thank you for contributing to Elastic! We're excited to have you. This is an open-source, community-driven project, and every contribution, whether it's a bug report, a new feature, or a documentation update, is heavily appreciated.

This document provides a set of guidelines to help you contribute to the project.

## Ways to Contribute

- **Bug Reports:** If you encounter a bug, please open a [Bug Report Issue](https://github.com/Gold87/elastic_dashboard/issues/new?assignees=&labels=bug&projects=&template=bug_report.md) on the project issue tracker.
- **Suggesting Enhancements:** If you have an idea for a new feature or an improvement to an existing one, feel free to open a [Feature Request Issue](https://github.com/Gold87/elastic_dashboard/issues/new?assignees=&labels=enhancement&projects=&template=feature_request.md).
- **Code Contributions:** If you'd like to fix a bug or implement a feature, please follow the workflow described below.

## Contribution Workflow

To ensure a standardized process, please follow this development workflow:

1. **Fork the Repository:** Start by [forking the repository](https://github.com/Gold87/elastic_dashboard/fork) to your own GitHub account.
2. **Create a Branch:** Create a new branch from `main` in your fork for your changes. Use a descriptive name, such as `fix-connection-error` or `add-new-widget`.
    ```bash
    git checkout -b <your-branch-name>
    ```
3. **Make Changes:** Write your code and any necessary tests.
4. **Commit Your Changes:** Commit your work with clear and concise commit messages.
5. **Push to Your Fork:** Push your branch to your forked repository.
    ```bash
    git push origin <your-branch-name>
    ```
6. **Open a Pull Request:** Go to the original Elastic repository and open a pull request from your forked branch. Provide a clear title and a detailed description of your changes, and link any relevant issues.

## Building from Source

### Flutter App

Elastic requires Flutter and platform-specific dependencies to run. See the [Flutter documentation](https://docs.flutter.dev/get-started) for installation instructions.

Once Flutter is installed, download the package dependencies:
```bash
flutter pub get
```

To build and run the app for debugging:
```bash
flutter run -d <PLATFORM>
```

To create a release build:
```bash
flutter build <PLATFORM>
```
* The output executable will be located in:
    * Windows: `<PROJECT DIR>/build/windows/x64/runner/Release`
    * MacOS: `<PROJECT DIR>/build/macos/Build/Products/Release`
    * Linux: `<PROJECT DIR>/build/linux/x64/release/bundle`
    * Web: `<PROJECT DIR>/build/web`

### Robot Code Library

The `elasticlib` directory contains a small robot code library written in C++, Java, and Python. Contributions to this part of the project are also welcome.

## Running Unit Tests

Elastic uses the [Flutter unit test](https://docs.flutter.dev/testing/overview) library and [Mockito](https://pub.dev/packages/mockito) for unit testing.

First, generate the necessary mock classes:
```bash
dart run build_runner build
```

Then, execute all automated unit tests:
```bash
flutter test .
```

## Pull Request Checklist

Before submitting a pull request, please ensure you have completed the following:

- All unit tests pass successfully:
    ```bash
    flutter test .
    ```
- All files are formatted according to the Dart style guide. Run the following commands to format your code:
    ```bash
    dart format .
    dart run import_sorter:main
    ```
- The code is free of any static analysis warnings or errors. Apply fixes and analyze your code:
    ```bash
    dart fix --apply
    flutter analyze
    ```
- Your pull request has a clear title and a detailed description.
- You have linked the pull request to any relevant issues.

## Licensing

By contributing to Elastic, you agree that your contributions will be licensed under the [MIT License](LICENSE) that covers the project.
