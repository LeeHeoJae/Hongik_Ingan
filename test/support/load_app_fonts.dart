import 'package:flutter/services.dart';

Future<void> loadAppFonts() async {
  final loader = FontLoader('Pretendard');
  for (final weight in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ]) {
    loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
  }
  await loader.load();
}
