# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:latest AS build-env

USER root
RUN git config --global --add safe.directory /sdks/flutter

WORKDIR /app
COPY . .

# Build-time environment variables
# Accept both with and without the prefix for maximum reliability on Render
ARG DOCKER_BUILD_ARG_FIREBASE_API_KEY
ARG DOCKER_BUILD_ARG_FIREBASE_AUTH_DOMAIN
ARG DOCKER_BUILD_ARG_FIREBASE_PROJECT_ID
ARG DOCKER_BUILD_ARG_FIREBASE_STORAGE_BUCKET
ARG DOCKER_BUILD_ARG_FIREBASE_MESSAGING_SENDER_ID
ARG DOCKER_BUILD_ARG_FIREBASE_APP_ID
ARG DOCKER_BUILD_ARG_FIREBASE_MEASUREMENT_ID
ARG DOCKER_BUILD_ARG_OPENWEATHER_API_KEY
ARG DOCKER_BUILD_ARG_GOOGLE_CLIENT_ID
ARG DOCKER_BUILD_ARG_FACEBOOK_APP_ID

# Set final variables, prioritizing the prefixed ones
ENV FIREBASE_API_KEY=${DOCKER_BUILD_ARG_FIREBASE_API_KEY}
ENV FIREBASE_AUTH_DOMAIN=${DOCKER_BUILD_ARG_FIREBASE_AUTH_DOMAIN}
ENV FIREBASE_PROJECT_ID=${DOCKER_BUILD_ARG_FIREBASE_PROJECT_ID}
ENV FIREBASE_STORAGE_BUCKET=${DOCKER_BUILD_ARG_FIREBASE_STORAGE_BUCKET}
ENV FIREBASE_MESSAGING_SENDER_ID=${DOCKER_BUILD_ARG_FIREBASE_MESSAGING_SENDER_ID}
ENV FIREBASE_APP_ID=${DOCKER_BUILD_ARG_FIREBASE_APP_ID}
ENV FIREBASE_MEASUREMENT_ID=${DOCKER_BUILD_ARG_FIREBASE_MEASUREMENT_ID}
ENV OPENWEATHER_API_KEY=${DOCKER_BUILD_ARG_OPENWEATHER_API_KEY}
ENV GOOGLE_CLIENT_ID=${DOCKER_BUILD_ARG_GOOGLE_CLIENT_ID}
ENV FACEBOOK_APP_ID=${DOCKER_BUILD_ARG_FACEBOOK_APP_ID}

# 1. VERIFICATION: This will fail if Render isn't passing the arguments correctly
RUN if [ -z "$FIREBASE_API_KEY" ]; then echo "BUILD ERROR: FIREBASE_API_KEY is empty."; exit 1; fi

# 2. LITERAL INJECTION into env_config.dart
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

# 3. Inject IDs into index.html
RUN if [ ! -z "$GOOGLE_CLIENT_ID" ]; then \
      sed -i "s/885191312691-pdr275ie3rp94tcbtn45mg58t16r9jvv.apps.googleusercontent.com/$GOOGLE_CLIENT_ID/g" web/index.html; \
    fi && \
    if [ ! -z "$FACEBOOK_APP_ID" ]; then \
      sed -i "s/1670995600575868/$FACEBOOK_APP_ID/g" web/index.html; \
    fi

# 4. Build
RUN rm -rf build/ && \
    flutter pub get && \
    flutter config --enable-web && \
    flutter build web --release --no-source-maps

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
