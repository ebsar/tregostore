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

    private val _cart = MutableStateFlow<List<CartItem>>(emptyList())
    val cart: StateFlow<List<CartItem>> = _cart.asStateFlow()

    private val _wishlist = MutableStateFlow<List<Product>>(emptyList())
    val wishlist: StateFlow<List<Product>> = _wishlist.asStateFlow()

    private val _searchResults = MutableStateFlow<List<Product>>(emptyList())
    val searchResults: StateFlow<List<Product>> = _searchResults.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _searchLoading = MutableStateFlow(false)
    val searchLoading: StateFlow<Boolean> = _searchLoading.asStateFlow()

    init {
        refreshSession()
        loadHomeData()
        loadPublicBusinesses()
        loadCart()
        loadWishlist()
    }

    fun refreshSession() {
        viewModelScope.launch {
            try {
                val response = apiService.getCurrentUser()
                if (response.isSuccessful) {
                    _user.value = response.body()
                }
            } catch (e: Exception) {}
        }
    }

    fun loadHomeData() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val productsResponse = apiService.getProducts(limit = 24, offset = 0)
                if (productsResponse.isSuccessful) {
                    _homeProducts.value = productsResponse.body()?.items ?: emptyList()
                }

                val recsResponse = apiService.getHomeRecommendations()
                if (recsResponse.isSuccessful) {
                    _recommendationSections.value = recsResponse.body()?.sections ?: emptyList()
                }
            } catch (e: Exception) {
            } finally {
                _isLoading.value = false
            }
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
}
