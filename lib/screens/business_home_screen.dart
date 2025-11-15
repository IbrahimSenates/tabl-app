import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'menu_management_screen.dart';

class BusinessHomeScreen extends StatelessWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İşletme Yönetimi'),
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
      body: FutureBuilder<Map<String, dynamic>?>(
        future: user != null ? userService.getUserData(user.uid) : null,
        builder: (context, snapshot) {
          final businessName = snapshot.data?['businessName'] ?? 'İşletme';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hoş geldiniz kartı
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    businessName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Menü başlığı
                Text(
                  'Yönetim Paneli',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                // Özellikler grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.qr_code,
                      title: 'QR Kod',
                      subtitle: 'QR kod oluştur',
                      color: Colors.blue,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR kod oluşturma özelliği yakında eklenecek.'),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.restaurant_menu,
                      title: 'Menü',
                      subtitle: 'Menü yönetimi',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MenuManagementScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.receipt_long,
                      title: 'Siparişler',
                      subtitle: 'Sipariş takibi',
                      color: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sipariş takibi yakında eklenecek.'),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.local_offer,
                      title: 'Kampanyalar',
                      subtitle: 'Kampanya yönetimi',
                      color: Colors.purple,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kampanya yönetimi yakında eklenecek.'),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.star,
                      title: 'Puan Sistemi',
                      subtitle: 'Puan ayarları',
                      color: Colors.amber,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Puan sistemi yakında eklenecek.'),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.settings,
                      title: 'Ayarlar',
                      subtitle: 'İşletme ayarları',
                      color: Colors.grey,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ayarlar yakında eklenecek.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


