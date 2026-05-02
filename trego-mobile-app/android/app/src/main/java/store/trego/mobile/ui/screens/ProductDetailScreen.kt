package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
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
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductDetailScreen(
    productId: Int,
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    var product by remember { mutableStateOf<Product?>(null) }
    val wishlist by viewModel.wishlist.collectAsState()
    val isWishlisted = wishlist.any { it.id == productId }

    LaunchedEffect(productId) {
        product = viewModel.homeProducts.value.find { it.id == productId }
            ?: viewModel.searchResults.value.find { it.id == productId }
    }

    Scaffold(
        bottomBar = {
            product?.let { p ->
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    tonalElevation = 12.dp,
                    shadowElevation = 24.dp
                ) {
                    Row(
                        modifier = Modifier
                            .padding(24.dp)
                            .navigationBarsPadding(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Çmimi Total",
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "€${p.price}",
                                style = MaterialTheme.typography.headlineMedium,
                                fontWeight = FontWeight.Black,
                                color = TregoColors.accent
                            )
                        }
                        Button(
                            onClick = { viewModel.addToCart(p) },
                            colors = ButtonDefaults.buttonColors(containerColor = TregoColors.accent),
                            shape = RoundedCornerShape(20.dp),
                            modifier = Modifier.height(64.dp).padding(start = 24.dp).weight(1.5f)
                        ) {
                            Text("Shto në Shportë", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                        }
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
                    Box(modifier = Modifier.fillMaxWidth().height(380.dp).padding(12.dp)) {
                        AsyncImage(
                            model = p.imagePath,
                            contentDescription = p.title,
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(32.dp))
                                .background(MaterialTheme.colorScheme.surfaceVariant),
                            contentScale = ContentScale.Crop
                        )

                        // iOS-style Floating Overlays
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                                .align(Alignment.BottomCenter),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            FloatingCircleButton(
                                icon = if (isWishlisted) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                                tint = if (isWishlisted) Color.Red else MaterialTheme.colorScheme.onSurface,
                                onClick = { viewModel.toggleWishlist(p) }
                            )
                            
                            FloatingCircleButton(
                                icon = Icons.Outlined.AddShoppingCart,
                                tint = TregoColors.accent,
                                onClick = { viewModel.addToCart(p) }
                            )
                        }

                        // Back Button Overlay
                        FloatingCircleButton(
                            icon = Icons.Default.ArrowBack,
                            modifier = Modifier.padding(16.dp).align(Alignment.TopStart),
                            onClick = onBack
                        )
                    }
                }

                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp)
                    ) {
                        Surface(
                            color = TregoColors.accent.copy(alpha = 0.1f),
                            shape = CircleShape
                        ) {
                            Text(
                                text = p.businessName ?: "Marketplace",
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                style = MaterialTheme.typography.labelLarge,
                                color = TregoColors.accent,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        
                        Text(
                            text = p.title,
                            style = MaterialTheme.typography.headlineLarge,
                            fontWeight = FontWeight.Black,
                            modifier = Modifier.padding(top = 12.dp)
                        )
                        
                        Spacer(modifier = Modifier.height(32.dp))
                        
                        Text(
                            text = "Përshkrimi i Produktit",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = p.description ?: "Nuk ka përshkrim për këtë produkt.",
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.padding(top = 12.dp),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            lineHeight = 26.sp
                        )
                        
                        Spacer(modifier = Modifier.height(40.dp))
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
        border = androidx.compose.foundation.BorderStroke(0.5.dp, Color.White.copy(alpha = 0.34f)),
        tonalElevation = 4.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(imageVector = icon, contentDescription = null, tint = tint, modifier = Modifier.size(22.dp))
        }
    }
}
