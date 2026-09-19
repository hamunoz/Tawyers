/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:material_ui/material_ui.dart';
import 'package:musify/widgets/marquee.dart';

class MarqueeTextWidget extends StatelessWidget {
  const MarqueeTextWidget({
    super.key,
    required this.text,
    required this.fontColor,
    required this.fontSize,
    required this.fontWeight,
  });
  final String text;
  final Color fontColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return MarqueeWidget(
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: fontColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
