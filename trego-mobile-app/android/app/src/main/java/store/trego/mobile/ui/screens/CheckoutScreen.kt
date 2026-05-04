package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun CheckoutScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onOrderSuccess: (Int) -> Unit
) {
    val cart by viewModel.cart.collectAsState()
    val user by viewModel.user.collectAsState()
    val userAddress by viewModel.userAddress.collectAsState()
    
    var addressLine by remember { mutableStateOf(userAddress["addressLine"]?.toString() ?: "") }
    var city by remember { mutableStateOf(userAddress["city"]?.toString() ?: "") }
    var country by remember { mutableStateOf("Kosovë") }
    var zipCode by remember { mutableStateOf(userAddress["zipCode"]?.toString() ?: "") }
    var phoneNumber by remember { mutableStateOf(user?.phoneNumber ?: userAddress["phoneNumber"]?.toString() ?: "") }
    var paymentMethod by remember { mutableStateOf("cash-on-delivery") }
    
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isSubmitting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Checkout",
                subtitle = "Plotesoni te dhenat per dërgesën.",
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
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Spacer(Modifier.height(8.dp))

            Text(
                text = "ADRESA E DËRGESËS",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Black,
                color = TregoColors.accent
            )

            TregoTextField(
                value = addressLine,
                onValueChange = { addressLine = it },
                label = "Rruga / Lagjja",
                placeholder = "Psh: Rruga Agim Ramadani, Nr. 15"
            )

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TregoTextField(
                    value = city,
                    onValueChange = { city = it },
                    label = "Qyteti",
                    placeholder = "Psh: Prishtinë",
                    modifier = Modifier.weight(1f)
                )
                TregoTextField(
                    value = zipCode,
                    onValueChange = { zipCode = it },
                    label = "Kodi Postar",
                    placeholder = "10000",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f)
                )
            }

            TregoTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = "Numri i telefonit",
                placeholder = "+383 4X XXX XXX",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)
            )

            Divider(color = TregoColors.borderLight.copy(alpha = 0.5f), modifier = Modifier.padding(vertical = 8.dp))

            Text(
                text = "MËNYRA E PAGESËS",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Black,
                color = TregoColors.accent
            )
            
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = TregoColors.mutedSurfaceLight,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    RadioButton(
                        selected = paymentMethod == "cash-on-delivery",
                        onClick = { paymentMethod = "cash-on-delivery" },
                        colors = RadioButtonDefaults.colors(selectedColor = TregoColors.accent)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text("Pagesë në dorë (Cash on Delivery)", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
                }
            }

            Divider(color = TregoColors.borderLight.copy(alpha = 0.5f), modifier = Modifier.padding(vertical = 8.dp))

            val total = cart.sumOf { (it.price ?: 0.0) * (it.quantity ?: 1) }
            
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Subtotal", color = TregoColors.secondaryTextLight)
                    Text("€$total", fontWeight = FontWeight.Bold)
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Dërgesa", color = TregoColors.secondaryTextLight)
                    Text("FALAS", color = TregoColors.success, fontWeight = FontWeight.Black)
                }
                Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Total", fontWeight = FontWeight.Black, fontSize = 20.sp)
                    Text("€$total", fontWeight = FontWeight.Black, fontSize = 20.sp, color = TregoColors.accent)
                }
            }

            if (errorMessage != null) {
                Text(
                    text = errorMessage!!,
                    color = TregoColors.error,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            TregoButton(
                text = "Përfundo Porosinë",
                isLoading = isSubmitting,
                enabled = cart.isNotEmpty(),
                onClick = {
                    if (addressLine.isBlank() || city.isBlank() || phoneNumber.isBlank()) {
                        errorMessage = "Ju lutem plotësoni të gjitha të dhënat."
                        return@TregoButton
                    }
                    
                    isSubmitting = true
                    errorMessage = null
                    scope.launch {
                        val addressMap = mapOf(
                            "addressLine" to addressLine,
                            "city" to city,
                            "country" to country,
                            "zipCode" to zipCode,
                            "phoneNumber" to phoneNumber
                        )
                        val cartLineIds = cart.map { it.id }
                        val result = viewModel.createOrder(paymentMethod, addressMap, cartLineIds)
                        isSubmitting = false
                        if (result.ok && result.order != null) {
                            onOrderSuccess(result.order.id)
                        } else {
                            errorMessage = result.message ?: "Porosia dështoi."
                        }
                    }
                }
            )
            
            Spacer(modifier = Modifier.height(60.dp))
        }
    }
}
