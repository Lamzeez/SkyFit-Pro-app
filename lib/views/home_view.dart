import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/weather_viewmodel.dart';
import 'profile_view.dart';
import 'widgets/activity_video_player.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationAndWeather();
    });
  }

  Future<void> _initLocationAndWeather() async {
    final user = context.read<AuthViewModel>().user;
    
    // 1. Show permission dialog
    bool? shouldAccessLocation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Location Access"),
        content: const Text("SkyFit Pro needs to access your location to provide accurate weather-based health activities for your specific area."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Use Default (Manila)"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Allow Access"),
          ),
        ],
      ),
    );

    if (shouldAccessLocation == true) {
      try {
        Position position = await _determinePosition();
        if (mounted) {
          context.read<WeatherViewModel>().updateWeatherByLocation(
            position.latitude, 
            position.longitude, 
            user
          );
        }
      } catch (e) {
        debugPrint("Location error: $e");
        if (mounted) {
          context.read<WeatherViewModel>().updateWeatherAndActivities("Manila", user);
        }
      }
    } else {
      if (mounted) {
        context.read<WeatherViewModel>().updateWeatherAndActivities("Manila", user);
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    } 

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _refreshWeather() async {
    final user = context.read<AuthViewModel>().user;
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        await context.read<WeatherViewModel>().updateWeatherByLocation(
          position.latitude, 
          position.longitude, 
          user
        );
      }
    } catch (e) {
      if (mounted) {
        await context.read<WeatherViewModel>().updateWeatherAndActivities("Manila", user);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final weatherViewModel = context.watch<WeatherViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("SkyFit Pro Dashboard"),
        backgroundColor: Colors.lightBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileView()),
              );
              // When coming back, the user profile might have changed (Age/Weight)
              if (mounted) {
                _refreshWeather();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authViewModel.logout();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWeather,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeatherCard(weatherViewModel),
              const SizedBox(height: 24),
              const Text(
                "Suggested Activities",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (weatherViewModel.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (weatherViewModel.suggestedActivities.isEmpty)
                const Text("No activities suggested for current weather.")
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: weatherViewModel.suggestedActivities.length,
                  itemBuilder: (context, index) {
                    final activity = weatherViewModel.suggestedActivities[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activity.mediaUrl != null)
                            ActivityVideoPlayer(videoUrl: activity.mediaUrl!),
                          ListTile(
                            leading: const Icon(Icons.fitness_center, color: Colors.lightBlue),
                            title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(activity.description),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard(WeatherViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Card(
        child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
      );
    }
    if (viewModel.weather == null) {
      return const Card(
        child: SizedBox(height: 150, child: Center(child: Text("Failed to load weather"))),
      );
    }

    final weather = viewModel.weather!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      color: isDark ? Colors.blueGrey[900] : Colors.lightBlue[100],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weather.cityName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(weather.condition, style: const TextStyle(fontSize: 18)),
                Text("Humidity: ${weather.humidity}%", style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
              ],
            ),
            Text(
              "${weather.temperature.toStringAsFixed(1)}°C",
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
