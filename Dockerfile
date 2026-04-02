# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:latest AS build-env

# Set as root for initial setup but configure git safety
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

# Inject keys into web/index.html using sed
RUN if [ ! -z "$GOOGLE_CLIENT_ID" ]; then \
      sed -i "s/885191312691-pdr275ie3rp94tcbtn45mg58t16r9jvv.apps.googleusercontent.com/$GOOGLE_CLIENT_ID/g" web/index.html; \
    fi && \
    if [ ! -z "$FACEBOOK_APP_ID" ]; then \
      sed -i "s/1670995600575868/$FACEBOOK_APP_ID/g" web/index.html; \
    fi

# Fetch dependencies first
RUN flutter pub get

# Enable web and build with verbose output for debugging
RUN flutter config --enable-web
RUN flutter build web --release --verbose \
    --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY \
    --dart-define=FIREBASE_AUTH_DOMAIN=$FIREBASE_AUTH_DOMAIN \
    --dart-define=FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID \
    --dart-define=FIREBASE_STORAGE_BUCKET=$FIREBASE_STORAGE_BUCKET \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID \
    --dart-define=FIREBASE_APP_ID=$FIREBASE_APP_ID \
    --dart-define=FIREBASE_MEASUREMENT_ID=$FIREBASE_MEASUREMENT_ID \
    --dart-define=OPENWEATHER_API_KEY=$OPENWEATHER_API_KEY \
    --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
