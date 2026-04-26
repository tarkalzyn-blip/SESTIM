import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class MediumSpeedScrollPhysics extends FixedExtentScrollPhysics {
  const MediumSpeedScrollPhysics({super.parent});

  @override
  MediumSpeedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return MediumSpeedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Reduce velocity by 40% for a smooth, medium-speed, Xiaomi-like scrolling friction
    final double dampedVelocity = velocity * 0.6;
    return super.createBallisticSimulation(position, dampedVelocity);
  }
}

const int _kLoop = 37200; // Divisible by 31 and 12 to keep initialItem math perfectly aligned

Future<DateTime?> showCustomDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
}) async {
  final date = initialDate ?? DateTime.now();
  return await showDialog<DateTime>(
    context: context,
    builder: (context) => _DatePickerDialog(
      initialDate: date,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  );
}

class _DatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? title;

  const _DatePickerDialog({
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.title,
  });

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;

  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  late int _yearStart;
  late int _yearRange;

  // Audio pool: 4 independent players for rapid-fire ticks
  static const int _poolSize = 4;
  late List<AudioPlayer> _pool;
  int _poolIdx = 0;
  bool _audioReady = false;

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    // Always open on today's date regardless of passed initialDate
    final today = DateTime.now();
    _selectedDay   = today.day;
    _selectedMonth = today.month;
    _selectedYear  = today.year;

    final baseYear = today.year;
    _yearRange = 400;
    _yearStart = baseYear - (_yearRange ~/ 2);

    _dayController = FixedExtentScrollController(
      initialItem: _kLoop + (_selectedDay - 1),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _kLoop + (_selectedMonth - 1),
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _yearStart,
    );

    // Track indices for scrolling sound synchronization
    _lastDayIdx = _dayController.initialItem;
    _lastMonthIdx = _monthController.initialItem;
    _lastYearIdx = _yearController.initialItem;

    _dayController.addListener(() => _checkScrollSound(_dayController, 0));
    _monthController.addListener(() => _checkScrollSound(_monthController, 1));
    _yearController.addListener(() => _checkScrollSound(_yearController, 2));

    _currentSound = AppSettings.datePickerSound;
    _initAudio();
  }

  late int _lastDayIdx;
  late int _lastMonthIdx;
  late int _lastYearIdx;
  late String _currentSound;

  void _checkScrollSound(FixedExtentScrollController controller, int type) {
    if (!controller.hasClients) return;
    final currentIdx = (controller.offset / 60.0).round();
    if (type == 0 && currentIdx != _lastDayIdx) {
      _lastDayIdx = currentIdx;
      _triggerFeedback();
    } else if (type == 1 && currentIdx != _lastMonthIdx) {
      _lastMonthIdx = currentIdx;
      _triggerFeedback();
    } else if (type == 2 && currentIdx != _lastYearIdx) {
      _lastYearIdx = currentIdx;
      _triggerFeedback();
    }
  }

  Future<void> _initAudio() async {
    try {
      final soundFile = AppSettings.datePickerSound;
      _pool = List.generate(_poolSize, (_) => AudioPlayer());
      // Initialize sequentially to avoid platform channel overload
      for (final p in _pool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(1.0);
        await p.setSource(AssetSource('sounds/$soundFile'));
      }
      _audioReady = true;
      debugPrint('Audio pool initialized ($soundFile)');
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    if (_audioReady) {
      for (final p in _pool) {
        p.dispose();
      }
    }
    super.dispose();
  }

  void _triggerFeedback() {
    HapticFeedback.selectionClick();
    if (_audioReady) {
      // Strictly prevent overlap by stopping all currently active players
      for (final p in _pool) {
        p.stop();
      }

      final player = _pool[_poolIdx];
      _poolIdx = (_poolIdx + 1) % _poolSize;
      
      // Direct play is the most reliable way to force a restart in lowLatency mode
      player.play(AssetSource('sounds/$_currentSound'), mode: PlayerMode.lowLatency).catchError((_) {});
    }
  }

  void _onDayChanged(int index) {
    setState(() => _selectedDay = (index % 31) + 1);
  }

  void _onMonthChanged(int index) {
    setState(() => _selectedMonth = (index % 12) + 1);
  }

  void _onYearChanged(int index) {
    setState(() => _selectedYear = _yearStart + index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ─── Color tokens ───────────────────────────────────────────
    final Color bgColor =
        isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color selectedColor =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final Color unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.40);
    final Color highlightBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final Color cancelBg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.07);

    const double itemH = 65.0;
    const double pickerH = itemH * 5.0; // 5 items visible for a wider, smoother look

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ──────────────────────────────────────────
            if (widget.title != null) ...[
              const SizedBox(height: 22),
              Text(
                widget.title!,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
            ] else
              const SizedBox(height: 18),

            const SizedBox(height: 12),

            // ── Picker body ────────────────────────────────────
            ClipRect(
              child: SizedBox(
                height: pickerH,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                  // Selection highlight band
                  Positioned(
                    child: Container(
                      height: itemH,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: highlightBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // The three wheels with Fade effect
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.35, 0.65, 1.0], // Fades top 35% and bottom 35% smoothly
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                        // Day
                        Expanded(
                          flex: 3,
                          child: _buildWheel(
                            controller: _dayController,
                            itemH: itemH,
                            onChanged: _onDayChanged,
                            itemBuilder: (ctx, i) {
                              final day = (i % 31) + 1;
                              final maxD =
                                  _daysInMonth(_selectedYear, _selectedMonth);
                              final isSelected = day == _selectedDay;
                              final isInvalid = day > maxD;
                              return Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    day.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isSelected ? 24.5 : 22,
                                      height: 1.0, // Force strict vertical bounds to prevent clipping
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isInvalid
                                          ? Colors.transparent
                                          : isSelected
                                              ? selectedColor
                                              : unselectedColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Month
                        Expanded(
                          flex: 3,
                          child: _buildWheel(
                            controller: _monthController,
                            itemH: itemH,
                            onChanged: _onMonthChanged,
                            itemBuilder: (ctx, i) {
                              final month = (i % 12) + 1;
                              final isSelected = month == _selectedMonth;
                              return Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    month.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isSelected ? 24.5 : 22,
                                      height: 1.0, // Force strict vertical bounds to prevent clipping
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? selectedColor
                                          : unselectedColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Year
                        Expanded(
                          flex: 4,
                          child: _buildWheel(
                            controller: _yearController,
                            itemH: itemH,
                            count: _yearRange + 1,
                            onChanged: _onYearChanged,
                            itemBuilder: (ctx, i) {
                              final year = _yearStart + i;
                              final isSelected = year == _selectedYear;
                              return Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    year.toString(),
                                    style: TextStyle(
                                      fontSize: isSelected ? 24.5 : 22,
                                      height: 1.0, // Force strict vertical bounds to prevent clipping
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? selectedColor
                                          : unselectedColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ), // Closing ClipRect

            const SizedBox(height: 8),

            // ── Buttons ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // Confirm
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        int maxD =
                            _daysInMonth(_selectedYear, _selectedMonth);
                        int finalDay =
                            _selectedDay > maxD ? maxD : _selectedDay;
                        Navigator.pop(
                          context,
                          DateTime(_selectedYear, _selectedMonth, finalDay),
                        );
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'حسناً',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: cancelBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'إلغاء',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w500,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required double itemH,
    required ValueChanged<int> onChanged,
    required IndexedWidgetBuilder itemBuilder,
    int? count,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemH,
      physics: const MediumSpeedScrollPhysics(),
      diameterRatio: 1.5, // Better logical scrolling speed
      squeeze: 1.25,      // Moderate compression to prevent hyper-fast scrolling
      useMagnifier: false,
      magnification: 1.0,
      onSelectedItemChanged: onChanged,
      clipBehavior: Clip.none, // Prevent text clipping on squeezed items
      childDelegate: count != null 
          ? ListWheelChildBuilderDelegate(builder: itemBuilder, childCount: count)
          : ListWheelChildBuilderDelegate(builder: itemBuilder),
    );
  }
}
