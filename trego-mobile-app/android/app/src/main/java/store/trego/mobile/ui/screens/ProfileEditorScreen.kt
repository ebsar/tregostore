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
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun ProfileEditorScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val user by viewModel.user.collectAsState()
    
    var firstName by remember { mutableStateOf(user?.firstName ?: "") }
    var lastName by remember { mutableStateOf(user?.lastName ?: "") }
    var email by remember { mutableStateOf(user?.email ?: "") }
    var phoneNumber by remember { mutableStateOf(user?.phoneNumber ?: "") }
    var isSubmitting by remember { mutableStateOf(false) }
    var uiMessage by remember { mutableStateOf<String?>(null) }
    
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Të dhënat personale",
                subtitle = "Përditësoni profilin tuaj publik dhe privat.",
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
                value = firstName,
                onValueChange = { firstName = it },
                label = "Emri",
                placeholder = "Emri juaj"
            )

            TregoTextField(
                value = lastName,
                onValueChange = { lastName = it },
                label = "Mbiemri",
                placeholder = "Mbiemri juaj"
            )

            TregoTextField(
                value = email,
                onValueChange = { email = it },
                label = "Email",
                placeholder = "email@shembull.com"
            )

            TregoTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = "Numri i telefonit",
                placeholder = "+383 4X XXX XXX"
            )

            if (uiMessage != null) {
                Text(
                    text = uiMessage!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (uiMessage!!.contains("sukses", ignoreCase = true)) TregoColors.success else TregoColors.error,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            TregoButton(
                text = "Ruaj ndryshimet",
                isLoading = isSubmitting,
                onClick = {
                    isSubmitting = true
                    scope.launch {
                        val result = viewModel.updateProfile(mapOf(
                            "firstName" to firstName,
                            "lastName" to lastName,
                            "email" to email,
                            "phoneNumber" to phoneNumber
                        ))
                        isSubmitting = false
                        uiMessage = result.message
                    }
                }
            )
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
