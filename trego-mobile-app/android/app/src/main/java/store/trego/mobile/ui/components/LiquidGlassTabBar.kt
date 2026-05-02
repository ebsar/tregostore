package store.trego.mobile.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material.icons.outlined.Store
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import store.trego.mobile.ui.theme.TregoColors
import kotlin.math.PI
import kotlin.math.sin

enum class LiquidGlassTab(val route: String, val title: String, val icon: ImageVector, val selectedIcon: ImageVector) {
    Home("home", "Home", Icons.Outlined.Home, Icons.Default.Home),
    Businesses("businesses", "Bizneset", Icons.Outlined.Store, Icons.Default.Store),
    Cart("cart", "Cart", Icons.Outlined.ShoppingCart, Icons.Default.ShoppingCart),
    Account("account", "Llogaria", Icons.Outlined.Person, Icons.Default.Person),
    Search("search", "Kerko", Icons.Outlined.Search, Icons.Default.Search)
}

@Composable
fun LiquidGlassTabBar(
    selection: LiquidGlassTab,
    badges: Map<LiquidGlassTab, String> = emptyMap(),
    onSelectionChange: (LiquidGlassTab) -> Unit
) {
    val groupedTabs = listOf(LiquidGlassTab.Home, LiquidGlassTab.Businesses, LiquidGlassTab.Cart, LiquidGlassTab.Account)
    val shellHeight = 64.dp
    val searchOrbSize = 62.dp
    val gap = 12.dp

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 32.dp),
        horizontalArrangement = Arrangement.spacedBy(gap),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Grouped Tab Shell (Capsule)
        Box(
            modifier = Modifier
                .weight(1f)
                .height(shellHeight)
                .shadow(12.dp, RoundedCornerShape(32.dp), spotColor = Color.Black.copy(alpha = 0.2f))
                .clip(RoundedCornerShape(32.dp))
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.94f))
                .border(0.5.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(32.dp))
        ) {
            TregoGlassNoiseTexture(modifier = Modifier.fillMaxSize(), grainOpacity = 0.18f)

            val selectionIndex = groupedTabs.indexOf(selection).takeIf { it != -1 } ?: 0
            val animatedIndex by animateFloatAsState(
                targetValue = selectionIndex.toFloat(),
                animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow),
                label = "pillIndex"
            )


            // Active Pill
            if (selection != LiquidGlassTab.Search) {
                BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                    val slotWidth = maxWidth / groupedTabs.size
                    val fraction = (animatedIndex % 1f)
                    val stretch = sin(fraction * PI.toFloat()) * 20.dp.value
                    val pillWidth = slotWidth - 10.dp + stretch.dp
                    val offset = animatedIndex * slotWidth.value

                    Box(
                        modifier = Modifier
                            .offset(x = offset.dp + 5.dp)
                            .width(pillWidth)
                            .height(shellHeight - 10.dp)
                            .align(Alignment.CenterStart)
                            .clip(RoundedCornerShape(26.dp))
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        TregoColors.accent.copy(alpha = 0.12f),
                                        TregoColors.accent.copy(alpha = 0.04f)
                                    )
                                )
                            )
                            .border(0.5.dp, TregoColors.accent.copy(alpha = 0.2f), RoundedCornerShape(26.dp))
                    )
                }
            }

            Row(modifier = Modifier.fillMaxSize()) {
                groupedTabs.forEach { tab ->
                    TabButton(
                        tab = tab,
                        isSelected = selection == tab,
                        badge = badges[tab],
                        modifier = Modifier.weight(1f),
                        onClick = { onSelectionChange(tab) }
                    )
                }
            }
        }

        // Search Orb
        SearchOrb(
            isSelected = selection == LiquidGlassTab.Search,
            badge = badges[LiquidGlassTab.Search],
            size = searchOrbSize,
            onClick = { onSelectionChange(LiquidGlassTab.Search) }
        )
    }
}

@Composable
private fun TabButton(
    tab: LiquidGlassTab,
    isSelected: Boolean,
    badge: String?,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxHeight()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Box {
                Icon(
                    imageVector = if (isSelected) tab.selectedIcon else tab.icon,
                    contentDescription = tab.title,
                    tint = if (isSelected) TregoColors.accent else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
                if (badge != null) {
                    Badge(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .offset(x = 8.dp, y = (-4).dp)
                    ) {
                        Text(badge, fontSize = 9.sp)
                    }
                }
            }
            Text(
                text = tab.title,
                fontSize = 10.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = if (isSelected) TregoColors.accent else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

@Composable
private fun SearchOrb(
    isSelected: Boolean,
    badge: String?,
    size: Dp,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(size)
            .shadow(12.dp, CircleShape, spotColor = TregoColors.accent.copy(alpha = 0.3f))
            .clip(CircleShape)
            .background(
                if (isSelected) {
                    Brush.linearGradient(listOf(TregoColors.accent, TregoColors.accentStrong))
                } else {
                    Brush.linearGradient(listOf(MaterialTheme.colorScheme.surface, MaterialTheme.colorScheme.surfaceVariant))
                }
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = if (isSelected) LiquidGlassTab.Search.selectedIcon else LiquidGlassTab.Search.icon,
            contentDescription = "Search",
            tint = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.size(26.dp)
        )
    }
}
