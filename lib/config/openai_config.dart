class OpenAIConfig {
  static const String apiKey =
      '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';

  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String model = 'openai/gpt-3.5-turbo';

  // Max tokens (yanıt uzunluğu)
  static const int maxTokens = 500;

  // Temperature (0-2 arası, düşük = daha tutarlı, yüksek = daha yaratıcı)
  static const double temperature = 0.7;

  // OpenAI API kullanılsın mı?
  static const bool useOpenAI = true;
}
