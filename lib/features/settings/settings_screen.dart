import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/brand.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/haptics/haptics.dart';
import '../../core/services/security_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/metrics.dart';

final ownerKeyProvider = FutureProvider<String?>(
    (ref) => ref.watch(securityServiceProvider).publicKey());

class NodeNameController extends Notifier<String> {
  @override
  String build() => ref.watch(powerNodeRepositoryProvider).node.name;

  Future<void> rename(String name) async {
    await ref.read(powerNodeRepositoryProvider).rename(name);
    state = name;
  }
}

final nodeNameProvider =
    NotifierProvider<NodeNameController, String>(NodeNameController.new);

const _reAuth = ReAuth();

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenH,
          18,
          AppSpace.screenH,
          AppSpace.navClearance + MediaQuery.paddingOf(context).bottom,
        ),
        children: const [
          TabTitle(
              title: 'Settings', subtitle: '${AppBrand.ownerName} · Admin'),
          SizedBox(height: 8),
          SectionHeader('My Power Core'),
          _DeviceCard(),
          SectionHeader('Energy Modes'),
          _ModesCard(),
          SectionHeader('Security'),
          _SecurityCard(),
          SectionHeader('Members'),
          _MembersCard(),
          SectionHeader('Preferences'),
          _PreferencesCard(),
          SectionHeader('About'),
          _AboutCard(),
          SizedBox(height: 12),
          _RemoveDevice(),
        ],
      ),
    );
  }
}

// ───────────────────────────── shared rows

class _Row extends StatelessWidget {
  const _Row(
      {required this.icon,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      this.color});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppType.body(14,
                          weight: FontWeight.w600,
                          color: color ?? AppColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style:
                            AppType.body(12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.divider);
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SurfaceCard(
        radius: AppRadii.tile,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(children: children),
      );
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.label, {required this.onTap, this.primary = false});
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? AppColors.ctaWhite : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: AppType.body(12.5,
                  weight: FontWeight.w600,
                  color: primary ? AppColors.ctaText : AppColors.textPrimary),
            ),
          ),
        ),
      );
}

// ───────────────────────────── device

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(powerNodeRepositoryProvider);
    final state = ref.watch(
        snapshotProvider.select((s) => s.value?.state ?? NodeState.idle));
    final fw = ref.watch(firmwareProvider);
    final node = repo.node;
    final name = ref.watch(nodeNameProvider);
    final updating = fw.phase != FirmwarePhase.idle &&
        fw.phase != FirmwarePhase.done &&
        fw.phase != FirmwarePhase.failed;

    return SurfaceCard(
      radius: AppRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProductHero(width: 46, state: state, reflection: false),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppType.display(20, weight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(node.id,
                        style: AppType.mono(12.5,
                            weight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    StatusPill(
                        label: Metrics.pillLabel(state),
                        color: state == NodeState.offline
                            ? AppColors.textTertiary
                            : AppColors.mint),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kv('Signal', '${node.signalPercent}% · 5.8 GHz Mesh'),
          _kv('Serial', node.serial),
          _kv('Firmware', fw.current),
          _kv('Capacity', '1,024 Wh · ${AppBrand.badge}'),
          if (fw.available != null || updating) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.mintDim,
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    updating ? _phaseLabel(fw) : '${fw.available} is ready',
                    style: AppType.body(13.5,
                        weight: FontWeight.w600, color: AppColors.mint),
                  ),
                  const SizedBox(height: 8),
                  if (updating)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fw.progress,
                        minHeight: 3,
                        color: AppColors.mint,
                        backgroundColor: AppColors.track,
                      ),
                    )
                  else
                    Text(
                      'Takes about a minute. The Core restarts on its own and keeps your home powered from the grid meanwhile.',
                      style: AppType.body(12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallPill('Rename', onTap: () => _rename(context, ref, name)),
              _SmallPill(
                'Restart',
                onTap: () {
                  ref
                      .read(toastProvider.notifier)
                      .show('Restarting the Core · back in a few seconds');
                  repo.restart();
                },
              ),
              if (fw.available != null && !updating)
                _SmallPill('Install update',
                    primary: true,
                    onTap: () => ref.read(firmwareProvider.notifier).install())
              else
                _SmallPill('Check for updates',
                    onTap: updating
                        ? null
                        : () => ref.read(firmwareProvider.notifier).check()),
            ],
          ),
        ],
      ),
    );
  }

  String _phaseLabel(FirmwareStatus fw) => switch (fw.phase) {
        FirmwarePhase.downloading =>
          'Downloading ${fw.available} · ${(fw.progress * 100).round()}%',
        FirmwarePhase.installing =>
          'Installing · ${(fw.progress * 100).round()}%',
        FirmwarePhase.restarting => 'Restarting the Core…',
        _ => '',
      };

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
                width: 82,
                child: Text(k,
                    style: AppType.body(12.5, color: AppColors.textSecondary))),
            Expanded(
                child: Text(v,
                    style: AppType.mono(12.5, weight: FontWeight.w500))),
          ],
        ),
      );

  Future<void> _rename(
      BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SheetFrame(
          title: 'Rename Power Core',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(controller: ctrl, hint: 'e.g. Garage Core'),
              const SizedBox(height: 16),
              PrimaryButton(
                  label: 'Save',
                  onTap: () => Navigator.pop(c, ctrl.text.trim())),
            ],
          ),
        ),
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(nodeNameProvider.notifier).rename(name);
      ref
          .read(toastProvider.notifier)
          .show('Renamed to $name', tone: ToastTone.success);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: true,
        style: AppType.body(15, weight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppType.body(15, color: AppColors.textTertiary),
          filled: true,
          fillColor: AppColors.surfaceHigh,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
        ),
      );
}

// ───────────────────────────── modes

class _ModesCard extends ConsumerWidget {
  const _ModesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        for (final m in EnergyMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              radius: AppRadii.tile,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: s.mode == m ? const Color(0xFF1F2523) : AppColors.surface,
              onTap: () {
                Haptics.toggle();
                ctrl.setMode(m);
              },
              semanticLabel: '${m.label}${s.mode == m ? ', selected' : ''}',
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.label,
                            style: AppType.body(14, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(m.detail,
                            style: AppType.body(12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.mode == m ? AppColors.mint : Colors.transparent,
                      border: Border.all(
                          color: s.mode == m
                              ? AppColors.mint
                              : AppColors.textTertiary,
                          width: 1.5),
                    ),
                    child: s.mode == m
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: AppColors.ctaText)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        _Card(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Backup reserve',
                          style: AppType.body(14, weight: FontWeight.w600))),
                  Text('${s.stormGuard ? 100 : s.reserve}%',
                      style: AppType.mono(14, color: AppColors.mint)),
                ],
              ),
            ),
            _ReserveSlider(value: s.reserve, enabled: !s.stormGuard),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s.stormGuard
                    ? 'Storm Guard is holding the Core full until the weather clears.'
                    : 'The Core never discharges below this, so it is always ready for an outage.',
                style: AppType.body(12, color: AppColors.textSecondary),
              ),
            ),
            const _Divider(),
            _Row(
              icon: AppIcons.storm,
              title: 'Storm Guard',
              subtitle: 'Raise reserve to 100% ahead of bad weather',
              trailing: AetherSwitch(
                value: s.stormGuard,
                semanticLabel: 'Storm Guard',
                onChanged: (v) {
                  Haptics.toggle();
                  ctrl.setStormGuard(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReserveSlider extends ConsumerStatefulWidget {
  const _ReserveSlider({required this.value, required this.enabled});
  final int value;
  final bool enabled;
  @override
  ConsumerState<_ReserveSlider> createState() => _ReserveSliderState();
}

class _ReserveSliderState extends ConsumerState<_ReserveSlider> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Backup reserve',
      value: '${(_drag ?? widget.value).round()} percent',
      child: Slider(
        value: (_drag ?? widget.value.toDouble()).clamp(10, 100),
        min: 10,
        max: 100,
        divisions: 18,
        onChanged: widget.enabled
            ? (v) {
                if ((v.round()) != (_drag ?? widget.value).round()) {
                  Haptics.nav();
                }
                setState(() => _drag = v);
              }
            : null,
        onChangeEnd: (v) {
          setState(() => _drag = null);
          ref.read(settingsProvider.notifier).setReserve(v.round());
        },
      ),
    );
  }
}

// ───────────────────────────── security

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final key = ref.watch(ownerKeyProvider).value;
    return _Card(
      children: [
        _Row(
          icon: AppIcons.key,
          title: 'Owner key',
          subtitle: key == null
              ? 'Not registered'
              : 'Ed25519 · ${SecurityService.fingerprint(key)}',
          trailing: Icon(key == null ? AppIcons.warning : AppIcons.check,
              color: key == null ? AppColors.amber : AppColors.mint, size: 20),
        ),
        const _Divider(),
        _Row(
          icon: AppIcons.fingerprint,
          title: 'Biometric lock',
          subtitle: 'Face ID / fingerprint to open the app',
          trailing: AetherSwitch(
            value: s.biometricLock,
            semanticLabel: 'Biometric lock',
            onChanged: (v) async {
              if (await _reAuth.confirm('Confirm to change biometric lock')) {
                Haptics.toggle();
                await ref.read(settingsProvider.notifier).setBiometric(v);
              }
            },
          ),
        ),
        const _Divider(),
        _Row(
          icon: AppIcons.lock,
          title: 'Local Auth Only',
          subtitle: s.localAuthOnly
              ? 'The Core only accepts commands signed by keys on this network.'
              : 'Remote read-only monitoring through the cloud relay is on.',
          trailing: AetherSwitch(
            value: s.localAuthOnly,
            semanticLabel: 'Local Auth Only',
            onChanged: (v) {
              Haptics.toggle();
              ref.read(settingsProvider.notifier).setLocalAuthOnly(v);
            },
          ),
        ),
        const _Divider(),
        _Row(
          icon: AppIcons.restart,
          title: 'Rotate owner key',
          subtitle: 'Issue a new key and revoke the old one',
          onTap: () async {
            if (!await _reAuth.confirm('Confirm to rotate the owner key')) {
              return;
            }
            await ref.read(securityServiceProvider).rotate();
            ref.invalidate(ownerKeyProvider);
            ref
                .read(toastProvider.notifier)
                .show('New owner key registered', tone: ToastTone.success);
          },
        ),
        const _Divider(),
        const _Row(
            icon: AppIcons.devices,
            title: 'Active sessions',
            subtitle: 'This phone · local link · now'),
      ],
    );
  }
}

// ───────────────────────────── members

class _MembersCard extends ConsumerWidget {
  const _MembersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(settingsProvider.select((s) => s.members));
    return _Card(
      children: [
        for (final m in members) ...[
          _Row(
            icon: AppIcons.users,
            title: m.you ? '${m.name} (you)' : m.name,
            subtitle: switch (m.role) {
              Role.admin => 'Admin · everything',
              Role.member => 'Member · view and change modes',
              Role.viewer => 'Viewer · read-only',
            },
            trailing: Text(m.role.label,
                style: AppType.body(12.5,
                    weight: FontWeight.w600, color: AppColors.mint)),
            onTap: m.you ? null : () => _roleSheet(context, ref, m),
          ),
          const _Divider(),
        ],
        _Row(
            icon: AppIcons.userPlus,
            title: 'Invite',
            subtitle: 'Share a QR code or link',
            color: AppColors.mint,
            onTap: () => _invite(context, ref)),
      ],
    );
  }

  void _roleSheet(BuildContext context, WidgetRef ref, Member m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SheetFrame(
        title: m.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in [Role.member, Role.viewer])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  radius: AppRadii.tile,
                  color: AppColors.surfaceHigh,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setRole(m.id, r);
                    Navigator.pop(c);
                  },
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(r.label,
                              style:
                                  AppType.body(14, weight: FontWeight.w600))),
                      if (m.role == r)
                        const Icon(AppIcons.check,
                            color: AppColors.mint, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    if (!await _reAuth
        .confirm('Confirm to invite someone to your Power Core')) {
      return;
    }
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    var role = Role.member;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
          child: SheetFrame(
            title: 'Invite to your Core',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(controller: ctrl, hint: 'Their name'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final r in [Role.member, Role.viewer]) ...[
                      _SmallPill(r.label,
                          primary: role == r, onTap: () => set(() => role = r)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  role == Role.member
                      ? 'Can view and change modes and reserve.'
                      : 'Can see everything, change nothing.',
                  style: AppType.body(12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                    label: 'Create invite link',
                    onTap: () => Navigator.pop(c, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      ref.read(settingsProvider.notifier).invite(ctrl.text.trim(), role);
      ref.read(toastProvider.notifier).show(
          'Invite created for ${ctrl.text.trim()}',
          tone: ToastTone.success);
    }
  }
}

// ───────────────────────────── preferences

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return _Card(
      children: [
        _Row(
          icon: AppIcons.bell,
          title: 'Outage alerts',
          trailing: AetherSwitch(
              value: s.notifyOutage,
              onChanged: (v) => c.setNotify(outage: v),
              semanticLabel: 'Outage alerts'),
        ),
        const _Divider(),
        _Row(
          icon: AppIcons.battery,
          title: 'Low reserve alerts',
          trailing: AetherSwitch(
              value: s.notifyLowReserve,
              onChanged: (v) => c.setNotify(lowReserve: v),
              semanticLabel: 'Low reserve alerts'),
        ),
        const _Divider(),
        _Row(
          icon: AppIcons.download,
          title: 'Firmware updates',
          trailing: AetherSwitch(
              value: s.notifyFirmware,
              onChanged: (v) => c.setNotify(firmware: v),
              semanticLabel: 'Firmware alerts'),
        ),
        const _Divider(),
        _Row(
          icon: AppIcons.currency,
          title: 'Units & currency',
          subtitle: 'kWh · ${s.currency}',
          trailing:
              Text(s.currency, style: AppType.mono(13, color: AppColors.mint)),
          onTap: () {
            const order = ['EUR', 'USD', 'GBP', 'TND'];
            c.setCurrency(
                order[(order.indexOf(s.currency) + 1) % order.length]);
          },
        ),
        const _Divider(),
        const _Row(
          icon: AppIcons.privacy,
          title: 'Data & privacy',
          subtitle:
              'Telemetry stays on your phone and the Core. No cloud account needed.',
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();
  @override
  Widget build(BuildContext context) => _Card(
        children: [
          const _Row(
              icon: AppIcons.info,
              title: 'Aether Grid',
              subtitle: 'App 1.0.0 · ${AppBrand.footer}'),
          const _Divider(),
          _Row(
            icon: AppIcons.flask,
            title: 'Open-source licences',
            onTap: () => showLicensePage(
                context: context, applicationName: AppBrand.name),
          ),
        ],
      );
}

class _RemoveDevice extends ConsumerWidget {
  const _RemoveDevice();

  @override
  Widget build(BuildContext context, WidgetRef ref) => GhostButton(
        label: 'Remove device',
        color: AppColors.danger,
        onTap: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            builder: (c) => SheetFrame(
              title: 'Remove this Power Core?',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The Core keeps running and powering your home. This phone forgets it and its owner key is revoked. You can pair again any time.',
                    style: AppType.body(13.5,
                        color: AppColors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  GhostButton(
                      label: 'Remove device',
                      color: AppColors.danger,
                      onTap: () => Navigator.pop(c, true)),
                  const SizedBox(height: 8),
                  PrimaryButton(
                      label: 'Keep it', onTap: () => Navigator.pop(c, false)),
                ],
              ),
            ),
          );
          if (ok != true) return;
          if (!await _reAuth.confirm('Confirm to remove the Power Core')) {
            return;
          }
          await ref.read(securityServiceProvider).wipe();
          await ref.read(settingsProvider.notifier).reset();
          if (context.mounted) context.go(Routes.onboarding);
        },
      );
}
