import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/weather_viewmodel.dart';
import 'profile_view.dart';

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
      final user = context.read<AuthViewModel>().user;
      context.read<WeatherViewModel>().updateWeatherAndActivities("Manila", user);
    });
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileView()),
            ),
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
        onRefresh: () => weatherViewModel.updateWeatherAndActivities("Manila", authViewModel.user),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center, color: Colors.lightBlue),
                        title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(activity.description),
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
