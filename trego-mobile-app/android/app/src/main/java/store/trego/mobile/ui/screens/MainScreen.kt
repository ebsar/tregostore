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
    
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    // Map cart count and notifications to badges
    val badges = remember(cart, orders) {
        val map = mutableMapOf<LiquidGlassTab, String>()
        if (cart.isNotEmpty()) {
            val totalQty = cart.sumOf { it.quantity ?: 1 }
            map[LiquidGlassTab.Cart] = if (totalQty > 99) "99+" else totalQty.toString()
        }
        // Example: Notification count on Account tab
        map
    }

    if (isLoading) {
        LoadingScreen()
    } else {
        Scaffold(
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
                composable(LiquidGlassTab.Businesses.route) { BusinessesScreen(viewModel) }
                composable(LiquidGlassTab.Search.route) { 
                    SearchScreen(viewModel, onOpenProduct = { id -> navController.navigate("product/$id") }) 
                }
                composable(LiquidGlassTab.Cart.route) { 
                    CartScreen(viewModel, onCheckout = { navController.navigate("checkout") }) 
                }
                composable(LiquidGlassTab.Account.route) { AccountScreen(viewModel, 
                    onLogin = { navController.navigate("login") },
                    onSignup = { navController.navigate("signup") },
                    onOrders = { navController.navigate("orders") }) 
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
                    ProductDetailScreen(productId, viewModel, onBack = { navController.popBackStack() })
                }
            }
        }
    }
}
