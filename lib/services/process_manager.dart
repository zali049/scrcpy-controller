import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/profile.dart';
import 'path_resolver.dart';

enum MirrorStatus { idle, starting, running, stopping, finished, error }

class LogEntry {
  final DateTime timestamp;
  final String text;
  final bool isError;

  LogEntry({required this.timestamp, required this.text, this.isError = false});

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class ScrcpyProcessManager extends ChangeNotifier {
  static final ScrcpyProcessManager instance = ScrcpyProcessManager._();
  ScrcpyProcessManager._();

  MirrorStatus status = MirrorStatus.idle;
  int? runningPid;
  Profile? activeProfile;
  final List<LogEntry> logs = [];
  Process? _process;

  bool get isRunning => status == MirrorStatus.running || status == MirrorStatus.starting;

  Future<void> start(Profile profile, {Device? device}) async {
    if (isRunning) return;

    final scrcpyPath = PathResolver.instance.resolveScrcpyPath();
    if (scrcpyPath == null) {
      status = MirrorStatus.error;
      _appendLog('Error: scrcpy executable not found.', isError: true);
      notifyListeners();
      return;
    }

    final adbPath = PathResolver.instance.resolveAdbPath();
    if (adbPath == null) {
      status = MirrorStatus.error;
      _appendLog('Error: ADB executable not found.', isError: true);
      notifyListeners();
      return;
    }

    status = MirrorStatus.starting;
    activeProfile = profile;
    _appendLog('Preparing scrcpy with profile: [${profile.name}]');

    final args = profile.generateArguments(serial: device?.serial);
    _appendLog('Command: $scrcpyPath ${args.join(" ")}');

    // Build environment with correct paths for scrcpy
    final Map<String, String> env = Map.from(Platform.environment);

    final serverPath = PathResolver.instance.resolveScrcpyServerPath();
    if (serverPath != null) {
      env['SCRCPY_SERVER_PATH'] = serverPath;
      _appendLog('SCRCPY_SERVER_PATH = $serverPath');
    }

    // Critical: set ADB env so scrcpy uses our bundled adb
    env['ADB'] = adbPath;
    _appendLog('ADB = $adbPath');

    // Also prepend adb directory to PATH so scrcpy can find it by name
    final adbDir = File(adbPath).parent.path;
    final sep = Platform.isWindows ? ';' : ':';
    env['PATH'] = '$adbDir$sep${env['PATH'] ?? ''}';

    notifyListeners();

    try {
      final proc = await Process.start(
        scrcpyPath,
        args,
        environment: env,
        workingDirectory: File(scrcpyPath).parent.path,
      );

      _process = proc;
      runningPid = proc.pid;
      status = MirrorStatus.running;
      _appendLog('scrcpy started successfully (PID: ${proc.pid})');
      notifyListeners();

      proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.trim().isNotEmpty) {
          final isErr = line.contains('ERROR') || line.contains('error');
          _appendLog(line, isError: isErr);
        }
      });

      proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.trim().isNotEmpty) {
          _appendLog(line, isError: true);
        }
      });

      proc.exitCode.then((code) {
        _appendLog('scrcpy exited with code $code', isError: code != 0);
        status = code == 0 ? MirrorStatus.finished : MirrorStatus.error;
        _process = null;
        runningPid = null;
        notifyListeners();
      });
    } catch (e) {
      status = MirrorStatus.error;
      _appendLog('Failed to start scrcpy: $e', isError: true);
      _process = null;
      runningPid = null;
      notifyListeners();
    }
  }

  void stop() {
    if (_process == null) {
      status = MirrorStatus.idle;
      notifyListeners();
      return;
    }

    status = MirrorStatus.stopping;
    _appendLog('Stopping scrcpy process (PID: $runningPid)...');
    notifyListeners();

    try {
      _process?.kill(ProcessSignal.sigint);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_process != null) {
          _process?.kill(ProcessSignal.sigterm);
        }
      });
    } catch (_) {
      _process?.kill();
    }
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  void _appendLog(String text, {bool isError = false}) {
    logs.add(LogEntry(timestamp: DateTime.now(), text: text, isError: isError));
    if (logs.length > 1000) logs.removeAt(0);
    notifyListeners();
  }
}
