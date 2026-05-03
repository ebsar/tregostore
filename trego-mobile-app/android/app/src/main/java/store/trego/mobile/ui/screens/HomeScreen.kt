package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import store.trego.mobile.data.model.LaunchAd
import store.trego.mobile.ui.components.ProductCard
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(viewModel: MainViewModel, onOpenProduct: (Int) -> Unit) {
    val products by viewModel.homeProducts.collectAsState()
    val sections by viewModel.recommendationSections.collectAsState()
    val launchAds by viewModel.launchAds.collectAsState()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        "TREGIO",
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontWeight = FontWeight.Black,
                            letterSpacing = (-1.5).sp
                        )
                    )
                },
                actions = {
                    IconButton(onClick = { /* Notifications */ }) {
                        Icon(Icons.Default.Notifications, contentDescription = "Notifications", modifier = Modifier.size(28.dp))
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(bottom = 120.dp)
        ) {
            // Hero Stage
            item {
                HomeHeroSection(launchAds)
            }

            // Pulse Rails
            items(sections) { section ->
                RecommendationRail(section, onOpenProduct)
            }

            // Main Product Grid
            item {
                SectionTitle("Zbuloni Produkte")
            }

            items(products.chunked(2)) { pair ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    ProductCard(
                        product = pair[0],
                        modifier = Modifier.weight(1f),
                        onClick = { onOpenProduct(pair[0].id) }
                    )
                    if (pair.size > 1) {
                        ProductCard(
                            product = pair[1],
                            modifier = Modifier.weight(1f),
                            onClick = { onOpenProduct(pair[1].id) }
                        )
                    } else {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
fun HomeHeroSection(launchAds: List<LaunchAd>) {
    val heroAd = launchAds.firstOrNull()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(290.dp)
            .padding(20.dp)
            .clip(RoundedCornerShape(32.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(TregoColors.accent.copy(alpha = 0.98f), TregoColors.softAccentLight)
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = Modifier.fillMaxSize().padding(22.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Surface(
                    color = Color.White.copy(alpha = 0.22f),
                    shape = CircleShape
                ) {
                    Text(
                        heroAd?.badge?.ifBlank { "Launch Ad" } ?: "Launch Ad",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelLarge,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    heroAd?.title?.takeIf { it.isNotBlank() } ?: "Miresevini ne\nEksperiencen TREGIO",
                    color = Color.White,
                    style = MaterialTheme.typography.headlineLarge,
                    lineHeight = 36.sp,
                    fontWeight = FontWeight.Black
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    heroAd?.subtitle?.takeIf { it.isNotBlank() } ?: "Kualiteti takon vleren.",
                    color = Color.White.copy(alpha = 0.84f),
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 2
                )
            }

            AsyncImage(
                model = heroAd?.imagePath,
                contentDescription = heroAd?.title,
                modifier = Modifier
                    .width(118.dp)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color.White.copy(alpha = 0.2f)),
                contentScale = ContentScale.Crop
            )
        }

        if (launchAds.size > 1) {
            LazyRow(
                modifier = Modifier.align(Alignment.BottomStart).padding(start = 18.dp, end = 18.dp, bottom = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(launchAds.take(5)) { ad ->
                    Surface(
                        shape = CircleShape,
                        color = Color.White.copy(alpha = 0.22f)
                    ) {
                        Text(
                            ad.title?.take(16) ?: "Launch",
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                            color = Color.White,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun RecommendationRail(
    section: store.trego.mobile.data.model.RecommendationSection,
    onOpenProduct: (Int) -> Unit
) {
    Column(modifier = Modifier.padding(vertical = 12.dp)) {
        SectionTitle(section.title, section.subtitle)
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(section.products) { product ->
                ProductCard(
                    product = product,
                    modifier = Modifier.width(160.dp),
                    onClick = { onOpenProduct(product.id) }
                )
            }
        }
    }
}

@Composable
fun SectionTitle(title: String, subtitle: String? = null) {
    Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge.copy(
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.sp
            )
        )
        if (subtitle != null) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
            )
        }
    }
}
