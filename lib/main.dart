import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/business_home_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat
  // Not: Firebase yapılandırma dosyalarını (google-services.json ve GoogleService-Info.plist)
  // Firebase Console'dan indirip projeye eklemeniz gerekiyor
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tabl App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/business': (context) => const BusinessHomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // Yükleniyor durumu
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Kullanıcı giriş yapmışsa kullanıcı tipine göre yönlendir
        if (authSnapshot.hasData && authSnapshot.data != null) {
          final userId = authSnapshot.data!.uid;
          
          return FutureBuilder<UserType?>(
            future: userService.getUserType(userId),
            builder: (context, userTypeSnapshot) {
              // Kullanıcı tipi yükleniyor
              if (userTypeSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Kullanıcı tipine göre yönlendir
              final userType = userTypeSnapshot.data;
              if (userType == UserType.business) {
                return const BusinessHomeScreen();
              } else {
                return const HomeScreen();
              }
            },
          );
        }

        // Kullanıcı giriş yapmamışsa giriş ekranına yönlendir
        return const LoginScreen();
      },
    );
  }
}
