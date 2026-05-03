package store.trego.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Reply
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountScreen(
    viewModel: MainViewModel,
    onLogin: () -> Unit,
    onSignup: () -> Unit,
    onOrders: () -> Unit,
    onWishlist: () -> Unit,
    onNotifications: () -> Unit,
    onMessages: () -> Unit,
    onReturns: () -> Unit,
    onBusinessHub: () -> Unit,
    onAdminControl: () -> Unit
) {
    val user by viewModel.user.collectAsState()
    val unreadNotifications by viewModel.notificationUnreadCount.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Llogaria", fontWeight = FontWeight.Black) }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                UserCard(user)
            }

            if (user == null) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = onLogin,
                            modifier = Modifier.fillMaxWidth(),
                            shape = MaterialTheme.shapes.medium
                        ) {
                            Text("Kyçuni", fontWeight = FontWeight.Bold)
                        }
                        OutlinedButton(
                            onClick = onSignup,
                            modifier = Modifier.fillMaxWidth(),
                            shape = MaterialTheme.shapes.medium
                        ) {
                            Text("Regjistrohuni", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            } else {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        AccountItem("Te dhenat personale", "Emri dhe fotoja", Icons.Default.Person) {}
                        AccountItem("Porosite e mia", "Historia e blerjeve", Icons.Default.ShoppingCart) {
                            onOrders()
                        }
                        AccountItem("Wishlist", "Produktet e ruajtura", Icons.Default.Favorite) {
                            onWishlist()
                        }
                        AccountItem("Mesazhet", "Chat me bizneset dhe support", Icons.Default.ChatBubble) {
                            onMessages()
                        }
                        AccountItem(
                            title = "Njoftimet",
                            subtitle = if (unreadNotifications > 0) "$unreadNotifications te palexuara" else "Porosi, mesazhe, oferta",
                            icon = Icons.Default.Notifications,
                            onClick = onNotifications
                        )
                        AccountItem("Refund / Returne", "Statuset e kerkesave", Icons.Default.Reply) {
                            onReturns()
                        }
                        if (user?.role == "business") {
                            AccountItem("Business Studio", "Produkte, porosi, analytics", Icons.Default.Business) {
                                onBusinessHub()
                            }
                        }
                        if (user?.role == "admin") {
                            AccountItem("Admin Control", "Platforma dhe moderimi", Icons.Default.AdminPanelSettings) {
                                onAdminControl()
                            }
                        }
                        AccountItem("Settings", "Aplikacioni dhe njoftimet", Icons.Default.Settings) {}
                        AccountItem("Shkyçu", "Dil nga llogaria", Icons.Default.ExitToApp, isDestructive = true) {
                            viewModel.logout()
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun UserCard(user: store.trego.mobile.data.model.SessionUser?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.extraLarge
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AsyncImage(
                model = user?.profileImagePath,
                contentDescription = null,
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )
            Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                Text(
                    text = user?.fullName ?: "Llogaria juaj",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = user?.email ?: "Kyçuni për të përfituar",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
fun AccountItem(
    title: String,
    subtitle: String,
    icon: ImageVector,
    isDestructive: Boolean = false,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
            )
            Column(modifier = Modifier.weight(1f).padding(horizontal = 16.dp)) {
                Text(
                    text = title,
                    fontWeight = FontWeight.Bold,
                    color = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
