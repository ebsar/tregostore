package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignupScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onSignupSuccess: () -> Unit,
    onGoToLogin: () -> Unit
) {
    var firstName by remember { mutableStateOf("") }
    var lastName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phoneNumber by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var gender by remember { mutableStateOf("femer") }
    
    var passwordVisible by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isSubmitting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(60.dp))
            
            Text(
                text = "Krijo Llogari",
                style = MaterialTheme.typography.displayLarge,
                textAlign = TextAlign.Center
            )
            
            Text(
                text = "Bëhu pjesë e TREGIO",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.Gray,
                modifier = Modifier.padding(top = 8.dp, bottom = 40.dp)
            )

            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(32.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            ) {
                Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        AuthTextField(value = firstName, onValueChange = { firstName = it }, placeholder = "Emri", modifier = Modifier.weight(1f))
                        AuthTextField(value = lastName, onValueChange = { lastName = it }, placeholder = "Mbiemri", modifier = Modifier.weight(1f))
                    }

                    Spacer(modifier = Modifier.height(16.dp))
                    AuthTextField(value = email, onValueChange = { email = it }, placeholder = "Email Adresa")
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    AuthTextField(value = phoneNumber, onValueChange = { phoneNumber = it }, placeholder = "Nr. Telefonit")

                    Spacer(modifier = Modifier.height(16.dp))
                    AuthTextField(
                        value = password, 
                        onValueChange = { password = it }, 
                        placeholder = "Fjalëkalimi",
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(if (passwordVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, null)
                            }
                        }
                    )

                    Spacer(modifier = Modifier.height(24.dp))
                    
                    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = gender == "femer", onClick = { gender = "femer" })
                        Text("Femër", style = MaterialTheme.typography.bodyMedium)
                        Spacer(modifier = Modifier.width(16.dp))
                        RadioButton(selected = gender == "mashkull", onClick = { gender = "mashkull" })
                        Text("Mashkull", style = MaterialTheme.typography.bodyMedium)
                    }

                    if (errorMessage != null) {
                        Text(errorMessage!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 16.dp), fontSize = 13.sp)
                    }

                    Spacer(modifier = Modifier.height(32.dp))

                    Button(
                        onClick = {
                            if (firstName.isBlank() || email.isBlank() || password.isBlank()) {
                                errorMessage = "Plotesoni fushat e detyrueshme."
                                return@Button
                            }
                            isSubmitting = true
                            scope.launch {
                                val res = viewModel.register(mapOf(
                                    "fullName" to "$firstName $lastName",
                                    "email" to email,
                                    "phoneNumber" to phoneNumber,
                                    "password" to password,
                                    "gender" to gender,
                                    "birthDate" to "1995-01-01"
                                ))
                                isSubmitting = false
                                if (res.ok) onSignupSuccess() else errorMessage = res.message
                            }
                        },
                        modifier = Modifier.fillMaxWidth().height(64.dp),
                        shape = RoundedCornerShape(20.dp),
                        enabled = !isSubmitting
                    ) {
                        if (isSubmitting) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                        else Text("Regjistrohuni", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                    }
                }
            }

            Spacer(modifier = Modifier.height(40.dp))
            
            TextButton(onClick = onGoToLogin) {
                Text("Keni llogari? Kyçuni tani.", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
            
            Spacer(modifier = Modifier.height(60.dp))
        }

        IconButton(onClick = onBack, modifier = Modifier.padding(16.dp).align(Alignment.TopStart)) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    trailingIcon: @Composable (() -> Unit)? = null
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder) },
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        singleLine = true,
        visualTransformation = visualTransformation,
        trailingIcon = trailingIcon,
        colors = TextFieldDefaults.outlinedTextFieldColors(
            unfocusedBorderColor = Color.Transparent,
            focusedBorderColor = MaterialTheme.colorScheme.primary,
            containerColor = MaterialTheme.colorScheme.background
        )
    )
}
