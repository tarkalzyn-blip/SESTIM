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
import 'package:cow_pregnancy/screens/splash_screen.dart';
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
  try {
    await Hive.initFlutter();
    try {
      Hive.registerAdapter(CowAdapter());
    } catch (e) {
      debugPrint("Adapter already registered: $e");
    }
    
    try {
      await Hive.openBox<Cow>('cows');
    } catch (e) {
      debugPrint("Error opening cows box: $e");
      await Hive.deleteBoxFromDisk('cows');
      await Hive.openBox<Cow>('cows');
    }

    try {
      await Hive.openBox('notes_box');
    } catch (e) {
      await Hive.deleteBoxFromDisk('notes_box');
      await Hive.openBox('notes_box');
    }

    try {
      await Hive.openBox('settings');
    } catch (e) {
      await Hive.deleteBoxFromDisk('settings');
      await Hive.openBox('settings');
    }
  } catch (e) {
    debugPrint("Hive initialization failed: $e");
  }

  // Initialize Notifications
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Notification init failed: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final fontFamily = ref.watch(fontProvider);
    final textScale = ref.watch(fontScaleProvider);

    TextTheme getTextTheme(TextTheme base) {
      switch (fontFamily) {
        case 'Tajawal':
          return GoogleFonts.tajawalTextTheme(base);
        case 'Almarai':
          return GoogleFonts.almaraiTextTheme(base);
        case 'Traditional':
          return GoogleFonts.notoNaskhArabicTextTheme(base);
        case 'Changa':
          return GoogleFonts.changaTextTheme(base);
        default:
          return GoogleFonts.cairoTextTheme(base);
      }
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
      home: const SplashScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        );
      },
    );
  }
}
