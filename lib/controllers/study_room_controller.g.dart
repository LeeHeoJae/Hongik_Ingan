// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_room_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StudyRoomController)
final studyRoomControllerProvider = StudyRoomControllerProvider._();

final class StudyRoomControllerProvider
    extends $NotifierProvider<StudyRoomController, StudyRoomState> {
  StudyRoomControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studyRoomControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studyRoomControllerHash();

  @$internal
  @override
  StudyRoomController create() => StudyRoomController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudyRoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudyRoomState>(value),
    );
  }
}

String _$studyRoomControllerHash() =>
    r'0a32fb27bafebc0e843067552423c23dbf271354';

abstract class _$StudyRoomController extends $Notifier<StudyRoomState> {
  StudyRoomState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<StudyRoomState, StudyRoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StudyRoomState, StudyRoomState>,
              StudyRoomState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
