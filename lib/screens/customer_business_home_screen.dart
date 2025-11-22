import 'package:flutter/material.dart';
import '../services/menu_service.dart';
import '../services/campaign_service.dart';
import '../services/order_service.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';
import '../models/cart_item.dart';
import 'cart_screen.dart';
import 'order_review_screen.dart';
import 'ai_assistant_screen.dart';

import '../services/session_service.dart';

class CustomerBusinessHomeScreen extends StatefulWidget {
  final String businessId;

  const CustomerBusinessHomeScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<CustomerBusinessHomeScreen> createState() => _CustomerBusinessHomeScreenState();
}

class _CustomerBusinessHomeScreenState extends State<CustomerBusinessHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _menuService = MenuService();
  final _campaignService = CampaignService();
  final _orderService = OrderService();
  final _authService = AuthService();
  final _sessionService = SessionService(); // SessionService instance
  
  late TabController _tabController;
  String? _businessName;
  List<CartItem> _cartItems = [];
  Offset _aiButtonPosition = const Offset(16, 0); // AI buton pozisyonu

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observer ekle
    _tabController = TabController(length: 3, vsync: this);
    _loadBusinessInfo();
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      // Eğer kullanıcı giriş yapmamışsa anonim giriş yap
      if (_authService.currentUser == null) {
        await _authService.signInAnonymously();
      }
      // Oturumu başlat
      await _sessionService.createOrUpdateSession(businessId: widget.businessId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oturum başarıyla başlatıldı'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oturum hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Uygulama arka plana atıldığında veya kapatıldığında oturumu sonlandır
      _sessionService.endSession(widget.businessId);
    } else if (state == AppLifecycleState.resumed) {
      // Uygulama tekrar açıldığında oturumu yenile
      _sessionService.createOrUpdateSession(businessId: widget.businessId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Observer kaldır
    _sessionService.endSession(widget.businessId); // Sayfa kapandığında oturumu sonlandır
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessInfo() async {
    try {
      final menuData = await _menuService.getMenu(widget.businessId);
      setState(() {
        _businessName = menuData?['businessName'] ?? 'İşletme';
      });
    } catch (e) {
      print('İşletme bilgisi yüklenirken hata: $e');
    }
  }

  void _addToCart(CartItem cartItem) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (item) => item.menuItem.id == cartItem.menuItem.id,
      );

      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity += cartItem.quantity;
      } else {
        _cartItems.add(cartItem);
      }
    });
  }

  void _updateCartItems(List<CartItem> items) {
    setState(() {
      _cartItems = items;
    });
  }

  void _openCart() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sepetiniz boş'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
    ).then((_) {
      // Sepet ekranından dönünce cart items'ı güncelle
      setState(() {});
    });
  }

  int get _cartItemCount {
    return _cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_businessName ?? 'İşletme'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menü'),
            Tab(icon: Icon(Icons.local_offer), text: 'Kampanyalar'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Siparişler'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _MenuTab(
                businessId: widget.businessId,
                onAddToCart: _addToCart,
              ),
              _CampaignsTab(
                businessId: widget.businessId,
              ),
              _OrdersTab(
                businessId: widget.businessId,
              ),
            ],
          ),
          // AI Asistan butonu - sürüklenebilir
          LayoutBuilder(
            builder: (context, constraints) {
              final buttonSize = 56.0; // FloatingActionButton boyutu
              final bottomOffset = _cartItemCount > 0 ? 80.0 : 16.0;
              
              return Positioned(
                left: _aiButtonPosition.dx.clamp(0.0, constraints.maxWidth - buttonSize),
                bottom: (_aiButtonPosition.dy + bottomOffset).clamp(
                  bottomOffset, 
                  constraints.maxHeight - buttonSize + bottomOffset
                ),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      // Yeni pozisyonu hesapla
                      double newX = _aiButtonPosition.dx + details.delta.dx;
                      double newY = _aiButtonPosition.dy - details.delta.dy;
                      
                      // Ekran sınırları içinde tut
                      newX = newX.clamp(0.0, constraints.maxWidth - buttonSize);
                      newY = newY.clamp(0.0, constraints.maxHeight - buttonSize - bottomOffset);
                      
                      _aiButtonPosition = Offset(newX, newY);
                    });
                  },
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AIAssistantScreen(
                            businessId: widget.businessId,
                          ),
                        ),
                      );
                    },
                    backgroundColor: Colors.orange,
                    child: Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                    ),
                    tooltip: 'AI Asistan',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: _openCart,
              icon: Stack(
                children: [
                  const Icon(Icons.shopping_cart),
                  Positioned(
                    right: 0,
                    top: 0,
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
                        _cartItemCount.toString(),
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
              label: Text('Sepet ($_cartItemCount)'),
            )
          : null,
    );
  }
}

// Menü Sekmesi
class _MenuTab extends StatefulWidget {
  final String businessId;
  final Function(CartItem) onAddToCart;

  const _MenuTab({
    required this.businessId,
    required this.onAddToCart,
  });

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  final _menuService = MenuService();
  final _campaignService = CampaignService();
  final _authService = AuthService();
  List<MenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;
  String? _selectedCategoryId;
  Map<String, CampaignProgress> _campaignProgressMap = {};
  Map<String, Campaign> _activeCampaignsMap = {};

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
      final categories = await _menuService.getCategories(widget.businessId);
      final menuItems = await _menuService.getMenuItems(widget.businessId);
      final availableItems = menuItems.where((item) => item.isAvailable).toList();

      final user = _authService.currentUser;
      Map<String, CampaignProgress> progressMap = {};
      Map<String, Campaign> campaignsMap = {};
      if (user != null) {
        try {
          final campaigns = await _campaignService.getActiveCampaigns(widget.businessId);
          for (final campaign in campaigns) {
            if (campaign.id != null) {
              campaignsMap[campaign.id!] = campaign;
            }
          }

          final progresses = await _campaignService.getCustomerProgresses(
            customerId: user.uid,
            businessId: widget.businessId,
          );
          for (final progress in progresses) {
            progressMap[progress.campaignId] = progress;
          }
        } catch (e) {
          print('Kampanya ilerlemesi yüklenirken hata: $e');
        }
      }

      setState(() {
        _categories = categories;
        _menuItems = availableItems;
        _campaignProgressMap = progressMap;
        _activeCampaignsMap = campaignsMap;
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

  double _getItemPrice(MenuItem item) {
    for (final campaign in _activeCampaignsMap.values) {
      final progress = _campaignProgressMap[campaign.id ?? ''];
      if (progress == null || !progress.isCompleted) continue;

      if (campaign.applicableMenuItemId == null) {
        return 0.0;
      } else if (campaign.applicableMenuItemId == item.id) {
        return 0.0;
      }
    }
    return item.price;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_menuItems.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: Column(
        children: [
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
                    final displayPrice = _getItemPrice(item);
                    final isFree = displayPrice == 0.0;
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
                            // Ürün fotoğrafı veya placeholder
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
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
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.restaurant,
                                      color: Colors.orange[700],
                                      size: 32,
                                    ),
                            ),
                            const SizedBox(width: 16),
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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (isFree)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green[100],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'BEDAVA',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[900],
                                                ),
                                              ),
                                            ),
                                          if (isFree && item.price > 0)
                                            Text(
                                              '${item.price.toStringAsFixed(2)} ₺',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600],
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          Text(
                                            isFree
                                                ? '0.00 ₺'
                                                : '${item.price.toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isFree ? Colors.green[700] : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () {
                                widget.onAddToCart(CartItem(menuItem: item, quantity: 1));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFree
                                          ? '${item.name} sepete eklendi (BEDAVA)'
                                          : '${item.name} sepete eklendi',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
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
}

// Kampanyalar Sekmesi
class _CampaignsTab extends StatefulWidget {
  final String businessId;

  const _CampaignsTab({
    required this.businessId,
  });

  @override
  State<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<_CampaignsTab> {
  final _campaignService = CampaignService();
  final _authService = AuthService();
  List<Campaign> _campaigns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final campaigns = await _campaignService.getActiveCampaigns(widget.businessId);
      setState(() {
        _campaigns = campaigns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kampanyalar yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz aktif kampanya yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: StreamBuilder<List<CampaignProgress>>(
        stream: () {
          final user = _authService.currentUser;
          if (user == null) {
            return Stream.value(<CampaignProgress>[]);
          }
          return _campaignService.getCustomerProgressesStream(
            customerId: user.uid,
            businessId: widget.businessId,
          );
        }(),
        builder: (context, progressSnapshot) {
          final progressMap = <String, CampaignProgress>{};
          if (progressSnapshot.hasData) {
            for (final progress in progressSnapshot.data!) {
              progressMap[progress.campaignId] = progress;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _campaigns.length,
            itemBuilder: (context, index) {
            final campaign = _campaigns[index];
            final progress = progressMap[campaign.id ?? ''];
            final currentProgress = progress?.progress ?? 0;
            final requiredProgress = campaign.requiredQuantity;
            final progressPercentage = requiredProgress > 0
                ? (currentProgress / requiredProgress).clamp(0.0, 1.0)
                : 0.0;
            final isCompleted = progress?.isCompleted ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.purple.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_offer,
                            color: Colors.purple[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (campaign.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  campaign.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${campaign.requiredQuantity}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${campaign.freeQuantity}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BEDAVA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (campaign.applicableMenuItemName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              campaign.applicableMenuItemName!,
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (campaign.endDate != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Bitiş: ${campaign.endDate!.day}/${campaign.endDate!.month}/${campaign.endDate!.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'İlerleme:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '$currentProgress / $requiredProgress',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCompleted
                                    ? Colors.green[700]
                                    : Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressPercentage,
                            minHeight: 20,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted ? Colors.green : Colors.purple,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.green[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Kampanya tamamlandı! Menüde ${campaign.freeQuantity} ürün bedava.',
                                    style: TextStyle(
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          );
        },
      ),
    );
  }
}

// Siparişler Sekmesi
class _OrdersTab extends StatefulWidget {
  final String businessId;

  const _OrdersTab({
    required this.businessId,
  });

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final _orderService = OrderService();
  final _reviewService = ReviewService();
  final _authService = AuthService();
  List<Order> _orders = [];
  bool _isLoading = true;
  Map<String, Review?> _reviewsMap = {};

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
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final orders = await _orderService.getCustomerOrdersByBusiness(
        customerId: user.uid,
        businessId: widget.businessId,
      );

      // Tamamlanan siparişler için yorumları yükle
      final reviewsMap = <String, Review?>{};
      for (final order in orders) {
        if (order.status == OrderStatus.completed && order.id != null) {
          try {
            final review = await _reviewService.getReviewByOrderId(order.id!);
            reviewsMap[order.id!] = review;
          } catch (e) {
            reviewsMap[order.id!] = null;
          }
        }
      }

      setState(() {
        _orders = orders;
        _reviewsMap = reviewsMap;
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

  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Siparişiniz işletme tarafından onay bekliyor.';
      case OrderStatus.confirmed:
        return 'Siparişiniz onaylandı ve hazırlanmaya başlandı.';
      case OrderStatus.preparing:
        return 'Siparişiniz hazırlanıyor.';
      case OrderStatus.ready:
        return 'Siparişiniz hazır!';
      case OrderStatus.completed:
        return 'Siparişiniz tamamlandı.';
      case OrderStatus.cancelled:
        return 'Siparişiniz iptal edildi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu işletmeden henüz sipariş vermediniz',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(order.status).withOpacity(0.2),
                child: Icon(
                  _getStatusIcon(order.status),
                  color: _getStatusColor(order.status),
                ),
              ),
              title: Text(
                'Sipariş #${order.id?.substring(0, 8) ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                backgroundColor: _getStatusColor(order.status).withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sipariş Detayları:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${item.quantity}x ${item.name}'),
                                Text(
                                  '${item.total.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note, size: 20, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.customerNote!,
                                  style: TextStyle(color: Colors.blue[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(order.status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(order.status),
                              color: _getStatusColor(order.status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getStatusDescription(order.status),
                                style: TextStyle(
                                  color: _getStatusColor(order.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tamamlanan siparişler için puanlama butonu
                      if (order.status == OrderStatus.completed) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final review = order.id != null ? _reviewsMap[order.id!] : null;
                            return Column(
                              children: [
                                if (review != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.amber[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        ...List.generate(5, (index) {
                                          return Icon(
                                            index < review.rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 20,
                                            color: Colors.amber,
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            review.comment ?? '',
                                            style: TextStyle(
                                              color: Colors.amber[900],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => OrderReviewScreen(
                                            order: order,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        // Yorum eklendi/güncellendi, siparişleri yenile
                                        _loadOrders();
                                      }
                                    },
                                    icon: Icon(
                                      review != null
                                          ? Icons.edit
                                          : Icons.star_rate,
                                    ),
                                    label: Text(
                                      review != null
                                          ? 'Yorumu Düzenle'
                                          : 'Siparişi Değerlendir',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

