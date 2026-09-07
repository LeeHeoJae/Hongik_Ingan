import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';

/// 인증번호 입력 다이얼로그
class AttendanceCodeDialog extends StatefulWidget {
  const AttendanceCodeDialog({super.key, required this.lecture});
  final Lecture lecture;
  @override
  State<AttendanceCodeDialog> createState() => _AttendanceCodeDialogState();
}

class _AttendanceCodeDialogState extends State<AttendanceCodeDialog> {
  final _authCodeController = TextEditingController();
  @override
  void dispose() {
    _authCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('출석 인증번호', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.lecture.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _authCodeController,
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
            if (_authCodeController.text.length == 4) {
              Navigator.of(context).pop(_authCodeController.text);
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
