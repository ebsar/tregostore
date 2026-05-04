package store.trego.mobile.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
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
fun LoginScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onLoginSuccess: () -> Unit,
    onGoToSignup: () -> Unit
) {
    var identifier by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isSubmitting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TregoHeader(
                title = "Mirësevini përsëri",
                subtitle = "Kyçuni në llogarinë tuaj për të vazhduar blerjet.",
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
            Spacer(modifier = Modifier.height(8.dp))

            TregoTextField(
                value = identifier,
                onValueChange = { 
                    identifier = it
                    errorMessage = null
                },
                label = "Email ose Telefoni",
                placeholder = "emri@email.com",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
            )

            TregoTextField(
                value = password,
                onValueChange = { 
                    password = it
                    errorMessage = null
                },
                label = "Fjalëkalimi",
                placeholder = "••••••••",
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                trailingIcon = {
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                            contentDescription = null,
                            tint = TregoColors.secondaryTextLight
                        )
                    }
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)
            )

            if (errorMessage != null) {
                Text(
                    text = errorMessage!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = TregoColors.error,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Start,
                    fontWeight = FontWeight.Bold
                )
            }

            Text(
                text = "Keni harruar fjalëkalimin?",
                style = MaterialTheme.typography.labelLarge,
                color = TregoColors.accent,
                fontWeight = FontWeight.Black,
                modifier = Modifier
                    .align(Alignment.End)
                    .clickable { /* Forgot Password */ }
            )

            Spacer(modifier = Modifier.height(12.dp))

            TregoButton(
                text = "Kyçu",
                isLoading = isSubmitting,
                onClick = {
                    if (identifier.isBlank() || password.isBlank()) {
                        errorMessage = "Ju lutem plotësoni të gjitha fushat."
                        return@TregoButton
                    }
                    
                    isSubmitting = true
                    errorMessage = null
                    scope.launch {
                        val result = viewModel.login(identifier, password)
                        isSubmitting = false
                        if (result.ok) {
                            onLoginSuccess()
                        } else {
                            errorMessage = result.message ?: "Kyçja dështoi."
                        }
                    }
                }
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 16.dp),
                contentAlignment = Alignment.Center
            ) {
                Divider(color = TregoColors.borderLight.copy(alpha = 0.5f))
                Text(
                    text = "OSE",
                    modifier = Modifier
                        .background(MaterialTheme.colorScheme.background)
                        .padding(horizontal = 16.dp),
                    style = MaterialTheme.typography.labelSmall,
                    color = TregoColors.secondaryTextLight,
                    fontWeight = FontWeight.Black
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                SocialLoginButton(
                    text = "Google",
                    modifier = Modifier.weight(1f),
                    onClick = { /* Google Login */ }
                )
                SocialLoginButton(
                    text = "Facebook",
                    modifier = Modifier.weight(1f),
                    onClick = { /* Facebook Login */ }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "Nuk keni llogari? ",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TregoColors.secondaryTextLight
                )
                Text(
                    text = "Regjistrohuni",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TregoColors.accent,
                    fontWeight = FontWeight.Black,
                    modifier = Modifier.clickable { onGoToSignup() }
                )
            }
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

@Composable
fun SocialLoginButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        modifier = modifier.height(54.dp),
        shape = RoundedCornerShape(16.dp),
        color = TregoColors.mutedSurfaceLight,
        border = BorderStroke(1.dp, TregoColors.borderLight.copy(alpha = 0.5f))
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = text,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = TregoColors.primaryTextLight
            )
        }
    }
}

