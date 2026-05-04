package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun VerifyEmailScreen(
    viewModel: MainViewModel,
    email: String,
    onBack: () -> Unit,
    onVerified: () -> Unit
) {
    var code by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isSubmitting by remember { mutableStateOf(false) }
    var isResending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Verifikoni email-in",
                subtitle = "Kemi dërguar një kod 6-shifror në $email",
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Spacer(modifier = Modifier.height(20.dp))

            TregoTextField(
                value = code,
                onValueChange = { 
                    if (it.length <= 6) code = it
                    errorMessage = null
                },
                label = "Kodi i verifikimit",
                placeholder = "000000",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.fillMaxWidth()
            )

            if (errorMessage != null) {
                Text(
                    text = errorMessage!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = TregoColors.error,
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.Bold
                )
            }

            TregoButton(
                text = "Verifiko",
                isLoading = isSubmitting,
                onClick = {
                    if (code.length < 6) {
                        errorMessage = "Ju lutem shkruani kodin e plotë."
                        return@TregoButton
                    }
                    
                    isSubmitting = true
                    scope.launch {
                        val result = viewModel.verifyEmail(email, code)
                        isSubmitting = false
                        if (result.ok) {
                            onVerified()
                        } else {
                            errorMessage = result.message ?: "Verifikimi dështoi."
                        }
                    }
                }
            )

            TextButton(
                onClick = {
                    isResending = true
                    scope.launch {
                        val result = viewModel.resendEmailVerification(email)
                        isResending = false
                        errorMessage = result.message
                    }
                },
                enabled = !isResending
            ) {
                Text(
                    text = if (isResending) "Po dërgohet..." else "Nuk e keni marrë kodin? Ridërgoje",
                    style = MaterialTheme.typography.labelLarge,
                    color = TregoColors.accent,
                    fontWeight = FontWeight.Black
                )
            }
        }
    }
}
