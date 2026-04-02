# Render Deployment Guide for SkyFit Pro

This guide summarizes the "small tweakings" and necessary manual steps to ensure your Flutter Web app runs smoothly on Render with all features (Biometrics, SSO, etc.) working.

## 1. Port and Docker Configuration
The project has been updated to use **Port 80** instead of 8080, which is the standard for Render's web services.
- `nginx.conf` updated to `listen 80;`
- `Dockerfile` updated to `EXPOSE 80;`

## 2. Environment Variables (Critical for Flutter Build)
Flutter Web bakes environment variables into the JavaScript during the build process. On Render, environment variables are available at runtime but NOT automatically at build time in Docker.

**Action Required:**
In your Render Dashboard, you must add your keys with the prefix `DOCKER_BUILD_ARG_`. This tells Render to pass them as `--build-arg` to the `docker build` command.

Add these to your **Render Environment Variables**:
- `DOCKER_BUILD_ARG_FIREBASE_API_KEY`
- `DOCKER_BUILD_ARG_FIREBASE_AUTH_DOMAIN`
- `DOCKER_BUILD_ARG_FIREBASE_PROJECT_ID`
- `DOCKER_BUILD_ARG_FIREBASE_STORAGE_BUCKET`
- `DOCKER_BUILD_ARG_FIREBASE_MESSAGING_SENDER_ID`
- `DOCKER_BUILD_ARG_FIREBASE_APP_ID`
- `DOCKER_BUILD_ARG_FIREBASE_MEASUREMENT_ID`
- `DOCKER_BUILD_ARG_OPENWEATHER_API_KEY`
- `DOCKER_BUILD_ARG_GOOGLE_CLIENT_ID`
- `DOCKER_BUILD_ARG_FACEBOOK_APP_ID`

## 3. Biometrics (WebAuthn)
The app uses WebAuthn for biometrics. This is dynamically configured to use the domain name of your Render deployment.
- **Requirement:** Your app MUST be accessed via `https://`. Render provides SSL by default.
- **Domain:** The app will automatically use `xxxx.onrender.com` as the Relying Party ID.

## 4. Google SSO Configuration
1. Go to the **Firebase Console** > Build > Authentication > Settings > Authorized domains.
2. Add your Render domain: `skyfit-pro-app.onrender.com` (replace with your actual Render URL).
3. Go to the **Google Cloud Console** > APIs & Services > Credentials.
4. Update your OAuth 2.0 Client ID for Web:
   - **Authorized JavaScript origins:** `https://skyfit-pro-app.onrender.com`
   - **Authorized redirect URIs:** `https://skyfit-pro-app.onrender.com/__/auth/handler`

## 5. Facebook SSO Configuration
1. Go to the **Facebook Developers Portal**.
2. In your App Settings > Basic:
   - Add `skyfit-pro-app.onrender.com` to **App Domains**.
   - Add your Site URL: `https://skyfit-pro-app.onrender.com`
3. In Facebook Login > Settings:
   - Add `https://skyfit-pro-app.onrender.com/__/auth/handler` to **Valid OAuth Redirect URIs**.

## 6. How to Deploy
1. Connect your repository to Render.
2. Select **Web Service**.
3. Render will automatically detect the `render.yaml` and `Dockerfile`.
4. Ensure you've added the `DOCKER_BUILD_ARG_` variables as mentioned in step 2.
5. Deploy!

Your app will be live and fully functional with all secure features enabled.
