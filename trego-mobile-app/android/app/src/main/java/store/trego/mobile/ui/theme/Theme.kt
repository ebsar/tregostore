package store.trego.mobile.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val TregoOrange = Color(0xFFFF6F18)
val TregoOrangeStrong = Color(0xFFF26522)
val TregoOrangeSoft = Color(0xFFFFF3EA)
val TregoBlue = Color(0xFF2563EB)
val TregoBackground = Color(0xFFF6F7F8)
val TregoSurface = Color(0xFFFFFFFF)
val TregoText = Color(0xFF111827)
val TregoMuted = Color(0xFF6B7280)
val TregoBorder = Color(0xFFE5E7EB)

val DarkTregoBackground = Color(0xFF0F1115)
val DarkTregoSurface = Color(0xFF171A21)
val DarkTregoText = Color(0xFFF8FAFC)
val DarkTregoMuted = Color(0xFFA0A8B5)
val DarkTregoBorder = Color(0x1AFFFFFF)

private val LightColorScheme = lightColorScheme(
    primary = TregoOrange,
    onPrimary = Color.White,
    background = TregoBackground,
    onBackground = TregoText,
    surface = TregoSurface,
    onSurface = TregoText,
    outline = TregoBorder
)

private val DarkColorScheme = darkColorScheme(
    primary = TregoOrange,
    onPrimary = Color.White,
    background = DarkTregoBackground,
    onBackground = DarkTregoText,
    surface = DarkTregoSurface,
    onSurface = DarkTregoText,
    outline = DarkTregoBorder
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
