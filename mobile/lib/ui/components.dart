import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/branding.dart';

const red = Color(0xFFB6000B);
const darkRed = Color(0xFF78000A);
const gold = Color(0xFFDA9B16);
const cream = Color(0xFF4B0006);
const ink = Color(0xFFFFF3E0);
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [darkRed, red, darkRed],
);

/// Paint the Android/iOS status area before applying SafeArea to the body.
class BrandBody extends StatelessWidget {
  const BrandBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: ColoredBox(
      color: darkRed,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Material(color: cream, child: child),
      ),
    ),
  );
}

ThemeData saiTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Cairo',
  fontFamilyFallback: const ['NotoSC'],
  scaffoldBackgroundColor: cream,
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: red,
    primary: gold,
    secondary: red,
    surface: darkRed,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: ink),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF680007),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xFFB5584C)),
    ),
  ),
);

class SaiCard extends StatelessWidget {
  const SaiCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.onTap,
  });
  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF92000D), Color(0xFF650007)],
      ),
      border: Border.all(color: const Color(0xFF9C5A32)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 7,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    ),
  );
}

class GoldWave extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 24)
    ..cubicTo(
      s.width * .25,
      s.height + 22,
      s.width * .6,
      s.height - 45,
      s.width,
      s.height - 16,
    )
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(GoldWave oldClipper) => false;
}

class SaiHeader extends StatelessWidget {
  const SaiHeader({super.key, required this.child, this.height = 115});
  final Widget child;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: GoldWave(),
            child: const ColoredBox(color: gold),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 5,
          child: ClipPath(
            clipper: GoldWave(),
            child: Container(
              decoration: const BoxDecoration(gradient: brandGradient),
              child: child,
            ),
          ),
        ),
      ],
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          logoAsset,
          height: compact ? 44 : 76,
          width: compact ? 44 : 76,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        collegeArabic,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 12 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      const Text(
        collegeChinese,
        style: TextStyle(
          color: Color(0xFFFFD56E),
          fontSize: 13,
          fontFamily: 'NotoSC',
        ),
      ),
    ],
  );
}

// Reuses only artwork rectangles from the supplied reference. Widgets/text are native Flutter.
// Replace these with original high-resolution assets later for sharper large displays.
class ReferenceArt extends StatelessWidget {
  const ReferenceArt({super.key, required this.rect, this.height = 140});
  final Rect rect;
  final double height;
  static const campus = Rect.fromLTWH(328, 146, 277, 86);
  static const temple = Rect.fromLTWH(1080, 100, 136, 91);
  static const wall = Rect.fromLTWH(331, 596, 139, 117);
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: LayoutBuilder(
      builder: (context, c) {
        final scale = math.max(c.maxWidth / rect.width, height / rect.height);
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: (c.maxWidth - rect.width * scale) / 2 - rect.left * scale,
                top: (height - rect.height * scale) / 2 - rect.top * scale,
                width: 1536 * scale,
                height: 1024 * scale,
                child: Image.asset(
                  'assets/images/approved_reference.png',
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class RedButton extends StatelessWidget {
  const RedButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD80D1B), darkRed],
      ),
    ),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    this.value,
    this.title = 'التقدم الدراسي',
    this.subtitle = 'الدروس المكتملة على هذا الجهاز',
  });
  final double? value;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => SaiCard(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'اللغة الصينية',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              Text(value == null ? 'لا توجد بيانات تقدم متصلة' : subtitle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value ?? 0,
                  strokeWidth: 7,
                  backgroundColor: const Color(0xFF9B3B42),
                  color: gold,
                ),
              ),
              Text(
                value == null ? '—' : '${(value! * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: gold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class Tile extends StatelessWidget {
  const Tile(this.title, this.icon, {super.key, this.subtitle, this.onTap});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SaiCard(
    padding: 12,
    onTap: onTap,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF5D0007),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: gold, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: ink.withValues(alpha: .76)),
                ),
            ],
          ),
        ),
        if (onTap != null) const Icon(Icons.chevron_left, size: 20),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => SaiCard(
    child: Column(
      children: [
        const Icon(Icons.info_outline, color: gold, size: 32),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}
