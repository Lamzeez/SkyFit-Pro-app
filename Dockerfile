# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:latest AS build-env

USER root
RUN git config --global --add safe.directory /sdks/flutter

WORKDIR /app
COPY . .

# Build-time environment variables
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

# 1. BAKE THE ACTUAL VALUES into lib/utils/env_config.dart
# This is much more reliable than --dart-define on some CI platforms
RUN mkdir -p lib/utils && \
    echo "class EnvConfig {" > lib/utils/env_config.dart && \
    echo "  static const String openWeatherApiKey = '$OPENWEATHER_API_KEY';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseApiKey = '$FIREBASE_API_KEY';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseAuthDomain = '$FIREBASE_AUTH_DOMAIN';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseProjectId = '$FIREBASE_PROJECT_ID';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseStorageBucket = '$FIREBASE_STORAGE_BUCKET';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseMessagingSenderId = '$FIREBASE_MESSAGING_SENDER_ID';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseAppId = '$FIREBASE_APP_ID';" >> lib/utils/env_config.dart && \
    echo "  static const String firebaseMeasurementId = '$FIREBASE_MEASUREMENT_ID';" >> lib/utils/env_config.dart && \
    echo "  static const String facebookAppId = '$FACEBOOK_APP_ID';" >> lib/utils/env_config.dart && \
    echo "  static bool get isFirebaseConfigured => firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty && firebaseAppId.isNotEmpty;" >> lib/utils/env_config.dart && \
    echo "}" >> lib/utils/env_config.dart

# 2. Inject keys into web/index.html using sed
RUN if [ ! -z "$GOOGLE_CLIENT_ID" ]; then \
      sed -i "s/885191312691-pdr275ie3rp94tcbtn45mg58t16r9jvv.apps.googleusercontent.com/$GOOGLE_CLIENT_ID/g" web/index.html; \
    fi && \
    if [ ! -z "$FACEBOOK_APP_ID" ]; then \
      sed -i "s/1670995600575868/$FACEBOOK_APP_ID/g" web/index.html; \
    fi

# 3. Fetch dependencies
RUN flutter pub get

# 4. Build
RUN flutter config --enable-web
RUN flutter build web --release --no-source-maps

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
