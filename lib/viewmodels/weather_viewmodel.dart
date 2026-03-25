import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import '../repositories/weather_repository.dart';

class WeatherViewModel extends ChangeNotifier {
  final WeatherRepository _weatherRepository = WeatherRepository();

  WeatherModel? _weather;
  List<ActivityModel> _suggestedActivities = [];
  bool _isLoading = false;
  String? _error;

  WeatherModel? get weather => _weather;
  List<ActivityModel> get suggestedActivities => _suggestedActivities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Structured Activity Data
  final Map<String, List<ActivityModel>> _activityData = {
    'Running': [
      ActivityModel(
        title: 'Proper Running Form',
        description: 'Learn the fundamentals to prevent injury and increase efficiency.',
        mediaUrl: 'https://www.youtube.com/watch?v=brFHyOtTwH4',
      ),
      ActivityModel(
        title: '20 Min Fat Burning Run',
        description: 'A targeted session designed to maximize calorie burn.',
        mediaUrl: 'https://www.youtube.com/watch?v=Z2sl3ssbnUQ',
      ),
      ActivityModel(
        title: 'Running for Beginners',
        description: 'Step-by-step guide for those just starting their journey.',
        mediaUrl: 'https://www.youtube.com/watch?v=kVnyY17VS9Y',
      ),
    ],
    'HIIT': [
      ActivityModel(
        title: '20 Min HIIT Workout',
        description: 'High-intensity interval training for maximum results in minimum time.',
        mediaUrl: 'https://www.youtube.com/watch?v=1TeYBhbURAw',
      ),
      ActivityModel(
        title: 'No Equipment HIIT',
        description: 'Effective cardio and strength training you can do anywhere.',
        mediaUrl: 'https://www.youtube.com/watch?v=wppLAEXbtOs',
      ),
      ActivityModel(
        title: '15 Min Tabata',
        description: 'Quick, explosive intervals to boost your metabolism.',
        mediaUrl: 'https://www.youtube.com/watch?v=KzYstSBeI_o',
      ),
    ],
    'TaiChi': [
      ActivityModel(
        title: 'Tai Chi for Beginners',
        description: 'Gentle movements to improve balance and reduce stress.',
        mediaUrl: 'https://www.youtube.com/watch?v=cEvSqHZIj8w',
      ),
      ActivityModel(
        title: '10 Min Morning Tai Chi',
        description: 'A perfect way to wake up your body and mind.',
        mediaUrl: 'https://www.youtube.com/watch?v=YlGV8DU4EZU',
      ),
      ActivityModel(
        title: 'Tai Chi for Seniors',
        description: 'Focused balance and mobility exercises for older adults.',
        mediaUrl: 'https://www.youtube.com/watch?v=Ka_7c_7p0GY',
      ),
    ],
    'Yoga': [
      ActivityModel(
        title: '20 Min Yoga for Beginners',
        description: 'Build a strong foundation with these basic poses.',
        mediaUrl: 'https://www.youtube.com/watch?v=camy0PIKxwU',
      ),
      ActivityModel(
        title: 'Stress Relief Yoga',
        description: 'Unwind and release tension after a long day.',
        mediaUrl: 'https://www.youtube.com/watch?v=sTANio_2E0Q',
      ),
      ActivityModel(
        title: 'Morning Yoga Flow',
        description: 'Energize your day with this fluid sequence.',
        mediaUrl: 'https://www.youtube.com/watch?v=2IcWJobNDck',
      ),
    ],
    'Swimming': [
      ActivityModel(
        title: 'Swimming Technique',
        description: 'Refine your strokes for better speed and endurance.',
        mediaUrl: 'https://www.youtube.com/watch?v=AQy_c30lNjI',
      ),
      ActivityModel(
        title: '5 Common Swimming Mistakes',
        description: 'Avoid these pitfalls to swim safer and faster.',
        mediaUrl: 'https://www.youtube.com/watch?v=s2h0tFWwqFc',
      ),
      ActivityModel(
        title: 'Swimming for Weight Loss',
        description: 'How to use the pool to reach your fitness goals.',
        mediaUrl: 'https://www.youtube.com/watch?v=nlGsZTsZaFc',
      ),
    ],
  };

  Future<void> updateWeatherAndActivities(String city, UserModel? user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _weather = await _weatherRepository.getWeather(city);
      if (_weather != null && user != null) {
        _suggestedActivities = _generateActivities(_weather!, user);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateWeatherByLocation(double lat, double lon, UserModel? user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _weather = await _weatherRepository.getWeatherByLocation(lat, lon);
      if (_weather != null && user != null) {
        _suggestedActivities = _generateActivities(_weather!, user);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ActivityModel> _generateActivities(WeatherModel weather, UserModel user) {
    List<ActivityModel> activities = [];
    String condition = weather.condition.toLowerCase();
    double temp = weather.temperature;
    String bmiCat = user.weightCategory; 
    int age = user.age;

    bool isClear = condition.contains("clear") || condition.contains("cloud");
    bool isRainy = condition.contains("rain") || condition.contains("snow") || condition.contains("storm");
    bool isHeat = temp > 35;

    // 1. CLEAR / SUNNY / CLOUDY
    if (isClear && !isHeat) {
      if (age < 50) {
        if (bmiCat == "Obese" || bmiCat == "Overweight" || bmiCat == "Normal/Athletic") {
          // Provide all running-related videos for high-benefit weight management/cardio
          activities.addAll(_activityData['Running']!);
          activities.add(_activityData['HIIT']![0]); // Add one HIIT for variety
        } else {
          // Underweight
          activities.addAll(_activityData['Yoga']!);
          activities.add(_activityData['Running']![0]); // Form only
        }
      } else {
        // Seniors (> 50)
        activities.addAll(_activityData['TaiChi']!);
        activities.add(_activityData['Yoga']![1]); // Stress relief
      }
    }

    // 2. RAIN / SNOW (Indoor Focus)
    else if (isRainy) {
      if (bmiCat == "Obese" || bmiCat == "Overweight" || bmiCat == "Normal/Athletic") {
        // High calorie burn indoors
        activities.addAll(_activityData['HIIT']!);
      } else {
        activities.addAll(_activityData['Yoga']!);
      }
    }

    // 3. EXTREME HEAT
    else if (isHeat) {
      if (bmiCat == "Overweight" || bmiCat == "Obese") {
        activities.addAll(_activityData['Swimming']!);
        activities.add(_activityData['Yoga']![1]); // Add a calm stretching video
      } else {
        activities.addAll(_activityData['Yoga']!);
        activities.add(_activityData['TaiChi']![0]);
      }
    }

    // Default Fallback
    if (activities.isEmpty) {
      activities.addAll(_activityData['Yoga']!);
    }

    return activities;
  }
}
