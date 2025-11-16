import 'package:flutter/material.dart';
import '../services/menu_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'menu_item_form_screen.dart';
import 'category_management_screen.dart';

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
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManagementScreen(),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                                _selectedCategoryId = selected
                                    ? category.id
                                    : null;
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
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Ürün fotoğrafı veya placeholder
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: item.isAvailable
                                              ? Colors.green
                                              : Colors.grey,
                                          width: 2,
                                        ),
                                      ),
                                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                item.imageUrl!,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.restaurant,
                                                    color: Colors.orange[700],
                                                    size: 32,
                                                  );
                                                },
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Center(
                                                    child: CircularProgressIndicator(
                                                      value: loadingProgress.expectedTotalBytes != null
                                                          ? loadingProgress.cumulativeBytesLoaded /
                                                              loadingProgress.expectedTotalBytes!
                                                          : null,
                                                      strokeWidth: 2,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Icon(
                                                  Icons.restaurant,
                                                  color: Colors.orange[700],
                                                  size: 32,
                                                ),
                                                if (!item.isAvailable)
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.grey,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    decoration: item.isAvailable
                                                        ? null
                                                        : TextDecoration.lineThrough,
                                                    color: item.isAvailable
                                                        ? null
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              if (!item.isAvailable)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Mevcut Değil',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (item.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item.description,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Chip(
                                                label: Text(
                                                  item.categoryName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${item.price.toStringAsFixed(2)} ₺',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton(
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
                                          onTap: () =>
                                              _toggleItemAvailability(item),
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
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.red,
                                              ),
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.category,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Kategori Yönetimi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: _categories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz kategori eklenmemiş',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yeni kategori ekleyerek başlayın',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.label,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                'Sıra: ${category.order}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue[700],
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditCategoryDialog(category);
                                      },
                                      tooltip: 'Düzenle',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red[700],
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteCategory(category);
                                      },
                                      tooltip: 'Sil',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Kapat'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCategoryDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Kategori'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Yeni Kategori Ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Text Field
              TextField(
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
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
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
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            name: categoryController.text.trim(),
                            order: _categories.length + 1,
                          );

                          final updatedCategories = [
                            ..._categories,
                            newCategory,
                          ];
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Ekle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCategoryDialog(MenuCategory category) {
    final categoryController = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
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
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Kategori Düzenle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Text Field
              TextField(
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
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
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

                          final updatedCategory = MenuCategory(
                            id: category.id,
                            name: categoryController.text.trim(),
                            order: category.order,
                          );

                          final updatedCategories = _categories.map((cat) {
                            return cat.id == category.id
                                ? updatedCategory
                                : cat;
                          }).toList();

                          await _menuService.saveCategories(
                            businessId: user.uid,
                            categories: updatedCategories,
                          );

                          // Bu kategorideki menü öğelerinin categoryName'ini güncelle
                          final itemsInCategory = _menuItems
                              .where((item) => item.categoryId == category.id)
                              .toList();

                          for (final item in itemsInCategory) {
                            if (item.id != null) {
                              final updatedItem = item.copyWith(
                                categoryName: updatedCategory.name,
                              );
                              await _menuService.updateMenuItem(updatedItem);
                            }
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kategori güncellendi'),
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    // Kategoride menü öğesi var mı kontrol et
    final itemsInCategory = _menuItems
        .where((item) => item.categoryId == category.id)
        .toList();

    bool deleteItems = false;

    if (itemsInCategory.isNotEmpty) {
      // Kategoride ürün varsa, kullanıcıya seçenek sun
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
        // Kullanıcı ürünlerle birlikte silmek istiyor
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
        // Kullanıcı sadece kategoriyi silmek istiyor (ürünler kalacak)
        // Bu durumda ürünlerin categoryId'sini null yapmak veya başka bir kategoriye taşımak gerekir
        // Şimdilik sadece kategoriyi siliyoruz, ürünlerin categoryId'si boş kalacak
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
      // Kategoride ürün yok, direkt sil
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

    // Silme işlemini gerçekleştir
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Eğer ürünlerle birlikte silinecekse, önce ürünleri sil
      if (deleteItems && itemsInCategory.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        // Kategorideki tüm ürünleri ve fotoğraflarını sil
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

      // Kategoriyi sil
      final filteredCategories = _categories
          .where((cat) => cat.id != category.id)
          .toList();

      // Order değerlerini yeniden düzenle
      final updatedCategories = filteredCategories.asMap().entries.map((
        entry,
      ) {
        final index = entry.key;
        final cat = entry.value;
        return MenuCategory(id: cat.id, name: cat.name, order: index + 1);
      }).toList();

      await _menuService.saveCategories(
        businessId: user.uid,
        categories: updatedCategories,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori silindi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
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
}
