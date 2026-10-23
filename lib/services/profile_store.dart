import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/profile.dart';

class ProfileStore extends ChangeNotifier {
  static final ProfileStore instance = ProfileStore._();
  ProfileStore._() {
    loadProfiles();
  }

  List<Profile> profiles = [];
  Profile? selectedProfile;

  File get _storageFile {
    String dirPath = '';
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      dirPath = '$home/Library/Application Support/scrcpyGUIController';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      dirPath = '$appData\\scrcpyGUIController';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      dirPath = '$home/.config/scrcpyGUIController';
    }

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}profiles.json');
  }

  void loadProfiles() {
    try {
      final file = _storageFile;
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        if (jsonList.isNotEmpty) {
          profiles = jsonList.map((j) => Profile.fromJson(j)).toList();
          selectedProfile = profiles.first;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    // Default presets
    profiles = Profile.defaultPresets;
    selectedProfile = profiles.isNotEmpty ? profiles.first : null;
    saveProfiles();
  }

  void saveProfiles() {
    try {
      final file = _storageFile;
      final jsonList = profiles.map((p) => p.toJson()).toList();
      file.writeAsStringSync(jsonEncode(jsonList));
    } catch (_) {}
    notifyListeners();
  }

  Profile addProfile({String name = 'New Profile'}) {
    final newP = Profile(
      id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: 'Custom screen mirror profile',
      isPreset: false,
      maxSize: 1080,
      videoBitRate: '8M',
      maxFps: 60,
      videoCodec: 'h264',
    );
    profiles.add(newP);
    selectedProfile = newP;
    saveProfiles();
    return newP;
  }

  void duplicateProfile(Profile profile) {
    final copy = Profile.fromJson(profile.toJson());
    copy.id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    copy.name = '${profile.name} (Copy)';
    copy.isPreset = false;
    profiles.add(copy);
    selectedProfile = copy;
    saveProfiles();
  }

  void updateProfile(Profile updated) {
    final idx = profiles.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      profiles[idx] = updated;
      if (selectedProfile?.id == updated.id) {
        selectedProfile = updated;
      }
      saveProfiles();
    }
  }

  void deleteProfile(Profile profile) {
    profiles.removeWhere((p) => p.id == profile.id);
    if (selectedProfile?.id == profile.id) {
      selectedProfile = profiles.isNotEmpty ? profiles.first : null;
    }
    saveProfiles();
  }

  void resetPresets() {
    profiles = Profile.defaultPresets;
    selectedProfile = profiles.isNotEmpty ? profiles.first : null;
    saveProfiles();
  }
}
