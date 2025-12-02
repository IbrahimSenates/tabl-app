import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/campaign_service.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final String businessId;
  final String businessName;
  final VoidCallback onOrderPlaced;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.businessId,
    required this.businessName,
    required this.onOrderPlaced,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _orderService = OrderService();
  final _authService = AuthService();
  final _campaignService = CampaignService();
  final _noteController = TextEditingController();
  bool _isPlacingOrder = false;
  Map<String, CampaignProgress> _campaignProgressMap = {};
  Map<String, Campaign> _activeCampaignsMap = {};
  Map<CartItem, int> _itemFreeQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadCampaignData();
  }

  Future<void> _loadCampaignData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Aktif kampanyaları al
      final campaigns = await _campaignService.getActiveCampaigns(
        widget.businessId,
      );
      final campaignsMap = <String, Campaign>{};
      for (final campaign in campaigns) {
        if (campaign.id != null) {
          campaignsMap[campaign.id!] = campaign;
        }
      }

      // Kampanya ilerlemelerini al
      final progresses = await _campaignService.getCustomerProgresses(
        customerId: user.uid,
        businessId: widget.businessId,
      );
      final progressMap = <String, CampaignProgress>{};
      for (final progress in progresses) {
        progressMap[progress.campaignId] = progress;
      }

      setState(() {
        _activeCampaignsMap = campaignsMap;
        _campaignProgressMap = progressMap;
      });
      
      _calculateFreeQuantities();
    } catch (e) {
      // Hata durumunda devam et
      print('Kampanya verileri yüklenirken hata: $e');
    }
  }

  void _updateQuantity(CartItem item, int newQuantity) {
    setState(() {
      item.quantity = newQuantity;
    });
    _calculateFreeQuantities();
  }

  void _removeItem(CartItem item) {
    setState(() {
      widget.cartItems.remove(item);
    });
    _calculateFreeQuantities();
  }

  void _calculateFreeQuantities() {
    final freeQuantities = <CartItem, int>{};
    
    // Her kampanya için kalan bedava hakkını takip et
    final campaignRemainingFree = <String, int>{};
    
    for (final campaign in _activeCampaignsMap.values) {
      final progress = _campaignProgressMap[campaign.id ?? ''];
      if (progress != null && progress.isCompleted) {
        campaignRemainingFree[campaign.id!] = campaign.freeQuantity;
      }
    }

    // Sepetteki her ürün için kontrol et
    for (final cartItem in widget.cartItems) {
      int freeQty = 0;
      
      for (final campaignId in campaignRemainingFree.keys) {
        final campaign = _activeCampaignsMap[campaignId];
        final remaining = campaignRemainingFree[campaignId] ?? 0;
        
        if (remaining <= 0) continue;
        if (campaign == null) continue;

        bool isApplicable = false;
        if (campaign.applicableMenuItemId == null) {
          // Tüm ürünler için geçerli
          isApplicable = true;
        } else if (campaign.applicableMenuItemId == cartItem.menuItem.id) {
          // Belirli ürün için geçerli
          isApplicable = true;
        }

        if (isApplicable) {
          // Bu ürün için ne kadar bedava kullanabiliriz?
          // Ürünün adedi ile kampanyadan kalan hak arasından küçük olanı al
          final canTake = (cartItem.quantity - freeQty).clamp(0, remaining);
          
          if (canTake > 0) {
            freeQty += canTake;
            campaignRemainingFree[campaignId] = remaining - canTake;
          }
        }
      }
      
      freeQuantities[cartItem] = freeQty;
    }

    setState(() {
      _itemFreeQuantities = freeQuantities;
    });
  }

  double get _totalAmount {
    return widget.cartItems.fold(0.0, (sum, cartItem) {
      final freeQty = _itemFreeQuantities[cartItem] ?? 0;
      final paidQty = cartItem.quantity - freeQty;
      return sum + (cartItem.menuItem.price * paidQty);
    });
  }

  // Kampanya tamamlandıysa ve bedava ürün kullanıldıysa ilerlemeyi sıfırla
  Future<void> _resetCampaignProgressIfUsed() async {
    try {
      final usedCampaignIds = <String>{};

      // Hangi kampanyaların kullanıldığını tespit et (basit bir yaklaşım)
      // _calculateFreeQuantities mantığını tekrar çalıştırıp hangi kampanyadan düştüğünü bulabiliriz
      // veya sadece bedava ürün varsa ve o ürünü kapsayan tamamlanmış kampanya varsa sıfırlarız.
      
      // Daha güvenli yaklaşım: Eğer toplamda herhangi bir bedava ürün kullandıysak,
      // bu bedava ürünlerin kaynağı olan kampanyaları sıfırla.
      
      bool anyFreeUsed = _itemFreeQuantities.values.any((qty) => qty > 0);
      if (!anyFreeUsed) return;

      // Tekrar hesaplama yaparak hangi kampanyaların kullanıldığını bul
      final campaignRemainingFree = <String, int>{};
      for (final campaign in _activeCampaignsMap.values) {
        final progress = _campaignProgressMap[campaign.id ?? ''];
        if (progress != null && progress.isCompleted) {
          campaignRemainingFree[campaign.id!] = campaign.freeQuantity;
        }
      }

      for (final cartItem in widget.cartItems) {
        int neededFree = _itemFreeQuantities[cartItem] ?? 0;
        if (neededFree <= 0) continue;

        for (final campaignId in campaignRemainingFree.keys) {
          if (neededFree <= 0) break;
          
          final campaign = _activeCampaignsMap[campaignId];
          final remaining = campaignRemainingFree[campaignId] ?? 0;
          
          if (remaining <= 0) continue;
          if (campaign == null) continue;

          bool isApplicable = false;
          if (campaign.applicableMenuItemId == null) {
            isApplicable = true;
          } else if (campaign.applicableMenuItemId == cartItem.menuItem.id) {
            isApplicable = true;
          }

          if (isApplicable) {
            final used = neededFree.clamp(0, remaining);
            if (used > 0) {
              usedCampaignIds.add(campaignId);
              campaignRemainingFree[campaignId] = remaining - used;
              neededFree -= used;
            }
          }
        }
      }

      for (final campaignId in usedCampaignIds) {
        final progress = _campaignProgressMap[campaignId];
        if (progress != null && progress.id != null) {
          await _campaignService.resetProgress(progress.id!);
        }
      }
    } catch (e) {
      print('Kampanya ilerlemesi sıfırlanırken hata: $e');
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sipariş vermek için giriş yapmanız gerekiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sepetiniz boş'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final orderItems = <OrderItem>[];
      
      for (final cartItem in widget.cartItems) {
        final freeQty = _itemFreeQuantities[cartItem] ?? 0;
        final paidQty = cartItem.quantity - freeQty;

        // Ücretli kısım
        if (paidQty > 0) {
          orderItems.add(OrderItem(
            menuItemId: cartItem.menuItem.id ?? '',
            name: cartItem.menuItem.name,
            price: cartItem.menuItem.price,
            quantity: paidQty,
          ));
        }

        // Bedava kısım
        if (freeQty > 0) {
          orderItems.add(OrderItem(
            menuItemId: cartItem.menuItem.id ?? '',
            name: '${cartItem.menuItem.name} (Kampanya)',
            price: 0.0,
            quantity: freeQty,
          ));
        }
      }

      final order = Order(
        customerId: user.uid,
        businessId: widget.businessId,
        businessName: widget.businessName,
        items: orderItems,
        totalAmount: _totalAmount,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      await _orderService.createOrder(order);

      // Kampanya tamamlandıysa ve bedava ürün kullanıldıysa ilerlemeyi sıfırla
      await _resetCampaignProgressIfUsed();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Siparişiniz başarıyla oluşturuldu!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onOrderPlaced();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isPlacingOrder = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sipariş verilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sepetim')),
      body: widget.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sepetiniz boş',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.cartItems.length,
                    itemBuilder: (context, index) {
                      final cartItem = widget.cartItems[index];
                      final freeQty = _itemFreeQuantities[cartItem] ?? 0;
                      final paidQty = cartItem.quantity - freeQty;
                      final itemTotal = paidQty * cartItem.menuItem.price;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Ürün Resmi / İkonu
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: cartItem.menuItem.imageUrl != null &&
                                            cartItem.menuItem.imageUrl!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              cartItem.menuItem.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(
                                                Icons.restaurant,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.restaurant,
                                            color: Colors.orange[700],
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Ürün Bilgileri
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cartItem.menuItem.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _removeItem(cartItem),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (paidQty > 0)
                                          Text(
                                            '$paidQty x ${cartItem.menuItem.price.toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                                color: Colors.grey[800],
                                                fontSize: 13),
                                          ),
                                        if (freeQty > 0)
                                          Text(
                                            '$freeQty x BEDAVA (Kampanya)',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Miktar Kontrolü
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 20),
                                          onPressed: () {
                                            if (cartItem.quantity > 1) {
                                              _updateQuantity(
                                                  cartItem, cartItem.quantity - 1);
                                            } else {
                                              _removeItem(cartItem);
                                            }
                                          },
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
                                        Text(
                                          '${cartItem.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 20),
                                          onPressed: () => _updateQuantity(
                                              cartItem, cartItem.quantity + 1),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Toplam Fiyat
                                  Text(
                                    '${itemTotal.toStringAsFixed(2)} ₺',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.orange,
                                    ),
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
                // Not alanı
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Sipariş Notu (Opsiyonel)',
                      hintText: 'Özel isteklerinizi buraya yazabilirsiniz',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                ),
                // Toplam ve sipariş ver butonu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Toplam:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_totalAmount.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPlacingOrder ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isPlacingOrder
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
                              : const Text(
                                  'Sipariş Ver',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
