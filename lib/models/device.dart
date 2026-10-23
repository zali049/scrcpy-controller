class Device {
  final String serial;
  final String state;
  final String product;
  final String model;
  final String device;
  final String transportId;

  Device({
    required this.serial,
    this.state = 'device',
    this.product = '',
    this.model = '',
    this.device = '',
    this.transportId = '',
  });

  bool get isWireless => serial.contains(':');
  bool get isAuthorized => state == 'device';

  String get displayName {
    String cleanModel = model.replaceFirst('model:', '').replaceAll('_', ' ');
    if (cleanModel.isNotEmpty) {
      return '$cleanModel ($serial)';
    }
    return serial;
  }

  static Device? parse(String line) {
    final trimmed = line.trim();
    final ignoredPrefixes = ['List of', '*', 'error:', 'ADB server', '---', 'adb:'];
    for (final prefix in ignoredPrefixes) {
      if (trimmed.startsWith(prefix)) return null;
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final serial = parts[0];
    final state = parts[1];

    // Strict whitelist of recognized ADB states
    const validStates = {'device', 'unauthorized', 'offline', 'recovery', 'sideload', 'bootloader'};
    if (!validStates.contains(state)) return null;

    String product = '';
    String model = '';
    String deviceName = '';
    String transportId = '';

    for (int i = 2; i < parts.length; i++) {
      final p = parts[i];
      if (p.startsWith('product:')) {
        product = p.substring('product:'.length);
      } else if (p.startsWith('model:')) {
        model = p.substring('model:'.length);
      } else if (p.startsWith('device:')) {
        deviceName = p.substring('device:'.length);
      } else if (p.startsWith('transport_id:')) {
        transportId = p.substring('transport_id:'.length);
      }
    }

    return Device(
      serial: serial,
      state: state,
      product: product,
      model: model,
      device: deviceName,
      transportId: transportId,
    );
  }
}
