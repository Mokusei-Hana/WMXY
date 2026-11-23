package com.sakiyui.dormhome.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import com.sakiyui.dormhome.core.storage.ThemeMode
import com.sakiyui.dormhome.core.viewmodel.DoorVisualState

@Immutable
data class DormExtendedColors(
    val isDark: Boolean,
    val bgBase: Color,
    val surfaceCard: Color,
    val surfaceElevated: Color,
    val surfaceSubtle: Color,
    val cardBorder: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val actionBlue: Color,
    val actionCyan: Color,
    val onlineGreen: Color,
    val warningAmber: Color,
    val dangerRed: Color,
    val electricYellow: Color,
    val waterBlue: Color,
    val hotWaterCoral: Color,
    val climateBlue: Color,
    val campusPurple: Color
) {
    fun accentFor(state: DoorVisualState): Color = when (state) {
        DoorVisualState.LOCKED -> actionBlue
        DoorVisualState.UNLOCKING -> actionCyan
        DoorVisualState.UNLOCKED -> onlineGreen
    }
}

private val DarkExtendedColors = DormExtendedColors(
    isDark = true,
    bgBase = Color(0xFF070C15),
    surfaceCard = Color(0xCC121B2B),
    surfaceElevated = Color(0xE6182338),
    surfaceSubtle = Color(0x14FFFFFF),
    cardBorder = Color(0x22FFFFFF),
    textPrimary = Color(0xFFF3F6FC),
    textSecondary = Color(0xFF9BA8BE),
    textTertiary = Color(0xFF6B788E),
    actionBlue = Color(0xFF3B82F6),
    actionCyan = Color(0xFF38BDF8),
    onlineGreen = Color(0xFF34D399),
    warningAmber = Color(0xFFFBBF24),
    dangerRed = Color(0xFFF87171),
    electricYellow = Color(0xFFFACC15),
    waterBlue = Color(0xFF38BDF8),
    hotWaterCoral = Color(0xFFFB923C),
    climateBlue = Color(0xFF60A5FA),
    campusPurple = Color(0xFFC084FC)
)

private val LightExtendedColors = DormExtendedColors(
    isDark = false,
    bgBase = Color(0xFFF2F6FC),
    surfaceCard = Color(0xE6FFFFFF),
    surfaceElevated = Color(0xFFFFFFFF),
    surfaceSubtle = Color(0x0D0F172A),
    cardBorder = Color(0x180F172A),
    textPrimary = Color(0xFF0F172A),
    textSecondary = Color(0xFF5B677B),
    textTertiary = Color(0xFF8B97AB),
    actionBlue = Color(0xFF2563EB),
    actionCyan = Color(0xFF0284C7),
    onlineGreen = Color(0xFF16A34A),
    warningAmber = Color(0xFFD97706),
    dangerRed = Color(0xFFDC2626),
    electricYellow = Color(0xFFD98A00),
    waterBlue = Color(0xFF0284C7),
    hotWaterCoral = Color(0xFFEA580C),
    climateBlue = Color(0xFF2563EB),
    campusPurple = Color(0xFF9333EA)
)

val LocalDormColors = staticCompositionLocalOf { DarkExtendedColors }

object DormTheme {
    val colors: DormExtendedColors
        @Composable get() = LocalDormColors.current
}

private val DormTypography = Typography(
    displaySmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 30.sp,
        lineHeight = 36.sp,
        letterSpacing = (-0.5).sp
    ),
    headlineSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp,
        lineHeight = 16.sp
    )
)

@Composable
fun DormHomeTheme(
    themeMode: ThemeMode,
    content: @Composable () -> Unit
) {
    val systemDark = isSystemInDarkTheme()
    val isDark = when (themeMode) {
        ThemeMode.SYSTEM -> systemDark
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    val extended = if (isDark) DarkExtendedColors else LightExtendedColors
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window ?: return@SideEffect
            val insetsController = WindowCompat.getInsetsController(window, view)
            insetsController.isAppearanceLightStatusBars = !isDark
            insetsController.isAppearanceLightNavigationBars = !isDark
        }
    }
    val m3Scheme = if (isDark) {
        darkColorScheme(
            primary = extended.actionBlue,
            onPrimary = Color.White,
            secondary = extended.actionCyan,
            background = extended.bgBase,
            surface = extended.surfaceCard,
            onBackground = extended.textPrimary,
            onSurface = extended.textPrimary,
            error = extended.dangerRed
        )
    } else {
        lightColorScheme(
            primary = extended.actionBlue,
            onPrimary = Color.White,
            secondary = extended.actionCyan,
            background = extended.bgBase,
            surface = extended.surfaceCard,
            onBackground = extended.textPrimary,
            onSurface = extended.textPrimary,
            error = extended.dangerRed
        )
    }

    CompositionLocalProvider(LocalDormColors provides extended) {
        MaterialTheme(
            colorScheme = m3Scheme,
            typography = DormTypography,
            content = content
        )
    }
}
