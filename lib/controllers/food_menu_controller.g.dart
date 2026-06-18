// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_menu_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FoodMenuController)
final foodMenuControllerProvider = FoodMenuControllerProvider._();

final class FoodMenuControllerProvider
    extends $NotifierProvider<FoodMenuController, FoodMenuState> {
  FoodMenuControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodMenuControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodMenuControllerHash();

  @$internal
  @override
  FoodMenuController create() => FoodMenuController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodMenuState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodMenuState>(value),
    );
  }
}

String _$foodMenuControllerHash() =>
    r'55c217303c0c0f9e9c7a859fef7405e9264476ca';

abstract class _$FoodMenuController extends $Notifier<FoodMenuState> {
  FoodMenuState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FoodMenuState, FoodMenuState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FoodMenuState, FoodMenuState>,
              FoodMenuState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
