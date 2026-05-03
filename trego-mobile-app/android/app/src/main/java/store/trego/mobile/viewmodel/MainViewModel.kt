package store.trego.mobile.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import store.trego.mobile.data.api.TregoApiService
import store.trego.mobile.data.model.*

class MainViewModel(private val apiService: TregoApiService) : ViewModel() {
    private val _user = MutableStateFlow<SessionUser?>(null)
    val user: StateFlow<SessionUser?> = _user.asStateFlow()

    private val _homeProducts = MutableStateFlow<List<Product>>(emptyList())
    val homeProducts: StateFlow<List<Product>> = _homeProducts.asStateFlow()

    private val _recommendationSections = MutableStateFlow<List<RecommendationSection>>(emptyList())
    val recommendationSections: StateFlow<List<RecommendationSection>> = _recommendationSections.asStateFlow()

    private val _publicBusinesses = MutableStateFlow<List<BusinessProfile>>(emptyList())
    val publicBusinesses: StateFlow<List<BusinessProfile>> = _publicBusinesses.asStateFlow()

    private val _launchAds = MutableStateFlow<List<LaunchAd>>(emptyList())
    val launchAds: StateFlow<List<LaunchAd>> = _launchAds.asStateFlow()

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

    private val _conversations = MutableStateFlow<List<ChatConversation>>(emptyList())
    val conversations: StateFlow<List<ChatConversation>> = _conversations.asStateFlow()

    private val _conversationMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val conversationMessages: StateFlow<List<ChatMessage>> = _conversationMessages.asStateFlow()

    private val _activeConversation = MutableStateFlow<ChatConversation?>(null)
    val activeConversation: StateFlow<ChatConversation?> = _activeConversation.asStateFlow()

    private val _returns = MutableStateFlow<List<ReturnRequest>>(emptyList())
    val returns: StateFlow<List<ReturnRequest>> = _returns.asStateFlow()

    private val _businessProducts = MutableStateFlow<List<Product>>(emptyList())
    val businessProducts: StateFlow<List<Product>> = _businessProducts.asStateFlow()

    private val _businessOrders = MutableStateFlow<List<OrderItem>>(emptyList())
    val businessOrders: StateFlow<List<OrderItem>> = _businessOrders.asStateFlow()

    private val _businessAnalytics = MutableStateFlow<BusinessAnalytics?>(null)
    val businessAnalytics: StateFlow<BusinessAnalytics?> = _businessAnalytics.asStateFlow()

    private val _businessPromotions = MutableStateFlow<List<Promotion>>(emptyList())
    val businessPromotions: StateFlow<List<Promotion>> = _businessPromotions.asStateFlow()

    private val _adminProducts = MutableStateFlow<List<Product>>(emptyList())
    val adminProducts: StateFlow<List<Product>> = _adminProducts.asStateFlow()

    private val _adminUsers = MutableStateFlow<List<AdminUser>>(emptyList())
    val adminUsers: StateFlow<List<AdminUser>> = _adminUsers.asStateFlow()

    private val _adminBusinesses = MutableStateFlow<List<BusinessProfile>>(emptyList())
    val adminBusinesses: StateFlow<List<BusinessProfile>> = _adminBusinesses.asStateFlow()

    private val _adminOrders = MutableStateFlow<List<OrderItem>>(emptyList())
    val adminOrders: StateFlow<List<OrderItem>> = _adminOrders.asStateFlow()

    private val _uiMessage = MutableStateFlow<String?>(null)
    val uiMessage: StateFlow<String?> = _uiMessage.asStateFlow()

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
            loadLaunchAds()
            if (_user.value != null) {
                launch { loadCart() }
                launch { loadWishlist() }
                launch { loadOrders() }
                launch { fetchNotifications() }
                launch { loadConversations() }
                launch { loadReturns() }
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

    fun clearUiMessage() {
        _uiMessage.value = null
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
                _conversations.value = emptyList()
                _conversationMessages.value = emptyList()
                _activeConversation.value = null
                _returns.value = emptyList()
                _businessProducts.value = emptyList()
                _businessOrders.value = emptyList()
                _businessAnalytics.value = null
                _businessPromotions.value = emptyList()
                _adminProducts.value = emptyList()
                _adminUsers.value = emptyList()
                _adminBusinesses.value = emptyList()
                _adminOrders.value = emptyList()
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

    fun loadLaunchAds() {
        viewModelScope.launch {
            try {
                val response = apiService.getLaunchAds()
                if (response.isSuccessful) {
                    _launchAds.value = response.body()?.launchAds ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadPublicBusinesses() {
        viewModelScope.launch {
            try {
                val response = apiService.getPublicBusinesses()
                if (response.isSuccessful) {
                    _publicBusinesses.value = response.body()?.businesses ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadCart() {
        viewModelScope.launch {
            try {
                val response = apiService.getCart()
                if (response.isSuccessful) {
                    _cart.value = response.body()?.items ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadWishlist() {
        viewModelScope.launch {
            try {
                val response = apiService.getWishlist()
                if (response.isSuccessful) {
                    _wishlist.value = response.body()?.items ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadOrders() {
        viewModelScope.launch {
            try {
                val response = apiService.getOrders()
                if (response.isSuccessful) {
                    _orders.value = response.body()?.orders ?: emptyList()
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
                _notifications.value = _notifications.value.map { it.copy(isRead = true) }
            } catch (e: Exception) {}
        }
    }

    fun loadConversations() {
        viewModelScope.launch {
            try {
                val response = apiService.getChatConversations()
                if (response.isSuccessful) {
                    val payload = response.body()
                    _conversations.value = payload?.conversations ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun openConversation(conversation: ChatConversation) {
        _activeConversation.value = conversation
        loadConversationMessages(conversation.id)
    }

    fun loadConversationMessages(conversationId: Int) {
        viewModelScope.launch {
            try {
                val response = apiService.getChatMessages(conversationId)
                if (response.isSuccessful) {
                    val payload = response.body()
                    _activeConversation.value = payload?.conversation ?: _activeConversation.value
                    _conversationMessages.value = payload?.messages ?: emptyList()
                    loadConversations()
                }
            } catch (e: Exception) {
                _uiMessage.value = "Biseda nuk u hap."
            }
        }
    }

    fun startSupportConversation(onOpened: (Int) -> Unit = {}) {
        viewModelScope.launch {
            try {
                val response = apiService.openChat(mapOf("target" to "support"))
                val payload = response.body()
                if (response.isSuccessful && payload?.ok == true && payload.conversation != null) {
                    _activeConversation.value = payload.conversation
                    loadConversations()
                    loadConversationMessages(payload.conversation.id)
                    onOpened(payload.conversation.id)
                } else {
                    _uiMessage.value = payload?.message ?: "Customer support nuk u hap."
                }
            } catch (e: Exception) {
                _uiMessage.value = "Customer support nuk u hap."
            }
        }
    }

    fun startBusinessConversation(businessId: Int, onOpened: (Int) -> Unit = {}) {
        viewModelScope.launch {
            try {
                val response = apiService.openChat(mapOf("businessId" to businessId))
                val payload = response.body()
                if (response.isSuccessful && payload?.ok == true && payload.conversation != null) {
                    _activeConversation.value = payload.conversation
                    loadConversations()
                    loadConversationMessages(payload.conversation.id)
                    onOpened(payload.conversation.id)
                } else {
                    _uiMessage.value = payload?.message ?: "Biseda nuk u hap."
                }
            } catch (e: Exception) {
                _uiMessage.value = "Biseda nuk u hap."
            }
        }
    }

    fun startProductConversation(product: Product, onOpened: (Int) -> Unit = {}) {
        val businessId = product.businessProfileId
        if (businessId == null || businessId <= 0) {
            _uiMessage.value = "Ky produkt nuk ka biznes te lidhur."
            return
        }
        viewModelScope.launch {
            try {
                val openResponse = apiService.openChat(mapOf("businessId" to businessId))
                val openPayload = openResponse.body()
                val conversation = openPayload?.conversation
                if (!openResponse.isSuccessful || openPayload?.ok != true || conversation == null) {
                    _uiMessage.value = openPayload?.message ?: "Biseda nuk u hap."
                    return@launch
                }

                val priceText = product.price?.let { " €$it" } ?: ""
                val messageBody = "Pershendetje, po pyes per produktin `${product.title}`$priceText. Link: /produkti?id=${product.id}"
                apiService.sendChatMessage(
                    mapOf("conversationId" to conversation.id, "body" to messageBody)
                )
                _activeConversation.value = conversation
                loadConversations()
                loadConversationMessages(conversation.id)
                onOpened(conversation.id)
            } catch (e: Exception) {
                _uiMessage.value = "Mesazhi per produktin nuk u dergua."
            }
        }
    }

    fun sendMessage(conversationId: Int, body: String) {
        val trimmed = body.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            try {
                val response = apiService.sendChatMessage(
                    mapOf("conversationId" to conversationId, "body" to trimmed)
                )
                val payload = response.body()
                if (response.isSuccessful && payload?.ok == true) {
                    val nextMessages = _conversationMessages.value.toMutableList()
                    payload.message?.let { nextMessages.add(it) }
                    payload.autoReplyMessage?.let { nextMessages.add(it) }
                    _conversationMessages.value = nextMessages
                    payload.conversation?.let { _activeConversation.value = it }
                    loadConversations()
                } else {
                    _uiMessage.value = "Mesazhi nuk u dergua."
                }
            } catch (e: Exception) {
                _uiMessage.value = "Mesazhi nuk u dergua."
            }
        }
    }

    fun loadReturns() {
        viewModelScope.launch {
            try {
                val response = apiService.getReturns()
                if (response.isSuccessful) {
                    _returns.value = response.body()?.requests ?: emptyList()
                }
            } catch (e: Exception) {}
        }
    }

    fun updateReturnStatus(returnRequestId: Int, status: String) {
        viewModelScope.launch {
            try {
                val response = apiService.updateReturnStatus(
                    mapOf("returnRequestId" to returnRequestId, "status" to status)
                )
                val body = response.body()
                if (response.isSuccessful && body?.ok == true) {
                    loadReturns()
                    _uiMessage.value = body.message ?: "Kerkesa u perditesua."
                } else {
                    _uiMessage.value = body?.message ?: "Kerkesa nuk u perditesua."
                }
            } catch (e: Exception) {
                _uiMessage.value = "Kerkesa nuk u perditesua."
            }
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

    fun fetchProductDetail(productId: Int, onLoaded: (Product?) -> Unit) {
        viewModelScope.launch {
            val cached = _homeProducts.value.firstOrNull { it.id == productId }
                ?: _searchResults.value.firstOrNull { it.id == productId }
                ?: _wishlist.value.firstOrNull { it.id == productId }
            if (cached != null) {
                onLoaded(cached)
                return@launch
            }
            try {
                val response = apiService.getProductDetail(productId)
                onLoaded(if (response.isSuccessful) response.body()?.product else null)
            } catch (e: Exception) {
                onLoaded(null)
            }
        }
    }

    fun loadBusinessStudio() {
        viewModelScope.launch {
            try {
                val products = apiService.getBusinessProducts()
                if (products.isSuccessful) _businessProducts.value = products.body()?.products ?: products.body()?.items ?: emptyList()
            } catch (e: Exception) {}
        }
        viewModelScope.launch {
            try {
                val orders = apiService.getBusinessOrders()
                if (orders.isSuccessful) _businessOrders.value = orders.body()?.orders ?: emptyList()
            } catch (e: Exception) {}
        }
        viewModelScope.launch {
            try {
                val analytics = apiService.getBusinessAnalytics()
                if (analytics.isSuccessful) _businessAnalytics.value = analytics.body()?.analytics
            } catch (e: Exception) {}
        }
        viewModelScope.launch {
            try {
                val promotions = apiService.getBusinessPromotions()
                if (promotions.isSuccessful) _businessPromotions.value = promotions.body()?.promotions ?: emptyList()
            } catch (e: Exception) {}
        }
    }

    fun loadAdminControl() {
        viewModelScope.launch {
            try {
                val products = apiService.getAdminProducts()
                if (products.isSuccessful) _adminProducts.value = products.body()?.products ?: products.body()?.items ?: emptyList()
            } catch (e: Exception) {}
        }
        viewModelScope.launch {
            try {
                val users = apiService.getAdminUsers()
                if (users.isSuccessful) _adminUsers.value = users.body()?.users ?: emptyList()
            } catch (e: Exception) {}
        }
        viewModelScope.launch {
            try {
                val businesses = apiService.getAdminBusinesses()
                if (businesses.isSuccessful) _adminBusinesses.value = businesses.body()?.businesses ?: emptyList()
            } catch (e: Exception) {}
        }
        viewModelScope.launch {
            try {
                val orders = apiService.getAdminOrders()
                if (orders.isSuccessful) _adminOrders.value = orders.body()?.orders ?: emptyList()
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
