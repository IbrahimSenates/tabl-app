import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/campaign_service.dart';

class BusinessOrdersScreen extends StatefulWidget {
  const BusinessOrdersScreen({super.key});

  @override
  State<BusinessOrdersScreen> createState() => _BusinessOrdersScreenState();
}

class _BusinessOrdersScreenState extends State<BusinessOrdersScreen> {
  final _orderService = OrderService();
  final _authService = AuthService();
  final _campaignService = CampaignService();
  List<Order> _orders = [];
  bool _isLoading = true;
  OrderStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final orders = await _orderService.getBusinessOrders(user.uid);
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Siparişler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Order> get _filteredOrders {
    if (_selectedStatus == null) {
      return _orders;
    }
    return _orders.where((order) => order.status == _selectedStatus).toList();
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      if (order.id == null) return;

      // Eski durumu kontrol et
      final wasCompleted = order.status == OrderStatus.completed;
      final willBeCompleted = newStatus == OrderStatus.completed;

      await _orderService.updateOrderStatus(order.id!, newStatus);

      // Sipariş tamamlandıysa ve daha önce tamamlanmamışsa kampanya ilerlemesini güncelle
      if (willBeCompleted && !wasCompleted) {
        await _updateCampaignProgress(order);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sipariş durumu "${_getStatusText(newStatus)}" olarak güncellendi',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateCampaignProgress(Order order) async {
    try {
      // İşletmenin aktif kampanyalarını al
      final campaigns = await _campaignService.getActiveCampaigns(
        order.businessId,
      );
      print(
        'Kampanya ilerlemesi güncelleniyor. Toplam kampanya: ${campaigns.length}',
      );

      for (final campaign in campaigns) {
        if (campaign.id == null) {
          print('Kampanya ID null, atlanıyor');
          continue;
        }

        // Kampanyanın uygulanabilir ürünlerini kontrol et
        for (final orderItem in order.items) {
          bool shouldUpdate = false;

          if (campaign.applicableMenuItemId == null) {
            // Tüm ürünler için kampanya
            shouldUpdate = true;
          } else if (campaign.applicableMenuItemId == orderItem.menuItemId) {
            // Belirli ürün için kampanya
            shouldUpdate = true;
          }

          if (shouldUpdate) {
            print(
              'Kampanya ilerlemesi güncelleniyor: ${campaign.title}, Müşteri: ${order.customerId}, Miktar: ${orderItem.quantity}',
            );
            // Kampanya ilerlemesini güncelle
            await _campaignService.updateProgress(
              customerId: order.customerId,
              campaignId: campaign.id!,
              businessId: order.businessId,
              quantity: orderItem.quantity,
            );
            print('Kampanya ilerlemesi güncellendi: ${campaign.title}');
          }
        }
      }
    } catch (e) {
      // Kampanya güncelleme hatası kritik değil, sadece log
      print('Kampanya ilerlemesi güncellenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kampanya ilerlemesi güncellenirken hata: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Beklemede';
      case OrderStatus.confirmed:
        return 'Onaylandı';
      case OrderStatus.preparing:
        return 'Hazırlanıyor';
      case OrderStatus.ready:
        return 'Hazır';
      case OrderStatus.completed:
        return 'Tamamlandı';
      case OrderStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.check_circle;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Durum filtresi
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: OrderStatus.values.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Tümü'),
                            selected: _selectedStatus == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatus = null;
                              });
                            },
                          ),
                        );
                      }
                      final status = OrderStatus.values[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getStatusText(status)),
                          selected: _selectedStatus == status,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatus = selected ? status : null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Sipariş listesi
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedStatus == null
                                    ? 'Henüz sipariş yok'
                                    : 'Bu durumda sipariş yok',
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
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(
                                    order.status,
                                  ).withOpacity(0.2),
                                  child: Icon(
                                    _getStatusIcon(order.status),
                                    color: _getStatusColor(order.status),
                                  ),
                                ),
                                title: Text(
                                  'Sipariş #${order.id?.substring(0, 8) ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${order.items.length} ürün • ${order.totalAmount.toStringAsFixed(2)} ₺',
                                    ),
                                    if (order.createdAt != null)
                                      Text(
                                        '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} ${order.createdAt!.hour}:${order.createdAt!.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    _getStatusText(order.status),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: _getStatusColor(
                                    order.status,
                                  ).withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _getStatusColor(order.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Sipariş öğeleri
                                        const Text(
                                          'Sipariş Detayları:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...order.items.map(
                                          (item) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${item.quantity}x ${item.name}',
                                                ),
                                                Text(
                                                  '${item.total.toStringAsFixed(2)} ₺',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Toplam:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            Text(
                                              '${order.totalAmount.toStringAsFixed(2)} ₺',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (order.customerNote != null &&
                                            order.customerNote!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.note,
                                                  size: 20,
                                                  color: Colors.blue[700],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    order.customerNote!,
                                                    style: TextStyle(
                                                      color: Colors.blue[900],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        // Durum güncelleme butonları
                                        const Text(
                                          'Durum Güncelle:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (order.status ==
                                                OrderStatus.pending)
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _updateOrderStatus(
                                                      order,
                                                      OrderStatus.confirmed,
                                                    ),
                                                icon: const Icon(
                                                  Icons.check,
                                                  size: 18,
                                                ),
                                                label: const Text('Onayla'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                ),
                                              ),
                                            if (order.status ==
                                                OrderStatus.confirmed)
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _updateOrderStatus(
                                                      order,
                                                      OrderStatus.preparing,
                                                    ),
                                                icon: const Icon(
                                                  Icons.restaurant,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Hazırlanıyor',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.purple,
                                                ),
                                              ),
                                            if (order.status ==
                                                OrderStatus.preparing)
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _updateOrderStatus(
                                                      order,
                                                      OrderStatus.ready,
                                                    ),
                                                icon: const Icon(
                                                  Icons.check_circle,
                                                  size: 18,
                                                ),
                                                label: const Text('Hazır'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                ),
                                              ),
                                            if (order.status ==
                                                OrderStatus.ready)
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _updateOrderStatus(
                                                      order,
                                                      OrderStatus.completed,
                                                    ),
                                                icon: const Icon(
                                                  Icons.done_all,
                                                  size: 18,
                                                ),
                                                label: const Text('Tamamlandı'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.grey,
                                                ),
                                              ),
                                            if (order.status !=
                                                    OrderStatus.completed &&
                                                order.status !=
                                                    OrderStatus.cancelled)
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _updateOrderStatus(
                                                      order,
                                                      OrderStatus.cancelled,
                                                    ),
                                                icon: const Icon(
                                                  Icons.cancel,
                                                  size: 18,
                                                ),
                                                label: const Text('İptal Et'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
