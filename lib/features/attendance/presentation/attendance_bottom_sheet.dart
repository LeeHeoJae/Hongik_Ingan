import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';

class AttendanceBottomSheet extends ConsumerStatefulWidget {
  const AttendanceBottomSheet({super.key});

  @override
  ConsumerState<AttendanceBottomSheet> createState() =>
      _AttendanceBottomSheetState();
}

class _AttendanceBottomSheetState extends ConsumerState<AttendanceBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).fetchLecture();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final controller = ref.read(attendanceProvider.notifier);
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 16.0,
          bottom: 24.0,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHandle(context),
                const Text(
                  '전자출결',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              ...previousChildren,
                              ?currentChild,
                            ],
                          );
                        },
                    child: _buildContent(context, state, controller),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showResultDialog(
                            context,
                            isSuccess: true,
                            message: '출석이 완료되었습니다.',
                          ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('성공 미리보기'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showResultDialog(
                            context,
                            isSuccess: false,
                            message: '인증번호가 올바르지 않습니다.',
                          ),
                          icon: const Icon(Icons.error_outline),
                          label: const Text('실패 미리보기'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: state.isLoading
                      ? null
                      : () => controller.fetchLecture(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('새로고침'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textSecondary,
                    side: BorderSide(color: palette.cardOutline),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 24.0),
        decoration: BoxDecoration(
          color: palette.cardOutline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AttendanceState state,
    AttendanceController controller,
  ) {
    if (state.isLoading && state.currentLecture == null) {
      return Container(
        key: const ValueKey('loading'),
        constraints: const BoxConstraints(minHeight: 150),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (state.error != null) {
      return CampusStateMessage(
        key: const ValueKey('error'),
        icon: Icons.wifi_off_rounded,
        title: '수업 정보를 불러오지 못했어요',
        message: state.error!,
        tone: CampusStateTone.error,
      );
    }
    if (state.currentLecture == null) {
      return const CampusStateMessage(
        key: ValueKey('empty'),
        icon: Icons.event_available_outlined,
        title: '현재 출석 가능한 수업이 없어요',
        message: '수업 시간이 아니거나 전자출결이 아직 열리지 않았어요.',
      );
    }
    return KeyedSubtree(
      key: const ValueKey('content'),
      child: _buildLectureCard(
        context,
        state,
        controller,
        state.currentLecture!,
      ),
    );
  }

  Widget _buildLectureCard(
    BuildContext context,
    AttendanceState state,
    AttendanceController controller,
    Lecture lecture,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardOutline),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lecture.name.isNotEmpty ? lecture.name : '알 수 없는 수업',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lecture.time,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: palette.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: palette.success),
                    const SizedBox(width: 4),
                    Text(
                      '출석 가능',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: palette.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: state.isLoading
                        ? colorScheme.brightness == Brightness.dark
                              ? 0.05
                              : 0.08
                        : colorScheme.brightness == Brightness.dark
                        ? 0.1
                        : 0.22,
                  ),
                  blurRadius: colorScheme.brightness == Brightness.dark
                      ? 14
                      : 22,
                  spreadRadius: colorScheme.brightness == Brightness.dark
                      ? 0
                      : 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: !state.isLoading
                  ? () => _handleAttendance(context, controller, lecture)
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shadowColor: colorScheme.primary.withValues(
                  alpha: colorScheme.brightness == Brightness.dark
                      ? 0.08
                      : 0.16,
                ),
                elevation: colorScheme.brightness == Brightness.dark ? 2 : 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.isLoading
                    ? SizedBox(
                        key: const ValueKey('loading_btn'),
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        '출석하기',
                        key: ValueKey('text_btn'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttendance(
    BuildContext context,
    AttendanceController controller,
    Lecture lecture,
  ) async {
    final authCode = await _showAuthCodeDialog(context, lecture);
    if (authCode == null || authCode.isEmpty) {
      return;
    }
    if (!context.mounted) return;
    _showSnackBar(context, '현재 위치를 확인하며 출석을 시도합니다...');

    try {
      final position = await controller.getUsersLocation();
      if (!context.mounted) return;
      final result = await controller.submitAttendance(authCode, position);
      if (context.mounted) {
        if (result.contains('완료되었습니다')) {
          _showResultDialog(context, isSuccess: true, message: result);
        } else {
          _showResultDialog(context, isSuccess: false, message: result);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<String?> _showAuthCodeDialog(BuildContext context, Lecture lecture) {
    final authCodeController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final palette =
            Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('출석 인증번호', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lecture.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: authCodeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (value) {
                  if (value.length == 4) {
                    Navigator.of(context).pop(value);
                  } else {
                    _showSnackBar(context, '네 자리 숫자를 입력해 주세요.');
                  }
                },
                autofocus: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0000',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '제출 후 출석 확인을 위해 현재 위치를 확인합니다.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소', style: TextStyle(color: palette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (authCodeController.text.length == 4) {
                  Navigator.of(context).pop(authCodeController.text);
                } else {
                  _showSnackBar(context, '네 자리 숫자를 입력해 주세요.');
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('제출'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResultDialog(
    BuildContext context, {
    required bool isSuccess,
    required String message,
  }) {
    if (!kIsWeb) {
      unawaited(
        isSuccess
            ? HapticFeedback.lightImpact()
            : HapticFeedback.mediumImpact(),
      );
    }
    showDialog(
      context: context,
      builder: (context) =>
          _AttendanceResultDialog(isSuccess: isSuccess, message: message),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _AttendanceResultDialog extends StatefulWidget {
  const _AttendanceResultDialog({
    required this.isSuccess,
    required this.message,
  });

  final bool isSuccess;
  final String message;

  @override
  State<_AttendanceResultDialog> createState() =>
      _AttendanceResultDialogState();
}

class _AttendanceResultDialogState extends State<_AttendanceResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconAnimation;
  late final Animation<Offset> _failureOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _iconAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _failureOffset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0.012, 0)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0.012, 0),
          end: const Offset(-0.012, 0),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.012, 0), end: Offset.zero),
        weight: 25,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final resultColor = widget.isSuccess ? palette.success : colorScheme.error;
    final title = widget.isSuccess ? '출석 성공' : '출석 실패';

    Widget resultIcon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.isSuccess ? Icons.check_rounded : Icons.error_outline_rounded,
        color: resultColor,
        size: 28,
      ),
    );
    if (!reduceMotion && widget.isSuccess) {
      resultIcon = FadeTransition(
        opacity: _iconAnimation,
        child: ScaleTransition(scale: _iconAnimation, child: resultIcon),
      );
    }

    Widget dialog = Semantics(
      label: '$title. ${widget.message}',
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            resultIcon,
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(widget.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!reduceMotion && !widget.isSuccess) {
      dialog = SlideTransition(position: _failureOffset, child: dialog);
    }
    return dialog;
  }
}
