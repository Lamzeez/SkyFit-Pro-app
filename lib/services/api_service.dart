import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../utils/env_config.dart';

class ApiService {
  final String _baseUrl = "https://api.openweathermap.org/data/2.5/weather";

  Future<WeatherModel?> fetchWeather(String city) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl?q=$city&appid=${EnvConfig.openWeatherApiKey}&units=metric"),
      );

      if (response.statusCode == 200) {
        return WeatherModel.fromJson(json.decode(response.body));
      } else {
        throw Exception("Failed to load weather data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching weather: $e");
      return null;
    }
  }

  Future<WeatherModel?> fetchWeatherByLocation(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl?lat=$lat&lon=$lon&appid=${EnvConfig.openWeatherApiKey}&units=metric"),
      );

      if (response.statusCode == 200) {
        return WeatherModel.fromJson(json.decode(response.body));
      } else {
        throw Exception("Failed to load weather data for location: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching weather by location: $e");
      return null;
    }
  }
}
