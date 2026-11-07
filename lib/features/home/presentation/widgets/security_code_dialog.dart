import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/presentation/widgets/code_entry_controls.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';

class _SecurityCodeController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final displayedText = text.isEmpty
        ? ''
        : '${'•' * (text.length - 1)}${text.substring(text.length - 1)}';
    return TextSpan(style: style, text: displayedText);
  }
}

class SecurityCodeDialog extends ConsumerStatefulWidget {
  const SecurityCodeDialog({super.key, required this.onSubmit});

  final Future<LoginResult?> Function(String code) onSubmit;

  @override
  ConsumerState<SecurityCodeDialog> createState() => _SecurityCodeDialogState();
}

class _SecurityCodeDialogState extends ConsumerState<SecurityCodeDialog> {
  final _controller = _SecurityCodeController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!isValidSecurityCode(_controller.text)) {
      setState(() => _error = '보안코드 6자리를 입력해 주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (result?.isSuccess == true) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {
      _submitting = false;
      _error = result?.isFailure == true ? result!.displayMessage : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final verifying = ref.watch(
      homeControllerProvider.select(
        (state) => state.loginStatus == LoginStatus.verifyingSecurityCode,
      ),
    );
    final busy = _submitting || verifying;
    ref.listen(homeControllerProvider, (previous, next) {
      if (previous?.isSecurityCodeStage == true &&
          !next.isSecurityCodeStage &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        constraints: const BoxConstraints(maxWidth: 360),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: CodeEntryHeading(
          title: '보안코드 입력',
          onClose: busy ? null : () => Navigator.of(context).pop(),
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: CodeEntryField(
                controller: _controller,
                length: 6,
                label: '보안코드 6자리',
                readOnly: busy,
                error: _error,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: CodeEntryAction(
              onPressed: busy ? null : _submit,
              label: busy ? '확인 중' : '확인하고 로그인',
            ),
          ),
        ],
      ),
    );
  }
}
