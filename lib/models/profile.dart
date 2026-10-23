class Profile {
  String id;
  String name;
  String description;
  bool isPreset;

  // Video
  int? maxSize; // e.g. 720, 1080, null = native
  String videoBitRate; // "8M", "4M", "16M"
  int maxFps; // 60, 30
  String videoCodec; // "h264", "h265", "av1"

  // Audio
  bool audioEnabled;
  String audioCodec; // "opus", "aac", "flac", "raw"
  String audioBitRate; // "128K", "64K", "192K"
  int audioBufferMs; // 50
  bool audioDup;

  // Window & Controls
  bool stayAwake;
  bool turnScreenOff;
  bool alwaysOnTop;
  bool fullscreen;
  bool showTouches;
  bool noControl;
  String windowTitle;

  // Advanced
  String extraArgs;

  Profile({
    required this.id,
    required this.name,
    this.description = '',
    this.isPreset = false,
    this.maxSize,
    this.videoBitRate = '8M',
    this.maxFps = 60,
    this.videoCodec = 'h264',
    this.audioEnabled = true,
    this.audioCodec = 'opus',
    this.audioBitRate = '128K',
    this.audioBufferMs = 50,
    this.audioDup = false,
    this.stayAwake = false,
    this.turnScreenOff = false,
    this.alwaysOnTop = false,
    this.fullscreen = false,
    this.showTouches = false,
    this.noControl = false,
    this.windowTitle = '',
    this.extraArgs = '',
  });

  List<String> generateArguments({String? serial}) {
    final List<String> args = [];

    if (serial != null && serial.trim().isNotEmpty) {
      args.add('--serial=$serial');
    }

    if (maxSize != null && maxSize! > 0) {
      args.add('--max-size=$maxSize');
    }

    if (videoBitRate.isNotEmpty) {
      args.add('--video-bit-rate=$videoBitRate');
    }

    if (maxFps > 0) {
      args.add('--max-fps=$maxFps');
    }

    if (videoCodec.isNotEmpty && videoCodec != 'auto') {
      args.add('--video-codec=$videoCodec');
    }

    if (!audioEnabled) {
      args.add('--no-audio');
    } else {
      if (audioCodec.isNotEmpty && audioCodec != 'opus') {
        args.add('--audio-codec=$audioCodec');
      }
      if (audioBitRate.isNotEmpty && audioBitRate != '128K') {
        args.add('--audio-bit-rate=$audioBitRate');
      }
      if (audioBufferMs > 0 && audioBufferMs != 50) {
        args.add('--audio-buffer=$audioBufferMs');
      }
      if (audioDup) {
        args.add('--audio-dup');
      }
    }

    if (stayAwake) args.add('--stay-awake');
    if (turnScreenOff) args.add('--turn-screen-off');
    if (alwaysOnTop) args.add('--always-on-top');
    if (fullscreen) args.add('--fullscreen');
    if (showTouches) args.add('--show-touches');
    if (noControl) args.add('--no-control');

    if (windowTitle.trim().isNotEmpty) {
      args.add('--window-title=$windowTitle');
    }

    if (extraArgs.trim().isNotEmpty) {
      final parts = extraArgs.trim().split(RegExp(r'\s+'));
      for (final p in parts) {
        if (p.isNotEmpty) args.add(p);
      }
    }

    return args;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'isPreset': isPreset,
    'maxSize': maxSize,
    'videoBitRate': videoBitRate,
    'maxFps': maxFps,
    'videoCodec': videoCodec,
    'audioEnabled': audioEnabled,
    'audioCodec': audioCodec,
    'audioBitRate': audioBitRate,
    'audioBufferMs': audioBufferMs,
    'audioDup': audioDup,
    'stayAwake': stayAwake,
    'turnScreenOff': turnScreenOff,
    'alwaysOnTop': alwaysOnTop,
    'fullscreen': fullscreen,
    'showTouches': showTouches,
    'noControl': noControl,
    'windowTitle': windowTitle,
    'extraArgs': extraArgs,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] ?? '',
    name: json['name'] ?? 'Unnamed',
    description: json['description'] ?? '',
    isPreset: json['isPreset'] ?? false,
    maxSize: json['maxSize'],
    videoBitRate: json['videoBitRate'] ?? '8M',
    maxFps: json['maxFps'] ?? 60,
    videoCodec: json['videoCodec'] ?? 'h264',
    audioEnabled: json['audioEnabled'] ?? true,
    audioCodec: json['audioCodec'] ?? 'opus',
    audioBitRate: json['audioBitRate'] ?? '128K',
    audioBufferMs: json['audioBufferMs'] ?? 50,
    audioDup: json['audioDup'] ?? false,
    stayAwake: json['stayAwake'] ?? false,
    turnScreenOff: json['turnScreenOff'] ?? false,
    alwaysOnTop: json['alwaysOnTop'] ?? false,
    fullscreen: json['fullscreen'] ?? false,
    showTouches: json['showTouches'] ?? false,
    noControl: json['noControl'] ?? false,
    windowTitle: json['windowTitle'] ?? '',
    extraArgs: json['extraArgs'] ?? '',
  );

  static List<Profile> get defaultPresets => [
    Profile(
      id: 'preset_gaming',
      name: '⚡ Low Latency Gaming',
      description: '720p, 60 FPS, 4Mbps, 20ms audio buffer for fast responsiveness.',
      isPreset: true,
      maxSize: 720,
      videoBitRate: '4M',
      maxFps: 60,
      videoCodec: 'h264',
      audioEnabled: true,
      audioCodec: 'opus',
      audioBufferMs: 20,
      stayAwake: true,
    ),
    Profile(
      id: 'preset_hd',
      name: '💎 High Definition 1080p',
      description: 'Full HD 1080p, 60 FPS, 16Mbps high quality mirroring.',
      isPreset: true,
      maxSize: 1080,
      videoBitRate: '16M',
      maxFps: 60,
      videoCodec: 'h264',
      audioEnabled: true,
      stayAwake: true,
    ),
    Profile(
      id: 'preset_presentation',
      name: '🎥 Presentation & Tutorial',
      description: 'Always on top, touch dots enabled, phone stays awake.',
      isPreset: true,
      maxSize: 1080,
      videoBitRate: '12M',
      maxFps: 60,
      stayAwake: true,
      alwaysOnTop: true,
      showTouches: true,
    ),
    Profile(
      id: 'preset_battery',
      name: '🔋 Screen Off (Work & Battery)',
      description: 'Mirror on PC while turning phone screen completely off.',
      isPreset: true,
      maxSize: 1080,
      videoBitRate: '8M',
      maxFps: 60,
      stayAwake: true,
      turnScreenOff: true,
    ),
    Profile(
      id: 'preset_wifi',
      name: '🌐 Wireless Wi-Fi Optimized',
      description: 'Reduced resolution and buffer tuned for Wi-Fi mirroring.',
      isPreset: true,
      maxSize: 720,
      videoBitRate: '4M',
      maxFps: 30,
      videoCodec: 'h264',
      audioBufferMs: 80,
    ),
  ];
}
