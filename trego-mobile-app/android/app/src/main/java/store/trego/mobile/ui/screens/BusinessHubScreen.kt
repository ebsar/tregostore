package store.trego.mobile.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Loyalty
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import store.trego.mobile.data.model.*
import store.trego.mobile.ui.components.TregoCard
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoStatusPill
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun BusinessHubScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onAddProduct: () -> Unit,
    onEditProduct: (Int) -> Unit,
    onAddPromotion: () -> Unit,
    onEditPromotion: (Int) -> Unit,
    onUpdateOrder: (Int) -> Unit
) {
    val analytics by viewModel.businessAnalytics.collectAsState()
    val products by viewModel.businessProducts.collectAsState()
    val orders by viewModel.businessOrders.collectAsState()
    val promotions by viewModel.businessPromotions.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadBusinessStudio()
    }

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Business Studio",
                subtitle = "Menaxhoni produktet dhe performancën tuaj.",
                onBack = onBack
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(bottom = 40.dp, start = 16.dp, end = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                BusinessStatsStrip(analytics)
            }

            item {
                BusinessSectionHeader("Produktet", onAddProduct)
            }

            if (products.isEmpty()) {
                item { Text("Nuk ka produkte ende.", modifier = Modifier.padding(8.dp)) }
            } else {
                items(products.take(5)) { product ->
                    TregoCard(onClick = { onEditProduct(product.id) }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(product.title, fontWeight = FontWeight.Bold)
                                Text("Stoku: ${product.stockQuantity ?: 0}", style = MaterialTheme.typography.bodySmall)
                            }
                            Text("€${product.price}", fontWeight = FontWeight.Black, color = TregoColors.accent)
                        }
                    }
                }
            }

            item {
                BusinessSectionHeader("Porositë e fundit") {}
            }

            if (orders.isEmpty()) {
                item { Text("Nuk ka porosi ende.", modifier = Modifier.padding(8.dp)) }
            } else {
                items(orders.take(5)) { order ->
                    TregoCard(onClick = { onUpdateOrder(order.id) }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Porosia #${order.id}", fontWeight = FontWeight.Bold)
                                Text(order.customerName ?: "Klient", style = MaterialTheme.typography.bodySmall)
                            }
                            TregoStatusPill(order.fulfillmentStatus ?: order.status ?: "pending")
                        }
                    }
                }
            }

            item {
                BusinessSectionHeader("Promocionet", onAddPromotion)
            }

            if (promotions.isEmpty()) {
                item { Text("Nuk ka promocione ende.", modifier = Modifier.padding(8.dp)) }
            } else {
                items(promotions) { promo ->
                    TregoCard(onClick = { onEditPromotion(promo.id) }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(promo.code ?: "CODE", fontWeight = FontWeight.Bold)
                                Text("${promo.discountPercent}% zbritje", style = MaterialTheme.typography.bodySmall)
                            }
                            if (promo.isActive == true) {
                                TregoStatusPill("APPROVED")
                            } else {
                                TregoStatusPill("CANCELLED")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun BusinessSectionHeader(title: String, onAdd: (() -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title.uppercase(),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Black,
            color = TregoColors.secondaryTextLight
        )
        if (onAdd != null) {
            IconButton(onClick = onAdd, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Default.Add, contentDescription = "Add", tint = TregoColors.accent)
            }
        }
    }
}

@Composable
fun BusinessStatsStrip(analytics: BusinessAnalytics?) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        StatCard("Shitjet", "€${analytics?.grossSales ?: 0.0}", Icons.Default.Analytics, Modifier.weight(1f))
        StatCard("Porositë", "${analytics?.ordersCount ?: 0}", Icons.Default.LocalShipping, Modifier.weight(1f))
    }
}

@Composable
fun StatCard(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(20.dp),
        color = TregoColors.softAccentLight
    ) {
        Column(Modifier.padding(16.dp)) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp), tint = TregoColors.accent)
            Spacer(Modifier.height(8.dp))
            Text(value, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleLarge, color = TregoColors.accent)
            Text(label, style = MaterialTheme.typography.labelMedium, color = TregoColors.secondaryTextLight)
        }
    }
}
