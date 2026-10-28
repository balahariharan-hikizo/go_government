/// Centralized configuration for Google Maps & Google Places services.
class GoogleConfig {
  GoogleConfig._();

  /// Google Maps Platform API Key.
  /// Enabled APIs: Maps SDK (Android/iOS), Maps JavaScript API,
  /// Geocoding API, Places API, Directions API.
  static const String mapsApiKey = 'AIzaSyA2AfzS1DtTjVTbK6hwm050Ylmr9tIJ780';

  /// Google Maps tile URL template for use with flutter_map.
  /// Styles: 'm' = roadmap, 's' = satellite, 'y' = hybrid, 't' = terrain.
  static const String googleTileUrl =
      'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=$mapsApiKey';

  /// Subdomains used to load-balance Google Maps tile requests.
  static const List<String> googleTileSubdomains = ['0', '1', '2', '3'];

  /// Whether the configured API key is valid (not a placeholder).
  static bool get hasValidKey =>
      mapsApiKey.isNotEmpty &&
      !mapsApiKey.contains('YOUR_') &&
      mapsApiKey.trim().length > 10;
}
