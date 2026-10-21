// Compiles every library so CI catches errors the analyzer may miss.
// ignore_for_file: unused_import
import 'package:aether_grid/app/app.dart';
import 'package:aether_grid/app/brand.dart';
import 'package:aether_grid/app/config.dart';
import 'package:aether_grid/app/providers.dart';
import 'package:aether_grid/app/router.dart';
import 'package:aether_grid/app/theme.dart';
import 'package:aether_grid/core/design_system/animated_number.dart';
import 'package:aether_grid/core/design_system/app_icons.dart';
import 'package:aether_grid/core/design_system/design_system.dart';
import 'package:aether_grid/core/design_system/energy_gauge.dart';
import 'package:aether_grid/core/design_system/floating_nav_pill.dart';
import 'package:aether_grid/core/design_system/flow_diagram.dart';
import 'package:aether_grid/core/design_system/led_ring_glow.dart';
import 'package:aether_grid/core/design_system/radar_pulse.dart';
import 'package:aether_grid/core/design_system/sheets.dart';
import 'package:aether_grid/core/design_system/status_pill.dart';
import 'package:aether_grid/core/design_system/surfaces.dart';
import 'package:aether_grid/core/design_system/swipe_to_connect.dart';
import 'package:aether_grid/core/design_system/toast_host.dart';
import 'package:aether_grid/core/design_system/tokens.dart';
import 'package:aether_grid/core/design_system/typography.dart';
import 'package:aether_grid/core/haptics/haptics.dart';
import 'package:aether_grid/core/services/notification_service.dart';
import 'package:aether_grid/core/services/security_service.dart';
import 'package:aether_grid/core/utils/format.dart';
import 'package:aether_grid/core/utils/motion.dart';
import 'package:aether_grid/data/sources/ble/ble_provisioning_source.dart';
import 'package:aether_grid/data/sources/live/live_link_source.dart';
import 'package:aether_grid/data/sources/mock/day_curves.dart';
import 'package:aether_grid/data/sources/mock/mock_power_node_source.dart';
import 'package:aether_grid/domain/entities/entities.dart';
import 'package:aether_grid/domain/metrics.dart';
import 'package:aether_grid/domain/repositories/power_node_repository.dart';
import 'package:aether_grid/features/alerts/alerts_sheet.dart';
import 'package:aether_grid/features/dashboard/dashboard_providers.dart';
import 'package:aether_grid/features/dashboard/dashboard_screen.dart';
import 'package:aether_grid/features/dashboard/debug_sheet.dart';
import 'package:aether_grid/features/energy_flow/energy_flow_screen.dart';
import 'package:aether_grid/features/gallery/gallery_screen.dart';
import 'package:aether_grid/features/insights/insights_screen.dart';
import 'package:aether_grid/features/insights/streak_screen.dart';
import 'package:aether_grid/features/onboarding/onboarding_screen.dart';
import 'package:aether_grid/features/onboarding/slide_art.dart';
import 'package:aether_grid/features/pairing/pairing_controller.dart';
import 'package:aether_grid/features/pairing/pairing_screen.dart';
import 'package:aether_grid/features/pairing/permissions_screen.dart';
import 'package:aether_grid/features/pairing/qr_scan_screen.dart';
import 'package:aether_grid/features/settings/settings_screen.dart';
import 'package:aether_grid/features/shell/home_shell.dart';
import 'package:aether_grid/features/solar/solar_screen.dart';
import 'package:aether_grid/main.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all libraries compile', () => expect(true, isTrue));
}
