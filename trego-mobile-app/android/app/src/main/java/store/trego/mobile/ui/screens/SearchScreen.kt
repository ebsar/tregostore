package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import store.trego.mobile.ui.components.ProductCard
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.components.TregoTextField
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun SearchScreen(viewModel: MainViewModel, onOpenProduct: (Int) -> Unit) {
    var query by remember { mutableStateOf("") }
    val results by viewModel.searchResults.collectAsState()
    val loading by viewModel.searchLoading.collectAsState()

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(MaterialTheme.colorScheme.background)) {
                TregoHeader(
                    title = "Kërko",
                    subtitle = "Gjeni gjithçka që ju nevojitet."
                )
                
                TregoTextField(
                    value = query,
                    onValueChange = { 
                        query = it
                        if (it.length >= 2) viewModel.performSearch(it)
                    },
                    placeholder = "Produkte, kategori, marka...",
                    trailingIcon = { 
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (loading) {
                                CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                            } else {
                                IconButton(onClick = { /* Visual Search */ }) {
                                    Icon(Icons.Default.CameraAlt, contentDescription = "Visual Search", tint = TregoColors.accent)
                                }
                                Icon(Icons.Default.Search, contentDescription = null, tint = TregoColors.secondaryTextLight)
                                Spacer(Modifier.width(8.dp))
                            }
                        }
                    },
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(results.chunked(2)) { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    ProductCard(product = pair[0], modifier = Modifier.weight(1f), onClick = { onOpenProduct(pair[0].id) })
                    if (pair.size > 1) {
                        ProductCard(product = pair[1], modifier = Modifier.weight(1f), onClick = { onOpenProduct(pair[1].id) })
                    } else {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
            
            if (results.isEmpty() && query.isNotEmpty() && !loading) {
                item {
                    Text(
                        "Nuk u gjet asnjë rezultat për \"$query\"",
                        modifier = Modifier.fillMaxWidth().padding(32.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        style = MaterialTheme.typography.bodyMedium,
                        color = TregoColors.secondaryTextLight
                    )
                }
            }
            
            item { Spacer(modifier = Modifier.height(100.dp)) }
        }
    }
}
