import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/menu_service.dart';

class MenuItemFormScreen extends StatefulWidget {
  final String businessId;
  final List<MenuCategory> categories;
  final MenuItem? menuItem;

  const MenuItemFormScreen({
    super.key,
    required this.businessId,
    required this.categories,
    this.menuItem,
  });

  @override
  State<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends State<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _menuService = MenuService();
  bool _isLoading = false;
  String? _selectedCategoryId;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    if (widget.menuItem != null) {
      _nameController.text = widget.menuItem!.name;
      _descriptionController.text = widget.menuItem!.description;
      _priceController.text = widget.menuItem!.price.toStringAsFixed(2);
      _selectedCategoryId = widget.menuItem!.categoryId;
      _isAvailable = widget.menuItem!.isAvailable;
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir kategori seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedCategory = widget.categories
        .firstWhere((cat) => cat.id == _selectedCategoryId);

    setState(() {
      _isLoading = true;
    });

    try {
      final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
      if (price == null || price <= 0) {
        throw 'Geçerli bir fiyat girin';
      }

      final menuItem = MenuItem(
        id: widget.menuItem?.id,
        businessId: widget.businessId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        categoryId: _selectedCategoryId!,
        categoryName: selectedCategory.name,
        isAvailable: _isAvailable,
        order: widget.menuItem?.order ?? 0,
      );

      if (widget.menuItem == null) {
        await _menuService.addMenuItem(menuItem);
      } else {
        await _menuService.updateMenuItem(menuItem);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.menuItem == null
                  ? 'Menü öğesi eklendi'
                  : 'Menü öğesi güncellendi',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.menuItem != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Menü Öğesi Düzenle' : 'Yeni Menü Öğesi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ad alanı
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Menü Öğesi Adı *',
                  hintText: 'Örn: Adana Kebap',
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen menü öğesi adını girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Açıklama alanı
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Menü öğesi hakkında bilgi',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Kategori seçimi
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Lütfen bir kategori seçin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fiyat alanı
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Fiyat (₺) *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen fiyat girin';
                  }
                  final price = double.tryParse(value.replaceAll(',', '.'));
                  if (price == null || price <= 0) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mevcut durumu
              SwitchListTile(
                title: const Text('Mevcut'),
                subtitle: const Text('Menü öğesi müşterilere gösterilsin mi?'),
                value: _isAvailable,
                onChanged: (value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
                secondary: Icon(
                  _isAvailable ? Icons.check_circle : Icons.cancel,
                  color: _isAvailable ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _saveMenuItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isEditing ? 'Güncelle' : 'Kaydet',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

