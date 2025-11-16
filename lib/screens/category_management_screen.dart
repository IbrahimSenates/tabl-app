import 'package:flutter/material.dart';
import '../services/menu_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _menuService = MenuService();
  final _authService = AuthService();
  final _userService = UserService();
  List<MenuCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final categories = await _menuService.getCategories(user.uid);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    final categoryController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Yeni Kategori',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: 'Kategori Adı',
            hintText: 'Örn: Ana Yemekler',
            prefixIcon: const Icon(Icons.label_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (categoryController.text.trim().isNotEmpty) {
                Navigator.pop(context, categoryController.text.trim());
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final user = _authService.currentUser;
        if (user == null) return;

        final newCategory = MenuCategory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result,
          order: _categories.length + 1,
        );

        final updatedCategories = [..._categories, newCategory];
        await _menuService.saveCategories(
          businessId: user.uid,
          categories: updatedCategories,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategori eklendi'),
              backgroundColor: Colors.green,
            ),
          );
          _loadCategories();
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
    }
  }

  Future<void> _editCategory(MenuCategory category) async {
    final categoryController = TextEditingController(text: category.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: Colors.blue[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Kategori Düzenle',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: 'Kategori Adı',
            hintText: 'Örn: Ana Yemekler',
            prefixIcon: const Icon(Icons.label_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (categoryController.text.trim().isNotEmpty) {
                Navigator.pop(context, categoryController.text.trim());
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final user = _authService.currentUser;
        if (user == null) return;

        final updatedCategory = MenuCategory(
          id: category.id,
          name: result,
          order: category.order,
        );

        final updatedCategories = _categories.map((cat) {
          return cat.id == category.id ? updatedCategory : cat;
        }).toList();

        await _menuService.saveCategories(
          businessId: user.uid,
          categories: updatedCategories,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategori güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
          _loadCategories();
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
    }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    // Kategoride menü öğesi var mı kontrol et
    final user = _authService.currentUser;
    if (user == null) return;

    final menuItems = await _menuService.getMenuItems(user.uid);
    final itemsInCategory = menuItems
        .where((item) => item.categoryId == category.id)
        .toList();

    bool deleteItems = false;

    if (itemsInCategory.isNotEmpty) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kategori Silme'),
          content: Text(
            'Bu kategoride ${itemsInCategory.length} menü öğesi bulunmaktadır.\n\n'
            'Kategoriyi silmek için ne yapmak istersiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete_items'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Ürünlerle Birlikte Sil'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep_items'),
              child: const Text('Sadece Kategoriyi Sil'),
            ),
          ],
        ),
      );

      if (result == null || result == 'cancel') {
        return;
      }

      if (result == 'delete_items') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Onay'),
            content: Text(
              '${category.name} kategorisini ve içindeki ${itemsInCategory.length} ürünü '
              'silmek istediğinize emin misiniz?\n\n'
              'Bu işlem geri alınamaz!',
            ),
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

        if (confirmed != true) {
          return;
        }

        deleteItems = true;
      } else if (result == 'keep_items') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Uyarı'),
            content: Text(
              'Kategori silindiğinde, bu kategorideki ${itemsInCategory.length} ürünün '
              'kategorisi boş kalacaktır. Ürünler silinmeyecektir.\n\n'
              'Devam etmek istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Devam Et'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          return;
        }
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kategoriyi Sil'),
          content: Text(
            '${category.name} kategorisini silmek istediğinize emin misiniz?',
          ),
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

      if (confirmed != true) {
        return;
      }
    }

    try {
      if (deleteItems && itemsInCategory.isNotEmpty) {
        await _menuService.deleteMenuItemsByCategory(user.uid, category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${itemsInCategory.length} ürün ve fotoğrafları silindi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      final filteredCategories = _categories
          .where((cat) => cat.id != category.id)
          .toList();

      final updatedCategories = filteredCategories.asMap().entries.map((entry) {
        final index = entry.key;
        final cat = entry.value;
        return MenuCategory(id: cat.id, name: cat.name, order: index + 1);
      }).toList();

      await _menuService.saveCategories(
        businessId: user.uid,
        categories: updatedCategories,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori silindi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Yönetimi'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : _buildCategoryList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Kategori'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_outlined,
              size: 80,
              color: Colors.orange[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz kategori eklenmemiş',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni kategori ekleyerek başlayın',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('İlk Kategoriyi Ekle'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryCard(category, index);
        },
      ),
    );
  }

  Widget _buildCategoryCard(MenuCategory category, int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final color = colors[index % colors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editCategory(category),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color[50]!,
                color[100]!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Sıra numarası ve ikon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category.order}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Kategori bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sıra: ${category.order}',
                        style: TextStyle(
                          fontSize: 14,
                          color: color[700],
                        ),
                      ),
                    ],
                  ),
                ),
                // Aksiyon butonları
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: color[700]),
                        onPressed: () => _editCategory(category),
                        tooltip: 'Düzenle',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                        onPressed: () => _deleteCategory(category),
                        tooltip: 'Sil',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


