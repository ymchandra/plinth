import 'package:flutter/material.dart';

/// Design tokens shared by every screen.
class Space {
  Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class Radii {
  Radii._();
  static const double card = 14;
  static const double chip = 10;
  static final cardBorder = BorderRadius.circular(card);
}

class Sizes {
  Sizes._();

  /// Minimum touch target (Material / Apple HIG guidance).
  static const double touch = 48;
  static const double contentMaxWidth = 720;
  static const double railBreakpoint = 600;
}

class Brand {
  Brand._();
  static const seed = Color(0xFF4F6D7A);
}
