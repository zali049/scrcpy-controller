import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import 'path_resolver.dart';

class ADBService extends ChangeNotifier {
  static final ADBService instance = ADBService._();
  ADBService._();

  List<Device> devices = [];
  Device? selectedDevice;
  bool isScanning = false;
  String? lastError;
  bool _adbInitialized = false;

  /// Kill the running ADB server and restart it with our bundled binary
  Future<void> _initAdbServer(String adbPath) async {
    if (_adbInitialized) return;
    try {
      // Kill any existing adb server (from system or previous session)
      await Process.run(adbPath, ['kill-server']);
      await Future.delayed(const Duration(milliseconds: 500));
      // Start our bundled adb server
      final startResult = await Process.run(adbPath, ['start-server']);
      if (startResult.exitCode == 0) {
        _adbInitialized = true;
      } else {
        lastError = 'ADB start-server failed: ${startResult.stderr}';
      }
    } catch (e) {
      lastError = 'ADB server init error: $e';
    }
  }

  Future<void> refreshDevices() async {
    final adbPath = PathResolver.instance.resolveAdbPath();
    if (adbPath == null) {
      lastError = 'ADB executable not found. Bundled binaries may be missing.';
      devices = [];
      notifyListeners();
      return;
    }

    isScanning = true;
    lastError = null;
    notifyListeners();

    // Ensure the ADB server is running with our binary on first scan
    await _initAdbServer(adbPath);

    try {
      final result = await Process.run(adbPath, ['devices', '-l'])
          .timeout(const Duration(seconds: 8));
      final output = result.stdout as String;
      final lines = output.split(RegExp(r'[\r\n]+'));

      final List<Device> found = [];
      for (final line in lines) {
        final dev = Device.parse(line);
        if (dev != null) found.add(dev);
      }

      devices = found;
      isScanning = false;

      // Maintain existing selection
      if (selectedDevice != null && found.any((d) => d.serial == selectedDevice!.serial)) {
        selectedDevice = found.firstWhere((d) => d.serial == selectedDevice!.serial);
      } else {
        selectedDevice = found.isNotEmpty ? found.first : null;
      }
      notifyListeners();
    } on TimeoutException {
      isScanning = false;
      lastError = 'ADB devices scan timed out. Check USB connection.';
      _adbInitialized = false; // Force re-init next time
      notifyListeners();
    } catch (e) {
      isScanning = false;
      lastError = 'Error scanning devices: $e';
      notifyListeners();
    }
  }

  Future<({bool success, String message})> connectWireless(String address) async {
    final adbPath = PathResolver.instance.resolveAdbPath();
    if (adbPath == null) return (success: false, message: 'ADB not found');

    final cleanAddr = address.trim();
    if (cleanAddr.isEmpty) return (success: false, message: 'Address is required');

    try {
      final result = await Process.run(adbPath, ['connect', cleanAddr]);
      final output = (result.stdout as String).trim();
      await refreshDevices();

      if (output.contains('connected to')) {
        return (success: true, message: output);
      } else {
        return (success: false, message: output.isNotEmpty ? output : 'Failed to connect');
      }
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  Future<({bool success, String message})> disconnectWireless(String address) async {
    final adbPath = PathResolver.instance.resolveAdbPath();
    if (adbPath == null) return (success: false, message: 'ADB not found');

    try {
      final result = await Process.run(adbPath, ['disconnect', address.trim()]);
      final output = (result.stdout as String).trim();
      await refreshDevices();
      return (success: true, message: output);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  Future<({bool success, String message})> enableTcpIp(String serial) async {
    final adbPath = PathResolver.instance.resolveAdbPath();
    if (adbPath == null) return (success: false, message: 'ADB not found');

    try {
      final result = await Process.run(adbPath, ['-s', serial, 'tcpip', '5555']);
      final output = (result.stdout as String).trim();
      return (success: result.exitCode == 0, message: output);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Reset the ADB server (force kill + reinit on next scan)
  Future<void> resetAdbServer() async {
    _adbInitialized = false;
    final adbPath = PathResolver.instance.resolveAdbPath();
    if (adbPath != null) {
      await Process.run(adbPath, ['kill-server']);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await refreshDevices();
  }
}
