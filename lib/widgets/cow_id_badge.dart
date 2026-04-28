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
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: fontSize * 0.9, color: color.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text(
            id,
            style: TextStyle(
              fontSize: fontSize + 2,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              height: 1, 
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
