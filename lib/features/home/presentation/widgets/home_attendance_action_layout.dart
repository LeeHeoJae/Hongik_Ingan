import 'package:flutter/material.dart';

class HomeAttendanceActionLayout extends StatelessWidget {
  const HomeAttendanceActionLayout({
    super.key,
    required this.content,
    required this.action,
  });

  final Widget content;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            MediaQuery.sizeOf(context).width >= 960 &&
            constraints.maxWidth >= 480 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19;
        if (!wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [content, const SizedBox(height: 12), action],
          );
        }
        return SizedBox(
          height: 280,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('home-attendance-information'),
                    primary: false,
                    child: content,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 160,
                child: Center(
                  child: SizedBox(width: 160, height: 44, child: action),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
