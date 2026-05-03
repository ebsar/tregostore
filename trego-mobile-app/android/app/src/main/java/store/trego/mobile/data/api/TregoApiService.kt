package store.trego.mobile.data.api

import retrofit2.Response
import retrofit2.http.*
import store.trego.mobile.data.model.*

interface TregoApiService {
    @GET("api/me")
    suspend fun getCurrentUser(): Response<SessionUser>

    @POST("api/login")
    suspend fun login(@Body body: Map<String, String>): Response<StatusResponse>

    @POST("api/register")
    suspend fun register(@Body body: Map<String, String>): Response<StatusResponse>

    @POST("api/logout")
    suspend fun logout(): Response<StatusResponse>

    @POST("api/forgot-password")
    suspend fun forgotPassword(@Body body: Map<String, String>): Response<StatusResponse>

    @POST("api/password-reset/confirm")
    suspend fun confirmPasswordReset(@Body body: Map<String, String>): Response<StatusResponse>

    // Marketplace
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
    suspend fun getProductDetail(@Query("id") productId: Int): Response<ProductsPayload>

    @GET("api/recommendations/home")
    suspend fun getHomeRecommendations(@Query("limit") limit: Int = 10): Response<HomeRecommendationsResponse>

    @GET("api/recommendations/product")
    suspend fun getProductRecommendations(
        @Query("id") productId: Int,
        @Query("limit") limit: Int = 6
    ): Response<HomeRecommendationsResponse>

    // Cart & Checkout
    @GET("api/cart")
    suspend fun getCart(): Response<CartPayload>

    @POST("api/cart/add")
    suspend fun addToCart(@Body body: Map<String, Any>): Response<StatusResponse>

    @POST("api/cart/quantity")
    suspend fun updateCartQuantity(@Body body: Map<String, Int>): Response<CartMutationResponse>

    @POST("api/cart/remove")
    suspend fun removeFromCart(@Body body: Map<String, Int>): Response<StatusResponse>

    @POST("api/checkout/reserve")
    suspend fun reserveCheckout(@Body body: Map<String, List<Int>>): Response<StatusResponse>

    @POST("api/orders/create")
    suspend fun createOrder(@Body body: Map<String, Any?>): Response<OrderResponse>

    // Wishlist
    @GET("api/wishlist")
    suspend fun getWishlist(): Response<ItemsPayload<Product>>

    @POST("api/wishlist/toggle")
    suspend fun toggleWishlist(@Body body: Map<String, Int>): Response<WishlistToggleResponse>

    // Account & Profile
    @GET("api/orders")
    suspend fun getOrders(): Response<OrdersPayload>

    @GET("api/notifications")
    suspend fun getNotifications(): Response<NotificationsPayload>

    @GET("api/notifications/count")
    suspend fun getNotificationsCount(): Response<Map<String, Int>>

    @POST("api/notifications/read")
    suspend fun markNotificationsRead(): Response<StatusResponse>

    @POST("api/push/subscribe")
    suspend fun subscribeToPush(@Body body: Map<String, String>): Response<StatusResponse>

    // Messages
    @GET("api/chat/conversations")
    suspend fun getChatConversations(): Response<ChatConversationsPayload>

    @GET("api/chat/messages")
    suspend fun getChatMessages(@Query("conversationId") conversationId: Int): Response<ChatMessagesPayload>

    @POST("api/chat/open")
    suspend fun openChat(@Body body: Map<String, Any>): Response<ChatOpenResponse>

    @POST("api/chat/messages")
    suspend fun sendChatMessage(@Body body: Map<String, Any>): Response<ChatSendResponse>

    // Returns
    @GET("api/returns")
    suspend fun getReturns(): Response<ReturnsPayload>

    @POST("api/returns/status")
    suspend fun updateReturnStatus(@Body body: Map<String, Any>): Response<StatusResponse>

    // Business
    @GET("api/businesses/public")
    suspend fun getPublicBusinesses(): Response<BusinessesPayload>

    @GET("api/business-profile")
    suspend fun getBusinessProfile(): Response<BusinessProfilePayload>

    @GET("api/launch-ads")
    suspend fun getLaunchAds(): Response<LaunchAdsPayload>

    @GET("api/business/products")
    suspend fun getBusinessProducts(): Response<ItemsPayload<Product>>

    @GET("api/business/orders")
    suspend fun getBusinessOrders(): Response<OrdersPayload>

    @GET("api/business/analytics")
    suspend fun getBusinessAnalytics(): Response<BusinessAnalyticsPayload>

    @GET("api/business/promotions")
    suspend fun getBusinessPromotions(): Response<PromotionsPayload>

    // Admin
    @GET("api/admin/products")
    suspend fun getAdminProducts(): Response<ItemsPayload<Product>>

    @GET("api/admin/users")
    suspend fun getAdminUsers(): Response<AdminUsersPayload>

    @GET("api/admin/businesses")
    suspend fun getAdminBusinesses(): Response<AdminBusinessesPayload>

    @GET("api/admin/orders")
    suspend fun getAdminOrders(): Response<OrdersPayload>
}
