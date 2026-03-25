import '../models/weather_model.dart';
import '../services/api_service.dart';

class WeatherRepository {
  final ApiService _apiService = ApiService();
  WeatherModel? _cachedWeather;
  DateTime? _lastFetch;

  Future<WeatherModel?> getWeather(String city) async {
    // Basic caching for 10 minutes
    if (_cachedWeather != null && _lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inMinutes < 10) {
      return _cachedWeather;
    }

    try {
      _cachedWeather = await _apiService.fetchWeather(city);
      if (_cachedWeather != null) {
        _lastFetch = DateTime.now();
      }
      return _cachedWeather;
    } catch (e) {
      print("Error in weather repo: $e");
      return _cachedWeather; // Return cached even if expired on error
    }
  }

  Future<WeatherModel?> getWeatherByLocation(double lat, double lon) async {
    try {
      _cachedWeather = await _apiService.fetchWeatherByLocation(lat, lon);
      if (_cachedWeather != null) {
        _lastFetch = DateTime.now();
      }
      return _cachedWeather;
    } catch (e) {
      print("Error in weather repo (location): $e");
      return _cachedWeather;
    }
  }
}
