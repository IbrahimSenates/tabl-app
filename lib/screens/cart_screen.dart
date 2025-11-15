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
    } catch (e) {
      // Hata durumunda devam et
      print('Kampanya verileri yüklenirken hata: $e');
    }
  }

  // Ürün fiyatını hesapla (kampanya varsa 0)
  double _getItemPrice(cartItem) {
    final item = cartItem.menuItem;
    for (final campaign in _activeCampaignsMap.values) {
      final progress = _campaignProgressMap[campaign.id ?? ''];
      if (progress == null || !progress.isCompleted) continue;

      if (campaign.applicableMenuItemId == null) {
        // Tüm ürünler için kampanya
        return 0.0;
      } else if (campaign.applicableMenuItemId == item.id) {
        // Belirli ürün için kampanya
        return 0.0;
      }
    }
    return item.price;
  }

  double get _totalAmount {
    return widget.cartItems.fold(0.0, (sum, cartItem) {
      final itemPrice = _getItemPrice(cartItem);
      return sum + (itemPrice * cartItem.quantity);
    });
  }

  // Kampanya tamamlandıysa ve bedava ürün kullanıldıysa ilerlemeyi sıfırla
  Future<void> _resetCampaignProgressIfUsed() async {
    try {
      for (final cartItem in widget.cartItems) {
        final itemPrice = _getItemPrice(cartItem);
        if (itemPrice == 0.0) {
          // Bedava ürün kullanıldı, ilgili kampanyaları bul ve ilerlemeyi sıfırla
          for (final campaign in _activeCampaignsMap.values) {
            final progress = _campaignProgressMap[campaign.id ?? ''];
            if (progress == null || !progress.isCompleted) continue;

            bool shouldReset = false;
            if (campaign.applicableMenuItemId == null) {
              // Tüm ürünler için kampanya
              shouldReset = true;
            } else if (campaign.applicableMenuItemId == cartItem.menuItem.id) {
              // Belirli ürün için kampanya
              shouldReset = true;
            }

            if (shouldReset && progress.id != null) {
              // İlerlemeyi sıfırla
              await _campaignService.resetProgress(progress.id!);
            }
          }
        }
      }
    } catch (e) {
      // Hata durumunda devam et
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
      final orderItems = widget.cartItems.map((cartItem) {
        // Kampanya kontrolü yap - eğer bedava ise fiyatı 0 yap
        final itemPrice = _getItemPrice(cartItem);
        return OrderItem(
          menuItemId: cartItem.menuItem.id ?? '',
          name: cartItem.menuItem.name,
          price: itemPrice, // Kampanya fiyatı
          quantity: cartItem.quantity,
        );
      }).toList();

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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.orange[700],
                            ),
                          ),
                          title: Text(
                            cartItem.menuItem.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Builder(
                            builder: (context) {
                              final itemPrice = _getItemPrice(cartItem);
                              final isFree = itemPrice == 0.0;
                              final originalPrice = cartItem.menuItem.price;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isFree && originalPrice > 0)
                                    Text(
                                      '${originalPrice.toStringAsFixed(2)} ₺ x ${cartItem.quantity}',
                                      style: TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    isFree
                                        ? '0.00 ₺ x ${cartItem.quantity} (BEDAVA)'
                                        : '${itemPrice.toStringAsFixed(2)} ₺ x ${cartItem.quantity}',
                                    style: TextStyle(
                                      color: isFree ? Colors.green[700] : null,
                                      fontWeight: isFree
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          trailing: Builder(
                            builder: (context) {
                              final itemPrice = _getItemPrice(cartItem);
                              final itemTotal = itemPrice * cartItem.quantity;
                              final isFree = itemPrice == 0.0;
                              return Text(
                                '${itemTotal.toStringAsFixed(2)} ₺',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isFree ? Colors.green : Colors.orange,
                                ),
                              );
                            },
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
