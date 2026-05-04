package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import store.trego.mobile.data.model.CartItem
import store.trego.mobile.data.model.OrderItem
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrdersScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val orders by viewModel.orders.collectAsState()
    var selectedFilterId by remember { mutableStateOf("all") }
    var returnTarget by remember { mutableStateOf<OrderItem?>(null) }
    var returnReason by remember { mutableStateOf("") }
    val filteredOrders = orders.filter { order ->
        val filter = orderStatusFilters.firstOrNull { it.id == selectedFilterId } ?: orderStatusFilters.first()
        orderMatchesStatusFilter(order, filter)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Porositë e mia") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        if (orders.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("Nuk keni bërë asnjë porosi ende.")
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    OrderStatusFilterRow(
                        filters = orderStatusFilters,
                        selectedFilterId = selectedFilterId,
                        orders = orders,
                        onSelect = { selectedFilterId = it }
                    )
                }

                if (filteredOrders.isEmpty()) {
                    item {
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(
                                modifier = Modifier.padding(18.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text("No orders in this status", fontWeight = FontWeight.Bold)
                                Text(
                                    "Try Waiting for shipping, Shipped, For review, or Return / Refund.",
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                        }
                    }
                }

                items(filteredOrders) { order ->
                    val orderTotal = order.totalPrice ?: order.total ?: 0.0
                    val status = order.fulfillmentStatus ?: order.status
                    val returnableItemId = returnableOrderItemId(order)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Porosia #${order.id}", fontWeight = FontWeight.Bold)
                                AssistChip(
                                    onClick = {},
                                    label = { Text(orderStatusLabel(status)) }
                                )
                            }
                            Text(
                                text = "Data: ${order.createdAt}",
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                            Divider(modifier = Modifier.padding(vertical = 12.dp))
                            if (order.items.isNullOrEmpty()) {
                                Text(
                                    text = order.itemSummary ?: "${order.totalItems ?: 0} artikuj",
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            } else {
                                order.items.forEach { item ->
                                    Text("• ${item.title} (x${item.quantity})", style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text("Total", style = MaterialTheme.typography.labelSmall)
                                    Text("€$orderTotal", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                                }
                                if (returnableItemId != null) {
                                    OutlinedButton(onClick = {
                                        returnTarget = order
                                        returnReason = ""
                                    }) {
                                        Text("Return / Refund")
                                    }
                                } else if (hasReturnActivity(order)) {
                                    AssistChip(onClick = {}, label = { Text("Return requested") })
                                }
                            }
                        }
                    }
                }
            }
        }

        returnTarget?.let { order ->
            val itemId = returnableOrderItemId(order)
            AlertDialog(
                onDismissRequest = { returnTarget = null },
                title = { Text("Return / Refund order") },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Return/refund can be requested after the order is delivered and ready for review.")
                        OutlinedTextField(
                            value = returnReason,
                            onValueChange = { returnReason = it },
                            label = { Text("Reason") },
                            minLines = 3
                        )
                    }
                },
                confirmButton = {
                    Button(
                        enabled = itemId != null && returnReason.trim().isNotEmpty(),
                        onClick = {
                            itemId?.let { viewModel.requestReturn(it, returnReason) }
                            returnTarget = null
                        }
                    ) {
                        Text("Send request")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { returnTarget = null }) {
                        Text("Cancel")
                    }
                }
            )
        }
    }
}

private data class OrderStatusFilter(
    val id: String,
    val label: String,
    val statuses: Set<String>,
    val includesReturnActivity: Boolean = false
)

private val orderStatusFilters = listOf(
    OrderStatusFilter("all", "All", emptySet()),
    OrderStatusFilter("waiting_shipping", "Waiting shipping", setOf("pending_confirmation", "confirmed", "packed", "partially_confirmed")),
    OrderStatusFilter("shipped", "Shipped", setOf("shipped")),
    OrderStatusFilter("for_review", "For review", setOf("delivered")),
    OrderStatusFilter("return_refund", "Return / Refund", setOf("returned", "refunded"), includesReturnActivity = true),
    OrderStatusFilter("cancelled", "Cancelled", setOf("cancelled", "canceled", "failed"))
)

@Composable
private fun OrderStatusFilterRow(
    filters: List<OrderStatusFilter>,
    selectedFilterId: String,
    orders: List<OrderItem>,
    onSelect: (String) -> Unit
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(filters) { filter ->
            FilterChip(
                selected = selectedFilterId == filter.id,
                onClick = { onSelect(filter.id) },
                label = {
                    Text("${filter.label} ${orders.count { orderMatchesStatusFilter(it, filter) }}")
                }
            )
        }
    }
}

private fun normalizedOrderStatus(order: OrderItem): String {
    return (order.fulfillmentStatus ?: order.status ?: "pending_confirmation").trim().lowercase()
}

private fun normalizedItemStatus(item: CartItem): String {
    return (item.fulfillmentStatus ?: item.status ?: "").trim().lowercase()
}

private fun orderMatchesStatusFilter(order: OrderItem, filter: OrderStatusFilter): Boolean {
    if (filter.id == "all") return true
    if (filter.includesReturnActivity && hasReturnActivity(order)) return true
    return normalizedOrderStatus(order) in filter.statuses
}

private fun hasReturnActivity(order: OrderItem): Boolean {
    return order.items?.any { !it.returnRequestStatus.isNullOrBlank() } == true
}

private fun returnableOrderItemId(order: OrderItem): Int? {
    return order.items
        ?.firstOrNull { item ->
            val status = normalizedItemStatus(item).ifBlank { normalizedOrderStatus(order) }
            val returnStatus = item.returnRequestStatus?.trim()?.lowercase().orEmpty()
            (status == "delivered" || status == "returned") && returnStatus !in setOf("requested", "approved", "received")
        }
        ?.id
}

private fun orderStatusLabel(status: String?): String {
    return when (status?.trim()?.lowercase()) {
        "pending_confirmation" -> "Waiting approval"
        "confirmed" -> "Waiting shipping"
        "partially_confirmed" -> "Partially waiting"
        "packed" -> "Ready to ship"
        "shipped" -> "Shipped"
        "delivered" -> "For review"
        "cancelled", "canceled" -> "Cancelled"
        "returned" -> "Return / Refund"
        "refunded" -> "Refunded"
        else -> "In progress"
    }
}
