#!/usr/bin/env bash
set -euo pipefail

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
if [ "$APP_ENV" = "preview" ]; then
  APP_ENV="development"
fi

flutter build web --release --base-href / \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=VERCEL_ENV="${VERCEL_ENV:-development}" \
  --dart-define=VERCEL_TARGET_ENV="${VERCEL_TARGET_ENV:-$APP_ENV}"