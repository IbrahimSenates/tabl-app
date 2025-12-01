import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
        OpenAIConfig.apiKey.isNotEmpty) {
      try {
        final response = await _askOpenAI(question, businessId, context);
        if (response.isNotEmpty) {
          return response;
        }
      } catch (e) {
        print('OpenAI API hatası: $e');
      }
    }

    return 'Üzgünüm, şu anda AI servisine erişilemiyor. Lütfen daha sonra tekrar deneyin.';
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
      final availableItems = menuItems
          .where((item) => item.isAvailable)
          .toList();
      final categories = await _menuService.getCategories(businessId);

      // Menü bilgilerini formatla
      final menuContext = _formatMenuContext(availableItems, categories);

      // System prompt oluştur
      final systemPrompt =
          '''Sen bir restoran menü asistanısın. Müşterilere menü hakkında yardımcı oluyorsun.
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
          'HTTP-Referer':
              'https://github.com/ibrahim/tabl_app', // OpenRouter için gerekli
          'X-Title': 'Tabl App', // OpenRouter için gerekli
        },
        body: jsonEncode({
          'model': OpenAIConfig.model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
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
          final errorMessage =
              errorData['error']?['message'] ?? 'Unknown error';
          final errorType = errorData['error']?['type'] ?? '';
          final errorCode = errorData['error']?['code'] ?? '';

          // Quota hatası veya diğer hatalar için log
          if (errorCode == 'insufficient_quota' ||
              errorType == 'insufficient_quota') {
            print('OpenAI API Quota Error: Hesabınızda yeterli kredi yok.');
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
  String _formatMenuContext(
    List<MenuItem> items,
    List<MenuCategory> categories,
  ) {
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
