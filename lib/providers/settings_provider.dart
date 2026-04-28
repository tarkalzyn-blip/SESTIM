import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class CowColorsNotifier extends StateNotifier<List<int>> {
  CowColorsNotifier() : super(AppSettings.availableColors);

  Future<void> addColor(int colorValue) async {
    if (!state.contains(colorValue)) {
      final newList = [...state, colorValue];
      await AppSettings.setAvailableColors(newList);
      state = newList;
    }
  }

  Future<void> removeColor(int colorValue) async {
    // Prevent removing the last color
    if (state.length <= 1) return;
    
    final newList = state.where((c) => c != colorValue).toList();
    await AppSettings.setAvailableColors(newList);
    state = newList;
  }
}

final cowColorsProvider = StateNotifierProvider<CowColorsNotifier, List<int>>((ref) {
  return CowColorsNotifier();
});
