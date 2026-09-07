import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';

/// 출결 결과 다이얼로그
class AttendanceResultDialog extends StatefulWidget {
  const AttendanceResultDialog({super.key, required this.result});

  final AttendanceSubmissionResult result;

  @override
  State<AttendanceResultDialog> createState() => _AttendanceResultDialogState();
}

class _AttendanceResultDialogState extends State<AttendanceResultDialog>
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
    final resultColor = widget.result.isSuccess
        ? palette.success
        : colorScheme.error;
    final title = widget.result.isSuccess ? '출석 성공' : '출석 실패';

    Widget resultIcon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.result.isSuccess
            ? Icons.check_rounded
            : Icons.error_outline_rounded,
        color: resultColor,
        size: 28,
      ),
    );
    if (!reduceMotion && widget.result.isSuccess) {
      resultIcon = FadeTransition(
        opacity: _iconAnimation,
        child: ScaleTransition(scale: _iconAnimation, child: resultIcon),
      );
    }

    Widget dialog = Semantics(
      label: '$title. ${widget.result.message}',
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            resultIcon,
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(widget.result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!reduceMotion && !widget.result.isSuccess) {
      dialog = SlideTransition(position: _failureOffset, child: dialog);
    }
    return dialog;
  }
}
