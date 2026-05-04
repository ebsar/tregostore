package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import store.trego.mobile.ui.components.TregoCard
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun AdminControlScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val users by viewModel.adminUsers.collectAsState()
    val businesses by viewModel.adminBusinesses.collectAsState()
    val orders by viewModel.adminOrders.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadAdminControl()
    }

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Admin Control",
                subtitle = "Menaxhimi i platformës dhe përdoruesve.",
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
                AdminStatsStrip(users.size, businesses.size, orders.size)
            }

            item {
                Text(
                    text = "BIZNESET",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Black,
                    color = TregoColors.secondaryTextLight
                )
            }

            items(businesses.take(5)) { business ->
                TregoCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(business.businessName ?: "Biznes", fontWeight = FontWeight.Bold)
                            Text(business.ownerEmail ?: "", style = MaterialTheme.typography.bodySmall)
                        }
                        Text(business.verificationStatus ?: "PENDING", fontWeight = FontWeight.Black, color = TregoColors.accent)
                    }
                }
            }

            item {
                Text(
                    text = "PËRDORUESIT",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Black,
                    color = TregoColors.secondaryTextLight
                )
            }

            items(users.take(5)) { user ->
                TregoCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(user.fullName ?: user.email ?: "Përdorues", fontWeight = FontWeight.Bold)
                            Text(user.role ?: "USER", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AdminStatsStrip(userCount: Int, businessCount: Int, orderCount: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        StatCardSmall("Users", userCount.toString(), Modifier.weight(1f))
        StatCardSmall("Vendors", businessCount.toString(), Modifier.weight(1f))
        StatCardSmall("Orders", orderCount.toString(), Modifier.weight(1f))
    }
}

@Composable
fun StatCardSmall(label: String, value: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        color = TregoColors.mutedSurfaceLight
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(value, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleMedium)
            Text(label, style = MaterialTheme.typography.labelSmall, color = TregoColors.secondaryTextLight)
        }
    }
}
