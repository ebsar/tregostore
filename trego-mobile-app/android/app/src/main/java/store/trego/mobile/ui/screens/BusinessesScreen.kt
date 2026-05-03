package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import store.trego.mobile.ui.components.BusinessCard
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BusinessesScreen(
    viewModel: MainViewModel,
    onOpenConversation: (Int) -> Unit
) {
    val businesses by viewModel.publicBusinesses.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Bizneset", fontWeight = FontWeight.Black) }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(businesses) { business ->
                BusinessCard(
                    business = business,
                    onClick = { /* Open Business Profile */ },
                    onMessage = {
                        viewModel.startBusinessConversation(business.id, onOpened = onOpenConversation)
                    }
                )
            }
        }
    }
}
