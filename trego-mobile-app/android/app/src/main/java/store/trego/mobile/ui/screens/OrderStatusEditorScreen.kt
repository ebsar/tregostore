package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import store.trego.mobile.data.model.OrderItem
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun OrderStatusEditorScreen(
    viewModel: MainViewModel,
    orderItem: OrderItem,
    onBack: () -> Unit
) {
    var status by remember { mutableStateOf(orderItem.fulfillmentStatus ?: "pending") }
    var trackingCode by remember { mutableStateOf("") }
    var trackingUrl by remember { mutableStateOf("") }
    
    var isSubmitting by remember { mutableStateOf(false) }
    var uiMessage by remember { mutableStateOf<String?>(null) }
    
    val scope = rememberCoroutineScope()
    val statuses = listOf("pending", "packed", "shipped", "delivered", "cancelled")

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Përditëso porosinë",
                subtitle = "Nr. ${orderItem.id} - ${orderItem.customerName}",
                onBack = onBack
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Spacer(modifier = Modifier.height(10.dp))

            Text(
                text = "STATUSI I POROSISË",
                style = MaterialTheme.typography.labelLarge,
                color = TregoColors.accent,
                fontWeight = FontWeight.Black
            )

            statuses.forEach { s ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(s.uppercase(), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
                    RadioButton(
                        selected = status == s,
                        onClick = { status = s },
                        colors = RadioButtonDefaults.colors(selectedColor = TregoColors.accent)
                    )
                }
            }

            Divider(color = TregoColors.borderLight.copy(alpha = 0.5f))

            TregoTextField(
                value = trackingCode,
                onValueChange = { trackingCode = it },
                label = "Kodi i Tracking",
                placeholder = "Psh: RKS12345678"
            )

            TregoTextField(
                value = trackingUrl,
                onValueChange = { trackingUrl = it },
                label = "Link-u i Tracking",
                placeholder = "https://posta.al/track?id=..."
            )

            if (uiMessage != null) {
                Text(
                    text = uiMessage!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (uiMessage!!.contains("sukses", ignoreCase = true)) TregoColors.success else TregoColors.error,
                    fontWeight = FontWeight.Bold
                )
            }

            TregoButton(
                text = "Ruaj statusin",
                isLoading = isSubmitting,
                onClick = {
                    isSubmitting = true
                    scope.launch {
                        val result = viewModel.updateOrderStatus(orderItem.id, status, trackingCode, trackingUrl)
                        isSubmitting = false
                        uiMessage = result.message
                        if (result.ok) onBack()
                    }
                }
            )
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
