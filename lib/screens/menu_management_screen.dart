import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/menu_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'menu_item_form_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _menuService = MenuService();
  final _authService = AuthService();
  final _userService = UserService();
  String? _selectedCategoryId;
  List<MenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Menüyü oluştur veya güncelle
      final userData = await _userService.getUserData(user.uid);
      final businessName = userData?['businessName'] ?? 'İşletme';
      await _menuService.createOrUpdateMenu(
        businessId: user.uid,
        businessName: businessName,
      );

      // Kategorileri ve menü öğelerini yükle
      final categories = await _menuService.getCategories(user.uid);
      final menuItems = await _menuService.getMenuItems(user.uid);

      setState(() {
        _categories = categories;
        _menuItems = menuItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<MenuItem> get _filteredMenuItems {
    if (_selectedCategoryId == null) {
      return _menuItems;
    }
    return _menuItems
        .where((item) => item.categoryId == _selectedCategoryId)
        .toList();
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Menü Öğesini Sil'),
        content: Text('${item.name} öğesini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && item.id != null) {
      try {
        await _menuService.deleteMenuItem(item.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menü öğesi silindi'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleItemAvailability(MenuItem item) async {
    try {
      final updatedItem = item.copyWith(isAvailable: !item.isAvailable);
      await _menuService.updateMenuItem(updatedItem);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menü Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final user = _authService.currentUser;
              if (user == null) return;

              if (_categories.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Önce kategori eklemeniz gerekiyor'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenuItemFormScreen(
                    businessId: user.uid,
                    categories: _categories,
                  ),
                ),
              );

              if (result == true) {
                _loadData();
              }
            },
            tooltip: 'Yeni Menü Öğesi Ekle',
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () => _showCategoryDialog(),
            tooltip: 'Kategori Yönetimi',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Kategori filtresi
                if (_categories.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('Tümü'),
                              selected: _selectedCategoryId == null,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId = null;
                                });
                              },
                            ),
                          );
                        }
                        final category = _categories[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category.name),
                            selected: _selectedCategoryId == category.id,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = selected ? category.id : null;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                // Menü öğeleri listesi
                Expanded(
                  child: _filteredMenuItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _categories.isEmpty
                                    ? 'Önce kategori ekleyin'
                                    : 'Menü öğesi yok',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMenuItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredMenuItems[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: item.isAvailable
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Icon(
                                    item.isAvailable
                                        ? Icons.check
                                        : Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: item.isAvailable
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.description),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(
                                            item.categoryName,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.price.toStringAsFixed(2)} ₺',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.isAvailable
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item.isAvailable
                                                ? 'Mevcut Değil Yap'
                                                : 'Mevcut Yap',
                                          ),
                                        ],
                                      ),
                                      onTap: () => _toggleItemAvailability(item),
                                    ),
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Düzenle'),
                                        ],
                                      ),
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MenuItemFormScreen(
                                              businessId: item.businessId,
                                              categories: _categories,
                                              menuItem: item,
                                            ),
                                          ),
                                        );
                                        if (result == true) {
                                          _loadData();
                                        }
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text(
                                            'Sil',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _deleteMenuItem(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showCategoryDialog() {
    final categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Ekle'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: 'Kategori Adı',
            hintText: 'Örn: Ana Yemekler',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              if (categoryController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen kategori adı girin'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final user = _authService.currentUser;
                if (user == null) return;

                final newCategory = MenuCategory(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: categoryController.text.trim(),
                  order: _categories.length + 1,
                );

                final updatedCategories = [..._categories, newCategory];
                await _menuService.saveCategories(
                  businessId: user.uid,
                  categories: updatedCategories,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kategori eklendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

