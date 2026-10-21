/// Brand constants and the copy deck (section 8). Every user-facing string the
/// reference screens show lives here so it stays verbatim. Mirrored in
/// lib/l10n/app_en.arb for future fr / ar translations.
abstract final class AppBrand {
  static const name = 'AETHER GRID';
  static const wordmark = 'AETHER GRID';
  static const tagline = 'Smart Home Power Core';
  static const productName = 'Aether Smart Home Power Core';
  static const badge = 'Cell Solid-State V4';
  static const firmware = 'v4.8.2-Aether';
  static const footer = 'Firmware v4.8.2-Aether • Local Auth Only';
  static const ownerName = 'German Ferrer';
  static const ownerInitial = 'G';
}

abstract final class Copy {
  // Status pills
  static const gridOnline = 'GRID ONLINE';
  static const pairingReady = 'PAIRING READY';
  static const islandMode = 'ISLAND MODE';
  static const nodeOffline = 'NODE OFFLINE';

  // Dashboard labels
  static const storedEnergy = 'STORED ENERGY';
  static const whActive = 'Wh Active';
  static const selfConsumption = 'SELF-CONSUMPTION';
  static const batteryHealth = 'BATTERY HEALTH';
  static const solarHarvest = 'Solar Harvest';
  static const exportedToGrid = 'Exported to Grid';
  static const totalIndependence = 'Total Energy Independence';
  static const days = 'DAYS';
  static const active = 'Active';
  static const paused = 'Paused';

  // CTAs
  static const initialize = 'Initialize Smart Node';
  static const swipeToConnect = 'SWIPE TO CONNECT';
  static const allowAccess = 'Allow access';
  static const tryAgain = 'Try again';
  static const scanQrInstead = 'Scan QR instead';

  // Pairing
  static const connectTitle = 'Connect Your Module';
  static const connectSubtitle = 'Sync your local storage cell to the automated grid network in real-time.';
  static const ownerKey = 'Owner Encryption Key';
  static const inverterBridge = 'Solar Inverter Bridge';
  static const microDetected = '3x Microinverters Detected';
  static const ready = 'Ready';
  static const looking = 'Looking for your Power Core…';
  static const notFound = 'No Power Core found. Make sure the LED ring is glowing mint and you are within 3 m.';

  // Toasts
  static const autonomyPaused = 'Autonomy Mode paused';
  static const autonomyActive = 'Autonomy Mode active';
  static String reserveSet(int p) => 'Backup reserve set to $p%';
  static const gridRestored = 'Grid restored';
  static const updateInstalled = 'Update installed';

  // Notifications
  static String outageBody(String runtime) =>
      'Grid outage detected. Your home is running on stored energy — about $runtime remaining.';
}
