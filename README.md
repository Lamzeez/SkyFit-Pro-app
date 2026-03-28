# SkyFit Pro - Secure Identity & Health System

SkyFit Pro is a secure Flutter Web application designed for identity management and personalized health recommendations. It implements a strict MVVM architecture with a Repository pattern, featuring biometric authentication, Google SSO, and weather-based activity suggestions.

## 🚀 Features

- **Secure Authentication**: Custom registration with strong password validation and Google SSO integration.
- **Biometric Security**: Optional biometric (Fingerprint/FaceID) lock for sensitive health data with password fallback.
- **Personalized Health Logic**: Real-time activity suggestions based on local weather conditions, age, and weight category (BMI).
- **Session Management**: Automatic logout after 5 minutes of inactivity.
- **Dark Mode**: Seamless toggle between light and dark themes.
- **Responsive Web Design**: Optimized for desktop and mobile web browsers.

## 🏗 Architecture (MVVM)

The project follows a strict MVVM structure:
- **Models**: Data structures for Users, Weather, and Activities.
- **Views**: UI components built with Flutter widgets.
- **ViewModels**: Business logic and state management using Provider.
- **Repositories**: Data access layer abstraction (Firebase Auth, Firestore, OpenWeather API).
- **Services**: External system integrations (Local Auth, Storage, API).

## 🛠 Prerequisites

- Flutter SDK (latest stable)
- Firebase Project (configured for Web)
- OpenWeatherMap API Key
- Docker (optional, for containerization)

## 🏁 Getting Started

### 1. Clone the repository
```bash
git clone <repository-url>
cd skyfit-pro-app
```

### 2. Configure Environment
Create a `.env` file or use `dart-define` to provide the following keys:
- `OPENWEATHER_API_KEY`
- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Run Locally
```bash
flutter run -d chrome --dart-define-from-file=.env
```

## 🐳 Docker & Deployment

The application is containerized using a multi-stage Docker build and optimized for Google Cloud Run.

### Build Image Locally
```bash
docker build -t skyfit-pro .
```

### Run Container Locally
```bash
docker run -p 8080:8080 skyfit-pro
```

### Deploy to Cloud Run (via Cloud Build)
The project includes a `cloudbuild.yaml` for CI/CD. Ensure the substitutions are configured in your GCP console.

## 👥 Team Members
- M1: Lamoste, Dennis Dave - Lead Architect & Auth Core
- M2: Masanguid, John Paul - Security & Biometrics
- M3: Paja, John Mark - Profile & Logic
- M4: Baccera, Clawrenz Carl - DevOps & Cloud (GCP)
- M5: Monton, Bondave - UI/UX & Integration
