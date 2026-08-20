import 'package:flutter/material.dart';

class HomeExpandedLayout extends StatelessWidget {
  const HomeExpandedLayout({
    super.key,
    required this.primary,
    required this.secondary,
    required this.centerVertically,
  });

  final Widget primary;
  final Widget secondary;
  final bool centerVertically;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Align(
        alignment: centerVertically ? Alignment.center : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 6, child: primary),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
