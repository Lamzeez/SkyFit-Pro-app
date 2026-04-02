# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:latest AS build-env

USER root
RUN git config --global --add safe.directory /sdks/flutter

WORKDIR /app
COPY . .

# Build-time environment variables (Passed from Render via DOCKER_BUILD_ARG_ prefix)
ARG FIREBASE_API_KEY
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_APP_ID
ARG FIREBASE_MEASUREMENT_ID
ARG OPENWEATHER_API_KEY
ARG GOOGLE_CLIENT_ID
ARG FACEBOOK_APP_ID

# 1. CREATE dart_defines.json (Mirroring your local setup)
# We use a temporary JSON file to ensure keys are passed correctly to the compiler
RUN echo "{" > dart_defines.json && \
    echo "  \"OPENWEATHER_API_KEY\": \"$OPENWEATHER_API_KEY\"," >> dart_defines.json && \
    echo "  \"FIREBASE_API_KEY\": \"$FIREBASE_API_KEY\"," >> dart_defines.json && \
    echo "  \"FIREBASE_AUTH_DOMAIN\": \"$FIREBASE_AUTH_DOMAIN\"," >> dart_defines.json && \
    echo "  \"FIREBASE_PROJECT_ID\": \"$FIREBASE_PROJECT_ID\"," >> dart_defines.json && \
    echo "  \"FIREBASE_STORAGE_BUCKET\": \"$FIREBASE_STORAGE_BUCKET\"," >> dart_defines.json && \
    echo "  \"FIREBASE_MESSAGING_SENDER_ID\": \"$FIREBASE_MESSAGING_SENDER_ID\"," >> dart_defines.json && \
    echo "  \"FIREBASE_APP_ID\": \"$FIREBASE_APP_ID\"," >> dart_defines.json && \
    echo "  \"FIREBASE_MEASUREMENT_ID\": \"$FIREBASE_MEASUREMENT_ID\"," >> dart_defines.json && \
    echo "  \"FACEBOOK_APP_ID\": \"$FACEBOOK_APP_ID\"" >> dart_defines.json && \
    echo "}" >> dart_defines.json

# 2. GENERATE env_config.dart (Required for successful compilation)
RUN mkdir -p lib/utils && \
    echo "class EnvConfig {" > lib/utils/env_config.dart && \
    echo "  static const String openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseMeasurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');" >> lib/utils/env_config.dart && \
    echo "  static const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');" >> lib/utils/env_config.dart && \
    echo "  static bool get isFirebaseConfigured => firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty && firebaseAppId.isNotEmpty;" >> lib/utils/env_config.dart && \
    echo "}" >> lib/utils/env_config.dart

# 3. Inject Google/Facebook IDs into index.html
RUN if [ ! -z "$GOOGLE_CLIENT_ID" ]; then \
      sed -i "s/885191312691-pdr275ie3rp94tcbtn45mg58t16r9jvv.apps.googleusercontent.com/$GOOGLE_CLIENT_ID/g" web/index.html; \
    fi && \
    if [ ! -z "$FACEBOOK_APP_ID" ]; then \
      sed -i "s/1670995600575868/$FACEBOOK_APP_ID/g" web/index.html; \
    fi

# 4. Clean and Build (Force removal of any local build files pushed via Git)
RUN rm -rf build/web && \
    flutter pub get && \
    flutter config --enable-web && \
    flutter build web --release --no-source-maps --dart-define-from-file=dart_defines.json

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
