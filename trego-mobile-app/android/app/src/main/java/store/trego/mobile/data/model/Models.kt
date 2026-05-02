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
    val isActive: Boolean?
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
    val status: String?,
    val createdAt: String?,
    val total: Double?,
    val items: List<CartItem>?
)

data class NotificationItem(
    val id: Int,
    val title: String?,
    val body: String?,
    val type: String?,
    val isRead: Boolean?,
    val createdAt: String?,
    val data: Map<String, String>?
)

data class NotificationsPayload(
    val ok: Boolean,
    val notifications: List<NotificationItem>,
    val unreadCount: Int
)

data class BusinessAnalytics(
    val totalOrders: Int,
    val totalRevenue: Double,
    val profileViews: Int,
    val conversionRate: Double
)

data class Promotion(
    val id: Int,
    val code: String?,
    val discountPercent: Int?,
    val discountAmount: Double?,
    val isActive: Boolean?
)
