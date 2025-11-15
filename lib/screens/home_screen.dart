import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabl App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await authService.signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Çıkış yapılırken hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_menu,
              size: 100,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              'Hoş geldiniz!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (user != null)
              Text(
                user.email ?? 'Kullanıcı',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            const SizedBox(height: 48),
            const Text(
              'QR kod okutarak menüye ulaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // QR kod okutma özelliği daha sonra eklenecek
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('QR kod okutma özelliği yakında eklenecek.'),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR Kod Okut'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


