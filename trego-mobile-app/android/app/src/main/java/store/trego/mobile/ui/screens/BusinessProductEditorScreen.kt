package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import store.trego.mobile.data.model.Product
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun BusinessProductEditorScreen(
    viewModel: MainViewModel,
    existingProduct: Product? = null,
    onBack: () -> Unit
) {
    var title by remember { mutableStateOf(existingProduct?.title ?: "") }
    var description by remember { mutableStateOf(existingProduct?.description ?: "") }
    var price by remember { mutableStateOf(existingProduct?.price?.toString() ?: "") }
    var category by remember { mutableStateOf(existingProduct?.category ?: "") }
    var stockQuantity by remember { mutableStateOf(existingProduct?.stockQuantity?.toString() ?: "") }
    
    var isSubmitting by remember { mutableStateOf(false) }
    var uiMessage by remember { mutableStateOf<String?>(null) }
    
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TregoHeader(
                title = if (existingProduct == null) "Shto produkt" else "Edito produktin",
                subtitle = "Shfaqni artikullin tuaj në marketplace.",
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

            TregoTextField(
                value = title,
                onValueChange = { title = it },
                label = "Titulli i produktit",
                placeholder = "Psh: Këmishë liri"
            )

            TregoTextField(
                value = description,
                onValueChange = { description = it },
                label = "Përshkrimi",
                placeholder = "Detajet e produktit..."
            )

            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                TregoTextField(
                    value = price,
                    onValueChange = { price = it },
                    label = "Çmimi (€)",
                    placeholder = "0.00",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1f)
                )
                TregoTextField(
                    value = stockQuantity,
                    onValueChange = { stockQuantity = it },
                    label = "Stoku",
                    placeholder = "0",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f)
                )
            }

            TregoTextField(
                value = category,
                onValueChange = { category = it },
                label = "Kategoria",
                placeholder = "Psh: Rroba"
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
                text = if (existingProduct == null) "Krijo produktin" else "Ruaj ndryshimet",
                isLoading = isSubmitting,
                onClick = {
                    val p = price.toDoubleOrNull()
                    val s = stockQuantity.toIntOrNull()
                    if (title.isBlank() || p == null) {
                        uiMessage = "Titulli dhe çmimi janë të detyrueshme."
                        return@TregoButton
                    }
                    
                    isSubmitting = true
                    scope.launch {
                        val payload = mapOf(
                            "title" to title,
                            "description" to description,
                            "price" to p,
                            "stockQuantity" to s,
                            "category" to category
                        )
                        val result = if (existingProduct == null) {
                            viewModel.createProduct(payload)
                        } else {
                            val updatePayload = payload.toMutableMap()
                            updatePayload["productId"] = existingProduct.id
                            viewModel.updateProduct(updatePayload)
                        }
                        isSubmitting = false
                        uiMessage = result.message
                        if (result.ok) onBack()
                    }
                }
            )
            
            if (existingProduct != null) {
                TregoButton(
                    text = "Fshij produktin",
                    isDestructive = true,
                    isSecondary = true,
                    onClick = {
                        isSubmitting = true
                        scope.launch {
                            val result = viewModel.deleteProduct(existingProduct.id)
                            isSubmitting = false
                            if (result.ok) onBack() else uiMessage = result.message
                        }
                    }
                )
            }
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
