package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.outlined.AddShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import store.trego.mobile.data.model.Product
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun ProductDetailScreen(
    productId: Int,
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onOpenConversation: (Int) -> Unit
) {
    var product by remember { mutableStateOf<Product?>(null) }
    val wishlist by viewModel.wishlist.collectAsState()
    val isWishlisted = wishlist.any { it.id == productId }
    val scope = rememberCoroutineScope()

    LaunchedEffect(productId) {
        viewModel.fetchProductDetail(productId) { loaded ->
            product = loaded
        }
    }

    Scaffold(
        bottomBar = {
            product?.let { p ->
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    tonalElevation = 8.dp,
                    color = Color.White
                ) {
                    Row(
                        modifier = Modifier
                            .padding(20.dp)
                            .navigationBarsPadding(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Çmimi",
                                style = MaterialTheme.typography.labelSmall,
                                color = TregoColors.secondaryTextLight,
                                fontWeight = FontWeight.Black
                            )
                            Text(
                                text = p.price?.let { "€$it" } ?: "-",
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Black,
                                color = TregoColors.primaryTextLight
                            )
                        }
                        TregoButton(
                            text = "Shto në Shportë",
                            modifier = Modifier.weight(1.5f),
                            onClick = { viewModel.addToCart(p) }
                        )
                    }
                }
            }
        }
    ) { padding ->
        product?.let { p ->
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = padding.calculateBottomPadding())
            ) {
                item {
                    Box(modifier = Modifier.fillMaxWidth().height(420.dp)) {
                        AsyncImage(
                            model = p.imagePath,
                            contentDescription = p.title,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )

                        // Top Navigation
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .statusBarsPadding()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            FloatingCircleButton(
                                icon = Icons.Default.ArrowBack,
                                onClick = onBack
                            )
                            FloatingCircleButton(
                                icon = if (isWishlisted) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                                tint = if (isWishlisted) Color.Red else TregoColors.primaryTextLight,
                                onClick = { viewModel.toggleWishlist(p) }
                            )
                        }
                    }
                }

                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Text(
                            text = (p.businessName ?: "TREGO").uppercase(),
                            style = MaterialTheme.typography.labelLarge,
                            color = TregoColors.accent,
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.sp
                        )
                        
                        Text(
                            text = p.title,
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Black,
                            color = TregoColors.primaryTextLight
                        )
                        
                        Divider(color = TregoColors.borderLight.copy(alpha = 0.5f))
                        
                        Text(
                            text = "Përshkrimi",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Black
                        )
                        Text(
                            text = p.description ?: "Nuk ka përshkrim për këtë produkt.",
                            style = MaterialTheme.typography.bodyLarge,
                            color = TregoColors.secondaryTextLight,
                            lineHeight = 24.sp
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        Surface(
                            onClick = {
                                viewModel.startProductConversation(p, onOpened = onOpenConversation)
                            },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(18.dp),
                            color = TregoColors.mutedSurfaceLight,
                            border = BorderStroke(1.dp, TregoColors.borderLight.copy(alpha = 0.5f))
                        ) {
                            Row(
                                modifier = Modifier.padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.Center
                            ) {
                                Icon(Icons.Default.ChatBubble, contentDescription = null, tint = TregoColors.accent, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    "Bisedo me biznesin",
                                    fontWeight = FontWeight.Black,
                                    color = TregoColors.accent,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(60.dp))
                    }
                }
            }
        } ?: Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = TregoColors.accent)
        }
    }
}

@Composable
private fun FloatingCircleButton(
    icon: ImageVector,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier
            .size(48.dp)
            .clickable { onClick() },
        shape = CircleShape,
        color = Color.White.copy(alpha = 0.82f),
        border = BorderStroke(0.5.dp, Color.White.copy(alpha = 0.34f)),
        tonalElevation = 4.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(imageVector = icon, contentDescription = null, tint = tint, modifier = Modifier.size(22.dp))
        }
    }
}
