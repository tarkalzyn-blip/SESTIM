import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cow_pregnancy/screens/auth_wrapper.dart';
import 'firebase_options.dart'; // ستحتاج لتشغيل flutterfire configure لتوليد هذا الملف

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

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
    final fontFamily = ref.watch(fontProvider);

    TextTheme getTextTheme(TextTheme base) {
      if (fontFamily == 'Tajawal') {
        return GoogleFonts.tajawalTextTheme(base);
      }
      return GoogleFonts.cairoTextTheme(base);
    }

    return MaterialApp(
      title: 'مدير القطيع',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ar', 'AE'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: getTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: getTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AuthWrapper(),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
  }
}
