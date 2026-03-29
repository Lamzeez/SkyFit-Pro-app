# SkyFit Pro: Project Requirement Analysis

This document provides a comprehensive analysis of the "SkyFit Pro" codebase against the technical specifications outlined in the laboratory exercise notes (`notes.txt`).

---

## 1. Requirement Match Overview

| Requirement Category | Specific Requirement | Status | Implementation Details |
| :--- | :--- | :---: | :--- |
| **MVVM Architecture** | Strict project folder structure | âœ… **Match** | Follows the requested `lib/` structure: `models`, `views`, `viewmodels`, `repositories`, `services`, `utils`. |
| **Secure Auth** | Custom Registration with Profile | âœ… **Match** | `RegisterView` handles Name, Age, Weight, Height, and Profile Picture. |
| **Secure Auth** | Password Strength (Regex) | âœ… **Match** | `RegisterView` implements checks for Uppercase, Lowercase, Numbers, Special Chars, and Min-length (8). |
| **Secure Auth** | Google SSO | âœ… **Match** | Integrated via `AuthRepository.signInWithGoogle`. |
| **Biometrics** | Biometric Toggle in Profile | âœ… **Match** | `ProfileView` contains a reactive switch for `biometricEnabled`. |
| **Biometrics** | 3-Fail Fallback Logic | âœ… **Match** | `AuthViewModel` tracks `_biometricFailCount`. `BiometricLockView` forces password entry after 3 failures. |
| **Biometrics** | Inactivity Timer (5 Mins) | âœ… **Match** | `SessionManager` service implemented with a 5-minute timeout and automatic logout. |
| **Health Logic** | OpenWeatherMap Integration | âœ… **Match** | `WeatherRepository` and `ApiService` fetch real-time temp and conditions. |
| **Health Logic** | Logic Engine (Age/BMI/Weather) | âœ… **Match** | `WeatherViewModel._generateActivities` cross-references Weather, Age, and BMI category. |
| **Health Logic** | Activity Media (AI Exercises) | âœ… **Match** | Integrated YouTube exercise videos for each suggested activity. |
| **Deployment** | Docker Containerization | âš ï¸ **Partial** | `Dockerfile` exists but is currently **Single-Stage**. `notes.txt` specifies a **Multi-Stage** build (Build-env + Nginx). |
| **Deployment** | GCP Cloud Build / CI/CD | âœ… **Match** | `cloudbuild.yaml` is configured with all required Firebase and OpenWeather API build arguments. |

---

## 2. Additional "High-Value" Features
The current implementation includes several advanced features that exceed the basic laboratory requirements:

1.  **Facebook SSO Integration**: In addition to Google, the app supports Facebook login via `flutter_facebook_auth`.
2.  **Secure PIN Fallback**: A secondary security layer allowing users to set a 4-6 digit PIN as an alternative to biometrics/password.
3.  **Email OTP Verification**: Registration includes a 6-digit email verification (OTP) step for account security, managed via `EmailService`.
4.  **Mock Environment Mode**: The app can function without Firebase (`EnvConfig.isFirebaseConfigured`) by providing mock data, which is excellent for testing and development.
5.  **BMI Analytics**: The `UserModel` includes a calculation engine that auto-categorizes users (Underweight, Normal, Overweight, High BMI) based on real-time metrics.
6.  **Theme Management**: A full Light/Dark mode implementation with a dedicated `ThemeViewModel` and persistence.
7.  **Profile Image Compression**: `AuthRepository` includes logic to resize and compress profile pictures to Base64 (JPG) before saving to Firestore, optimizing storage.

---

## 3. Deployment Discrepancy Note
The `notes.txt` requirement for a **Multi-Stage Dockerfile** is critical for security and image size optimization (so the Flutter SDK isn't included in the final production image). The current `Dockerfile` relies on a local `flutter build web` command first. 

**Recommendation**: Update the `Dockerfile` to the Multi-Stage version provided in the `notes.txt` to fully automate the GCP pipeline without requiring local builds.
