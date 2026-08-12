// Stub taken from https://github.com/leanflutter/window_manager/tree/main/packages/window_manager/lib
// which is licensed under the MIT License: https://github.com/leanflutter/window_manager/blob/main/LICENSE

import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'package:window_manager/window_manager.dart'
    show DockSide, WindowOptions;

enum TitleBarStyle { normal, hidden }

abstract mixin class WindowListener {
  /// Emitted when the window is going to be closed.
  void onWindowClose() {}

  /// Emitted when the window gains focus.
  void onWindowFocus() {}

  /// Emitted when the window loses focus.
  void onWindowBlur() {}

  /// Emitted when window is maximized.
  void onWindowMaximize() {}

  /// Emitted when the window exits from a maximized state.
  void onWindowUnmaximize() {}

  /// Emitted when the window is minimized.
  void onWindowMinimize() {}

  /// Emitted when the window is restored from a minimized state.
  void onWindowRestore() {}

  /// Emitted after the window has been resized.
  void onWindowResize() {}

  /// Emitted once when the window has finished being resized.
  ///
  /// @platforms macos,windows
  void onWindowResized() {}

  /// Emitted when the window is being moved to a new position.
  void onWindowMove() {}

  /// Emitted once when the window is moved to a new position.
  ///
  /// @platforms macos,windows
  void onWindowMoved() {}

  /// Emitted when the window enters a full-screen state.
  void onWindowEnterFullScreen() {}

  /// Emitted when the window leaves a full-screen state.
  void onWindowLeaveFullScreen() {}

  /// Emitted when the window entered a docked state.
  ///
  /// @platforms windows
  void onWindowDocked() {}

  /// Emitted when the window leaves a docked state.
  ///
  /// @platforms windows
  void onWindowUndocked() {}

  /// Emitted all events.
  void onWindowEvent(String eventName) {}
}

class WindowManager {
  WindowManager._();

  /// The shared instance of [WindowManager].
  static final WindowManager instance = WindowManager._();

  void addListener(WindowListener listener) {}

  void removeListener(WindowListener listener) {}

  // ignore: deprecated_member_use
  double getDevicePixelRatio() => window.devicePixelRatio;

  Future<void> ensureInitialized() async {}

  /// You can call this to remove the window frame (title bar, outline border, etc), which is basically everything except the Flutter view, also can call setTitleBarStyle(TitleBarStyle.normal) or setTitleBarStyle(TitleBarStyle.hidden) to restore it.
  Future<void> setAsFrameless() async {}

  /// Wait until ready to show.
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]) async {}

  /// Force closing the window.
  Future<void> destroy() async {}

  /// Try to close the window.
  Future<void> close() async {}

  /// Check if is intercepting the native close signal.
  Future<bool> isPreventClose() async => true;

  /// Set if intercept the native close signal. May useful when combine with the onclose event listener.
  /// This will also prevent the manually triggered close event.
  Future<void> setPreventClose(bool isPreventClose) async {}

  /// Focuses on the window.
  Future<void> focus() async {}

  /// Removes focus from the window.
  ///
  /// @platforms macos,windows
  Future<void> blur() async {}

  /// Returns `bool` - Whether window is focused.
  ///
  /// @platforms macos,windows
  Future<bool> isFocused() async => true;

  /// Shows and gives focus to the window.
  Future<void> show({bool inactive = false}) async {}

  /// Hides the window.
  Future<void> hide() async {}

  /// Returns `bool` - Whether the window is visible to the user.
  Future<bool> isVisible() async => true;

  /// Returns `bool` - Whether the window is maximized.
  Future<bool> isMaximized() async => true;

  /// Maximizes the window. `vertically` simulates aero snap, only works on Windows
  Future<void> maximize({bool vertically = false}) async {}

  /// Unmaximizes the window.
  Future<void> unmaximize() async {}

  /// Returns `bool` - Whether the window is minimized.
  Future<bool> isMinimized() async => true;

  /// Minimizes the window. On some platforms the minimized window will be shown in the Dock.
  Future<void> minimize() async {}

  /// Restores the window from minimized state to its previous state.
  Future<void> restore() async {}

  /// Returns `bool` - Whether the window is in fullscreen mode.
  Future<bool> isFullScreen() async => false;

  /// Sets whether the window should be in fullscreen mode.
  Future<void> setFullScreen(bool isFullScreen) async {}

  /// Returns `bool` - Whether the window is dockable or not.
  ///
  /// @platforms windows
  Future<bool> isDockable() async => false;

  /// Returns `bool` - Whether the window is docked.
  ///
  /// @platforms windows
  Future<DockSide?> isDocked() async => null;

  /// Docks the window. only works on Windows
  ///
  /// @platforms windows
  Future<void> dock({required DockSide side, required int width}) async {}

  /// Undocks the window. only works on Windows
  ///
  /// @platforms windows
  Future<bool> undock() async => false;

  /// This will make a window maintain an aspect ratio.
  Future<void> setAspectRatio(double aspectRatio) async {}

  /// Sets the background color of the window.
  Future<void> setBackgroundColor(Color backgroundColor) async {}

  /// Move the window to a position aligned with the screen.
  Future<void> setAlignment(
    Alignment alignment, {
    bool animate = false,
  }) async {}

  /// Moves window to the center of the screen.
  Future<void> center({bool animate = false}) async {}

  /// Returns `Rect` - The bounds of the window as Object.
  Future<Rect> getBounds() async => Rect.fromLTWH(0, 0, 0, 0);

  /// Resizes and moves the window to the supplied bounds.
  Future<void> setBounds(
    Rect? bounds, {
    Offset? position,
    Size? size,
    bool animate = false,
  }) async {}

  /// Returns `Size` - Contains the window's width and height.
  Future<Size> getSize() async => Size.zero;

  /// Resizes the window to `width` and `height`.
  Future<void> setSize(Size size, {bool animate = false}) =>
      setBounds(null, size: size, animate: animate);

  /// Returns `Offset` - Contains the window's current position.
  Future<Offset> getPosition() async => Offset.zero;

  /// Moves window to position.
  Future<void> setPosition(Offset position, {bool animate = false}) async {
    await setBounds(null, position: position, animate: animate);
  }

  /// Sets the minimum size of window to `width` and `height`.
  Future<void> setMinimumSize(Size size) async {}

  /// Sets the maximum size of window to `width` and `height`.
  Future<void> setMaximumSize(Size size) async {}

  /// Returns `bool` - Whether the window can be manually resized by the user.
  Future<bool> isResizable() async => false;

  /// Sets whether the window can be manually resized by the user.
  Future<void> setResizable(bool isResizable) async {}

  /// Returns `bool` - Whether the window can be moved by user.
  ///
  /// @platforms macos
  Future<bool> isMovable() async => false;

  /// Sets whether the window can be moved by user.
  ///
  /// @platforms macos
  Future<void> setMovable(bool isMovable) async {}

  /// Returns `bool` - Whether the window can be manually minimized by the user.
  ///
  /// @platforms macos,windows
  Future<bool> isMinimizable() async => false;

  /// Sets whether the window can be manually minimized by user.
  ///
  /// @platforms macos,windows
  Future<void> setMinimizable(bool isMinimizable) async {}

  /// Returns `bool` - Whether the window can be manually closed by user.
  ///
  /// @platforms windows
  Future<bool> isClosable() async => false;

  /// Returns `bool` - Whether the window can be manually maximized by the user.
  ///
  /// @platforms macos,windows
  Future<bool> isMaximizable() async => false;

  /// Sets whether the window can be manually maximized by the user.
  Future<void> setMaximizable(bool isMaximizable) async {}

  /// Sets whether the window can be manually closed by user.
  ///
  /// @platforms macos,windows
  Future<void> setClosable(bool isClosable) async {}

  /// Returns `bool` - Whether the window is always on top of other windows.
  // Future<bool> isAlwaysOnTop() async {}

  /// Sets whether the window should show always on top of other windows.
  Future<void> setAlwaysOnTop(bool isAlwaysOnTop) async {}

  /// Returns `bool` - Whether the window is always below other windows.
  Future<bool> isAlwaysOnBottom() async => false;

  /// Sets whether the window should show always below other windows.
  ///
  /// @platforms linux,windows
  Future<void> setAlwaysOnBottom(bool isAlwaysOnBottom) async {}

  /// Returns `String` - The title of the native window.
  Future<String> getTitle() async => '';

  /// Changes the title of native window to title.
  Future<void> setTitle(String title) async {}

  /// Changes the title bar style of native window.
  Future<void> setTitleBarStyle(
    TitleBarStyle titleBarStyle, {
    bool windowButtonVisibility = true,
  }) async {}

  Future<void> startDragging() async {}
}

final windowManager = WindowManager.instance;
