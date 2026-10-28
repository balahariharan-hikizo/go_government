/// Centralized configuration for Ola Maps routing and navigation services.
class OlaConfig {
  OlaConfig._();

  /// Ola Maps API Key (for Places Autocomplete and Geocoding).
  static String mapsApiKey = '9UcYHjloYEKwF9GTAE01qHDWb8Fdoai1Ujqe09mN';

  /// Ola Maps OAuth 2.0 Client Credentials (for Directions & Distance Matrix).
  static String clientId = '7f9a7e34-79d3-4893-a98e-b6e1c6857042';
  static String clientSecret = '0ba5d32008de411caa3522b5b8d82379';

  /// Base URL
  static const String olaMapsBaseUrl = 'https://api.olamaps.io';

  /// Check if developer has replaced placeholder with a valid custom key or OAuth credentials
  static bool get hasValidMapsKey =>
      mapsApiKey.isNotEmpty &&
      !mapsApiKey.contains('YOUR_OLA_MAPS_API_KEY') &&
      mapsApiKey.trim().length > 5;

  static bool get hasValidOAuth =>
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      !clientId.contains('YOUR_') &&
      !clientSecret.contains('YOUR_');
}
