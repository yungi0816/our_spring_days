class AppConstants {
  static const String appName = '비비랑 우리';

  static const String partnerAId = String.fromEnvironment(
    'PARTNER_A_ID',
    defaultValue: 'PARTNER_A',
  );

  static const String partnerBId = String.fromEnvironment(
    'PARTNER_B_ID',
    defaultValue: 'PARTNER_B',
  );

  static const String coupleId = String.fromEnvironment(
    'COUPLE_ID',
    defaultValue: 'DEMO_COUPLE',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  // AI 비서는 OpenAI API Key 입력 후 사용할 수 있습니다.
}
