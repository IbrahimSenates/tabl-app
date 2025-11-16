import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/menu_service.dart';
import '../services/storage_service.dart';

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
  final _storageService = StorageService();
  bool _isLoading = false;
  String? _selectedCategoryId;
  bool _isAvailable = true;
  File? _selectedImageFile;
  String? _currentImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.menuItem != null) {
      _nameController.text = widget.menuItem!.name;
      _descriptionController.text = widget.menuItem!.description;
      _priceController.text = widget.menuItem!.price.toStringAsFixed(2);
      _selectedCategoryId = widget.menuItem!.categoryId;
      _isAvailable = widget.menuItem!.isAvailable;
      _currentImageUrl = widget.menuItem!.imageUrl;
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

  Future<void> _pickImage() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fotoğraf Seç'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kameradan Çek'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _storageService.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _currentImageUrl = null; // Yeni resim seçildi, eski URL'i temizle
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim seçilirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImageFile = null;
      _currentImageUrl = null;
    });
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

      String? imageUrl = _currentImageUrl;

      // Yeni resim seçildiyse yükle
      if (_selectedImageFile != null) {
        setState(() {
          _isUploadingImage = true;
        });

        // Önce menü öğesini oluştur (ID almak için) - sadece yeni öğe ise
        String? menuItemId = widget.menuItem?.id;
        if (menuItemId == null) {
          // Yeni öğe ekle (resim olmadan)
          final tempMenuItem = MenuItem(
            businessId: widget.businessId,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            categoryId: _selectedCategoryId!,
            categoryName: selectedCategory.name,
            isAvailable: _isAvailable,
            order: 0,
          );
          menuItemId = await _menuService.addMenuItem(tempMenuItem);
        }

        // Eski resmi sil (varsa ve güncelleme yapılıyorsa)
        if (widget.menuItem != null && widget.menuItem!.imageUrl != null) {
          try {
            await _storageService.deleteMenuItemImage(widget.menuItem!.imageUrl!);
          } catch (e) {
            print('Eski resim silinirken hata: $e');
          }
        }

        // Yeni resmi yükle
        imageUrl = await _storageService.uploadMenuItemImage(
          businessId: widget.businessId,
          menuItemId: menuItemId!,
          imageFile: _selectedImageFile!,
        );

        setState(() {
          _isUploadingImage = false;
        });
      }

      final menuItem = MenuItem(
        id: widget.menuItem?.id,
        businessId: widget.businessId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        categoryId: _selectedCategoryId!,
        categoryName: selectedCategory.name,
        imageUrl: imageUrl,
        isAvailable: _isAvailable,
        order: widget.menuItem?.order ?? 0,
      );

      if (widget.menuItem == null && _selectedImageFile == null) {
        // Yeni öğe ve resim yok, direkt ekle
        await _menuService.addMenuItem(menuItem);
      } else if (widget.menuItem != null || _selectedImageFile != null) {
        // Güncelle (resim yüklendiyse veya mevcut öğe güncelleniyorsa)
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
        _isUploadingImage = false;
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
              // Fotoğraf seçimi
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _selectedImageFile != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImageFile!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _removeImage,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _currentImageUrl != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _currentImageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: _removeImage,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ürün Fotoğrafı',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Fotoğraf Seç'),
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 16),

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

