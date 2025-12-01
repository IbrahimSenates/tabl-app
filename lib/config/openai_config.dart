import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIConfig {
  static String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String model = 'openai/gpt-3.5-turbo';

  // Max tokens (yanıt uzunluğu)
  static const int maxTokens = 500;

  // Temperature (0-2 arası, düşük = daha tutarlı, yüksek = daha yaratıcı)
  static const double temperature = 0.7;

  // OpenAI API kullanılsın mı?
  static const bool useOpenAI = true;
}
