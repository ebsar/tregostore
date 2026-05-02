package store.trego.mobile.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Fill
import kotlin.random.Random

@Composable
fun TregoGlassNoiseTexture(
    modifier: Modifier = Modifier,
    seed: Int = 17,
    grainOpacity: Float = 0.1f
) {
    Canvas(modifier = modifier) {
        val random = Random(seed)
        for (i in 0 until 56) {
            val x = random.nextFloat() * size.width
            val y = random.nextFloat() * size.height
            val radius = 0.45f + random.nextFloat() * 1.15f
            val alpha = grainOpacity * (0.08f + random.nextFloat() * 0.34f)
            
            drawCircle(
                color = Color.White.copy(alpha = alpha),
                radius = radius,
                center = androidx.compose.ui.geometry.Offset(x, y),
                style = Fill
            )
        }
    }
}
