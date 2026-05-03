package store.trego.mobile.data.model

import com.google.gson.annotations.SerializedName

data class SessionUser(
    val id: Int,
    val role: String,
    val fullName: String?,
    val firstName: String?,
    val lastName: String?,
    val email: String?,
    val phoneNumber: String?,
    val birthDate: String?,
    val gender: String?,
    val profileImagePath: String?,
    val businessName: String?,
    val businessLogoPath: String?
)

data class Product(
    val id: Int,
    val articleNumber: String?,
    val title: String,
    val description: String?,
    val brand: String?,
    val gtin: String?,
    val mpn: String?,
    val material: String?,
    val weightValue: Double?,
    val weightUnit: String?,
    val metaTitle: String?,
    val metaDescription: String?,
    val imagePath: String?,
    val imageGallery: List<String>?,
    val price: Double?,
    val compareAtPrice: Double?,
    val saleEndsAt: String?,
    val averageRating: Double?,
    val reviewCount: Int?,
    val buyersCount: Int?,
    val viewsCount: Int?,
    val wishlistCount: Int?,
    val cartCount: Int?,
    val shareCount: Int?,
    val stockQuantity: Int?,
    val category: String?,
    val productType: String?,
    val size: String?,
    val color: String?,
    val businessName: String?,
    val businessProfileId: Int?,
    val supportEmail: String?,
    val websiteUrl: String?,
    val supportHours: String?,
    val returnPolicySummary: String?,
    val variantMode: String?,
    val requiresVariantSelection: Boolean?,
    val availableSizes: List<String>?,
    val availableColors: List<String>?,
    val selectedSize: String?,
    val selectedColor: String?,
    val variantKey: String?,
    val variantLabel: String?,
    val isTrending: Boolean?,
    val createdAt: String?,
    val updatedAt: String?
)

data class RecommendationSection(
    val key: String,
    val title: String,
    val subtitle: String?,
    val products: List<Product>
)

data class HomeRecommendationsResponse(
    val ok: Boolean,
    val personalized: Boolean,
    val limit: Int,
    val sections: List<RecommendationSection>
)

data class ProductsPayload(
    val ok: Boolean,
    val product: Product?
)

data class ItemsPayload<T>(
    val ok: Boolean,
    val message: String?,
    val items: List<T>?,
    val products: List<T>? = null
)

data class PaginatedProductsResponse(
    val ok: Boolean,
    val items: List<Product>,
    val limit: Int,
    val offset: Int,
    val total: Int?,
    val hasMore: Boolean
)

data class LaunchAd(
    val id: Int,
    val badge: String?,
    val title: String?,
    val subtitle: String?,
    val imagePath: String?,
    val ctaLabel: String?,
    val sortOrder: Int?,
    val isActive: Boolean?,
    val startsAt: String? = null,
    val endsAt: String? = null
)

data class LaunchAdsPayload(
    val ok: Boolean,
    val launchAds: List<LaunchAd>?
)

data class BusinessesPayload(
    val ok: Boolean,
    val businesses: List<BusinessProfile>?
)

data class BusinessProfile(
    val id: Int,
    val businessName: String?,
    val businessDescription: String?,
    val logoPath: String?,
    val verificationStatus: String?,
    val city: String?,
    val followersCount: Int?,
    val productsCount: Int?,
    val sellerRating: Double?,
    val sellerReviewCount: Int?,
    val isFollowed: Boolean? = false
)

data class BusinessProfilePayload(
    val ok: Boolean,
    val profile: BusinessProfile?,
    val business: BusinessProfile?
)

data class CartItem(
    val id: Int,
    val productId: Int?,
    val title: String,
    val imagePath: String?,
    val price: Double?,
    val compareAtPrice: Double?,
    val quantity: Int?,
    val businessName: String?,
    val businessProfileId: Int?,
    val selectedSize: String?,
    val selectedColor: String?,
    val variantKey: String?
)

data class CartPayload(
    val ok: Boolean,
    val items: List<CartItem>?,
    val guest: Boolean? = null,
    val message: String? = null
)

data class OrdersPayload(
    val ok: Boolean,
    val orders: List<OrderItem>?,
    val message: String? = null
)

data class Address(
    val id: Int,
    val userId: Int?,
    val addressLine: String?,
    val city: String?,
    val country: String?,
    val zipCode: String?,
    val phoneNumber: String?,
    val isDefault: Boolean?
)

data class Order(
    val id: Int,
    val totalAmount: Double?,
    val status: String?,
    val paymentMethod: String?,
    val createdAt: String?,
    val items: List<CartItem>?
)

data class OrderResponse(
    val ok: Boolean,
    val message: String?,
    val order: Order?
)

data class StatusResponse(
    val ok: Boolean,
    val message: String?,
    val errors: List<String>?,
    val user: SessionUser? = null
)

data class CartMutationResponse(
    val ok: Boolean,
    val message: String?,
    val items: List<CartItem>?
)

data class WishlistToggleResponse(
    val ok: Boolean,
    val action: String?,
    val items: List<Product>?
)

data class OrderItem(
    val id: Int,
    val orderId: Int?,
    val customerName: String?,
    val customerEmail: String?,
    val status: String?,
    val fulfillmentStatus: String?,
    val createdAt: String?,
    val total: Double?,
    val totalPrice: Double?,
    val totalItems: Int?,
    val itemSummary: String?,
    val businessSummary: String?,
    val items: List<CartItem>?
)

data class NotificationItem(
    val id: Int,
    val title: String?,
    val body: String?,
    val type: String?,
    val href: String?,
    val isRead: Boolean?,
    val createdAt: String?,
    val readAt: String?,
    val metadata: Map<String, Any>?,
    val data: Map<String, String>?
)

data class NotificationsPayload(
    val ok: Boolean,
    val notifications: List<NotificationItem>,
    val unreadCount: Int
)

data class ChatConversationsPayload(
    val ok: Boolean,
    val conversations: List<ChatConversation>?,
    val total: Int?,
    val unreadCount: Int?
)

data class ChatMessagesPayload(
    val ok: Boolean,
    val conversation: ChatConversation?,
    val messages: List<ChatMessage>?,
    val counterpartTyping: Boolean?
)

data class ChatOpenResponse(
    val ok: Boolean,
    val message: String?,
    val conversation: ChatConversation?
)

data class ChatSendResponse(
    val ok: Boolean,
    val message: ChatMessage?,
    val autoReplyMessage: ChatMessage?,
    val conversation: ChatConversation?
)

data class ChatConversation(
    val id: Int,
    val clientUserId: Int?,
    val businessUserId: Int?,
    val businessProfileId: Int?,
    val businessName: String?,
    val clientName: String?,
    val counterpartName: String?,
    val counterpartRole: String?,
    val counterpartImagePath: String?,
    val counterpartIsOnline: Boolean?,
    val counterpartLastSeenAt: String?,
    val profileUrl: String?,
    val lastMessagePreview: String?,
    val messagesCount: Int?,
    val unreadCount: Int?,
    val createdAt: String?,
    val updatedAt: String?,
    val lastMessageAt: String?,
    val counterpartTyping: Boolean? = false
)

data class ChatMessage(
    val id: Int,
    val conversationId: Int?,
    val senderUserId: Int?,
    val recipientUserId: Int?,
    val body: String?,
    val attachmentPath: String?,
    val attachmentContentType: String?,
    val attachmentFileName: String?,
    val createdAt: String?,
    val editedAt: String?,
    val deletedAt: String?,
    val readAt: String?,
    val senderName: String?,
    val senderRole: String?,
    val isOwn: Boolean?
)

data class ReturnRequest(
    val id: Int,
    val orderId: Int?,
    val orderItemId: Int?,
    val userId: Int?,
    val businessUserId: Int?,
    val reason: String?,
    val details: String?,
    val status: String?,
    val resolutionNotes: String?,
    val resolvedAt: String?,
    val createdAt: String?,
    val updatedAt: String?,
    val productTitle: String?,
    val productImagePath: String?,
    val businessName: String?,
    val customerName: String?
)

data class ReturnsPayload(
    val ok: Boolean,
    val requests: List<ReturnRequest>?,
    val message: String? = null
)

data class BusinessAnalytics(
    val totalProducts: Int? = null,
    val publicProducts: Int? = null,
    val totalStock: Int? = null,
    val orderItems: Int? = null,
    val unitsSold: Int? = null,
    val grossSales: Double? = null,
    val sellerEarnings: Double? = null,
    val readyPayout: Double? = null,
    val pendingPayout: Double? = null,
    val reviewCount: Int? = null,
    val averageRating: Double? = null,
    val totalReturns: Int? = null,
    val openReturns: Int? = null,
    val activePromotions: Int? = null,
    val viewsCount: Int? = null,
    val wishlistCount: Int? = null,
    val cartCount: Int? = null,
    val shareCount: Int? = null
)

data class BusinessAnalyticsPayload(
    val ok: Boolean,
    val analytics: BusinessAnalytics?
)

data class Promotion(
    val id: Int,
    val code: String?,
    val discountPercent: Int?,
    val discountAmount: Double?,
    val isActive: Boolean?
)

data class PromotionsPayload(
    val ok: Boolean,
    val promotions: List<Promotion>?
)

data class AdminUser(
    val id: Int,
    val role: String?,
    val fullName: String?,
    val email: String?,
    val createdAt: String?
)

data class AdminUsersPayload(
    val ok: Boolean,
    val users: List<AdminUser>?
)

data class AdminBusinessesPayload(
    val ok: Boolean,
    val businesses: List<BusinessProfile>?
)

data class AdminReportsPayload(
    val ok: Boolean,
    val reports: List<Map<String, Any>>?
)
