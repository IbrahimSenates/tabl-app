import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../services/menu_service.dart';
import '../config/openai_config.dart';

class AIService {
  final MenuService _menuService = MenuService();

  /// AI asistanına soru sor ve yanıt al
  Future<String> askQuestion({
    required String question,
    required String businessId,
    String? context, // Ek bağlam (ör: sepet içeriği)
  }) async {
    // OpenAI API kullanılıyorsa ve API key varsa
    if (OpenAIConfig.useOpenAI && 
        OpenAIConfig.apiKey.isNotEmpty && 
        OpenAIConfig.apiKey != 'YOUR_OPENAI_API_KEY_HERE') {
      try {
        final response = await _askOpenAI(question, businessId, context);
        if (response.isNotEmpty) {
          return response;
        }
        // Boş yanıt gelirse (quota hatası vb.) fallback'e geç
      } catch (e) {
        print('OpenAI API hatası: $e');
        // Hata durumunda fallback'e geç
      }
    }

    // Fallback: Kural tabanlı sistem
    try {
      final lowerQuestion = question.toLowerCase().trim();

      // Menü öğelerini al
      final menuItems = await _menuService.getMenuItems(businessId);
      final availableItems = menuItems.where((item) => item.isAvailable).toList();
      final categories = await _menuService.getCategories(businessId);

      // Soru türlerine göre yanıt üret
      if (_containsAny(lowerQuestion, ['merhaba', 'selam', 'hello', 'hi'])) {
        return 'Merhaba! Size nasıl yardımcı olabilirim? Menü hakkında sorular sorabilir, ürün önerileri isteyebilir veya sipariş verme konusunda yardım alabilirsiniz.';
      }

      if (_containsAny(lowerQuestion, ['fiyat', 'ne kadar', 'kaç para', 'ücret', 'tutar'])) {
        return _getPriceInfo(availableItems, lowerQuestion);
      }

      if (_containsAny(lowerQuestion, ['öner', 'tavsiye', 'ne yemeliyim', 'ne içmeliyim', 'öneri'])) {
        return _getRecommendations(availableItems, categories);
      }

      if (_containsAny(lowerQuestion, ['vegan', 'vejetaryen', 'gluten', 'şekersiz', 'diyet'])) {
        return _getDietaryInfo(availableItems, lowerQuestion);
      }

      if (_containsAny(lowerQuestion, ['popüler', 'en çok', 'favori', 'çok satan'])) {
        return _getPopularItems(availableItems);
      }

      if (_containsAny(lowerQuestion, ['kategori', 'kategoriler', 'türler'])) {
        return _getCategoriesInfo(categories);
      }

      if (_containsAny(lowerQuestion, ['kampanya', 'indirim', 'promosyon'])) {
        return 'Kampanyalar hakkında bilgi almak için "Kampanyalar" sekmesine bakabilirsiniz. Aktif kampanyalarımızı orada görebilirsiniz.';
      }

      if (_containsAny(lowerQuestion, ['sipariş', 'nasıl sipariş', 'sipariş ver'])) {
        return 'Sipariş vermek için menüden beğendiğiniz ürünleri sepete ekleyin. Sepetinizi kontrol edip siparişinizi tamamlayabilirsiniz.';
      }

      // Ürün arama
      final foundItems = availableItems.where((item) {
        return item.name.toLowerCase().contains(lowerQuestion) ||
            item.description.toLowerCase().contains(lowerQuestion) ||
            item.categoryName.toLowerCase().contains(lowerQuestion);
      }).toList();

      if (foundItems.isNotEmpty) {
        return _getItemDetails(foundItems);
      }

      // Genel yanıt
      return _getGeneralResponse(availableItems, categories);
    } catch (e) {
      return 'Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _getPriceInfo(List<MenuItem> items, String question) {
    if (items.isEmpty) {
      return 'Şu anda menüde ürün bulunmamaktadır.';
    }

    // Belirli bir ürün sorulmuşsa
    for (final item in items) {
      if (question.contains(item.name.toLowerCase())) {
        return '${item.name} ürününün fiyatı ${item.price.toStringAsFixed(2)} ₺. ${item.description.isNotEmpty ? "Açıklama: ${item.description}" : ""}';
      }
    }

    // Genel fiyat bilgisi
    final prices = items.map((e) => e.price).toList();
    final minPrice = prices.reduce(min);
    final maxPrice = prices.reduce(max);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;

    return 'Menümüzdeki ürünler ${minPrice.toStringAsFixed(2)} ₺ ile ${maxPrice.toStringAsFixed(2)} ₺ arasında değişmektedir. Ortalama fiyat ${avgPrice.toStringAsFixed(2)} ₺. Belirli bir ürünün fiyatını öğrenmek için ürün adını sorabilirsiniz.';
  }

  String _getRecommendations(List<MenuItem> items, List<MenuCategory> categories) {
    if (items.isEmpty) {
      return 'Şu anda menüde ürün bulunmamaktadır.';
    }

    // Rastgele 3-5 ürün öner
    final shuffled = List<MenuItem>.from(items)..shuffle();
    final recommendations = shuffled.take(min(5, shuffled.length)).toList();

    final buffer = StringBuffer('Size şu ürünleri önerebilirim:\n\n');
    for (int i = 0; i < recommendations.length; i++) {
      final item = recommendations[i];
      buffer.writeln('${i + 1}. ${item.name} - ${item.price.toStringAsFixed(2)} ₺');
      if (item.description.isNotEmpty) {
        buffer.writeln('   ${item.description}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _getDietaryInfo(List<MenuItem> items, String question) {
    if (items.isEmpty) {
      return 'Şu anda menüde ürün bulunmamaktadır.';
    }

    final keywords = [];
    if (question.contains('vegan')) keywords.add('vegan');
    if (question.contains('vejetaryen')) keywords.add('vejetaryen');
    if (question.contains('gluten')) keywords.add('gluten');
    if (question.contains('şekersiz')) keywords.add('şekersiz');
    if (question.contains('diyet')) keywords.add('diyet');

    // Açıklamalarda arama yap
    final matchingItems = items.where((item) {
      final desc = item.description.toLowerCase();
      return keywords.any((keyword) => desc.contains(keyword));
    }).toList();

    if (matchingItems.isEmpty) {
      return 'Maalesef ${keywords.join(" veya ")} seçenekleri için uygun ürün bulunamadı. Detaylı bilgi için menüyü inceleyebilir veya işletmeye sorabilirsiniz.';
    }

    final buffer = StringBuffer('${keywords.join(" veya ")} seçenekleri için şu ürünleri buldum:\n\n');
    for (final item in matchingItems.take(5)) {
      buffer.writeln('• ${item.name} - ${item.price.toStringAsFixed(2)} ₺');
    }

    return buffer.toString();
  }

  String _getPopularItems(List<MenuItem> items) {
    if (items.isEmpty) {
      return 'Şu anda menüde ürün bulunmamaktadır.';
    }

    // Rastgele popüler ürünler (gerçek veri yoksa)
    final shuffled = List<MenuItem>.from(items)..shuffle();
    final popular = shuffled.take(min(5, shuffled.length)).toList();

    final buffer = StringBuffer('En popüler ürünlerimiz:\n\n');
    for (int i = 0; i < popular.length; i++) {
      final item = popular[i];
      buffer.writeln('${i + 1}. ${item.name} - ${item.price.toStringAsFixed(2)} ₺');
    }

    return buffer.toString();
  }

  String _getCategoriesInfo(List<MenuCategory> categories) {
    if (categories.isEmpty) {
      return 'Henüz kategori eklenmemiş.';
    }

    final buffer = StringBuffer('Menümüzde şu kategoriler bulunmaktadır:\n\n');
    for (final category in categories) {
      buffer.writeln('• ${category.name}');
    }

    return buffer.toString();
  }

  String _getItemDetails(List<MenuItem> items) {
    if (items.length == 1) {
      final item = items.first;
      return '${item.name} hakkında:\n\nFiyat: ${item.price.toStringAsFixed(2)} ₺\nKategori: ${item.categoryName}\n${item.description.isNotEmpty ? "Açıklama: ${item.description}" : ""}';
    }

    final buffer = StringBuffer('Bulduğum ürünler:\n\n');
    for (final item in items.take(5)) {
      buffer.writeln('• ${item.name} - ${item.price.toStringAsFixed(2)} ₺ (${item.categoryName})');
    }

    return buffer.toString();
  }

  String _getGeneralResponse(List<MenuItem> items, List<MenuCategory> categories) {
    return 'Size nasıl yardımcı olabilirim? Menü hakkında sorular sorabilir, ürün önerileri isteyebilir, fiyat bilgisi alabilir veya sipariş verme konusunda yardım isteyebilirsiniz. Örneğin:\n\n'
        '• "Bana öneri ver"\n'
        '• "En popüler ürünler neler?"\n'
        '• "Vegan seçenekler var mı?"\n'
        '• "Fiyatlar ne kadar?"';
  }

  /// Hızlı öneriler (menü açıldığında gösterilebilir)
  Future<List<String>> getQuickSuggestions(String businessId) async {
    return [
      'Bana öneri ver',
      'En popüler ürünler neler?',
      'Fiyatlar ne kadar?',
      'Vegan seçenekler var mı?',
      'Kategoriler neler?',
    ];
  }

  /// OpenAI API ile soru sor
  Future<String> _askOpenAI(
    String question,
    String businessId,
    String? context,
  ) async {
    try {
      // Menü bilgilerini al
      final menuItems = await _menuService.getMenuItems(businessId);
      final availableItems = menuItems.where((item) => item.isAvailable).toList();
      final categories = await _menuService.getCategories(businessId);

      // Menü bilgilerini formatla
      final menuContext = _formatMenuContext(availableItems, categories);

      // System prompt oluştur
      final systemPrompt = '''Sen bir restoran menü asistanısın. Müşterilere menü hakkında yardımcı oluyorsun.
Menü bilgileri:
$menuContext

Görevlerin:
- Müşterilere ürün önerileri yap
- Fiyat bilgisi ver
- Diyet tercihlerine göre öneriler sun (vegan, vejetaryen, gluten-free vb.)
- Kategoriler hakkında bilgi ver
- Sipariş verme konusunda yardımcı ol
- Samimi, yardımsever ve profesyonel bir dil kullan
- Türkçe yanıt ver
- Yanıtların kısa ve öz olsun (maksimum 200 kelime)''';

      // API isteği
      final response = await http.post(
        Uri.parse(OpenAIConfig.apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: jsonEncode({
          'model': OpenAIConfig.model,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': question,
            },
          ],
          'max_tokens': OpenAIConfig.maxTokens,
          'temperature': OpenAIConfig.temperature,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
          final errorType = errorData['error']?['type'] ?? '';
          final errorCode = errorData['error']?['code'] ?? '';
          
          // Quota hatası veya diğer hatalar için log
          if (errorCode == 'insufficient_quota' || errorType == 'insufficient_quota') {
            print('OpenAI API Quota Error: Hesabınızda yeterli kredi yok. Fallback sistem kullanılıyor.');
          } else {
            print('OpenAI API Error: ${response.statusCode} - $errorMessage');
          }
        } catch (e) {
          print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        }
        return '';
      }
    } catch (e) {
      print('OpenAI API Exception: $e');
      return '';
    }
  }

  /// Menü bilgilerini OpenAI için formatla
  String _formatMenuContext(List<MenuItem> items, List<MenuCategory> categories) {
    final buffer = StringBuffer();

    // Kategoriler
    if (categories.isNotEmpty) {
      buffer.writeln('Kategoriler:');
      for (final category in categories) {
        buffer.writeln('- ${category.name}');
      }
      buffer.writeln('');
    }

    // Ürünler
    if (items.isNotEmpty) {
      buffer.writeln('Ürünler:');
      for (final item in items) {
        buffer.write('• ${item.name} - ${item.price.toStringAsFixed(2)} ₺');
        buffer.write(' (${item.categoryName})');
        if (item.description.isNotEmpty) {
          buffer.write(' - ${item.description}');
        }
        buffer.writeln('');
      }
    } else {
      buffer.writeln('Şu anda menüde ürün bulunmamaktadır.');
    }

    return buffer.toString();
  }
}

