import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/campaign_service.dart';
import '../services/menu_service.dart';

class CampaignFormScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final List<MenuItem> menuItems;
  final Campaign? campaign;

  const CampaignFormScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.menuItems,
    this.campaign,
  });

  @override
  State<CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends State<CampaignFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requiredQuantityController = TextEditingController();
  final _freeQuantityController = TextEditingController();
  final _campaignService = CampaignService();
  bool _isLoading = false;
  bool _isActive = true;
  String? _selectedMenuItemId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) {
      _titleController.text = widget.campaign!.title;
      _descriptionController.text = widget.campaign!.description;
      _requiredQuantityController.text = widget.campaign!.requiredQuantity
          .toString();
      _freeQuantityController.text = widget.campaign!.freeQuantity.toString();
      _selectedMenuItemId = widget.campaign!.applicableMenuItemId;
      _isActive = widget.campaign!.isActive;
      _startDate = widget.campaign!.startDate;
      _endDate = widget.campaign!.endDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requiredQuantityController.dispose();
    _freeQuantityController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveCampaign() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final requiredQuantity = int.tryParse(_requiredQuantityController.text);
      final freeQuantity = int.tryParse(_freeQuantityController.text);

      if (requiredQuantity == null || requiredQuantity <= 0) {
        throw 'Geçerli bir miktar girin';
      }

      if (freeQuantity == null || freeQuantity <= 0) {
        throw 'Geçerli bir bedava miktar girin';
      }

      final selectedMenuItem = _selectedMenuItemId != null
          ? widget.menuItems.firstWhere(
              (item) => item.id == _selectedMenuItemId,
              orElse: () => widget.menuItems.first,
            )
          : null;

      final campaign = Campaign(
        id: widget.campaign?.id,
        businessId: widget.businessId,
        businessName: widget.businessName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requiredQuantity: requiredQuantity,
        freeQuantity: freeQuantity,
        applicableMenuItemId: _selectedMenuItemId,
        applicableMenuItemName: selectedMenuItem?.name,
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
        createdAt: widget.campaign?.createdAt,
        updatedAt: widget.campaign?.updatedAt,
      );

      if (widget.campaign == null) {
        await _campaignService.createCampaign(campaign);
      } else {
        await _campaignService.updateCampaign(campaign);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.campaign == null
                  ? 'Kampanya eklendi'
                  : 'Kampanya güncellendi',
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
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.campaign != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Kampanya Düzenle' : 'Yeni Kampanya'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Kampanya Başlığı *',
                  hintText: 'Örn: 5 Kahve İçene 1 Bedava',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen kampanya başlığını girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Kampanya hakkında detaylı bilgi',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // X al Y bedava
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _requiredQuantityController,
                      decoration: const InputDecoration(
                        labelText: 'Alınacak Miktar (X) *',
                        hintText: '5',
                        prefixIcon: Icon(Icons.shopping_cart),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Gerekli';
                        }
                        final quantity = int.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Geçerli bir sayı girin';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _freeQuantityController,
                      decoration: const InputDecoration(
                        labelText: 'Bedava Miktar (Y) *',
                        hintText: '1',
                        prefixIcon: Icon(Icons.free_breakfast),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Gerekli';
                        }
                        final quantity = int.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Geçerli bir sayı girin';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ürün seçimi (opsiyonel)
              DropdownButtonFormField<String>(
                initialValue: _selectedMenuItemId,
                decoration: const InputDecoration(
                  labelText: 'Uygulanacak Ürün (Opsiyonel)',
                  hintText: 'Tüm ürünler için boş bırakın',
                  prefixIcon: Icon(Icons.restaurant),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tüm Ürünler'),
                  ),
                  ...widget.menuItems.map((item) {
                    return DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMenuItemId = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Başlangıç tarihi
              ListTile(
                title: const Text('Başlangıç Tarihi (Opsiyonel)'),
                subtitle: Text(
                  _startDate != null
                      ? DateFormat('dd/MM/yyyy').format(_startDate!)
                      : 'Seçilmedi',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(true),
              ),
              const SizedBox(height: 8),

              // Bitiş tarihi
              ListTile(
                title: const Text('Bitiş Tarihi (Opsiyonel)'),
                subtitle: Text(
                  _endDate != null
                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                      : 'Seçilmedi',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(false),
              ),
              const SizedBox(height: 16),

              // Aktif durumu
              SwitchListTile(
                title: const Text('Aktif'),
                subtitle: const Text('Kampanya aktif mi?'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                secondary: Icon(
                  _isActive ? Icons.check_circle : Icons.cancel,
                  color: _isActive ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCampaign,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
