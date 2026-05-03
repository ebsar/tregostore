package store.trego.mobile.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HeadsetMic
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Reply
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.SyncAlt
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import store.trego.mobile.data.model.ChatConversation
import store.trego.mobile.data.model.ChatMessage
import store.trego.mobile.data.model.NotificationItem
import store.trego.mobile.data.model.Product
import store.trego.mobile.data.model.ReturnRequest
import store.trego.mobile.ui.components.ProductCard
import store.trego.mobile.ui.theme.TregoColors
import store.trego.mobile.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onOpenNotification: (NotificationItem) -> Unit
) {
    val notifications by viewModel.notifications.collectAsState()
    val unread by viewModel.notificationUnreadCount.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.fetchNotifications()
        viewModel.markNotificationsRead()
    }

    TregoSecondaryScaffold(
        title = "Njoftimet",
        subtitle = if (unread > 0) "$unread te palexuara" else "Porosi, mesazhe dhe promovime",
        onBack = onBack,
        action = {
            IconButton(onClick = { viewModel.fetchNotifications() }) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh")
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (notifications.isEmpty()) {
                item {
                    EmptyStateCard(
                        title = "Ende nuk ka njoftime",
                        body = "Statusi i porosive, mesazhet e bizneseve dhe ofertat do te shfaqen ketu."
                    )
                }
            } else {
                items(notifications) { notification ->
                    NotificationRow(notification, onClick = { onOpenNotification(notification) })
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WishlistScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onOpenProduct: (Int) -> Unit
) {
    val wishlist by viewModel.wishlist.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadWishlist()
    }

    TregoSecondaryScaffold(
        title = "Wishlist",
        subtitle = "${wishlist.size} produkte te ruajtura",
        onBack = onBack
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (wishlist.isEmpty()) {
                item {
                    EmptyStateCard(
                        title = "Wishlist eshte bosh",
                        body = "Produktet qe ruan do te dalin ketu per t'i gjetur me shpejt."
                    )
                }
            } else {
                items(wishlist.chunked(2)) { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        ProductCard(row[0], Modifier.weight(1f), onClick = { onOpenProduct(row[0].id) })
                        if (row.size > 1) {
                            ProductCard(row[1], Modifier.weight(1f), onClick = { onOpenProduct(row[1].id) })
                        } else {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessagesScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit,
    onOpenConversation: (Int) -> Unit
) {
    val conversations by viewModel.conversations.collectAsState()
    var search by remember { mutableStateOf("") }
    val filtered = remember(conversations, search) {
        val query = search.trim().lowercase()
        if (query.isEmpty()) conversations else conversations.filter {
            listOf(it.counterpartName, it.businessName, it.clientName, it.lastMessagePreview)
                .joinToString(" ")
                .lowercase()
                .contains(query)
        }
    }

    LaunchedEffect(Unit) {
        viewModel.loadConversations()
    }

    TregoSecondaryScaffold(
        title = "Mesazhet",
        subtitle = "${conversations.sumOf { it.unreadCount ?: 0 }} te palexuara",
        onBack = onBack,
        action = {
            IconButton(onClick = {
                viewModel.startSupportConversation(onOpened = onOpenConversation)
            }) {
                Icon(Icons.Default.HeadsetMic, contentDescription = "Customer support")
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                OutlinedTextField(
                    value = search,
                    onValueChange = { search = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Kerko ne biseda") },
                    singleLine = true,
                    shape = RoundedCornerShape(18.dp)
                )
            }

            if (filtered.isEmpty()) {
                item {
                    EmptyStateCard(
                        title = "Nuk ka biseda",
                        body = "Hap nje profil biznesi ose perdor support per te nisur biseden."
                    )
                }
            } else {
                items(filtered) { conversation ->
                    ConversationRow(
                        conversation = conversation,
                        onClick = {
                            viewModel.openConversation(conversation)
                            onOpenConversation(conversation.id)
                        }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConversationScreen(
    conversationId: Int,
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val conversation by viewModel.activeConversation.collectAsState()
    val messages by viewModel.conversationMessages.collectAsState()
    var draft by remember { mutableStateOf("") }

    LaunchedEffect(conversationId) {
        viewModel.loadConversationMessages(conversationId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            conversation?.counterpartName ?: "Biseda",
                            fontWeight = FontWeight.Black,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            conversation?.counterpartRole ?: "Marketplace chat",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            Surface(tonalElevation = 8.dp) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    OutlinedTextField(
                        value = draft,
                        onValueChange = { draft = it },
                        modifier = Modifier.weight(1f),
                        placeholder = { Text("Shkruaj mesazh") },
                        shape = RoundedCornerShape(18.dp),
                        maxLines = 4
                    )
                    FilledIconButton(
                        onClick = {
                            viewModel.sendMessage(conversationId, draft)
                            draft = ""
                        },
                        colors = IconButtonDefaults.filledIconButtonColors(containerColor = TregoColors.accent)
                    ) {
                        Icon(Icons.Default.Send, contentDescription = "Send")
                    }
                }
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (messages.isEmpty()) {
                item {
                    EmptyStateCard(
                        title = "Nise biseden",
                        body = "Mesazhet per kete bisede do te shfaqen ketu."
                    )
                }
            } else {
                items(messages) { message ->
                    MessageBubble(message)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReturnsScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val requests by viewModel.returns.collectAsState()
    val user by viewModel.user.collectAsState()
    val canManage = user?.role == "business" || user?.role == "admin"

    LaunchedEffect(Unit) {
        viewModel.loadReturns()
    }

    TregoSecondaryScaffold(
        title = "Refund / Returne",
        subtitle = if (canManage) "Menaxho kerkesat" else "Statuset e kerkesave",
        onBack = onBack,
        action = {
            IconButton(onClick = { viewModel.loadReturns() }) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh")
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (requests.isEmpty()) {
                item {
                    EmptyStateCard(
                        title = "Ende nuk ka kerkesa",
                        body = "Refund dhe returne do te listohen ketu."
                    )
                }
            } else {
                items(requests) { request ->
                    ReturnRequestRow(
                        request = request,
                        canManage = canManage,
                        onStatus = { status -> viewModel.updateReturnStatus(request.id, status) }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BusinessHubScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val analytics by viewModel.businessAnalytics.collectAsState()
    val products by viewModel.businessProducts.collectAsState()
    val orders by viewModel.businessOrders.collectAsState()
    val promotions by viewModel.businessPromotions.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadBusinessStudio()
    }

    TregoSecondaryScaffold(
        title = "Business Studio",
        subtitle = "Produkte, porosi dhe performanca",
        onBack = onBack,
        leadingIcon = Icons.Default.Business,
        action = {
            IconButton(onClick = { viewModel.loadBusinessStudio() }) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh")
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                MetricStrip(
                    listOf(
                        "Revenue" to "€${analytics?.grossSales ?: 0.0}",
                        "Orders" to "${analytics?.orderItems ?: orders.size}",
                        "Views" to "${analytics?.viewsCount ?: 0}"
                    )
                )
            }
            item {
                SectionCard("Inventory", "${products.size} produkte", Icons.Default.Store) {
                    products.take(4).forEach { product ->
                        CompactProductRow(product)
                    }
                }
            }
            item {
                SectionCard("Orders", "${orders.size} aktive", Icons.Default.Inbox) {
                    orders.take(4).forEach { order ->
                        CompactLine("Order #${order.id}", order.status ?: "pending", "€${order.totalPrice ?: order.total ?: 0.0}")
                    }
                }
            }
            item {
                SectionCard("Promotions", "${promotions.size} aktive", Icons.Default.SyncAlt) {
                    promotions.take(3).forEach { promo ->
                        CompactLine(promo.code ?: "Promo", "${promo.discountPercent ?: 0}%", if (promo.isActive == true) "Active" else "Off")
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminControlScreen(
    viewModel: MainViewModel,
    onBack: () -> Unit
) {
    val products by viewModel.adminProducts.collectAsState()
    val users by viewModel.adminUsers.collectAsState()
    val businesses by viewModel.adminBusinesses.collectAsState()
    val orders by viewModel.adminOrders.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadAdminControl()
    }

    TregoSecondaryScaffold(
        title = "Admin Control",
        subtitle = "Platform overview",
        onBack = onBack,
        leadingIcon = Icons.Default.AdminPanelSettings,
        action = {
            IconButton(onClick = { viewModel.loadAdminControl() }) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh")
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                MetricStrip(
                    listOf(
                        "Users" to "${users.size}",
                        "Businesses" to "${businesses.size}",
                        "Orders" to "${orders.size}"
                    )
                )
            }
            item {
                SectionCard("Products", "${products.size} listings", Icons.Default.Store) {
                    products.take(5).forEach { product -> CompactProductRow(product) }
                }
            }
            item {
                SectionCard("Businesses", "${businesses.size} vendors", Icons.Default.Business) {
                    businesses.take(5).forEach { business ->
                        CompactLine(
                            business.businessName ?: "Business",
                            business.verificationStatus ?: "unverified",
                            "${business.productsCount ?: 0} products"
                        )
                    }
                }
            }
            item {
                SectionCard("Users", "${users.size} accounts", Icons.Default.AdminPanelSettings) {
                    users.take(5).forEach { user ->
                        CompactLine(user.fullName ?: user.email ?: "User", user.role ?: "user", user.email ?: "")
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TregoSecondaryScaffold(
    title: String,
    subtitle: String,
    onBack: () -> Unit,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector = Icons.Default.Notifications,
    action: @Composable RowScope.() -> Unit = {},
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(leadingIcon, contentDescription = null, tint = TregoColors.accent)
                        Column {
                            Text(title, fontWeight = FontWeight.Black)
                            Text(
                                subtitle,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = action
            )
        },
        content = content
    )
}

@Composable
private fun NotificationRow(notification: NotificationItem, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.16f))
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                Modifier.size(38.dp).clip(CircleShape).background(TregoColors.softAccentLight),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Notifications, contentDescription = null, tint = TregoColors.accent)
            }
            Column(Modifier.weight(1f)) {
                Text(notification.title ?: "Njoftim", fontWeight = FontWeight.Bold)
                Text(
                    notification.body ?: "",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    notification.createdAt ?: "",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            if (notification.isRead != true) {
                Box(Modifier.size(9.dp).clip(CircleShape).background(TregoColors.accent))
            }
        }
    }
}

@Composable
private fun ConversationRow(conversation: ChatConversation, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.16f))
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            AsyncImage(
                model = conversation.counterpartImagePath,
                contentDescription = conversation.counterpartName,
                modifier = Modifier.size(50.dp).clip(RoundedCornerShape(16.dp)).background(TregoColors.softAccentLight),
                contentScale = ContentScale.Crop
            )
            Column(Modifier.weight(1f)) {
                Text(conversation.counterpartName ?: "Biseda", fontWeight = FontWeight.Black, maxLines = 1)
                Text(
                    conversation.lastMessagePreview ?: "Nise biseden nga ketu.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            val unread = conversation.unreadCount ?: 0
            if (unread > 0) {
                Badge(containerColor = TregoColors.accent) { Text(unread.toString()) }
            }
        }
    }
}

@Composable
private fun MessageBubble(message: ChatMessage) {
    val isOwn = message.isOwn == true
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isOwn) Arrangement.End else Arrangement.Start
    ) {
        Surface(
            shape = RoundedCornerShape(
                topStart = 18.dp,
                topEnd = 18.dp,
                bottomStart = if (isOwn) 18.dp else 4.dp,
                bottomEnd = if (isOwn) 4.dp else 18.dp
            ),
            color = if (isOwn) TregoColors.accent else MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.widthIn(max = 310.dp)
        ) {
            Column(Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                Text(
                    message.body ?: "",
                    color = if (isOwn) Color.White else MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    message.createdAt ?: "",
                    color = if (isOwn) Color.White.copy(alpha = 0.72f) else MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun ReturnRequestRow(
    request: ReturnRequest,
    canManage: Boolean,
    onStatus: (String) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.16f))
    ) {
        Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                AsyncImage(
                    model = request.productImagePath,
                    contentDescription = request.productTitle,
                    modifier = Modifier.size(54.dp).clip(RoundedCornerShape(14.dp)).background(TregoColors.softAccentLight),
                    contentScale = ContentScale.Crop
                )
                Column(Modifier.weight(1f)) {
                    Text(request.productTitle ?: "Produkt", fontWeight = FontWeight.Black, maxLines = 1)
                    Text(request.reason ?: "Return request", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                StatusPill(request.status ?: "requested")
            }
            if (!request.details.isNullOrBlank()) {
                Text(request.details, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (canManage) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AssistChip(onClick = { onStatus("approved") }, label = { Text("Approve") })
                    AssistChip(onClick = { onStatus("rejected") }, label = { Text("Reject") })
                    AssistChip(onClick = { onStatus("refunded") }, label = { Text("Refund") })
                }
            }
        }
    }
}

@Composable
private fun StatusPill(status: String) {
    val normalized = status.lowercase()
    val color = when (normalized) {
        "approved", "delivered", "refunded" -> TregoColors.success
        "rejected", "cancelled" -> TregoColors.error
        else -> TregoColors.accent
    }
    Surface(shape = CircleShape, color = color.copy(alpha = 0.12f)) {
        Text(
            normalized.uppercase(),
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontWeight = FontWeight.Black
        )
    }
}

@Composable
private fun EmptyStateCard(title: String, body: String) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.16f)),
        tonalElevation = 1.dp
    ) {
        Column(
            Modifier.fillMaxWidth().padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Default.Inbox, contentDescription = null, tint = TregoColors.accent)
            Text(title, fontWeight = FontWeight.Black)
            Text(body, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun MetricStrip(metrics: List<Pair<String, String>>) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        metrics.forEach { (label, value) ->
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 1.dp,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.16f)),
                modifier = Modifier.weight(1f)
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text(label.uppercase(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(value, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleLarge)
                }
            }
        }
    }
}

@Composable
private fun SectionCard(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.16f)),
        tonalElevation = 1.dp
    ) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(icon, contentDescription = null, tint = TregoColors.accent)
                Column(Modifier.weight(1f)) {
                    Text(title, fontWeight = FontWeight.Black)
                    Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            content()
        }
    }
}

@Composable
private fun CompactProductRow(product: Product) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        AsyncImage(
            model = product.imagePath,
            contentDescription = product.title,
            modifier = Modifier.size(42.dp).clip(RoundedCornerShape(12.dp)).background(TregoColors.softAccentLight),
            contentScale = ContentScale.Crop
        )
        CompactLine(product.title, product.category ?: "Product", "€${product.price ?: 0.0}", Modifier.weight(1f))
    }
}

@Composable
private fun CompactLine(title: String, subtitle: String, trailing: String, modifier: Modifier = Modifier) {
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
        }
        Text(trailing, fontWeight = FontWeight.Black, color = TregoColors.accent)
    }
}
