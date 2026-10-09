import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_colors.dart';
import 'screens/introduction_screen.dart';
import 'screens/main_tab_scaffold.dart';
import 'screens/settings_screen.dart';
import 'screens/speech_translation_screen.dart';
import 'screens/sign_translation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const SenyasApp());
}

class SenyasApp extends StatelessWidget {
  const SenyasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Senyas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.background,
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroductionScreen(),
        '/home': (context) => const MainTabScaffold(initialIndex: 0),
        '/history': (context) => const MainTabScaffold(initialIndex: 1),
        '/profile': (context) => const MainTabScaffold(initialIndex: 2),
        '/settings': (context) => const SettingsScreen(),
        '/speech-translation': (context) => const SpeechTranslationScreen(),
        '/sign-translation': (context) => const SignTranslationScreen(),
      },
    );
  }
}
