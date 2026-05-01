package store.trego.mobile.data.api

import retrofit2.Response
import retrofit2.http.*
import store.trego.mobile.data.model.*

interface TregoApiService {
    @GET("api/me")
    suspend fun getCurrentUser(): Response<SessionUser>

    @GET("api/recommendations/home")
    suspend fun getHomeRecommendations(
        @Query("limit") limit: Int = 10
    ): Response<HomeRecommendationsResponse>

    @GET("api/products")
    suspend fun getProducts(
        @Query("limit") limit: Int = 24,
        @Query("offset") offset: Int = 0
    ): Response<PaginatedProductsResponse>

    @GET("api/products/search")
    suspend fun searchProducts(
        @Query("q") query: String,
        @Query("limit") limit: Int = 24,
        @Query("offset") offset: Int = 0
    ): Response<PaginatedProductsResponse>

    @GET("api/product")
    suspend fun getProductDetail(
        @Query("id") productId: Int
    ): Response<Product>

    @GET("api/recommendations/product")
    suspend fun getProductRecommendations(
        @Query("id") productId: Int,
        @Query("limit") limit: Int = 6
    ): Response<HomeRecommendationsResponse>

    @GET("api/launch-ads")
    suspend fun getLaunchAds(): Response<List<LaunchAd>>

    @GET("api/businesses/public")
    suspend fun getPublicBusinesses(): Response<List<BusinessProfile>>

    @GET("api/wishlist")
    suspend fun getWishlist(): Response<List<Product>>

    @POST("api/wishlist/toggle")
    suspend fun toggleWishlist(
        @Body body: Map<String, Int>
    ): Response<WishlistToggleResponse>

    @GET("api/cart")
    suspend fun getCart(): Response<List<CartItem>>

    @POST("api/cart/add")
    suspend fun addToCart(
        @Body body: Map<String, Any>
    ): Response<StatusResponse>

    @POST("api/cart/quantity")
    suspend fun updateCartQuantity(
        @Body body: Map<String, Int>
    ): Response<CartMutationResponse>

    @POST("api/cart/remove")
    suspend fun removeFromCart(
        @Body body: Map<String, Int>
    ): Response<StatusResponse>

    @GET("api/orders")
    suspend fun getOrders(): Response<List<OrderItem>>

    @GET("api/notifications")
    suspend fun getNotifications(): Response<Map<String, Any>>
}
