import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand.dart';

/// The Material 3 theme built from [Brand]. Every stock Material component
/// (buttons, fields, chips, tabs, sheets, dialogs, snackbars, pickers) picks
/// the brand up from here, so screens that use plain widgets look right
/// without per-screen styling.
abstract final class AppTheme {
  static const _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Brand.forest,
    onPrimary: Colors.white,
    primaryContainer: Brand.canopy,
    onPrimaryContainer: Brand.canopyText,
    secondary: Brand.growth,
    onSecondary: Colors.white,
    secondaryContainer: Brand.mint,
    onSecondaryContainer: Brand.mintText,
    tertiary: Brand.goldDeep,
    onTertiary: Colors.white,
    tertiaryContainer: Brand.goldContainer,
    onTertiaryContainer: Brand.onGoldContainer,
    error: Brand.error,
    onError: Colors.white,
    errorContainer: Brand.errorContainer,
    onErrorContainer: Brand.onErrorContainer,
    surface: Brand.surface,
    onSurface: Brand.ink,
    onSurfaceVariant: Brand.inkMuted,
    surfaceDim: Brand.mistContainerHigh,
    surfaceBright: Brand.surface,
    surfaceContainerLowest: Brand.surface,
    surfaceContainerLow: Brand.mistContainerLow,
    surfaceContainer: Brand.mistContainer,
    surfaceContainerHigh: Brand.mistContainerHigh,
    surfaceContainerHighest: Brand.mistContainerHigh,
    outline: Brand.sage,
    outlineVariant: Brand.sageLight,
    shadow: Brand.canopy,
    scrim: Color(0x99012D1D),
    inverseSurface: Brand.forest,
    onInverseSurface: Colors.white,
    inversePrimary: Brand.mint,
    surfaceTint: Colors.transparent,
  );

  static TextTheme _textTheme() {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(bodyColor: Brand.ink, displayColor: Brand.forest);

    TextStyle? tight(TextStyle? s, FontWeight w, double tracking) =>
        s?.copyWith(fontWeight: w, letterSpacing: tracking);

    return base.copyWith(
      displayLarge: tight(base.displayLarge, FontWeight.w800, -1.2),
      displayMedium: tight(base.displayMedium, FontWeight.w800, -1.0),
      displaySmall: tight(base.displaySmall, FontWeight.w700, -0.6),
      headlineLarge: tight(base.headlineLarge, FontWeight.w700, -0.5),
      headlineMedium: tight(base.headlineMedium, FontWeight.w700, -0.4),
      headlineSmall: tight(base.headlineSmall, FontWeight.w700, -0.2),
      titleLarge: tight(
        base.titleLarge,
        FontWeight.w700,
        -0.2,
      )?.copyWith(color: Brand.forest),
      titleMedium: tight(base.titleMedium, FontWeight.w600, 0),
      titleSmall: tight(base.titleSmall, FontWeight.w600, 0.1),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: Brand.inkMuted, height: 1.4),
      labelLarge: tight(base.labelLarge, FontWeight.w700, 0.2),
      labelMedium: tight(base.labelMedium, FontWeight.w600, 0.3),
      labelSmall: tight(base.labelSmall, FontWeight.w600, 0.4),
    );
  }

  static ThemeData light() {
    final text = _textTheme();
    final buttonText = text.labelLarge?.copyWith(fontSize: 15);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Brand.radius),
    );
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brand.radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      primaryColor: Brand.forest,
      scaffoldBackgroundColor: Brand.mist,
      canvasColor: Brand.mist,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Brand.forest,
        selectionColor: Color(0x66A0F4C8),
        selectionHandleColor: Brand.growth,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Brand.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: text.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 19,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Brand.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusLg),
          side: const BorderSide(color: Brand.mistContainer),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Brand.forest,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Brand.mistContainerHigh,
          disabledForegroundColor: Brand.sage,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.forest,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: Brand.forest, width: 1.5),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Brand.growth,
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Brand.forest,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Brand.mist,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: Brand.sage),
        labelStyle: text.bodyLarge?.copyWith(color: Brand.inkMuted),
        floatingLabelStyle: text.labelLarge?.copyWith(color: Brand.forest),
        prefixIconColor: Brand.growth,
        suffixIconColor: Brand.sage,
        errorStyle: text.bodySmall?.copyWith(color: Brand.error),
        border: field(Brand.mistContainerHigh),
        enabledBorder: field(Brand.mistContainerHigh),
        focusedBorder: field(Brand.forest, 2),
        errorBorder: field(Brand.error, 1.5),
        focusedErrorBorder: field(Brand.error, 2),
        disabledBorder: field(Brand.mistContainer),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Brand.surface,
        selectedColor: Brand.forest,
        secondarySelectedColor: Brand.forest,
        disabledColor: Brand.mistContainer,
        checkmarkColor: Colors.white,
        labelStyle: text.labelMedium?.copyWith(color: Brand.forest),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: Colors.white),
        side: const BorderSide(color: Brand.mistContainerHigh),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Brand.forest,
        unselectedLabelColor: Brand.sage,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: Brand.growth,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Brand.mistContainer,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Brand.growth, width: 3),
          borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Brand.surface,
        indicatorColor: Brand.mint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Brand.surface,
        indicatorColor: Brand.mint,
        selectedIconTheme: const IconThemeData(color: Brand.forest),
        unselectedIconTheme: const IconThemeData(color: Brand.sage),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: Brand.forest,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: Brand.sage),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Brand.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(Brand.radiusLg),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: Brand.growth,
        textColor: Brand.ink,
        titleTextStyle: text.titleSmall?.copyWith(color: Brand.ink),
        subtitleTextStyle: text.bodySmall,
        shape: rounded,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Brand.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Brand.surface,
        dragHandleColor: Brand.sageLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Brand.radiusXl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Brand.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusXl),
        ),
        titleTextStyle: text.headlineSmall?.copyWith(color: Brand.forest),
        contentTextStyle: text.bodyMedium?.copyWith(color: Brand.inkMuted),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Brand.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: Brand.forest,
        headerForegroundColor: Colors.white,
        dividerColor: Brand.mistContainer,
        todayForegroundColor: const WidgetStatePropertyAll(Brand.growth),
        todayBorder: const BorderSide(color: Brand.growth),
        dayStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusXl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Brand.forest,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: Brand.mint,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: rounded,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Brand.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Brand.canopy.withValues(alpha: 0.2),
        textStyle: text.bodyMedium,
        shape: rounded,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Brand.forest,
          borderRadius: BorderRadius.circular(Brand.radiusSm),
        ),
        textStyle: text.labelMedium?.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Brand.growth,
        linearTrackColor: Brand.mistContainer,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: Brand.mistContainer,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Brand.forest : null,
        ),
        side: const BorderSide(color: Brand.sage, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Brand.sage,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Brand.growth : null,
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: Brand.error,
        textColor: Colors.white,
      ),
    );
  }
}
