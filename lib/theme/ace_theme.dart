import 'package:flutter/material.dart';

/// Colours and component styles taken from the Ace Admin template so this app
/// looks the same as the web ERP.
/// Open Sans when bundled as an asset family, otherwise Segoe UI (Windows),
/// which looks nearly identical. No network access is needed.
TextStyle _openSans({
  TextStyle? textStyle,
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: 'OpenSans',
    fontFamilyFallback: const ['Segoe UI', 'Arial'],
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

class Ace {
  // Brand / navbar
  static const navbar = Color(0xFF438EB9);
  static const navbarDark = Color(0xFF2E7BA6);

  // Contextual colours (Ace "btn-*" / "infobox-*")
  static const primary = Color(0xFF428BCA);
  static const info = Color(0xFF6FB3E0);
  static const success = Color(0xFF87B87F);
  static const successDark = Color(0xFF5CB85C);
  static const warning = Color(0xFFFFB752);
  static const danger = Color(0xFFD15B47);
  static const purple = Color(0xFF9585BF);
  static const pink = Color(0xFFD6487E);
  static const grey = Color(0xFF777777);

  // Surfaces
  static const pageBg = Color(0xFFFFFFFF);
  static const breadcrumbBg = Color(0xFFF5F5F5);
  static const sidebarBg = Color(0xFFF2F2F2);
  static const border = Color(0xFFD5D5D5);
  static const borderLight = Color(0xFFE5E5E5);
  static const headerBg = Color(0xFFF7F7F7);

  // Text
  static const text = Color(0xFF393939);
  static const muted = Color(0xFF777777);
  static const link = Color(0xFF4C8FBD);
  static const widgetTitle = Color(0xFF669FC7);

  static TextTheme _textTheme(TextTheme base) {
    TextStyle s(TextStyle? t, double size, [FontWeight? w]) =>
        _openSans(textStyle: t, fontSize: size, fontWeight: w, color: text);
    return base.copyWith(
      displayLarge: s(base.displayLarge, 32),
      displayMedium: s(base.displayMedium, 28),
      displaySmall: s(base.displaySmall, 24),
      headlineLarge: s(base.headlineLarge, 24, FontWeight.w300),
      headlineMedium: s(base.headlineMedium, 22, FontWeight.w300),
      headlineSmall: s(base.headlineSmall, 18, FontWeight.w400),
      titleLarge: s(base.titleLarge, 17, FontWeight.w400),
      titleMedium: s(base.titleMedium, 15, FontWeight.w400),
      titleSmall: s(base.titleSmall, 13, FontWeight.w600),
      bodyLarge: s(base.bodyLarge, 14),
      bodyMedium: s(base.bodyMedium, 13),
      bodySmall: s(base.bodySmall, 12),
      labelLarge: s(base.labelLarge, 13, FontWeight.w600),
      labelMedium: s(base.labelMedium, 12),
      labelSmall: s(base.labelSmall, 11),
    );
  }

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: info,
        error: danger,
        surface: Colors.white,
      ).copyWith(surfaceTint: Colors.transparent),
    );

    const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
    final btnText = _openSans(fontSize: 13, fontWeight: FontWeight.w600);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: border),
    );

    return base.copyWith(
      primaryColor: navbar,
      scaffoldBackgroundColor: pageBg,
      cardColor: Colors.white,
      canvasColor: Colors.white,
      dividerColor: borderLight,
      textTheme: _textTheme(base.textTheme),
      primaryTextTheme: _textTheme(base.primaryTextTheme),
      iconTheme: const IconThemeData(color: grey),
      dividerTheme: const DividerThemeData(color: borderLight, space: 1),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFFF59942)),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: danger),
        ),
        labelStyle: _openSans(fontSize: 13, color: muted),
        floatingLabelStyle: _openSans(fontSize: 13, color: primary),
        hintStyle: _openSans(fontSize: 13, color: const Color(0xFFAAAAAA)),
        prefixIconColor: muted,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 36,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: square,
          elevation: 0,
          textStyle: btnText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: square,
          elevation: 0,
          textStyle: btnText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: grey,
          side: const BorderSide(color: border),
          shape: square,
          textStyle: btnText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: link,
          shape: square,
          textStyle: btnText,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: square,
          textStyle: btnText,
          selectedBackgroundColor: info,
          selectedForegroundColor: Colors.white,
          foregroundColor: grey,
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: Color(0xFF333333)),
        textStyle: _openSans(fontSize: 12, color: Colors.white),
      ),
    );
  }
}

/// Ace "widget-box": a bordered box with a light header and a title.
class AceWidgetBox extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final Color headerColor;
  final Color titleColor;
  final EdgeInsetsGeometry padding;

  const AceWidgetBox({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.headerColor = Ace.headerBg,
    this.titleColor = Ace.widgetTitle,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Ace.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: headerColor,
              border: const Border(bottom: BorderSide(color: Ace.border)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: titleColor),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: titleColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// Ace flat label ("label label-success").
class AceLabel extends StatelessWidget {
  final String text;
  final Color color;
  const AceLabel(this.text, {super.key, this.color = Ace.success});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: color,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
