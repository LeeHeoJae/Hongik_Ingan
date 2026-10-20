import 'package:flutter/widgets.dart';

void initializeKeyboardViewport() {}

bool downloadKeyboardDiagnostics() => false;

Widget buildKeyboardViewport(BuildContext context, Widget? child) =>
    child ?? const SizedBox.shrink();
