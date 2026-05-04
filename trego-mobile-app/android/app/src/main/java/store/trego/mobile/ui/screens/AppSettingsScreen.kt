package store.trego.mobile.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun AppSettingsScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    Scaffold(
        topBar = {
            TregoHeader(
                title = "Cilësimet",
                subtitle = "Menaxhoni aplikacionin dhe preferencat tuaja.",
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
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Spacer(modifier = Modifier.height(10.dp))

            SettingsSection("Gjuha & Monedha") {
                SettingsItem("Gjuha", "Shqip") {}
                SettingsItem("Monedha", "Euro (€)") {}
            }

            SettingsSection("Njoftimet") {
                SettingsItem("Njoftimet Push", "Aktiv") {}
                SettingsItem("Email Marketing", "Jo aktiv") {}
            }

            SettingsSection("Privatësia") {
                SettingsItem("Kushtet e përdorimit", "") {}
                SettingsItem("Politika e privatësisë", "") {}
            }

            SettingsSection("Sistemi") {
                SettingsItem("Tema", "Sipas sistemit") {}
                SettingsItem("Versioni", "0.1.0 (Android Native)") {}
            }
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

@Composable
fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = Modifier.padding(vertical = 12.dp)) {
        Text(
            text = title.uppercase(),
            style = MaterialTheme.typography.labelLarge,
            color = TregoColors.accent,
            fontWeight = FontWeight.Black,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        content()
    }
}

@Composable
fun SettingsItem(title: String, value: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Bold,
            color = TregoColors.primaryTextLight
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (value.isNotEmpty()) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TregoColors.secondaryTextLight,
                    modifier = Modifier.padding(end = 8.dp)
                )
            }
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = TregoColors.borderLight,
                modifier = Modifier.size(20.dp)
            )
        }
    }
    Divider(color = TregoColors.borderLight.copy(alpha = 0.5f))
}
