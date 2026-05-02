package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckoutScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onOrderSuccess: (Int) -> Unit
) {
    val cart by viewModel.cart.collectAsState()
    val user by viewModel.user.collectAsState()
    
    var addressLine by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var country by remember { mutableStateOf("Kosovë") }
    var zipCode by remember { mutableStateOf("") }
    var phoneNumber by remember { mutableStateOf(user?.phoneNumber ?: "") }
    var paymentMethod by remember { mutableStateOf("cash-on-delivery") }
    
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isSubmitting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Checkout") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = "Adresa e dërgesës",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            OutlinedTextField(
                value = addressLine,
                onValueChange = { addressLine = it },
                label = { Text("Adresa (Rruga, Nr. etj)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Spacer(modifier = Modifier.height(12.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = city,
                    onValueChange = { city = it },
                    label = { Text("Qyteti") },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
                OutlinedTextField(
                    value = zipCode,
                    onValueChange = { zipCode = it },
                    label = { Text("Zip Code") },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = { Text("Nr. Telefonit për dërgesë") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Divider(modifier = Modifier.padding(vertical = 24.dp))

            Text(
                text = "Mënyra e pagesës",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = paymentMethod == "cash-on-delivery",
                    onClick = { paymentMethod = "cash-on-delivery" }
                )
                Text("Pagesë në dorë (Cash on Delivery)")
            }

            Divider(modifier = Modifier.padding(vertical = 24.dp))

            val total = cart.sumOf { (it.price ?: 0.0) * (it.quantity ?: 1) }
            
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Subtotal", color = MaterialTheme.colorScheme.secondary)
                Text("€$total")
            }
            Row(modifier = Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Dërgesa", color = MaterialTheme.colorScheme.secondary)
                Text("FALAS")
            }
            Row(modifier = Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Total", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text("€$total", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = MaterialTheme.colorScheme.primary)
            }

            if (errorMessage != null) {
                Text(
                    text = errorMessage!!,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 16.dp),
                    fontSize = 14.sp
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            Button(
                onClick = {
                    if (addressLine.isBlank() || city.isBlank() || phoneNumber.isBlank()) {
                        errorMessage = "Ju lutem plotësoni të dhënat e dërgesës."
                        return@Button
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
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSubmitting && cart.isNotEmpty(),
                shape = MaterialTheme.shapes.medium
            ) {
                if (isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text("Përfundo Porosinë", fontWeight = FontWeight.Bold)
                }
            }
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
