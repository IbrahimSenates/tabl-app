import 'package:flutter/material.dart';
import '../services/menu_service.dart';
import '../models/cart_item.dart';
import 'cart_screen.dart';

class MenuViewScreen extends StatefulWidget {
  final String businessId;

  const MenuViewScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<MenuViewScreen> createState() => _MenuViewScreenState();
}

class _MenuViewScreenState extends State<MenuViewScreen> {
  final _menuService = MenuService();
  List<MenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  String? _businessName;
  bool _isLoading = true;
  String? _selectedCategoryId;
  List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // İşletme bilgilerini menü koleksiyonundan al (public erişim)
      final menuData = await _menuService.getMenu(widget.businessId);
      _businessName = menuData?['businessName'] ?? 'İşletme';

      // Kategorileri ve menü öğelerini yükle
      final categories = await _menuService.getCategories(widget.businessId);
      final menuItems = await _menuService.getMenuItems(widget.businessId);

      // Sadece mevcut olan menü öğelerini filtrele
      final availableItems = menuItems.where((item) => item.isAvailable).toList();

      setState(() {
        _categories = categories;
        _menuItems = availableItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menü yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<MenuItem> get _filteredMenuItems {
    final items = _menuItems.where((item) => item.isAvailable).toList();
    
    if (_selectedCategoryId == null) {
      return items;
    }
    
    return items.where((item) => item.categoryId == _selectedCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_businessName ?? 'Menü'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMenu,
            tooltip: 'Yenile',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _cartItems.isEmpty
                    ? null
                    : () => _openCart(),
                tooltip: 'Sepet',
              ),
              if (_cartItems.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _cartItems.fold<int>(0, (sum, item) => sum + item.quantity).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _menuItems.isEmpty
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
                        'Henüz menü öğesi eklenmemiş',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
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
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Bu kategoride menü öğesi yok',
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
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Menü öğesi ikonu
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.restaurant,
                                            color: Colors.orange[700],
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Menü öğesi bilgileri
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (item.description.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.description,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue[100],
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      item.categoryName,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.blue[900],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    '${item.price.toStringAsFixed(2)} ₺',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Sepete ekle butonu
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.add_shopping_cart),
                                          color: Theme.of(context).colorScheme.primary,
                                          onPressed: () => _addToCart(item),
                                          tooltip: 'Sepete Ekle',
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

  void _addToCart(MenuItem item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (cartItem) => cartItem.menuItem.id == item.id,
      );

      if (existingIndex >= 0) {
        // Eğer sepette varsa miktarını artır
        _cartItems[existingIndex].quantity++;
      } else {
        // Yoksa yeni ekle
        _cartItems.add(CartItem(menuItem: item, quantity: 1));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} sepete eklendi'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Sepete Git',
          textColor: Colors.white,
          onPressed: () => _openCart(),
        ),
      ),
    );
  }

  void _openCart() {
    if (_cartItems.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          cartItems: _cartItems,
          businessId: widget.businessId,
          businessName: _businessName ?? 'İşletme',
          onOrderPlaced: () {
            setState(() {
              _cartItems.clear();
            });
          },
        ),
      ),
    );
  }
}

