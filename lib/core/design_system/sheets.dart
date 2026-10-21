import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Shared bottom-sheet chrome.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.hero)),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(title, style: AppType.display(22, weight: FontWeight.w500))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Large tab heading used by Solar, Insights and Settings.
class TabTitle extends StatelessWidget {
  const TabTitle({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.display(34, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle, style: AppType.body(13, color: AppColors.textSecondary)),
          ],
        ),
      );
}
