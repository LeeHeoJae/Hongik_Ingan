#!/usr/bin/env bash
set -euo pipefail

# Neon injects the isolated branch connection before a Preview build starts.
# Stop the build if its schema cannot be updated.
if [ "${VERCEL_ENV:-development}" = "preview" ]; then
  npm run db:migrate:votes
fi

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
  FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

  if [ ! -d "$FLUTTER_HOME" ]; then
    git clone --depth 1 --branch "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi

  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

flutter config --enable-web
flutter pub get

APP_ENV="${VERCEL_ENV:-development}"
BUILD_MODE="release"
if [ "$APP_ENV" = "preview" ]; then
  APP_ENV="development"
  BUILD_MODE="debug"
fi

flutter build web "--$BUILD_MODE" --wasm --base-href / \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=VERCEL_ENV="${VERCEL_ENV:-development}" \
  --dart-define=VERCEL_TARGET_ENV="${VERCEL_TARGET_ENV:-$APP_ENV}"

node scripts/optimize-web-build.js
