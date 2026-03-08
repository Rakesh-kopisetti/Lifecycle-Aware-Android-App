# Dockerfile for Lifecycle Master Flutter App
# Supports multiple build targets: analyze, test, build-apk, build-web

FROM ghcr.io/cirruslabs/flutter:stable AS base

# Allow Flutter to run as root in Docker
ENV FLUTTER_ALLOW_ROOT=true

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the project
COPY . .

# Enable web platform
RUN flutter create . --platforms web --project-name lifecycle_master_app || true

# ============================================
# Stage: Analyzer - Run static analysis
# ============================================
FROM base AS analyzer
RUN flutter analyze --no-fatal-infos
CMD ["flutter", "analyze"]

# ============================================
# Stage: Tester - Run unit tests
# ============================================
FROM base AS tester
CMD ["flutter", "test", "--coverage"]

# ============================================
# Stage: Web Builder - Build for web
# ============================================
FROM base AS web-builder
RUN flutter pub get && flutter build web --release
CMD ["echo", "Web build complete"]

# ============================================
# Stage: APK Builder - Build Android APK
# ============================================
FROM base AS apk-builder

# Install Android SDK dependencies
RUN flutter doctor --android-licenses || true

# Build release APK
RUN flutter build apk --release --no-tree-shake-icons

CMD ["echo", "APK build complete. Output: /app/build/app/outputs/flutter-apk/app-release.apk"]

# ============================================
# Stage: Web Server - Serve the web build
# ============================================
FROM nginx:alpine AS web-server

# Copy the built web app to nginx
COPY --from=web-builder /app/build/web /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

# ============================================
# Default stage - Development environment
# ============================================
FROM base AS development

# Expose Flutter DevTools port
EXPOSE 9100

# Default command: start in interactive mode
CMD ["bash"]
