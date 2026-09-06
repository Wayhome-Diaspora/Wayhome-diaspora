import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:flutter/material.dart';

/// Waya app theme — built on top of BMONI's dark theme.
/// The warm, human tone is achieved through the app's screen designs
/// and copy; the BMONI theme provides the base design system.
class WayaTheme {
  WayaTheme._();

  static ThemeData get dark => BMoniTheme.darkTheme();

  static ThemeData get light => BMoniTheme.lightTheme();
}
