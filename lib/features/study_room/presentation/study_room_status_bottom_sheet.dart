import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/study_room/application/study_room_controller.dart';
import 'package:hongik_ingan/features/study_room/domain/study_room.dart';
import 'package:hongik_ingan/features/study_room/presentation/study_room_status_content.dart';

class StudyRoomStatusBottomSheet extends ConsumerStatefulWidget {
  const StudyRoomStatusBottomSheet({super.key});

  @override
  ConsumerState<StudyRoomStatusBottomSheet> createState() =>
      _StudyRoomStatusBottomSheetState();
}

class _StudyRoomStatusBottomSheetState
    extends ConsumerState<StudyRoomStatusBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studyRoomControllerProvider.notifier).fetchStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyRoomControllerProvider);
    final controller = ref.read(studyRoomControllerProvider.notifier);
    final subtitle = state.status == null
        ? '학관, T동, R동 좌석 현황'
        : '${state.status!.location.label} ${_formatTime(state.status!.updatedAt)} 기준';

    return CampusSheetScaffold(
      title: '열람실 현황',
      subtitle: subtitle,
      icon: Icons.local_library_rounded,
      isRefreshing: state.isLoading && state.statuses.isNotEmpty,
      onRefresh: () => controller.refresh(),
      child: const StudyRoomStatusContent(),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
