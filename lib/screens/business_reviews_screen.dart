import 'package:flutter/material.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';

class BusinessReviewsScreen extends StatefulWidget {
  const BusinessReviewsScreen({super.key});

  @override
  State<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends State<BusinessReviewsScreen> {
  final _reviewService = ReviewService();
  final _authService = AuthService();
  List<Review> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
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

      final reviews = await _reviewService.getBusinessReviews(user.uid);
      final averageRating = await _reviewService.getBusinessAverageRating(user.uid);

      setState(() {
        _reviews = reviews;
        _averageRating = averageRating;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorumlar yüklenirken hata oluştu: $e'),
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
        title: const Text('Puanlar ve Yorumlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_border,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz yorum yapılmamış',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: Column(
                    children: [
                      // Ortalama puan kartı
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber[400]!,
                              Colors.amber[600]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Ortalama Puan',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  ' / 5.0',
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < _averageRating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.white,
                                  size: 24,
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_reviews.length} değerlendirme',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Yorumlar listesi
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Yıldızlar
                                        ...List.generate(5, (starIndex) {
                                          return Icon(
                                            starIndex < review.rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 20,
                                            color: Colors.amber,
                                          );
                                        }),
                                        const Spacer(),
                                        // Tarih
                                        if (review.createdAt != null)
                                          Text(
                                            '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (review.comment != null &&
                                        review.comment!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          review.comment!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Sipariş #${review.orderId.substring(0, 8)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
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
                    ],
                  ),
                ),
    );
  }
}

