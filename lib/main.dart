import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/screens/main_screen.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(CowAdapter());
  await Hive.openBox<Cow>('cows');
  await Hive.openBox('settings');

  // Initialize Notifications
  await NotificationService().init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'مدير القطيع',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainScreen(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}
