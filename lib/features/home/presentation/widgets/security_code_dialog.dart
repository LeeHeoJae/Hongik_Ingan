import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        title: Row(
          children: [
            const Expanded(child: Text('보안코드 입력')),
            IconButton(
              tooltip: '닫기',
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: TextField(
                controller: _controller,
                autofocus: true,
                readOnly: busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: '보안코드 6자리',
                  error: _error == null ? null : Text(_error!),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? '확인 중' : '확인하고 로그인'),
          ),
        ],
      ),
    );
  }
}
