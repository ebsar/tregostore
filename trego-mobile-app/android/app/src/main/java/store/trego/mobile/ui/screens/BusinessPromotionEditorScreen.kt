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
import store.trego.mobile.data.model.Promotion
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun BusinessPromotionEditorScreen(
    viewModel: MainViewModel,
    existingPromotion: Promotion? = null,
    onBack: () -> Unit
) {
    var code by remember { mutableStateOf(existingPromotion?.code ?: "") }
    var discountPercent by remember { mutableStateOf(existingPromotion?.discountPercent?.toString() ?: "") }
    
    var isSubmitting by remember { mutableStateOf(false) }
    var uiMessage by remember { mutableStateOf<String?>(null) }
    
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TregoHeader(
                title = if (existingPromotion == null) "Shto promocion" else "Edito promocionin",
                subtitle = "Krijo zbritje për klientët tuaj.",
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
                value = code,
                onValueChange = { code = it },
                label = "Kodi i promocionit",
                placeholder = "Psh: ZBRITJE10"
            )

            TregoTextField(
                value = discountPercent,
                onValueChange = { discountPercent = it },
                label = "Zbritja (%)",
                placeholder = "0",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
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
                text = if (existingPromotion == null) "Krijo promocionin" else "Ruaj ndryshimet",
                isLoading = isSubmitting,
                onClick = {
                    val d = discountPercent.toIntOrNull()
                    if (code.isBlank() || d == null) {
                        uiMessage = "Kodi dhe zbritja janë të detyrueshme."
                        return@TregoButton
                    }
                    
                    isSubmitting = true
                    scope.launch {
                        val payload = mapOf(
                            "code" to code,
                            "discountPercent" to d,
                            "isActive" to true
                        )
                        val result = if (existingPromotion == null) {
                            viewModel.saveBusinessPromotion(payload)
                        } else {
                            val updatePayload = payload.toMutableMap()
                            updatePayload["promotionId"] = existingPromotion.id
                            viewModel.saveBusinessPromotion(updatePayload)
                        }
                        isSubmitting = false
                        uiMessage = result.message
                        if (result.ok) onBack()
                    }
                }
            )
            
            if (existingPromotion != null) {
                TregoButton(
                    text = "Fshij promocionin",
                    isDestructive = true,
                    isSecondary = true,
                    onClick = {
                        isSubmitting = true
                        scope.launch {
                            val result = viewModel.deleteBusinessPromotion(existingPromotion.id)
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
