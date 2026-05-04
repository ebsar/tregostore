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

@Composable
fun HomeScreen(viewModel: MainViewModel, onOpenProduct: (Int) -> Unit) {
    val products by viewModel.homeProducts.collectAsState()
    val sections by viewModel.recommendationSections.collectAsState()
    val launchAds by viewModel.launchAds.collectAsState()

    Scaffold(
        topBar = {
            HomeHeader()
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
                SectionTitle("Zbuloni Produkte", "Përzgjedhje e veçantë për ju")
            }

            items(products.chunked(2)) { pair ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
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
fun HomeHeader() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "TREGIO",
            style = MaterialTheme.typography.headlineMedium.copy(
                fontWeight = FontWeight.Black,
                letterSpacing = (-1.5).sp,
                color = TregoColors.primaryTextLight
            )
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            IconButton(
                onClick = { /* Search */ },
                modifier = Modifier.size(40.dp).clip(CircleShape).background(TregoColors.mutedSurfaceLight)
            ) {
                Icon(Icons.Default.Search, contentDescription = "Search", modifier = Modifier.size(22.dp))
            }
            IconButton(
                onClick = { /* Notifications */ },
                modifier = Modifier.size(40.dp).clip(CircleShape).background(TregoColors.mutedSurfaceLight)
            ) {
                Icon(Icons.Default.Notifications, contentDescription = "Notifications", modifier = Modifier.size(22.dp))
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
            .height(260.dp)
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(TregoColors.accent, TregoColors.accentStrong)
                )
            )
    ) {
        Row(
            modifier = Modifier.fillMaxSize().padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Surface(
                    color = Color.White.copy(alpha = 0.2f),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        heroAd?.badge?.uppercase() ?: "NEW ARRIVAL",
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        fontWeight = FontWeight.Black,
                        fontSize = 10.sp
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    heroAd?.title ?: "Zbuloni\nKoleksionin e Ri",
                    color = Color.White,
                    style = MaterialTheme.typography.headlineSmall,
                    lineHeight = 28.sp,
                    fontWeight = FontWeight.Black
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    heroAd?.subtitle ?: "Kualiteti takon vlerën.",
                    color = Color.White.copy(alpha = 0.8f),
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 2
                )
            }

            AsyncImage(
                model = heroAd?.imagePath,
                contentDescription = null,
                modifier = Modifier
                    .width(100.dp)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color.White.copy(alpha = 0.1f)),
                contentScale = ContentScale.Crop
            )
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
