import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/campaign_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/menu_service.dart';
import 'campaign_form_screen.dart';

class CampaignManagementScreen extends StatefulWidget {
  const CampaignManagementScreen({super.key});

  @override
  State<CampaignManagementScreen> createState() => _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
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
      final user = _authService.currentUser;
      if (user == null) return;

      final campaigns = await _campaignService.getBusinessCampaigns(user.uid);
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

  Future<void> _deleteCampaign(Campaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kampanyayı Sil'),
        content: Text('${campaign.title} kampanyasını silmek istediğinize emin misiniz?'),
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

    if (confirmed == true && campaign.id != null) {
      try {
        await _campaignService.deleteCampaign(campaign.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kampanya silindi'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadCampaigns();
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

  Future<void> _toggleCampaignStatus(Campaign campaign) async {
    try {
      final updatedCampaign = Campaign(
        id: campaign.id,
        businessId: campaign.businessId,
        businessName: campaign.businessName,
        title: campaign.title,
        description: campaign.description,
        requiredQuantity: campaign.requiredQuantity,
        freeQuantity: campaign.freeQuantity,
        applicableMenuItemId: campaign.applicableMenuItemId,
        applicableMenuItemName: campaign.applicableMenuItemName,
        startDate: campaign.startDate,
        endDate: campaign.endDate,
        isActive: !campaign.isActive,
        createdAt: campaign.createdAt,
        updatedAt: campaign.updatedAt,
      );

      await _campaignService.updateCampaign(updatedCampaign);
      _loadCampaigns();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampanya Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final user = _authService.currentUser;
              if (user == null) return;

              final userService = UserService();
              final userData = await userService.getUserData(user.uid);
              final businessName = userData?['businessName'] ?? 'İşletme';

              final menuService = MenuService();
              final menuItems = await menuService.getMenuItems(user.uid);

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampaignFormScreen(
                    businessId: user.uid,
                    businessName: businessName,
                    menuItems: menuItems,
                  ),
                ),
              );

              if (result == true) {
                _loadCampaigns();
              }
            },
            tooltip: 'Yeni Kampanya Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
              ? Center(
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
                        'Henüz kampanya eklenmemiş',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _campaigns.length,
                  itemBuilder: (context, index) {
                    final campaign = _campaigns[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: campaign.isValid && campaign.isActive
                              ? Colors.green
                              : Colors.grey,
                          child: Icon(
                            campaign.isValid && campaign.isActive
                                ? Icons.check
                                : Icons.close,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          campaign.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(campaign.description),
                            const SizedBox(height: 4),
                            Text(
                              '${campaign.requiredQuantity} al ${campaign.freeQuantity} bedava',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (campaign.applicableMenuItemName != null)
                              Text(
                                'Ürün: ${campaign.applicableMenuItemName}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            if (campaign.endDate != null)
                              Text(
                                'Bitiş: ${campaign.endDate!.day}/${campaign.endDate!.month}/${campaign.endDate!.year}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Düzenle'),
                                ],
                              ),
                              onTap: () async {
                                final user = _authService.currentUser;
                                if (user == null) return;

                                final userService = UserService();
                                final userData = await userService.getUserData(user.uid);
                                final businessName = userData?['businessName'] ?? 'İşletme';

                                final menuService = MenuService();
                                final menuItems = await menuService.getMenuItems(user.uid);

                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CampaignFormScreen(
                                      businessId: user.uid,
                                      businessName: businessName,
                                      menuItems: menuItems,
                                      campaign: campaign,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _loadCampaigns();
                                }
                              },
                            ),
                            PopupMenuItem(
                              child: Row(
                                children: [
                                  Icon(
                                    campaign.isActive
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    campaign.isActive
                                        ? 'Pasif Yap'
                                        : 'Aktif Yap',
                                  ),
                                ],
                              ),
                              onTap: () => _toggleCampaignStatus(campaign),
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sil',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              onTap: () => _deleteCampaign(campaign),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

