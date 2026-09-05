import 'package:flutter/material.dart';

import '../core/hud_theme.dart';

/// 玻璃质感数值卡片
class HudValueTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  final String? sub;
  final bool large;
  final VoidCallback? onTap;

  const HudValueTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.sub,
    this.large = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HudColors.bgPanel, HudColors.bgPanelAlt],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HudColors.stroke, width: 1),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: large ? 0.12 : 0.07),
                blurRadius: large ? 26 : 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(large ? 20 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HudColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: HudColors.textPrimary,
                          fontSize: large ? 44 : 30,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 18),
                          ],
                        ),
                      ),
                      if (unit.isNotEmpty)
                        TextSpan(
                          text: '  $unit',
                          style: const TextStyle(
                            color: HudColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub!,
                    style: const TextStyle(
                      color: HudColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
