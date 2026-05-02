package store.trego.mobile.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import store.trego.mobile.data.api.TregoApiService
import store.trego.mobile.data.model.*
import java.util.Date

class MainViewModel(private val apiService: TregoApiService) : ViewModel() {
    private val _user = MutableStateFlow<SessionUser?>(null)
    val user: StateFlow<SessionUser?> = _user.asStateFlow()

    private val _homeProducts = MutableStateFlow<List<Product>>(emptyList())
    val homeProducts: StateFlow<List<Product>> = _homeProducts.asStateFlow()

    private val _recommendationSections = MutableStateFlow<List<RecommendationSection>>(emptyList())
    val recommendationSections: StateFlow<List<RecommendationSection>> = _recommendationSections.asStateFlow()

    private val _publicBusinesses = MutableStateFlow<List<BusinessProfile>>(emptyList())
    val publicBusinesses: StateFlow<List<BusinessProfile>> = _publicBusinesses.asStateFlow()

    private val _cart = MutableStateFlow<List<CartItem>>(emptyList())
    val cart: StateFlow<List<CartItem>> = _cart.asStateFlow()

    private val _wishlist = MutableStateFlow<List<Product>>(emptyList())
    val wishlist: StateFlow<List<Product>> = _wishlist.asStateFlow()

    private val _searchResults = MutableStateFlow<List<Product>>(emptyList())
    val searchResults: StateFlow<List<Product>> = _searchResults.asStateFlow()

    private val _orders = MutableStateFlow<List<OrderItem>>(emptyList())
    val orders: StateFlow<List<OrderItem>> = _orders.asStateFlow()

    private val _notifications = MutableStateFlow<List<NotificationItem>>(emptyList())
    val notifications: StateFlow<List<NotificationItem>> = _notifications.asStateFlow()

    private val _notificationUnreadCount = MutableStateFlow(0)
    val notificationUnreadCount: StateFlow<Int> = _notificationUnreadCount.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _searchLoading = MutableStateFlow(false)
    val searchLoading: StateFlow<Boolean> = _searchLoading.asStateFlow()

    private var lastSessionRefresh: Long = 0
    private val sessionRefreshThrottle: Long = 12000 // 12 seconds like iOS

    init {
        bootstrap()
    }

    fun bootstrap() {
        viewModelScope.launch {
            refreshSession(force = true)
            loadHomeData()
            loadPublicBusinesses()
            if (_user.value != null) {
                launch { loadCart() }
                launch { loadWishlist() }
                launch { loadOrders() }
                launch { fetchNotifications() }
            }
            _isLoading.value = false
        }
    }

    fun refreshSession(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastSessionRefresh < sessionRefreshThrottle) return
        
        lastSessionRefresh = now
        viewModelScope.launch {
            try {
                val response = apiService.getCurrentUser()
                if (response.isSuccessful) {
                    _user.value = response.body()
                } else if (response.code() == 401 || response.code() == 403) {
                    _user.value = null
                }
            } catch (e: Exception) {
                _user.value = null
            }
        }
    }

    fun warmSessionRefreshInBackground() {
        refreshSession(force = false)
    }

    suspend fun login(identifier: String, password: String): StatusResponse {
        return try {
            val response = apiService.login(mapOf("identifier" to identifier, "password" to password))
            if (response.isSuccessful) {
                val status = response.body() ?: StatusResponse(false, "Unknown error", null)
                if (status.ok) {
                    _user.value = status.user
                    bootstrap()
                }
                status
            } else {
                StatusResponse(false, "Gabim gjate kyçjes: ${response.code()}", null)
            }
        } catch (e: Exception) {
            StatusResponse(false, "Lidhja deshtoi: ${e.message}", null)
        }
    }

    suspend fun register(payload: Map<String, String>): StatusResponse {
        return try {
            val response = apiService.register(payload)
            if (response.isSuccessful) {
                val status = response.body() ?: StatusResponse(false, "Unknown error", null)
                if (status.ok) {
                    _user.value = status.user
                    bootstrap()
                }
                status
            } else {
                StatusResponse(false, "Gabim gjate regjistrimit: ${response.code()}", null)
            }
        } catch (e: Exception) {
            StatusResponse(false, "Lidhja deshtoi: ${e.message}", null)
        }
    }

    fun logout() {
        viewModelScope.launch {
            try {
                apiService.logout()
                _user.value = null
                _cart.value = emptyList()
                _wishlist.value = emptyList()
                _orders.value = emptyList()
                _notifications.value = emptyList()
                _notificationUnreadCount.value = 0
            } catch (e: Exception) {
                _user.value = null
            }
        }
    }

    fun loadHomeData() {
        viewModelScope.launch {
            try {
                val productsResponse = apiService.getProducts(limit = 24, offset = 0)
                if (productsResponse.isSuccessful) {
                    _homeProducts.value = productsResponse.body()?.items ?: emptyList()
                }

                val recsResponse = apiService.getHomeRecommendations()
                if (recsResponse.isSuccessful) {
                    _recommendationSections.value = recsResponse.body()?.sections ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadPublicBusinesses() {
        viewModelScope.launch {
            try {
                val response = apiService.getPublicBusinesses()
                if (response.isSuccessful) {
                    _publicBusinesses.value = response.body() ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadCart() {
        viewModelScope.launch {
            try {
                val response = apiService.getCart()
                if (response.isSuccessful) {
                    _cart.value = response.body() ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadWishlist() {
        viewModelScope.launch {
            try {
                val response = apiService.getWishlist()
                if (response.isSuccessful) {
                    _wishlist.value = response.body() ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadOrders() {
        viewModelScope.launch {
            try {
                val response = apiService.getOrders()
                if (response.isSuccessful) {
                    _orders.value = response.body() ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun fetchNotifications() {
        viewModelScope.launch {
            try {
                val response = apiService.getNotifications()
                if (response.isSuccessful) {
                    val payload = response.body()
                    _notifications.value = payload?.notifications ?: emptyList()
                    _notificationUnreadCount.value = payload?.unreadCount ?: 0
                }
            } catch (e: Exception) {}
        }
    }

    fun markNotificationsRead() {
        viewModelScope.launch {
            try {
                apiService.markNotificationsRead()
                _notificationUnreadCount.value = 0
            } catch (e: Exception) {}
        }
    }

    fun performSearch(query: String) {
        viewModelScope.launch {
            _searchLoading.value = true
            try {
                val response = apiService.searchProducts(query)
                if (response.isSuccessful) {
                    _searchResults.value = response.body()?.items ?: emptyList()
                }
            } catch (e: Exception) {
            } finally {
                _searchLoading.value = false
            }
        }
    }

    fun toggleWishlist(product: Product) {
        viewModelScope.launch {
            try {
                val response = apiService.toggleWishlist(mapOf("productId" to product.id))
                if (response.isSuccessful) {
                    loadWishlist()
                }
            } catch (e: Exception) {}
        }
    }

    fun addToCart(product: Product, quantity: Int = 1) {
        viewModelScope.launch {
            try {
                val response = apiService.addToCart(mapOf("productId" to product.id, "quantity" to quantity))
                if (response.isSuccessful) {
                    loadCart()
                }
            } catch (e: Exception) {}
        }
    }

    fun removeFromCart(cartLineId: Int) {
        viewModelScope.launch {
            try {
                val response = apiService.removeFromCart(mapOf("cartLineId" to cartLineId))
                if (response.isSuccessful) {
                    loadCart()
                }
            } catch (e: Exception) {}
        }
    }

    suspend fun createOrder(
        paymentMethod: String,
        address: Map<String, String>,
        cartLineIds: List<Int>
    ): OrderResponse {
        return try {
            val payload = mapOf(
                "cartItemIds" to cartLineIds,
                "paymentMethod" to paymentMethod,
                "addressLine" to address["addressLine"],
                "city" to address["city"],
                "country" to address["country"],
                "zipCode" to address["zipCode"],
                "phoneNumber" to address["phoneNumber"]
            )
            val response = apiService.createOrder(payload)
            if (response.isSuccessful) {
                val orderResponse = response.body() ?: OrderResponse(false, "Unknown error", null)
                if (orderResponse.ok) {
                    loadCart()
                    loadOrders()
                }
                orderResponse
            } else {
                OrderResponse(false, "Gabim gjate porosise: ${response.code()}", null)
            }
        } catch (e: Exception) {
            OrderResponse(false, "Lidhja deshtoi: ${e.message}", null)
        }
    }

    suspend fun subscribeToPush(token: String, deviceId: String): StatusResponse {
        return try {
            val response = apiService.subscribeToPush(mapOf(
                "provider" to "fcm",
                "platform" to "android",
                "token" to token,
                "deviceId" to deviceId
            ))
            response.body() ?: StatusResponse(false, "Error", null)
        } catch (e: Exception) {
            StatusResponse(false, e.message, null)
        }
    }
}
