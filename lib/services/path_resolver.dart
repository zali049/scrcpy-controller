import 'dart:io';

class PathResolver {
  static final PathResolver instance = PathResolver._();
  PathResolver._();

  String get currentPlatform {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Locates the appropriate scrcpy executable for the current OS
  String? resolveScrcpyPath() {
    final exeName = Platform.isWindows ? 'scrcpy.exe' : 'scrcpy';
    final path = _resolveBinary(exeName);
    if (path != null) _ensureExecutable(path);
    return path;
  }

  /// Locates the appropriate adb executable for the current OS
  String? resolveAdbPath() {
    final exeName = Platform.isWindows ? 'adb.exe' : 'adb';
    final path = _resolveBinary(exeName);
    if (path != null) _ensureExecutable(path);
    return path;
  }

  /// Locates the scrcpy-server file
  String? resolveScrcpyServerPath() {
    return _resolveBinary('scrcpy-server');
  }

  /// Remove macOS quarantine attribute and ensure executable bit is set
  void _ensureExecutable(String path) {
    try {
      // Ensure executable permission
      Process.runSync('chmod', ['+x', path]);
      // Remove macOS quarantine (critical for bundled binaries extracted from pkg/app)
      if (Platform.isMacOS) {
        Process.runSync('xattr', ['-d', 'com.apple.quarantine', path]);
      }
    } catch (_) {}
  }

  String? _resolveBinary(String name) {
    // 1. Check next to executable (production install)
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final inExecDir = '$execDir/$name';
    if (File(inExecDir).existsSync()) return inExecDir;

    final inExecBin = '$execDir/bin/$name';
    if (File(inExecBin).existsSync()) return inExecBin;

    // In macOS App bundle (Contents/MacOS/../Resources/bin)
    if (Platform.isMacOS) {
      final macBundlePath = '$execDir/../Resources/bin/$name';
      final resolved = File(macBundlePath);
      if (resolved.existsSync()) return resolved.absolute.path;

      // Also check Flutter.framework Resources
      final macBundlePath2 = '$execDir/../Frameworks/App.framework/Resources/flutter_assets/assets/bin/macos/$name';
      if (File(macBundlePath2).existsSync()) return macBundlePath2;
    }

    // 2. Check development assets directory (flutter run from project root)
    final currentDir = Directory.current.path;
    final devAssetPath = '$currentDir/assets/bin/$currentPlatform/$name';
    if (File(devAssetPath).existsSync()) return devAssetPath;

    // Also check absolute project path for dev
    const projectPath = '/Volumes/Data/Project/Flutter/scrcpyGUIController';
    final projectAssetPath = '$projectPath/assets/bin/$currentPlatform/$name';
    if (File(projectAssetPath).existsSync()) return projectAssetPath;

    // 3. Fallback: search system PATH
    return _which(name);
  }

  String? _which(String command) {
    try {
      final checkCmd = Platform.isWindows ? 'where' : 'which';
      final result = Process.runSync(checkCmd, [command]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).split(RegExp(r'[\r\n]+')).first.trim();
        if (path.isNotEmpty && File(path).existsSync()) return path;
      }
    } catch (_) {}
    return null;
  }
}
