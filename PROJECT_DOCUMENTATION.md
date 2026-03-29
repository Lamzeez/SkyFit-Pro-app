# Project Documentation: SkyFit Pro
## Secure Identity & Personalized Health System

**Topic:** Mobile Secure Deployment (MVVM), Docker, GCP Cloud Run, Biometrics & SSO
**Platform:** Flutter Web / Native Mobile

---

## 1. Project Objective
The SkyFit Pro application is designed to provide a secure, personalized atmospheric fitness experience. The system integrates real-time weather data with user-specific health metrics (Age, Weight) to suggest optimized physical activities while maintaining high-standard security through Biometric Authentication and Google SSO.

---

## 2. Technical Architecture: Strict MVVM
The project adheres to a strict **Model-View-ViewModel (MVVM)** architecture with a **Repository Pattern** to ensure separation of concerns, testability, and scalability.

### File Structure & Responsibilities:
- **Models (`lib/models/`):** Defines the data structures for `UserModel`, `WeatherModel`, and `ActivityModel`.
- **Views (`lib/views/`):** The UI layer. Includes authentication screens (Login/Register), the main Dashboard, and Profile management.
- **ViewModels (`lib/viewmodels/`):** The logic layer. Bridges the UI and Data layers, handling auth state, profile updates, and weather-driven activity logic.
- **Repositories (`lib/repositories/`):** The data decision layer. Orchestrates data flow between Firebase Auth, Firestore, and external APIs.
- **Services (`lib/services/`):** External integrations including `ApiService` (Weather), `LocalAuthService` (Biometrics), and `StorageService` (Secure Preferences).

---

## 3. Feature Specifications

### A. Secure Authentication
- **Custom Registration:** Supports user creation with strong password validation and profile initialization (Name, Age, Weight, Height).
- **Google SSO:** Integrated "Sign in with Google" for streamlined user onboarding.
- **Profile Management:** Users can update personal metrics at any time, which dynamically recalculates health suggestions.

### B. Biometric Security
- **Biometric Toggle:** Located in the Profile View, allowing users to opt-in to Fingerprint or FaceID security.
- **Hardware Abstraction:** The system uses the `local_auth` package, providing native biometric support for Android and iOS devices.
- **Security Fallbacks:** Includes logic for password fallbacks after 3 failed biometric attempts.
- **Session Security:** Implements a `SessionManager` that monitors user activity, automatically locking the app after 5 minutes of inactivity.

### C. Personalized Health Logic (Algorithm)
The core engine suggests activities by cross-referencing real-time weather conditions with user demographics:
- **Logic Matrix:** 
    - *Clear/Sunny + Age < 50 + Normal Weight:* Outdoor HIIT/Running.
    - *Clear/Sunny + Age > 50:* Morning Walk / Tai Chi.
    - *Rain/Snow:* Indoor Yoga / Circuit Training.
    - *Extreme Heat + Overweight:* Swimming / Light Stretching.
- **Media Integration:** Includes AI-generated exercise videos to guide users through suggested activities.

---

## 4. Deployment & DevOps

### Containerization (Docker)
The app uses a **Multi-Stage Dockerfile** to optimize the production image:
1.  **Build Stage:** Uses a Debian-based environment to compile the Flutter Web app into release-ready static files.
2.  **Serve Stage:** Employs a lightweight `nginx:alpine` server to host the static content on port 8080.

### CI/CD Pipeline (GCP Cloud Run)
- **Cloud Build:** Orchestrated via `cloudbuild.yaml`, handling the automated build and push of Docker images to the Google Container Registry.
- **Cloud Run:** Hosts the containerized application in a serverless environment, ensuring high availability and secure HTTPS endpoints.

---

## 5. Deliverables & Validation
- **Source Control:** Managed via Git with sensitive environment variables protected.
- **Live URL:** Deployed and accessible via GCP Cloud Run.
- **Personalization Proof:** Demonstrated by changing user age or weight and observing the immediate shift in recommended activities on the dashboard.
