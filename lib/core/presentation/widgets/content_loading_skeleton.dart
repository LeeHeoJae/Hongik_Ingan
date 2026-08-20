import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

class ContentLoadingSkeleton extends StatelessWidget {
  const ContentLoadingSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final baseColor = palette.cardSurfaceMuted;

    return Semantics(
      label: '정보를 불러오는 중입니다',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: itemCount,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return Container(
              height: index == 0 ? 118 : 104,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.cardOutline),
              ),
            );
          },
        ),
      ),
    );
  }
}
