package store.trego.mobile.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import store.trego.mobile.ui.theme.TregoColors

@Composable
fun LoadingScreen() {
    val infiniteTransition = rememberInfiniteTransition(label = "loading")
    
    val animateOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween(4000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "offset"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentAlignment = Alignment.Center
    ) {
        // iOS-style Moving Blur Backdrop
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .size(280.dp)
                    .offset(x = (72 + animateOffset).dp, y = (-280).dp)
                    .blur(96.dp)
                    .clip(CircleShape)
                    .background(TregoColors.accent.copy(alpha = 0.15f))
            )
            Box(
                modifier = Modifier
                    .size(260.dp)
                    .offset(x = ((-88) - animateOffset).dp, y = 290.dp)
                    .blur(102.dp)
                    .clip(CircleShape)
                    .background(TregoColors.accentStrong.copy(alpha = 0.12f))
            )
            Box(
                modifier = Modifier
                    .size(220.dp)
                    .offset(x = 18.dp, y = (58 + animateOffset / 2).dp)
                    .blur(88.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
            )
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            TregoiOSSpinner()
            
            Spacer(modifier = Modifier.height(24.dp))
            
            Text(
                text = "Tregio po ngarkohet...",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                letterSpacing = 0.5.sp
            )
        }
    }
}

@Composable
private fun TregoiOSSpinner() {
    val infiniteTransition = rememberInfiniteTransition(label = "spinner")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    CircularProgressIndicator(
        modifier = Modifier
            .size(34.dp),
        color = TregoColors.accent,
        strokeWidth = 4.dp,
        trackColor = Color.Transparent,
        strokeCap = androidx.compose.ui.graphics.StrokeCap.Round
    )
}
