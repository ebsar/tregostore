package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import store.trego.mobile.ui.components.ProductCard
import store.trego.mobile.ui.theme.TregoOrange
import store.trego.mobile.ui.theme.TregoOrangeSoft
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(viewModel: MainViewModel, onOpenProduct: (Int) -> Unit) {
    val products by viewModel.homeProducts.collectAsState()
    val sections by viewModel.recommendationSections.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "TREGIO",
                        style = MaterialTheme.typography.titleLarge.copy(
                            fontWeight = FontWeight.Black,
                            letterSpacing = (-1).sp
                        )
                    )
                },
                actions = {
                    IconButton(onClick = { /* Search */ }) {
                        Icon(Icons.Default.Search, contentDescription = "Search")
                    }
                    IconButton(onClick = { /* Notifications */ }) {
                        Icon(Icons.Default.Notifications, contentDescription = "Notifications")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(bottom = 80.dp)
        ) {
            // Hero Stage / Pulse Rail
            item {
                HomeHeroSection()
            }

            // Recommendation Sections (Pulse Rails)
            items(sections) { section ->
                RecommendationRail(section, onOpenProduct)
            }

            // Main Product Grid
            item {
                SectionTitle("Te gjitha")
            }

            // Simplified Grid using item chunks for performance in LazyColumn
            items(products.chunked(2)) { pair ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
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

// ... (HomeHeroSection remains same)

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
    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge.copy(
                fontWeight = FontWeight.Black
            )
        )
        if (subtitle != null) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
