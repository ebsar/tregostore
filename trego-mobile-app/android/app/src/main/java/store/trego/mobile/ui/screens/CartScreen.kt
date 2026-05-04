package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import store.trego.mobile.data.model.CartItem
import store.trego.mobile.ui.components.TregoButton
import store.trego.mobile.ui.components.TregoHeader
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun CartScreen(
    viewModel: MainViewModel,
    onCheckout: () -> Unit
) {
    val cart by viewModel.cart.collectAsState()

    Scaffold(
        topBar = {
            TregoHeader(title = "Shporta")
        },
        bottomBar = {
            if (cart.isNotEmpty()) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    tonalElevation = 8.dp,
                    color = Color.White
                ) {
                    Column(
                        modifier = Modifier
                            .padding(20.dp)
                            .navigationBarsPadding()
                    ) {
                        val total = cart.sumOf { (it.price ?: 0.0) * (it.quantity ?: 1) }
                        
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Total Pagesa",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = TregoColors.primaryTextLight
                            )
                            Text(
                                text = "€$total",
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Black,
                                color = TregoColors.accent
                            )
                        }
                        
                        TregoButton(
                            text = "Vazhdo te Pagesa",
                            onClick = onCheckout
                        )
                    }
                }
            }
        }
    ) { padding ->
        if (cart.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(48.dp), tint = TregoColors.borderLight)
                    Text("Shporta është e zbrazët", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("Shtoni produkte për të filluar blerjen", color = TregoColors.secondaryTextLight)
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(cart) { item ->
                    CartItemRow(
                        item = item,
                        onRemove = { viewModel.removeFromCart(item.id) }
                    )
                }
                item { Spacer(modifier = Modifier.height(100.dp)) }
            }
        }
    }
}

@Composable
fun CartItemRow(item: CartItem, onRemove: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = TregoColors.mutedSurfaceLight,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AsyncImage(
                model = item.imagePath,
                contentDescription = null,
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(16.dp)),
                contentScale = ContentScale.Crop
            )
            
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 12.dp)
            ) {
                Text(
                    text = item.title ?: "Produkt",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "€${item.price}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TregoColors.accent,
                    fontWeight = FontWeight.Black
                )
                
                Text(
                    text = "Sasia: ${item.quantity}",
                    style = MaterialTheme.typography.labelSmall,
                    color = TregoColors.secondaryTextLight,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            
            IconButton(
                onClick = onRemove,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(Color.White)
            ) {
                Icon(Icons.Default.Delete, contentDescription = "Remove", tint = TregoColors.error, modifier = Modifier.size(18.dp))
            }
        }
    }
}
