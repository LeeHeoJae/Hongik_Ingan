import 'package:flutter/widgets.dart';

void startKeyboardDiagnostics() {}

bool downloadKeyboardDiagnostics() => false;

Widget buildKeyboardViewport(BuildContext context, Widget? child) =>
    child ?? const SizedBox.shrink();
