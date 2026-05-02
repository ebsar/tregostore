package store.trego.mobile.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = TregoColors.accent,
    onPrimary = Color.White,
    background = TregoColors.backgroundLight,
    onBackground = TregoColors.primaryTextLight,
    surface = TregoColors.cardSurfaceLight,
    onSurface = TregoColors.primaryTextLight,
    surfaceVariant = TregoColors.mutedSurfaceLight,
    onSurfaceVariant = TregoColors.secondaryTextLight,
    outline = TregoColors.borderLight,
    error = TregoColors.error
)

private val DarkColorScheme = darkColorScheme(
    primary = TregoColors.accent,
    onPrimary = Color.White,
    background = TregoColors.backgroundDark,
    onBackground = TregoColors.primaryTextDark,
    surface = TregoColors.cardSurfaceDark,
    onSurface = TregoColors.primaryTextDark,
    surfaceVariant = TregoColors.mutedSurfaceDark,
    onSurfaceVariant = TregoColors.secondaryTextDark,
    outline = TregoColors.borderDark,
    error = TregoColors.error
)

@Composable
fun TregoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
