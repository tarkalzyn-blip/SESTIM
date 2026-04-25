import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/cow_detail_screen.dart';

class CowCard extends ConsumerStatefulWidget {
  final Cow cow;
  final int index;
  const CowCard({super.key, required this.cow, this.index = 0});

  @override
  ConsumerState<CowCard> createState() => _CowCardState();
}

class _CowCardState extends ConsumerState<CowCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Hero(
          tag: 'cow_card_${widget.cow.uniqueKey}',
          child: Card(
            elevation: 4,
            shadowColor: widget.cow.color.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: widget.cow.color.withValues(alpha: 0.3), width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTapDown: (_) => _controller.forward(),
                onTapUp: (_) => _controller.reverse(),
                onTapCancel: () => _controller.reverse(),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CowDetailScreen(cow: widget.cow)
                  ));
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف البقرة'),
                      content: Text('هل أنت متأكد من حذف البقرة رقم ${widget.cow.id}؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                        TextButton(
                          onPressed: () {
                            ref.read(cowProvider.notifier).deleteCow(widget.cow.uniqueKey);
                            Navigator.pop(ctx);
                          },
                          child: const Text('حذف', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).cardColor,
                        widget.cow.color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.cow.color,
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.cow.color.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ]
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'بقرة #${widget.cow.id}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (widget.cow.userId != null)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0, left: 8.0),
                                  child: Icon(Icons.cloud_done, size: 16, color: Colors.green),
                                ),
                            ],
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.cow.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.cow.status,
                              style: TextStyle(color: widget.cow.color, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${widget.cow.isPostBirth ? 'تاريخ الولادة' : (widget.cow.isInseminated ? 'تاريخ التلقيح' : 'آخر شبق')}: ${DateFormat('yyyy-MM-dd').format(widget.cow.isPostBirth ? widget.cow.birthDate! : widget.cow.inseminationDate)}', 
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                          ),
                          Text('اليوم: ${widget.cow.isPostBirth ? widget.cow.daysSinceBirth : widget.cow.daysSinceInsemination}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(widget.cow.pregnancyPercentage),
                        tween: Tween<double>(begin: 0, end: widget.cow.pregnancyPercentage),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 12,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: value,
                                        child: Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: widget.cow.color,
                                            boxShadow: [
                                              BoxShadow(
                                                color: widget.cow.color.withValues(alpha: 0.5),
                                                blurRadius: 4,
                                              )
                                            ]
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 45,
                                child: Text('${(value * 100).toInt()}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: widget.cow.color,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
