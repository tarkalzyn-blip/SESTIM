import 'package:flutter/material.dart';

class CowIdBadge extends StatelessWidget {
  final String id;
  final Color color;
  final bool showCloud;
  final double fontSize;
  final double boxSize;
  final EdgeInsets padding;

  const CowIdBadge({
    super.key,
    required this.id,
    required this.color,
    this.showCloud = false,
    this.fontSize = 14,
    this.boxSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        color: color.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showCloud) ...[
            const Icon(Icons.cloud_done, size: 10, color: Colors.green),
            const SizedBox(width: 4),
          ],
          Text(
            id,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.1, 
            ),
          ),
          const SizedBox(width: 6),
          Transform.translate(
            offset: const Offset(0, -1), // Move square up by 1 pixel
            child: Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
