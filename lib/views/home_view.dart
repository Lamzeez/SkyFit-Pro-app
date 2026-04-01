import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/weather_viewmodel.dart';
import '../services/storage_service.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'profile_view.dart';
import 'auth/login_view.dart';
import 'widgets/activity_video_player.dart';
import 'widgets/custom_widgets.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentNavIndex = 0; // 0=Home, 1=Activity, 2=Profile
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationAndWeather();
      context.read<WeatherViewModel>().loadPersistedActivity();
    });
  }

  Future<void> _initLocationAndWeather() async {
    final user = context.read<AuthViewModel>().user;
    final storage = StorageService();
    
    // Check if user already made a location preference choice
    String? locationPreference = await storage.read('location_preference');
    bool? shouldAccessLocation;

    if (locationPreference == null) {
      // No preference saved, show dialog
      shouldAccessLocation = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Location Access'),
          content: const Text(
              'SkyFit Pro needs to access your location to provide accurate weather-based health activities for your specific area.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Use Default (Manila)'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38B6FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Allow Access',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      // Save preference for next time
      if (shouldAccessLocation != null) {
        await storage.save('location_preference', shouldAccessLocation.toString());
      }
    } else {
      // Use saved preference
      shouldAccessLocation = locationPreference == 'true';
    }

    if (shouldAccessLocation == true) {
      try {
        Position position = await _determinePosition();
        if (mounted) {
          context.read<WeatherViewModel>().updateWeatherByLocation(
                position.latitude,
                position.longitude,
                user,
              );
        }
      } catch (e) {
        debugPrint('Location error: $e');
        if (mounted) {
          context
              .read<WeatherViewModel>()
              .updateWeatherAndActivities('Manila', user);
        }
      }
    } else {
      if (mounted) {
        context
            .read<WeatherViewModel>()
            .updateWeatherAndActivities('Manila', user);
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
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _refreshWeather() async {
    final user = context.read<AuthViewModel>().user;
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        await context
            .read<WeatherViewModel>()
            .updateWeatherByLocation(position.latitude, position.longitude, user);
      }
    } catch (e) {
      if (mounted) {
        await context
            .read<WeatherViewModel>()
            .updateWeatherAndActivities('Manila', user);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final weatherViewModel = context.watch<WeatherViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg =
        isDark ? const Color(0xFF0D1321) : const Color(0xFFF0F4FA);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            authViewModel.clearError();
            authViewModel.clearSuccess();
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(authViewModel, isDark),
                  Expanded(
                    child: _currentNavIndex == 0
                        ? _buildHomePage(weatherViewModel, isDark)
                        : _currentNavIndex == 1
                            ? _buildActivityPage(weatherViewModel, isDark)
                            : _buildProfilePage(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ── Top App Bar ──────────────────────────────────────────────────────────
  Widget _buildTopBar(AuthViewModel authViewModel, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back or Logo
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
            ).createShader(bounds),
            child: const Icon(Icons.cloud_queue, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
            ).createShader(bounds),
            child: const Text(
              'SkyFit Pro',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const Spacer(),
          // Logout
          TextButton.icon(
            onPressed: () => _showLogoutConfirmation(context, authViewModel),
            icon: Icon(Icons.logout_rounded,
                color: isDark ? Colors.white54 : Colors.black38, size: 18),
            label: Text(
              'Logout',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthViewModel authViewModel) {
    setState(() => _isDialogOpen = true);
    showDialog(
      context: context,
      builder: (context) => PointerInterceptor(
        child: ConfirmLogoutDialog(
          onCancel: () {
            Navigator.pop(context);
            setState(() => _isDialogOpen = false);
          },
          onConfirm: () async {
            // 1. Close the dialog first
            Navigator.pop(context);
            setState(() => _isDialogOpen = false);
            
            // 2. Perform the logout
            await authViewModel.logout();
            
            // 3. Force navigate to LoginView using a clean route
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginView()),
                (route) => false, // Clears the entire navigation stack
              );
            }
          },
        ),
      ),
    ).then((_) {
      if (mounted && _isDialogOpen) {
        setState(() => _isDialogOpen = false);
      }
    });
  }

  // ── Bottom Navigation Bar ────────────────────────────────────────────────
  Widget _buildBottomNav(bool isDark) {
    final Color activeTint = const Color(0xFF38B6FF);
    final Color inactiveTint = isDark ? Colors.white30 : Colors.black38;
    final Color navBg = isDark ? const Color(0xFF0E1826) : Colors.white;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'HOME', 0, activeTint, inactiveTint),
          _navItem(Icons.fitness_center_rounded, 'ACTIVITY', 1, activeTint,
              inactiveTint),
          _navItem(
              Icons.person_rounded, 'PROFILE', 2, activeTint, inactiveTint),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, Color activeTint,
      Color inactiveTint) {
    final bool active = _currentNavIndex == index;
    return GestureDetector(
      onTap: () async {
        // If leaving Profile, re-run activity logic with the (possibly updated) user
        if (_currentNavIndex == 2 && index != 2) {
          setState(() => _currentNavIndex = index);
          await _refreshWeather();
        } else {
          setState(() => _currentNavIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? activeTint : inactiveTint,
                size: active ? 26 : 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? activeTint : inactiveTint,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Home Page ────────────────────────────────────────────────────────────
  Widget _buildHomePage(WeatherViewModel weatherViewModel, bool isDark) {
    return RefreshIndicator(
      onRefresh: _refreshWeather,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildWeatherCard(weatherViewModel, isDark),
            const SizedBox(height: 20),
            _buildIntroCard(isDark),
            const SizedBox(height: 24),
            Text(
              'Suggested Activities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (weatherViewModel.isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF38B6FF)),
              ))
            else if (weatherViewModel.suggestedActivities.isEmpty)
              _buildEmptyActivities(isDark)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: weatherViewModel.suggestedActivities.length,
                itemBuilder: (context, index) {
                  final activity =
                      weatherViewModel.suggestedActivities[index];
                  return _buildActivityCard(activity, isDark, weatherViewModel);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(bool isDark) {
    final Color cardBg = isDark ? const Color(0xFF131C2E) : Colors.white;
    final Color accentColor = const Color(0xFF38B6FF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2D45) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to SkyFit Pro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Your AI-Powered Weather Coach',
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'SkyFit Pro helps you stay active by recommending the best workouts based on your local weather and personal health profile.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _introBullet(Icons.wb_sunny_rounded, 'Weather Optimized', 'Get indoor or outdoor exercises based on conditions.', isDark),
          const SizedBox(height: 12),
          _introBullet(Icons.monitor_heart_rounded, 'Tailored to You', 'Exercises adjusted for your age and BMI category.', isDark),
          const SizedBox(height: 12),
          _introBullet(Icons.play_circle_fill_rounded, 'Step-by-Step', 'Every activity includes a video to guide your form.', isDark),
        ],
      ),
    );
  }

  Widget _introBullet(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF38B6FF).withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Activity Detail Page ─────────────────────────────────────────────────
  Widget _buildActivityPage(WeatherViewModel weatherViewModel, bool isDark) {
    if (weatherViewModel.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF38B6FF)));
    }

    final activity = weatherViewModel.selectedActivity;
    if (activity == null) {
      return _buildNoActivitySelected(isDark);
    }

    final weather = weatherViewModel.weather;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video player
          if (activity.mediaUrl != null)
            ClipRRect(
              child: ActivityVideoPlayer(
                videoUrl: activity.mediaUrl!,
                isInteractivityEnabled: !_isDialogOpen,
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38B6FF).withValues(alpha: 0.3),
                    const Color(0xFF00E5CC).withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.fitness_center,
                    size: 64, color: Colors.white30),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI label
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 13, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 5),
                    Text(
                      'AI-GENERATED EXERCISE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Why this was chosen box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A2235)
                        : const Color(0xFFF0F6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A3A55)
                          : Colors.blueGrey.shade100,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14,
                              color: isDark
                                  ? Colors.lightBlue
                                  : Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            'WHY THIS WAS CHOSEN',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.lightBlue
                                  : Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weather != null
                            ? 'Based on current conditions in ${weather.cityName} (${weather.temperature.toStringAsFixed(0)}°C, Humidity: ${weather.humidity}%), '
                                'we\'ve recommended this activity to match your profile and optimize your workout safely.'
                            : 'This activity was selected based on your profile and current weather conditions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _pillTag(
                              Icons.settings_suggest_outlined,
                              'Adaptive Load',
                              const Color(0xFF4CAF50)),
                          _pillTag(
                              Icons.wb_sunny_outlined,
                              'Weather Optimized',
                              const Color(0xFFFF9800)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Health Snapshot
                _buildHealthSnapshot(weatherViewModel, activity, isDark),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActivitySelected(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2235) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38B6FF).withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 80,
                color: Color(0xFF38B6FF),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Activity Selected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please select an activity from the Home page to start exercising.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentNavIndex = 0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38B6FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Go to Home',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile Page (embedded inline so bottom nav stays visible) ──────────
  Widget _buildProfilePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0D1321) : const Color(0xFFF0F4FA);
    return Container(
      color: bg,
      child: const ProfileBody(showTopBar: false),
    );
  }

  // ── Weather Card ─────────────────────────────────────────────────────────
  Widget _buildWeatherCard(WeatherViewModel viewModel, bool isDark) {
    if (viewModel.isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            const Center(child: CircularProgressIndicator(color: Color(0xFF38B6FF))),
      );
    }
    if (viewModel.weather == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text('Failed to load weather',
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38)),
        ),
      );
    }

    final weather = viewModel.weather!;
    final IconData weatherIcon = _weatherIcon(weather.condition);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2440), const Color(0xFF1A3A5C)]
              : [const Color(0xFF38B6FF), const Color(0xFF0077CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38B6FF).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weather.cityName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                weather.condition,
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.water_drop_outlined,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    'Humidity: ${weather.humidity}%',
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(weatherIcon, size: 36, color: Colors.white70),
              const SizedBox(height: 4),
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _weatherIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('rain') || c.contains('drizzle')) {
      return Icons.grain;
    } else if (c.contains('cloud')) {
      return Icons.cloud_outlined;
    } else if (c.contains('snow')) {
      return Icons.ac_unit;
    } else if (c.contains('thunder')) {
      return Icons.thunderstorm_outlined;
    } else {
      return Icons.wb_sunny_outlined;
    }
  }

  // ── Activity Card (Home list) ─────────────────────────────────────────────
  Widget _buildActivityCard(dynamic activity, bool isDark, WeatherViewModel viewModel) {
    return GestureDetector(
      onTap: () {
        viewModel.selectActivity(activity);
        setState(() => _currentNavIndex = 1);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131C2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isDark ? const Color(0xFF1E2D45) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity.mediaUrl != null)
              Stack(
                children: [
                  IgnorePointer(
                    child: ActivityVideoPlayer(
                      videoUrl: activity.mediaUrl!,
                      isInteractivityEnabled: !_isDialogOpen,
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!_isDialogOpen) {
                          viewModel.selectActivity(activity);
                          setState(() => _currentNavIndex = 1);
                        }
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 13, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 5),
                      const Text(
                        'AI-GENERATED EXERCISE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _pillTag(Icons.settings_suggest_outlined, 'Adaptive Load',
                          const Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      _pillTag(Icons.wb_sunny_outlined, 'Weather Optimized',
                          const Color(0xFFFF9800)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivities(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.fitness_center_outlined,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No activities suggested\nfor current weather.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Health Snapshot ───────────────────────────────────────────────────────
  Widget _buildHealthSnapshot(
      WeatherViewModel weatherViewModel, dynamic activity, bool isDark) {
    final weather = weatherViewModel.weather;
    final user = context.read<AuthViewModel>().user;

    // Derive intensity from BMI category
    final String bmiCat = user?.weightCategory ?? 'Normal/Athletic';
    final String intensity;
    final Color intensityColor;
    if (bmiCat == 'High BMI') {
      intensity = 'Low — start gentle';
      intensityColor = const Color(0xFFFF7043);
    } else if (bmiCat == 'Overweight') {
      intensity = 'Low–Moderate';
      intensityColor = const Color(0xFFFF9800);
    } else if (bmiCat == 'Normal') {
      intensity = 'Moderate–High';
      intensityColor = const Color(0xFF4CAF50);
    } else {
      // Underweight
      intensity = 'Light — build gradually';
      intensityColor = const Color(0xFF38B6FF);
    }

    // Derive weather suitability
    final String suitability;
    final IconData suitabilityIcon;
    if (weather != null) {
      final cond = weather.condition.toLowerCase();
      final temp = weather.temperature;
      if (cond.contains('rain') ||
          cond.contains('snow') ||
          cond.contains('storm')) {
        suitabilityIcon = Icons.home_outlined;
        suitability = 'Rain detected — stay indoors today';
      } else if (temp > 35) {
        suitabilityIcon = Icons.thermostat_outlined;
        suitability = 'Extreme heat — keep sessions short';
      } else {
        suitabilityIcon = Icons.wb_sunny_outlined;
        suitability = 'Good conditions for outdoor activity';
      }
    } else {
      suitabilityIcon = Icons.wb_sunny_outlined;
      suitability = 'Conditions suitable for activity';
    }

    // Derive activity type label from title
    final String titleLower = activity.title.toLowerCase();
    final String activityType;
    final List<String> tips;

    if (titleLower.contains('run') || titleLower.contains('hiit') ||
        titleLower.contains('tabata') || titleLower.contains('fat')) {
      activityType = 'Cardio & Endurance';
      tips = ['Stay hydrated', 'Wear running shoes', 'Watch your heart rate'];
    } else if (titleLower.contains('yoga') || titleLower.contains('tai chi') ||
        titleLower.contains('stress') || titleLower.contains('morning')) {
      activityType = 'Balance & Flexibility';
      tips = ['Focus on breathing', 'Move slowly', 'Find a quiet space'];
    } else if (titleLower.contains('swim')) {
      activityType = 'Low-Impact Cardio';
      tips = ['Control your breath', 'Check water temp', 'Proper stroke form'];
    } else {
      activityType = 'General Fitness';
      tips = ['Stay hydrated', 'Warm up first', 'Rest if sore'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monitor_heart_outlined,
                size: 18,
                color: isDark ? const Color(0xFF38B6FF) : const Color(0xFF0077CC)),
            const SizedBox(width: 6),
            Text(
              'Your Health Snapshot',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2235) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2A3A55)
                  : Colors.blueGrey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _snapshotRow(
                icon: Icons.speed_rounded,
                iconColor: intensityColor,
                label: 'Intensity Level',
                value: intensity,
                isDark: isDark,
              ),
              _snapshotDivider(isDark),
              _snapshotRow(
                icon: suitabilityIcon,
                iconColor: const Color(0xFF38B6FF),
                label: 'Weather Suitability',
                value: suitability,
                isDark: isDark,
              ),
              _snapshotDivider(isDark),
              _snapshotRow(
                icon: Icons.category_outlined,
                iconColor: const Color(0xFF9C27B0),
                label: 'Activity Type',
                value: activityType,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tips
                .map((tip) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _pillTag(
                          Icons.tips_and_updates_outlined,
                          tip,
                          isDark
                              ? const Color(0xFF38B6FF)
                              : const Color(0xFF0077CC)),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _snapshotRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _snapshotDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
    );
  }
}
