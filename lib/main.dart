import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/device.dart';
import 'models/profile.dart';
import 'services/adb_service.dart';
import 'services/process_manager.dart';
import 'services/profile_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScrcpyGUIApp());
}

class ScrcpyGUIApp extends StatelessWidget {
  const ScrcpyGUIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrcpy Controller (Multi-Platform)',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF16181D),
        cardColor: const Color(0xFF1F232B),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ProfileStore _profileStore = ProfileStore.instance;
  final ADBService _adbService = ADBService.instance;
  final ScrcpyProcessManager _processManager = ScrcpyProcessManager.instance;

  bool _showConsole = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _adbService.refreshDevices();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_adbService.isScanning && !_processManager.isRunning) {
        _adbService.refreshDevices();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_profileStore, _adbService, _processManager]),
      builder: (context, _) {
        return Scaffold(
          body: Row(
            children: [
              // 1. Sidebar (Profiles)
              Container(
                width: 270,
                color: const Color(0xFF121418),
                child: _buildSidebar(),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF282C37)),

              // 2. Main Stage
              Expanded(
                child: Column(
                  children: [
                    // Top Device Bar
                    _buildDeviceBar(),
                    const Divider(height: 1, thickness: 1, color: Color(0xFF282C37)),

                    // Profile Detail Editor
                    Expanded(
                      child: _profileStore.selectedProfile != null
                          ? _buildProfileEditor(_profileStore.selectedProfile!)
                          : const Center(child: Text('Select or create a profile')),
                    ),

                    // Bottom Control Action Bar
                    const Divider(height: 1, thickness: 1, color: Color(0xFF282C37)),
                    _buildControlBar(),

                    // Collapsible Log Console Drawer
                    if (_showConsole) ...[
                      const Divider(height: 1, thickness: 1, color: Color(0xFF282C37)),
                      SizedBox(
                        height: 180,
                        child: _buildConsoleLog(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    final presets = _profileStore.profiles.where((p) => p.isPreset).toList();
    final customProfiles = _profileStore.profiles.where((p) => !p.isPreset).toList();

    return Column(
      children: [
        // Sidebar Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.screen_share_rounded, color: Colors.indigoAccent, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Scrcpy Controller',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF282C37)),

        // Profiles List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Presets Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('PRESETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              for (final p in presets) _buildProfileListItem(p),

              const SizedBox(height: 12),
              // Custom Profiles Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('MY PROFILES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      tooltip: 'New Profile',
                      onPressed: () => _promptNewProfile(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              if (customProfiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('No custom profiles yet.\nClick + to create one.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                )
              else
                for (final p in customProfiles) _buildProfileListItem(p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileListItem(Profile profile) {
    final isSelected = _profileStore.selectedProfile?.id == profile.id;
    final isActive = _processManager.isRunning && _processManager.activeProfile?.id == profile.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.indigoAccent.withOpacity(0.5)) : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        title: Row(
          children: [
            Expanded(
              child: Text(
                profile.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[300],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: profile.description.isNotEmpty
            ? Text(
                profile.description,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        onTap: () {
          setState(() {
            _profileStore.selectedProfile = profile;
          });
        },
      ),
    );
  }

  Widget _buildDeviceBar() {
    final hasError = _adbService.lastError != null && _adbService.devices.isEmpty;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF191C22),
          child: Row(
            children: [
              Icon(
                Icons.smartphone_rounded,
                color: _adbService.devices.isEmpty ? Colors.grey : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 8),

              // Device Dropdown
              if (_adbService.devices.isEmpty)
                Text(
                  _adbService.isScanning ? 'Scanning devices...' : 'No device connected',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                )
              else
                DropdownButton<Device>(
                  value: _adbService.selectedDevice,
                  dropdownColor: const Color(0xFF222630),
                  underline: const SizedBox(),
                  items: _adbService.devices.map((d) {
                    return DropdownMenuItem<Device>(
                      value: d,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(d.isWireless ? Icons.wifi : Icons.usb, size: 16, color: Colors.indigoAccent),
                          const SizedBox(width: 6),
                          Text(d.displayName, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (dev) {
                    setState(() {
                      _adbService.selectedDevice = dev;
                    });
                  },
                ),

              const SizedBox(width: 8),
              IconButton(
                icon: _adbService.isScanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh devices',
                onPressed: () => _adbService.refreshDevices(),
              ),

              const SizedBox(width: 4),
              // ADB Reset Button
              Tooltip(
                message: 'Kill & restart ADB server (fixes "ADB server didn\'t ACK" errors)',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset ADB', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent, width: 0.5),
                  ),
                  onPressed: () => _adbService.resetAdbServer(),
                ),
              ),

              const SizedBox(width: 8),
              // Wireless Connect Button
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi, size: 16),
                label: const Text('Wi-Fi Connect', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: _showWirelessDialog,
              ),

              if (_adbService.selectedDevice != null && !_adbService.selectedDevice!.isWireless) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_input_antenna, size: 16),
                  label: const Text('Enable Wireless Mode (TCP/IP)', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: _enableTcpIp,
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
        // ADB Error Banner
        if (hasError)
          Container(
            width: double.infinity,
            color: const Color(0xFF2A1A1A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _adbService.lastError ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => _adbService.resetAdbServer(),
                  child: const Text('Fix', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProfileEditor(Profile profile) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: profile.name,
                enabled: !profile.isPreset,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Profile Name'),
                onChanged: (val) {
                  profile.name = val;
                  _profileStore.updateProfile(profile);
                },
              ),
            ),
            if (profile.isPreset)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: const Text('Preset', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Duplicate to edit',
              onPressed: () => _profileStore.duplicateProfile(profile),
            ),
            if (!profile.isPreset)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                tooltip: 'Delete profile',
                onPressed: () => _profileStore.deleteProfile(profile),
              ),
          ],
        ),
        Text(
          profile.description.isNotEmpty ? profile.description : 'No description provided.',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),

        // Display & Video Settings Card
        _buildSectionCard(
          title: 'Display & Video',
          icon: Icons.videocam_outlined,
          children: [
            DropdownButtonFormField<int?>(
              value: profile.maxSize,
              decoration: const InputDecoration(labelText: 'Resolution (Max Size)'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Native (Device Original)')),
                DropdownMenuItem(value: 720, child: Text('720p (1280x720)')),
                DropdownMenuItem(value: 1080, child: Text('1080p Full HD (1920x1080)')),
                DropdownMenuItem(value: 1440, child: Text('1440p 2K (2560x1440)')),
                DropdownMenuItem(value: 1920, child: Text('1920 Max Size')),
              ],
              onChanged: profile.isPreset ? null : (val) {
                setState(() => profile.maxSize = val);
                _profileStore.updateProfile(profile);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: profile.videoBitRate,
                    decoration: const InputDecoration(labelText: 'Bitrate'),
                    items: ['2M', '4M', '8M', '12M', '16M', '24M', '32M'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: profile.isPreset ? null : (val) {
                      if (val != null) setState(() => profile.videoBitRate = val);
                      _profileStore.updateProfile(profile);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: profile.maxFps,
                    decoration: const InputDecoration(labelText: 'Max FPS'),
                    items: [30, 60, 90, 120].map((f) => DropdownMenuItem(value: f, child: Text('$f FPS'))).toList(),
                    onChanged: profile.isPreset ? null : (val) {
                      if (val != null) setState(() => profile.maxFps = val);
                      _profileStore.updateProfile(profile);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: profile.videoCodec,
                    decoration: const InputDecoration(labelText: 'Codec'),
                    items: ['h264', 'h265', 'av1'].map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                    onChanged: profile.isPreset ? null : (val) {
                      if (val != null) setState(() => profile.videoCodec = val);
                      _profileStore.updateProfile(profile);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),
        // Audio Settings Card
        _buildSectionCard(
          title: 'Audio Settings',
          icon: Icons.volume_up_outlined,
          children: [
            SwitchListTile(
              title: const Text('Forward Device Audio'),
              subtitle: const Text('Play sound through computer speakers'),
              value: profile.audioEnabled,
              onChanged: profile.isPreset ? null : (val) {
                setState(() => profile.audioEnabled = val);
                _profileStore.updateProfile(profile);
              },
            ),
            if (profile.audioEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: profile.audioCodec,
                      decoration: const InputDecoration(labelText: 'Audio Codec'),
                      items: ['opus', 'aac', 'flac', 'raw'].map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                      onChanged: profile.isPreset ? null : (val) {
                        if (val != null) setState(() => profile.audioCodec = val);
                        _profileStore.updateProfile(profile);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: profile.audioBufferMs,
                      decoration: const InputDecoration(labelText: 'Audio Buffer'),
                      items: [20, 50, 80, 120].map((b) => DropdownMenuItem(value: b, child: Text('$b ms ${b <= 20 ? "(Low Latency)" : ""}'))).toList(),
                      onChanged: profile.isPreset ? null : (val) {
                        if (val != null) setState(() => profile.audioBufferMs = val);
                        _profileStore.updateProfile(profile);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),
        // Window & Behavior Card
        _buildSectionCard(
          title: 'Window & Device Behavior',
          icon: Icons.laptop_chromebook_rounded,
          children: [
            SwitchListTile(
              title: const Text('Stay Awake'),
              subtitle: const Text('Prevent device from sleeping'),
              value: profile.stayAwake,
              onChanged: profile.isPreset ? null : (val) {
                setState(() => profile.stayAwake = val);
                _profileStore.updateProfile(profile);
              },
            ),
            SwitchListTile(
              title: const Text('Turn Screen Off'),
              subtitle: const Text('Keep phone display black during mirroring'),
              value: profile.turnScreenOff,
              onChanged: profile.isPreset ? null : (val) {
                setState(() => profile.turnScreenOff = val);
                _profileStore.updateProfile(profile);
              },
            ),
            SwitchListTile(
              title: const Text('Always on Top'),
              subtitle: const Text('Keep window floating above other windows'),
              value: profile.alwaysOnTop,
              onChanged: profile.isPreset ? null : (val) {
                setState(() => profile.alwaysOnTop = val);
                _profileStore.updateProfile(profile);
              },
            ),
            SwitchListTile(
              title: const Text('Show Touches'),
              subtitle: const Text('Display physical touches on phone screen'),
              value: profile.showTouches,
              onChanged: profile.isPreset ? null : (val) {
                setState(() => profile.showTouches = val);
                _profileStore.updateProfile(profile);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),
        // Extra Flags
        _buildSectionCard(
          title: 'Advanced Arguments',
          icon: Icons.terminal_rounded,
          children: [
            TextFormField(
              initialValue: profile.extraArgs,
              enabled: !profile.isPreset,
              decoration: const InputDecoration(
                labelText: 'Extra CLI Flags',
                hintText: '--crop=1224:1440:0:0',
              ),
              onChanged: (val) {
                profile.extraArgs = val;
                _profileStore.updateProfile(profile);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),
        // Generated CLI Preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF101216), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Generated Command Preview:', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              SelectableText(
                'scrcpy ${profile.generateArguments(serial: _adbService.selectedDevice?.serial).join(" ")}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1F232B), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.indigoAccent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    final isRunning = _processManager.isRunning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF191C22),
      child: Row(
        children: [
          if (isRunning)
            ElevatedButton.icon(
              icon: const Icon(Icons.stop_circle, size: 18),
              label: const Text('Stop Mirroring', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _processManager.stop(),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill, size: 18),
              label: const Text('Start Mirroring', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                if (_profileStore.selectedProfile != null) {
                  _processManager.start(_profileStore.selectedProfile!, device: _adbService.selectedDevice);
                }
              },
            ),

          const SizedBox(width: 16),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isRunning ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isRunning
                      ? 'Mirroring Active (PID: ${_processManager.runningPid})'
                      : 'Ready to mirror',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          const Spacer(),
          // Toggle Console
          OutlinedButton.icon(
            icon: const Icon(Icons.terminal, size: 16),
            label: Text(_showConsole ? 'Hide Terminal' : 'Show Terminal', style: const TextStyle(fontSize: 12)),
            onPressed: () => setState(() => _showConsole = !_showConsole),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleLog() {
    return Container(
      color: const Color(0xFF101216),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF181B22),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Terminal Output', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  tooltip: 'Copy all logs',
                  onPressed: () {
                    final allText = _processManager.logs.map((l) => '[${l.formattedTime}] ${l.text}').join('\n');
                    Clipboard.setData(ClipboardData(text: allText));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14),
                  tooltip: 'Clear logs',
                  onPressed: () => _processManager.clearLogs(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _processManager.logs.length,
              itemBuilder: (context, i) {
                final l = _processManager.logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.formattedTime, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          l.text,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: l.isError ? Colors.redAccent : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _promptNewProfile() {
    final controller = TextEditingController(text: 'Custom Profile ${_profileStore.profiles.where((p) => !p.isPreset).length + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Custom Profile'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Profile Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _profileStore.addProfile(name: controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showWirelessDialog() {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '5555');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Wireless Device (Wi-Fi)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connect without USB cable using your Android phone\'s IP address.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: ipController,
                    decoration: const InputDecoration(labelText: 'Phone IP', hintText: '192.168.1.50'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: portController,
                    decoration: const InputDecoration(labelText: 'Port', hintText: '5555'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ip = ipController.text.trim();
              final port = portController.text.trim().isEmpty ? '5555' : portController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(ctx);
                final res = await _adbService.connectWireless('$ip:$port');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.message), backgroundColor: res.success ? Colors.green : Colors.red),
                  );
                }
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _enableTcpIp() async {
    final dev = _adbService.selectedDevice;
    if (dev == null) return;

    final res = await _adbService.enableTcpIp(dev.serial);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success
                ? 'TCP/IP 5555 enabled! You can now unplug USB and use Wi-Fi Connect.'
                : 'Failed: ${res.message}',
          ),
          backgroundColor: res.success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
