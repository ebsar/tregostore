package store.trego.mobile.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import store.trego.mobile.ui.components.LiquidGlassTab
import store.trego.mobile.ui.components.LiquidGlassTabBar
import store.trego.mobile.viewmodel.MainViewModel

@Composable
fun MainScreen(viewModel: MainViewModel) {
    val navController = rememberNavController()
    val isLoading by viewModel.isLoading.collectAsState()
    val cart by viewModel.cart.collectAsState()
    val orders by viewModel.orders.collectAsState()
    val notifications by viewModel.notificationUnreadCount.collectAsState()
    val uiMessage by viewModel.uiMessage.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    LaunchedEffect(uiMessage) {
        val message = uiMessage ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(message)
        viewModel.clearUiMessage()
    }

    // Map cart count and notifications to badges
    val badges = remember(cart, orders, notifications) {
        val map = mutableMapOf<LiquidGlassTab, String>()
        if (cart.isNotEmpty()) {
            val totalQty = cart.sumOf { it.quantity ?: 1 }
            map[LiquidGlassTab.Cart] = if (totalQty > 99) "99+" else totalQty.toString()
        }
        if (notifications > 0) {
            map[LiquidGlassTab.Account] = if (notifications > 99) "99+" else notifications.toString()
        }
        map
    }

    if (isLoading) {
        LoadingScreen()
    } else {
        Scaffold(
            snackbarHost = { SnackbarHost(snackbarHostState) },
            bottomBar = {
                val currentRoute = currentDestination?.route
                val showBottomBar = LiquidGlassTab.values().any { it.route == currentRoute }

                if (showBottomBar) {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
                        val currentTab = LiquidGlassTab.values().find { it.route == currentRoute } ?: LiquidGlassTab.Home
                        
                        LiquidGlassTabBar(
                            selection = currentTab,
                            badges = badges,
                            onSelectionChange = { tab ->
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        )
                    }
                }
            }
        ) { innerPadding ->
            NavHost(
                navController = navController,
                startDestination = LiquidGlassTab.Home.route,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = if (LiquidGlassTab.values().any { it.route == currentDestination?.route }) 0.dp else innerPadding.calculateBottomPadding())
            ) {
                composable(LiquidGlassTab.Home.route) { 
                    HomeScreen(viewModel, onOpenProduct = { id -> navController.navigate("product/$id") }) 
                }
                composable(LiquidGlassTab.Businesses.route) {
                    BusinessesScreen(
                        viewModel = viewModel,
                        onOpenConversation = { id -> navController.navigate("conversation/$id") }
                    )
                }
                composable(LiquidGlassTab.Search.route) { 
                    SearchScreen(viewModel, onOpenProduct = { id -> navController.navigate("product/$id") }) 
                }
                composable(LiquidGlassTab.Cart.route) { 
                    CartScreen(viewModel, onCheckout = { navController.navigate("checkout") }) 
                }
                composable(LiquidGlassTab.Account.route) { AccountScreen(viewModel, 
                    onLogin = { navController.navigate("login") },
                    onSignup = { navController.navigate("signup") },
                    onOrders = { navController.navigate("orders") },
                    onWishlist = { navController.navigate("wishlist") },
                    onNotifications = { navController.navigate("notifications") },
                    onMessages = { navController.navigate("messages") },
                    onReturns = { navController.navigate("returns") },
                    onBusinessHub = { navController.navigate("business-hub") },
                    onAdminControl = { navController.navigate("admin-control") },
                    onSettings = { navController.navigate("settings") },
                    onProfile = { navController.navigate("profile-editor") }
                    )
                    }
                    composable("verify-email/{email}") { backStackEntry ->
                    val email = backStackEntry.arguments?.getString("email") ?: ""
                    VerifyEmailScreen(viewModel, email, onBack = { navController.popBackStack() }) {
                    navController.navigate(LiquidGlassTab.Home.route) {
                        popUpTo(0)
                    }
                    }
                    }
                    composable("profile-editor") {
                    ProfileEditorScreen(viewModel) { navController.popBackStack() }
                    }
                    composable("settings") {
                    AppSettingsScreen(viewModel) { navController.popBackStack() }
                    }
                // Sub-screens
                composable("checkout") {
                    CheckoutScreen(viewModel, 
                        onBack = { navController.popBackStack() },
                        onOrderSuccess = { orderId ->
                            navController.navigate(LiquidGlassTab.Home.route) {
                                popUpTo(LiquidGlassTab.Home.route) { inclusive = true }
                            }
                        })
                }
                composable("orders") {
                    OrdersScreen(viewModel, onBack = { navController.popBackStack() })
                }
                composable("wishlist") {
                    WishlistScreen(
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                        onOpenProduct = { id -> navController.navigate("product/$id") }
                    )
                }
                composable("notifications") {
                    NotificationsScreen(
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                        onOpenNotification = { notification ->
                            val href = notification.href.orEmpty()
                            val metadata = notification.metadata ?: emptyMap()
                            fun metadataInt(key: String): Int? = (metadata[key] as? Number)?.toInt()
                            val conversationId = metadataInt("conversationId")
                            val productId = metadataInt("productId")

                            when {
                                conversationId != null -> navController.navigate("conversation/$conversationId")
                                href.contains("mesazhet", ignoreCase = true) || href.contains("messages", ignoreCase = true) -> {
                                    navController.navigate("messages")
                                }
                                productId != null -> navController.navigate("product/$productId")
                                href.contains("returns", ignoreCase = true) || href.contains("refund", ignoreCase = true) -> {
                                    navController.navigate("returns")
                                }
                                href.contains("porosite", ignoreCase = true) || href.contains("orders", ignoreCase = true) -> {
                                    navController.navigate("orders")
                                }
                                else -> navController.navigate(LiquidGlassTab.Account.route)
                            }
                        }
                    )
                }
                composable("messages") {
                    MessagesScreen(
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                        onOpenConversation = { id -> navController.navigate("conversation/$id") }
                    )
                }
                composable("conversation/{conversationId}") { backStackEntry ->
                    val conversationId = backStackEntry.arguments?.getString("conversationId")?.toIntOrNull() ?: 0
                    ConversationScreen(conversationId, viewModel, onBack = { navController.popBackStack() })
                }
                composable("returns") {
                    ReturnsScreen(viewModel, onBack = { navController.popBackStack() })
                }
                composable("business-hub") {
                    BusinessHubScreen(
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                        onAddProduct = { navController.navigate("business-product-editor") },
                        onEditProduct = { id -> navController.navigate("business-product-editor?id=$id") },
                        onAddPromotion = { navController.navigate("business-promotion-editor") },
                        onEditPromotion = { id -> navController.navigate("business-promotion-editor?id=$id") },
                        onUpdateOrder = { id -> navController.navigate("order-status-editor/$id") }
                    )
                }
                composable("business-product-editor?id={id}") { backStackEntry ->
                    val productId = backStackEntry.arguments?.getString("id")?.toIntOrNull()
                    val product = if (productId != null) viewModel.businessProducts.value.find { it.id == productId } else null
                    BusinessProductEditorScreen(viewModel, product) { navController.popBackStack() }
                }
                composable("business-promotion-editor?id={id}") { backStackEntry ->
                    val promoId = backStackEntry.arguments?.getString("id")?.toIntOrNull()
                    val promo = if (promoId != null) viewModel.businessPromotions.value.find { it.id == promoId } else null
                    BusinessPromotionEditorScreen(viewModel, promo) { navController.popBackStack() }
                }
                composable("order-status-editor/{id}") { backStackEntry ->
                    val orderItemId = backStackEntry.arguments?.getString("id")?.toIntOrNull() ?: 0
                    val orderItem = viewModel.businessOrders.value.find { it.id == orderItemId }
                        ?: viewModel.orders.value.find { it.id == orderItemId }
                    if (orderItem != null) {
                        OrderStatusEditorScreen(viewModel, orderItem) { navController.popBackStack() }
                    } else {
                        navController.popBackStack()
                    }
                }

                composable("admin-control") {
                    AdminControlScreen(viewModel, onBack = { navController.popBackStack() })
                }
                composable("login") {
                    LoginScreen(viewModel, 
                        onBack = { navController.popBackStack() },
                        onLoginSuccess = { navController.popBackStack() },
                        onGoToSignup = { navController.navigate("signup") {
                            popUpTo("login") { inclusive = true }
                        } })
                }
                composable("signup") {
                    SignupScreen(viewModel,
                        onBack = { navController.popBackStack() },
                        onSignupSuccess = { navController.popBackStack() },
                        onGoToLogin = { navController.navigate("login") {
                            popUpTo("signup") { inclusive = true }
                        } })
                }
                composable("product/{productId}") { backStackEntry ->
                    val productId = backStackEntry.arguments?.getString("productId")?.toIntOrNull() ?: 0
                    ProductDetailScreen(
                        productId,
                        viewModel,
                        onBack = { navController.popBackStack() },
                        onOpenConversation = { id -> navController.navigate("conversation/$id") }
                    )
                }
            }
        }
    }
}
