// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MenuController)
final menuControllerProvider = MenuControllerProvider._();

final class MenuControllerProvider
    extends $NotifierProvider<MenuController, MenuState> {
  MenuControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'menuControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$menuControllerHash();

  @$internal
  @override
  MenuController create() => MenuController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MenuState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MenuState>(value),
    );
  }
}

String _$menuControllerHash() =>
    r'55c217303c0c0f9e9c7a859fef7405e9264476ca';

abstract class _$MenuController extends $Notifier<MenuState> {
  MenuState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MenuState, MenuState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MenuState, MenuState>,
              MenuState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
