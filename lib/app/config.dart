/// Feature flags. `useMockDevice` binds the repository to the simulator so the
/// whole app is demo-able without hardware.
class AppConfig {
  const AppConfig({
    this.useMockDevice = true,
    this.enableNotifications = true,
    this.liveLinkUri,
  });

  final bool useMockDevice;
  final bool enableNotifications;

  /// e.g. wss://nexus-core-901.local:8443/telemetry when a real node exists.
  final Uri? liveLinkUri;
}
