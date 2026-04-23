import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final int delayMs;

  const StatCard({
    super.key,
    required this.title,
    required this.count,
    required this.color,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? color.withValues(alpha: 0.15)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(count),
                    tween: Tween<double>(begin: 0, end: count.toDouble()),
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeOutCubic,
                    builder: (context, numberValue, child) {
                      return Text(
                        numberValue.toInt().toString(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
