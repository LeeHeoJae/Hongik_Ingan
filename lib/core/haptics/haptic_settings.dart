import 'package:flutter/material.dart';

import '../app_config.dart';
import 'app_haptics.dart';

class HapticSettings extends StatefulWidget {
  const HapticSettings({super.key, this.config});

  final AppConfig? config;

  @override
  State<HapticSettings> createState() => _HapticSettingsState();
}

class _HapticSettingsState extends State<HapticSettings> {
  AppConfig get _config => widget.config ?? AppConfig();
  bool _saving = false;
  String? _error;

  Future<void> _change(HapticMode? mode) async {
    if (mode == null || mode == _config.hapticMode || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    AppHaptics.instance.cancel();
    try {
      await _config.setHapticMode(mode);
    } catch (_) {
      if (mounted) setState(() => _error = '진동 설정을 저장하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '진동 피드백',
          helperText: _saving ? '저장 중' : '로그인·출석 결과와 오류에 진동해요.',
          helperMaxLines: 3,
          errorText: _error,
          errorMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<HapticMode>(
            value: _config.hapticMode,
            isExpanded: true,
            enableFeedback: false,
            onChanged: _saving ? null : _change,
            items: const [
              DropdownMenuItem(
                value: HapticMode.resultsOnly,
                child: Text('중요한 결과만'),
              ),
              DropdownMenuItem(value: HapticMode.off, child: Text('끄기')),
            ],
          ),
        ),
      ),
    );
  }
}
