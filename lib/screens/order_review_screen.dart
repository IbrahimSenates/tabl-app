import 'package:flutter/material.dart';
import '../services/review_service.dart';
import '../services/order_service.dart';

class OrderReviewScreen extends StatefulWidget {
  final Order order;

  const OrderReviewScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  final _reviewService = ReviewService();
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  Review? _existingReview;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReview() async {
    try {
      final review = await _reviewService.getReviewByOrderId(widget.order.id ?? '');
      if (review != null) {
        setState(() {
          _existingReview = review;
          _rating = review.rating;
          _commentController.text = review.comment ?? '';
        });
      }
    } catch (e) {
      print('Mevcut yorum yüklenirken hata: $e');
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen puan verin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final review = Review(
        orderId: widget.order.id ?? '',
        customerId: widget.order.customerId,
        businessId: widget.order.businessId,
        businessName: widget.order.businessName,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      await _reviewService.createOrUpdateReview(review);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorumunuz kaydedildi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true döndür ki parent sayfa yenilensin
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorum kaydedilirken hata oluştu: $e'),
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
        title: const Text('Siparişi Değerlendir'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sipariş bilgisi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sipariş #${widget.order.id?.substring(0, 8) ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.order.businessName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.order.items.length} ürün • ${widget.order.totalAmount.toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Puanlama
            const Text(
              'Puanınız:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = starIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starIndex <= _rating
                            ? Icons.star
                            : Icons.star_border,
                        size: 48,
                        color: starIndex <= _rating
                            ? Colors.amber
                            : Colors.grey[400],
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _getRatingText(_rating),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            
            // Yorum
            const Text(
              'Yorumunuz (Opsiyonel):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Deneyiminizi paylaşın...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment),
              ),
              maxLines: 6,
              maxLength: 500,
            ),
            const SizedBox(height: 32),
            
            // Gönder butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _existingReview != null
                            ? 'Yorumu Güncelle'
                            : 'Yorumu Gönder',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Çok Kötü';
      case 2:
        return 'Kötü';
      case 3:
        return 'Orta';
      case 4:
        return 'İyi';
      case 5:
        return 'Mükemmel';
      default:
        return '';
    }
  }
}

