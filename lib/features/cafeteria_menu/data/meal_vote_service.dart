import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

final mealVoteAccountProvider = Provider<String?>((ref) {
  final account = ref.watch(
    homeControllerProvider.select(
      (state) => state.isLoggedIn ? state.userId?.trim().toUpperCase() : null,
    ),
  );
  return account == null || account.isEmpty ? null : account;
});

String normalizedVoteItems(List<String> items) => items
    .map((item) => item.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((item) => item.isNotEmpty)
    .join('\n');

class MealVoteAuthenticationException implements Exception {
  const MealVoteAuthenticationException();
}
