class DeploymentEnvironment {
  const DeploymentEnvironment._();

  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const vercelEnv = String.fromEnvironment(
    'VERCEL_ENV',
    defaultValue: 'development',
  );

  static const vercelTargetEnv = String.fromEnvironment(
    'VERCEL_TARGET_ENV',
    defaultValue: appEnv,
  );

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';
}
