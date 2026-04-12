import Foundation
import SwiftUI

struct TregoUploadedImagesPayload: Equatable {
    let paths: [String]
}

struct TregoSessionUser: Codable, Identifiable, Equatable {
    let id: Int
    let role: String
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phoneNumber: String?
    let birthDate: String?
    let gender: String?
    let profileImagePath: String?
    let businessName: String?
    let businessLogoPath: String?
}

struct TregoAddress: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let addressLine: String?
    let city: String?
    let country: String?
    let zipCode: String?
    let phoneNumber: String?
    let isDefault: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct TregoNotificationItem: Codable, Identifiable, Equatable {
    let id: Int
    let type: String?
    let title: String?
    let body: String?
    let href: String?
    let isRead: Bool?
    let createdAt: String?
    let readAt: String?
}

struct TregoReturnRequest: Codable, Identifiable, Equatable {
    let id: Int
    let orderId: Int?
    let orderItemId: Int?
    let userId: Int?
    let businessUserId: Int?
    let reason: String?
    let details: String?
    let status: String?
    let resolutionNotes: String?
    let resolvedAt: String?
    let createdAt: String?
    let updatedAt: String?
    let productTitle: String?
    let productImagePath: String?
    let businessName: String?
    let customerName: String?
}

struct TregoProductVariant: Codable, Equatable {
    let key: String?
    let label: String?
    let size: String?
    let color: String?
    let quantity: Int?
    let price: Double?
    let imagePath: String?
}

struct TregoProduct: Codable, Identifiable, Equatable {
    let id: Int
    let articleNumber: String?
    let title: String
    let description: String?
    let brand: String?
    let gtin: String?
    let mpn: String?
    let material: String?
    let weightValue: Double?
    let weightUnit: String?
    let metaTitle: String?
    let metaDescription: String?
    let imagePath: String?
    let imageGallery: [String]?
    let price: Double?
    let compareAtPrice: Double?
    let saleEndsAt: String?
    let averageRating: Double?
    let reviewCount: Int?
    let buyersCount: Int?
    let viewsCount: Int?
    let wishlistCount: Int?
    let cartCount: Int?
    let shareCount: Int?
    let stockQuantity: Int?
    let category: String?
    let productType: String?
    let size: String?
    let color: String?
    let businessName: String?
    let supportEmail: String?
    let websiteUrl: String?
    let supportHours: String?
    let returnPolicySummary: String?
    let shippingSettings: TregoBusinessShippingSettings?
    let variantInventory: [TregoProductVariant]?
    let variantMode: String?
    let requiresVariantSelection: Bool?
    let availableSizes: [String]?
    let availableColors: [String]?
    let selectedSize: String?
    let selectedColor: String?
    let variantKey: String?
    let variantLabel: String?
    let packageAmountValue: Double?
    let packageAmountUnit: String?
    let showStockPublic: Bool?
    let isPublic: Bool?
    let createdByUserId: Int?
    let businessProfileId: Int?
    let isTrending: Bool?
    let businessVerificationStatus: String?
    let createdAt: String?
    let updatedAt: String?
}

struct TregoViewedHistoryEntry: Codable, Identifiable, Equatable {
    let product: TregoProduct
    let viewedAt: String

    var id: Int { product.id }
}

struct TregoPaginatedPayload<Item: Equatable>: Equatable {
    let items: [Item]
    let limit: Int
    let offset: Int
    let total: Int?
    let hasMore: Bool
}

struct TregoRecommendationSection: Codable, Identifiable, Equatable {
    let key: String
    let title: String
    let subtitle: String?
    let products: [TregoProduct]

    var id: String { key }
}

struct TregoProductReview: Codable, Identifiable, Equatable {
    let id: Int
    let rating: Int?
    let title: String?
    let body: String?
    let createdAt: String?
    let authorName: String?
    let photoPath: String?
}

struct TregoCartItem: Codable, Identifiable, Equatable {
    let id: Int
    let productId: Int?
    let title: String
    let imagePath: String?
    let price: Double?
    let compareAtPrice: Double?
    let quantity: Int?
    let businessName: String?
    let businessProfileId: Int?
    let selectedSize: String?
    let selectedColor: String?
    let variantKey: String?
    let variantLabel: String?
}

struct TregoOrderItem: Codable, Identifiable, Equatable {
    let id: Int
    let orderId: Int?
    let productId: Int?
    let businessUserId: Int?
    let businessName: String?
    let title: String?
    let description: String?
    let imagePath: String?
    let category: String?
    let productType: String?
    let size: String?
    let color: String?
    let variantKey: String?
    let variantLabel: String?
    let packageAmountValue: Double?
    let packageAmountUnit: String?
    let unitPrice: Double?
    let quantity: Int?
    let status: String?
    let fulfillmentStatus: String?
    let trackingCode: String?
    let trackingUrl: String?
    let totalAmount: Double?
    let totalPrice: Double?
    let subtotalAmount: Double?
    let shippingAmount: Double?
    let discountAmount: Double?
    let createdAt: String?
    let confirmationDueAt: String?
    let confirmedAt: String?
    let packedAt: String?
    let shippedAt: String?
    let deliveredAt: String?
    let cancelledAt: String?
    let customerName: String?
    let customerEmail: String?
    let paymentMethod: String?
    let deliveryMethod: String?
    let deliveryLabel: String?
    let estimatedDeliveryText: String?
    let addressLine: String?
    let city: String?
    let country: String?
    let zipCode: String?
    let phoneNumber: String?
    let returnRequestStatus: String?
    let totalItems: Int?
    let items: [TregoCartItem]?
}

struct TregoBusinessCityRate: Codable, Equatable, Identifiable {
    let city: String
    let surcharge: Double?

    var id: String { city.lowercased() }
}

struct TregoBusinessShippingSettings: Codable, Equatable {
    let standardEnabled: Bool?
    let standardFee: Double?
    let standardEta: String?
    let expressEnabled: Bool?
    let expressFee: Double?
    let expressEta: String?
    let pickupEnabled: Bool?
    let pickupEta: String?
    let pickupAddress: String?
    let pickupHours: String?
    let pickupMapUrl: String?
    let cityRates: [TregoBusinessCityRate]?
    let halfOffThreshold: Double?
    let freeShippingThreshold: Double?
}

struct TregoBusinessProfile: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let businessName: String?
    let businessDescription: String?
    let businessNumber: String?
    let logoPath: String?
    let supportEmail: String?
    let websiteUrl: String?
    let supportHours: String?
    let returnPolicySummary: String?
    let verificationStatus: String?
    let verificationNotes: String?
    let profileEditAccessStatus: String?
    let profileEditNotes: String?
    let phoneNumber: String?
    let city: String?
    let addressLine: String?
    let shippingSettings: TregoBusinessShippingSettings?
    let ownerEmail: String?
    let productsCount: Int?
    let ordersCount: Int?
    let sellerRating: Double?
    let sellerReviewCount: Int?
}

struct TregoBusinessAnalytics: Codable, Equatable {
    let totalProducts: Int?
    let publicProducts: Int?
    let totalStock: Int?
    let orderItems: Int?
    let unitsSold: Int?
    let grossSales: Double?
    let sellerEarnings: Double?
    let readyPayout: Double?
    let pendingPayout: Double?
    let reviewCount: Int?
    let averageRating: Double?
    let totalReturns: Int?
    let openReturns: Int?
    let activePromotions: Int?
    let viewsCount: Int?
    let wishlistCount: Int?
    let cartCount: Int?
    let shareCount: Int?
    let buyersCount: Int?
    let ordersCount: Int?
}

struct TregoPublicBusinessProfile: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let businessName: String?
    let businessDescription: String?
    let logoPath: String?
    let supportEmail: String?
    let websiteUrl: String?
    let supportHours: String?
    let returnPolicySummary: String?
    let verificationStatus: String?
    let city: String?
    let phoneNumber: String?
    let addressLine: String?
    let shippingSettings: TregoBusinessShippingSettings?
    let followersCount: Int?
    let productsCount: Int?
    let sellerRating: Double?
    let sellerReviewCount: Int?
    let isFollowed: Bool?
    let ownerEmail: String?
}

struct TregoDeliveryMethodOption: Codable, Equatable, Identifiable {
    let value: String
    let label: String?
    let description: String?
    let shippingAmount: Double?
    let estimatedDeliveryText: String?
    let badge: String?

    var id: String { value }
}

struct TregoCheckoutPricing: Codable, Equatable {
    let promoCode: String?
    let subtotal: Double?
    let discountAmount: Double?
    let shippingAmount: Double?
    let total: Double?
    let deliveryMethod: String?
    let deliveryLabel: String?
    let estimatedDeliveryText: String?
    let cityZoneLabel: String?
    let shippingRuleMessage: String?
    let shippingBaseAmount: Double?
    let shippingCitySurcharge: Double?
    let shippingSubtotalDiscount: Double?
    let availableDeliveryMethods: [TregoDeliveryMethodOption]?
    let deliveryNotice: String?
    let message: String?
}

struct TregoCheckoutDraft: Equatable {
    var addressLine: String
    var city: String
    var country: String
    var zipCode: String
    var phoneNumber: String
}

struct TregoBusinessSelection: Identifiable, Equatable {
    let id: Int
}

struct TregoStripeCheckoutSession: Equatable, Identifiable {
    let sessionId: String
    let checkoutURL: String
    let reservedUntil: String?
    let pricing: TregoCheckoutPricing?
    let message: String?

    var id: String { sessionId }
}

struct TregoPromotion: Codable, Identifiable, Equatable {
    let id: Int?
    let code: String?
    let title: String?
    let description: String?
    let discountType: String?
    let discountValue: Double?
    let minimumSubtotal: Double?
    let perUserLimit: Int?
    let usageLimit: Int?
    let isActive: Bool?
    let pageSection: String?
    let category: String?
    let businessUserId: Int?
    let startsAt: String?
    let endsAt: String?
    let createdAt: String?

    var stableID: String {
        if let id {
            return "promotion-\(id)"
        }
        return "promotion-\(code ?? title ?? UUID().uuidString)"
    }
}

struct TregoLaunchAd: Codable, Identifiable, Equatable {
    let id: Int
    let badge: String?
    let title: String?
    let subtitle: String?
    let imagePath: String?
    let ctaLabel: String?
    let sortOrder: Int?
    let isActive: Bool?
    let startsAt: String?
    let endsAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct TregoConversation: Codable, Identifiable, Equatable {
    let id: Int
    let businessName: String?
    let clientName: String?
    let counterpartName: String?
    let counterpartRole: String?
    let counterpartImagePath: String?
    let counterpartIsOnline: Bool?
    let counterpartLastSeenAt: String?
    let lastMessagePreview: String?
    let messagesCount: Int?
    let unreadCount: Int?
    let createdAt: String?
    let updatedAt: String?
    let lastMessageAt: String?
    let counterpartTyping: Bool?
}

struct TregoChatMessage: Codable, Identifiable, Equatable {
    let id: Int
    let conversationId: Int
    let senderUserId: Int
    let recipientUserId: Int?
    let body: String?
    let attachmentPath: String?
    let attachmentContentType: String?
    let attachmentFileName: String?
    let createdAt: String?
    let editedAt: String?
    let deletedAt: String?
    let readAt: String?
    let senderName: String?
    let senderRole: String?
    let isOwn: Bool?
}

struct TregoConversationDetail: Codable {
    let conversation: TregoConversation?
    let messages: [TregoChatMessage]
    let counterpartTyping: Bool
}

struct TregoAdminUser: Codable, Identifiable, Equatable {
    let id: Int
    let fullName: String?
    let email: String?
    let phoneNumber: String?
    let birthDate: String?
    let gender: String?
    let role: String?
    let isEmailVerified: Bool?
    let emailVerifiedAt: String?
    let city: String?
    let createdAt: String?
    let updatedAt: String?
    let ordersCount: Int?
    let profileImagePath: String?
}

struct TregoAdminBusiness: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let businessNumber: String?
    let businessName: String?
    let businessDescription: String?
    let ownerName: String?
    let ownerEmail: String?
    let logoPath: String?
    let verificationStatus: String?
    let verificationNotes: String?
    let profileEditAccessStatus: String?
    let profileEditNotes: String?
    let productsCount: Int?
    let ordersCount: Int?
    let sellerRating: Double?
    let city: String?
    let phoneNumber: String?
    let addressLine: String?
    let shippingSettings: TregoBusinessShippingSettings?
}

struct TregoAdminReport: Codable, Identifiable, Equatable {
    let id: Int
    let targetType: String?
    let targetId: Int?
    let targetLabel: String?
    let reason: String?
    let details: String?
    let status: String?
    let adminNotes: String?
    let createdAt: String?
    let updatedAt: String?
    let reporterName: String?
    let reportedUserName: String?
    let businessName: String?
}

struct TregoImageSearchUpload: Equatable {
    let data: Data
    let filename: String
    let mimeType: String
}

struct TregoAttachmentUpload: Equatable {
    let data: Data
    let filename: String
    let mimeType: String
}

enum TregoAuthRoute: String, Identifiable {
    case login
    case signup
    case forgotPassword
    case verifyEmail

    var id: String { rawValue }
}

struct TregoAppSettings: Equatable {
    var theme: String
    var language: String
    var currency: String
    var notificationMode: String
    var privacyMode: String
    var personalizationConsentStatus: String

    static let storageKey = "trego-ios-native-settings"
    static let defaultValue = TregoAppSettings(
        theme: "system",
        language: "sq",
        currency: "EUR",
        notificationMode: "all",
        privacyMode: "standard",
        personalizationConsentStatus: "pending"
    )

    static func load() -> TregoAppSettings {
        let defaults = UserDefaults.standard
        guard let payload = defaults.dictionary(forKey: storageKey) else {
            return defaultValue
        }

        return TregoAppSettings(
            theme: String(payload["theme"] as? String ?? defaultValue.theme),
            language: String(payload["language"] as? String ?? defaultValue.language),
            currency: String(payload["currency"] as? String ?? defaultValue.currency),
            notificationMode: String(payload["notificationMode"] as? String ?? defaultValue.notificationMode),
            privacyMode: String(payload["privacyMode"] as? String ?? defaultValue.privacyMode),
            personalizationConsentStatus: String(
                payload["personalizationConsentStatus"] as? String ?? defaultValue.personalizationConsentStatus
            )
        )
    }

    func persist() {
        UserDefaults.standard.set(
            [
                "theme": theme,
                "language": language,
                "currency": currency,
                "notificationMode": notificationMode,
                "privacyMode": privacyMode,
                "personalizationConsentStatus": personalizationConsentStatus,
            ],
            forKey: Self.storageKey
        )
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

struct TregoAPIConfiguration {
    let baseURL: URL

    private static let productionBaseURL = URL(string: "https://www.tregos.store")!
    private static let debugOverrideDefaultsKey = "trego.debug.apiBaseURL"

    var isLocalDevelopmentServer: Bool {
        let host = baseURL.host?.lowercased() ?? ""
        if host == "127.0.0.1" || host == "localhost" {
            return true
        }
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            return true
        }
        if host.hasPrefix("172.16.") || host.hasPrefix("172.17.") || host.hasPrefix("172.18.") || host.hasPrefix("172.19.") {
            return true
        }
        if host.hasPrefix("172.2") || host.hasPrefix("172.30.") || host.hasPrefix("172.31.") {
            return true
        }
        return false
    }

    static func load() -> TregoAPIConfiguration {
        #if DEBUG
        if
            let overrideURL = normalizedURL(from: UserDefaults.standard.string(forKey: debugOverrideDefaultsKey)),
            !isLocalDevelopmentURL(overrideURL)
        {
            return TregoAPIConfiguration(baseURL: overrideURL)
        }

        if let debugURL = normalizedURL(
            from: Bundle.main.object(forInfoDictionaryKey: "TregoDebugAPIBaseURL") as? String
        ) {
            return TregoAPIConfiguration(baseURL: debugURL)
        }

        #if targetEnvironment(simulator)
        if let simulatorDebugURL = normalizedURL(
            from: Bundle.main.object(forInfoDictionaryKey: "TregoDebugSimulatorAPIBaseURL") as? String
        ) {
            return TregoAPIConfiguration(baseURL: simulatorDebugURL)
        }
        #endif
        #endif

        if let configuredURL = normalizedURL(
            from: Bundle.main.object(forInfoDictionaryKey: "TregoAPIBaseURL") as? String
        ) {
            return TregoAPIConfiguration(baseURL: configuredURL)
        }

        return TregoAPIConfiguration(baseURL: productionBaseURL)
    }

    private static func normalizedURL(from rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private static func isLocalDevelopmentURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        if host == "127.0.0.1" || host == "localhost" {
            return true
        }
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            return true
        }
        if host.hasPrefix("172.16.") || host.hasPrefix("172.17.") || host.hasPrefix("172.18.") || host.hasPrefix("172.19.") {
            return true
        }
        if host.hasPrefix("172.2") || host.hasPrefix("172.30.") || host.hasPrefix("172.31.") {
            return true
        }
        return false
    }
}

struct TregoStatusResponse: Codable {
    let ok: Bool?
    let message: String?
    let errors: [String]?
    let redirectTo: String?
    let user: TregoSessionUser?

    init(ok: Bool?, message: String?, errors: [String]?, redirectTo: String? = nil, user: TregoSessionUser? = nil) {
        self.ok = ok
        self.message = message
        self.errors = errors
        self.redirectTo = redirectTo
        self.user = user
    }
}

struct TregoWishlistToggleResponse: Codable {
    let ok: Bool?
    let message: String?
    let errors: [String]?
    let action: String?
    let items: [TregoProduct]?
}

struct TregoCartMutationResponse: Codable {
    let ok: Bool?
    let message: String?
    let errors: [String]?
    let items: [TregoCartItem]?
}

struct TregoAdminBusinessCreatePayload: Equatable {
    let fullName: String
    let email: String
    let password: String
    let businessName: String
    let businessDescription: String
    let businessNumber: String
    let phoneNumber: String
    let city: String
    let addressLine: String
}

struct TregoNotificationsPayload: Equatable {
    let notifications: [TregoNotificationItem]
    let unreadCount: Int
}

struct TregoCheckoutReservePayload: Equatable {
    let reservedUntil: String
    let message: String?
}

private struct TregoProductReviewsResponse: Codable {
    let reviews: [TregoProductReview]?
}

private struct TregoListResponse<T: Codable>: Codable {
    let ok: Bool?
    let message: String?
    let items: [T]?
    let products: [T]?
    let orders: [T]?
    let users: [T]?
    let businesses: [T]?
    let reports: [T]?
    let conversations: [T]?
    let promotions: [T]?
    let launchAds: [T]?
}

struct TregoListFetchResult<T> {
    let items: [T]
    let didSucceed: Bool
    let message: String?
}

struct TregoPageFetchResult<T: Equatable> {
    let page: TregoPaginatedPayload<T>
    let didSucceed: Bool
    let message: String?
}

final class TregoAPIClient {
    private struct TregoMultipartUpload {
        let data: Data
        let filename: String
        let mimeType: String
    }

    private let configuration: TregoAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let visitorDefaultsKey = "trego-ios-native-visitor-token"

    init(configuration: TregoAPIConfiguration = .load()) {
        self.configuration = configuration
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    static func imageURL(from path: String?) -> URL? {
        guard let raw = path?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }
        return TregoAPIConfiguration.load().baseURL.appendingPathComponent(raw.hasPrefix("/") ? String(raw.dropFirst()) : raw)
    }

    var currentBaseURLString: String {
        configuration.baseURL.absoluteString
    }

    var usesLocalDevelopmentServer: Bool {
        configuration.isLocalDevelopmentServer
    }

    fileprivate func fetchCurrentUserState() async -> TregoCurrentUserFetchState {
        if let immediate = await fetchCurrentUserStateOnce() {
            return immediate
        }

        try? await Task.sleep(nanoseconds: 150_000_000)

        if let retry = await fetchCurrentUserStateOnce() {
            return retry
        }

        return .failed("Lidhja me serverin deshtoi.")
    }

    func login(identifier: String, password: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/login",
            method: "POST",
            body: ["identifier": identifier, "password": password]
        )
    }

    func register(fullName: String, email: String, phoneNumber: String, password: String, birthDate: String, gender: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/register",
            method: "POST",
            body: [
                "fullName": fullName,
                "email": email,
                "phoneNumber": phoneNumber,
                "password": password,
                "birthDate": birthDate,
                "gender": gender,
            ]
        )
    }

    func requestPasswordReset(email: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/forgot-password",
            method: "POST",
            body: ["email": email]
        )
    }

    func verifyEmail(email: String, code: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/email/verify",
            method: "POST",
            body: [
                "email": email,
                "code": code,
            ]
        )
    }

    func resendEmailVerification(email: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/email/resend",
            method: "POST",
            body: ["email": email]
        )
    }

    func confirmPasswordReset(email: String, code: String, newPassword: String, confirmPassword: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/password-reset/confirm",
            method: "POST",
            body: [
                "email": email,
                "code": code,
                "newPassword": newPassword,
                "confirmPassword": confirmPassword,
            ]
        )
    }

    func uploadProfilePhoto(upload: TregoImageSearchUpload) async -> String? {
        guard let json = await sendMultipartRequest(path: "/api/profile/photo", upload: upload) else {
            return nil
        }
        guard json.ok else {
            return nil
        }
        return json.object["path"] as? String
    }

    func updateProfile(
        firstName: String,
        lastName: String,
        birthDate: String,
        gender: String,
        profileImagePath: String
    ) async -> (TregoStatusResponse, TregoSessionUser?) {
        guard let json = await sendJSONRequest(
            path: "/api/profile",
            method: "POST",
            body: [
                "firstName": firstName,
                "lastName": lastName,
                "birthDate": birthDate,
                "gender": gender,
                "profileImagePath": profileImagePath,
            ]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let user: TregoSessionUser? = decode(json.object["user"])
        return (response, user)
    }

    func changePassword(currentPassword: String, newPassword: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/change-password",
            method: "POST",
            body: [
                "currentPassword": currentPassword,
                "newPassword": newPassword,
            ]
        )
    }

    func deleteOwnAccount(password: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/account/delete",
            method: "POST",
            body: ["password": password]
        )
    }

    func fetchDefaultAddress() async -> TregoAddress? {
        guard let json = await sendJSONRequest(path: "/api/address") else { return nil }
        guard json.ok else { return nil }
        return decode(json.object["address"])
    }

    func saveDefaultAddress(
        addressLine: String,
        city: String,
        country: String,
        zipCode: String,
        phoneNumber: String
    ) async -> (TregoStatusResponse, TregoAddress?) {
        guard let json = await sendJSONRequest(
            path: "/api/address",
            method: "POST",
            body: [
                "addressLine": addressLine,
                "city": city,
                "country": country,
                "zipCode": zipCode,
                "phoneNumber": phoneNumber,
            ]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let address: TregoAddress? = decode(json.object["address"])
        return (response, address)
    }

    func fetchNotifications() async -> TregoNotificationsPayload {
        guard let json = await sendJSONRequest(path: "/api/notifications"), json.ok else {
            return TregoNotificationsPayload(notifications: [], unreadCount: 0)
        }
        let notifications: [TregoNotificationItem] = decodeArray(json.object["notifications"]) ?? []
        let unreadCount = Int(json.object["unreadCount"] as? Int ?? 0)
        return TregoNotificationsPayload(notifications: notifications, unreadCount: unreadCount)
    }

    func markNotificationsRead() async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/notifications/read", method: "POST")
    }

    func fetchReturnRequests() async -> [TregoReturnRequest] {
        guard let json = await sendJSONRequest(path: "/api/returns"), json.ok else {
            return []
        }
        return decodeArray(json.object["requests"]) ?? []
    }

    func updateReturnRequestStatus(
        returnRequestId: Int,
        status: String,
        resolutionNotes: String = ""
    ) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/returns/status",
            method: "POST",
            body: [
                "returnRequestId": returnRequestId,
                "status": status,
                "resolutionNotes": resolutionNotes,
            ]
        )
    }

    func reserveCheckout(cartLineIds: [Int]) async -> (TregoStatusResponse, TregoCheckoutReservePayload?) {
        guard let json = await sendJSONRequest(
            path: "/api/checkout/reserve",
            method: "POST",
            body: ["cartItemIds": cartLineIds]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let payload = TregoCheckoutReservePayload(
            reservedUntil: String(json.object["reservedUntil"] as? String ?? ""),
            message: json.object["message"] as? String
        )
        return (response, payload)
    }

    func fetchCheckoutPricing(
        cartLineIds: [Int],
        draft: TregoCheckoutDraft,
        promoCode: String,
        deliveryMethod: String
    ) async -> (TregoStatusResponse, TregoCheckoutPricing?) {
        guard let json = await sendJSONRequest(
            path: "/api/promotions/apply",
            method: "POST",
            body: [
                "cartItemIds": cartLineIds,
                "promoCode": promoCode,
                "deliveryMethod": deliveryMethod,
                "addressLine": draft.addressLine,
                "city": draft.city,
                "country": draft.country,
                "zipCode": draft.zipCode,
                "phoneNumber": draft.phoneNumber,
            ]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let pricing: TregoCheckoutPricing? = decode(json.object["pricing"])
        return (response, pricing)
    }

    func createOrder(
        cartLineIds: [Int],
        draft: TregoCheckoutDraft,
        paymentMethod: String,
        promoCode: String,
        deliveryMethod: String
    ) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/orders/create",
            method: "POST",
            body: [
                "cartItemIds": cartLineIds,
                "paymentMethod": paymentMethod,
                "promoCode": promoCode,
                "deliveryMethod": deliveryMethod,
                "addressLine": draft.addressLine,
                "city": draft.city,
                "country": draft.country,
                "zipCode": draft.zipCode,
                "phoneNumber": draft.phoneNumber,
            ]
        )
    }

    func createStripeCheckoutSession(
        cartLineIds: [Int],
        draft: TregoCheckoutDraft,
        promoCode: String,
        deliveryMethod: String
    ) async -> (TregoStatusResponse, TregoStripeCheckoutSession?) {
        guard let json = await sendJSONRequest(
            path: "/api/payments/stripe/checkout",
            method: "POST",
            body: [
                "cartItemIds": cartLineIds,
                "promoCode": promoCode,
                "deliveryMethod": deliveryMethod,
                "addressLine": draft.addressLine,
                "city": draft.city,
                "country": draft.country,
                "zipCode": draft.zipCode,
                "phoneNumber": draft.phoneNumber,
            ]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let pricing: TregoCheckoutPricing? = decode(json.object["pricing"])
        let checkout = TregoStripeCheckoutSession(
            sessionId: String(json.object["sessionId"] as? String ?? ""),
            checkoutURL: String(json.object["checkoutUrl"] as? String ?? ""),
            reservedUntil: json.object["reservedUntil"] as? String,
            pricing: pricing,
            message: json.object["message"] as? String
        )
        return (response, checkout.sessionId.isEmpty || checkout.checkoutURL.isEmpty ? nil : checkout)
    }

    func confirmStripeCheckoutSession(sessionId: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/payments/stripe/confirm",
            method: "POST",
            body: ["stripeSessionId": sessionId]
        )
    }

    func logout() async {
        _ = await sendStatusRequest(path: "/api/logout", method: "POST")
        clearCookies()
    }

    func fetchMarketplaceProducts(limit: Int = 24, offset: Int = 0) async -> [TregoProduct] {
        let page = await fetchMarketplaceProductsPage(limit: limit, offset: offset)
        return page.items
    }

    func fetchMarketplaceProductsPageResult(limit: Int = 24, offset: Int = 0) async -> TregoPageFetchResult<TregoProduct> {
        let path = "/api/products?limit=\(limit)&offset=\(offset)"
        return await fetchPageResult(path: path, keyPreference: [.products, .items])
    }

    func fetchMarketplaceProductsPage(limit: Int = 24, offset: Int = 0) async -> TregoPaginatedPayload<TregoProduct> {
        let result = await fetchMarketplaceProductsPageResult(limit: limit, offset: offset)
        return result.page
    }

    func fetchHomeRecommendations(limit: Int = 8) async -> [TregoRecommendationSection] {
        guard let json = await sendJSONRequest(path: "/api/recommendations/home?limit=\(limit)") else { return [] }
        guard json.ok else { return [] }
        return (decodeArray(json.object["sections"]) ?? []).filter { !$0.products.isEmpty }
    }

    func searchProducts(query: String) async -> [TregoProduct] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let page = await searchProductsPage(query: encoded, encoded: true)
        return page.items
    }

    func searchProductsPage(query: String, limit: Int = 18, offset: Int = 0, encoded: Bool = false) async -> TregoPaginatedPayload<TregoProduct> {
        let rawQuery = encoded ? query : (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        return await fetchPage(
            path: "/api/products/search?q=\(rawQuery)&limit=\(limit)&offset=\(offset)",
            keyPreference: [.products, .items]
        )
    }

    func searchProducts(imageUpload: TregoImageSearchUpload) async -> [TregoProduct] {
        guard let json = await sendMultipartRequest(path: "/api/products/visual-search", upload: imageUpload) else {
            return []
        }
        guard json.ok else { return [] }
        return decodeArray(json.object["products"]) ?? []
    }

    func fetchProductDetail(id: Int) async -> TregoProduct? {
        let path = "/api/product?id=\(id)"
        guard let json = await sendJSONRequest(path: path) else { return nil }
        guard json.ok else { return nil }
        return decode(json.object["product"])
    }

    func fetchProductReviews(id: Int) async -> [TregoProductReview] {
        let path = "/api/product/reviews?id=\(id)"
        guard let json = await sendJSONRequest(path: path) else { return [] }
        guard json.ok else { return [] }
        return decodeArray(json.object["reviews"]) ?? []
    }

    func fetchProductRecommendations(id: Int, limit: Int = 6) async -> [TregoRecommendationSection] {
        let path = "/api/recommendations/product?id=\(id)&limit=\(limit)"
        guard let json = await sendJSONRequest(path: path) else { return [] }
        guard json.ok else { return [] }
        return (decodeArray(json.object["sections"]) ?? []).filter { !$0.products.isEmpty }
    }

    func trackProductShare(productId: Int) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/products/share",
            method: "POST",
            body: ["productId": productId]
        )
    }

    func createProductReview(productId: Int, rating: Int, title: String, body: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/product/reviews",
            method: "POST",
            body: [
                "productId": productId,
                "rating": rating,
                "title": title,
                "body": body,
            ]
        )
    }

    func createReport(
        targetType: String,
        targetId: Int,
        targetLabel: String,
        reason: String,
        details: String,
        reportedUserId: Int? = nil,
        businessUserId: Int? = nil
    ) async -> TregoStatusResponse {
        var body: [String: Any] = [
            "targetType": targetType,
            "targetId": targetId,
            "targetLabel": targetLabel,
            "reason": reason,
            "details": details,
        ]
        if let reportedUserId {
            body["reportedUserId"] = reportedUserId
        }
        if let businessUserId {
            body["businessUserId"] = businessUserId
        }
        return await sendStatusRequest(path: "/api/reports", method: "POST", body: body)
    }

    func fetchWishlist() async -> [TregoProduct] {
        await fetchList(path: "/api/wishlist", keyPreference: [.items, .products])
    }

    func toggleWishlist(productId: Int) async -> TregoWishlistToggleResponse {
        guard let json = await sendJSONRequest(path: "/api/wishlist/toggle", method: "POST", body: ["productId": productId]) else {
            return TregoWishlistToggleResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil, action: nil, items: nil)
        }
        if let decoded: TregoWishlistToggleResponse = decode(json.object) {
            return decoded
        }
        return TregoWishlistToggleResponse(ok: json.ok, message: json.message, errors: nil, action: nil, items: nil)
    }

    func fetchCart() async -> [TregoCartItem] {
        await fetchList(path: "/api/cart", keyPreference: [.items])
    }

    func addToCart(productId: Int, quantity: Int = 1, variantKey: String = "", selectedSize: String = "", selectedColor: String = "") async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/cart/add",
            method: "POST",
            body: [
                "productId": productId,
                "quantity": quantity,
                "variantKey": variantKey,
                "selectedSize": selectedSize,
                "selectedColor": selectedColor,
            ]
        )
    }

    func updateCartQuantity(cartLineId: Int, quantity: Int) async -> (TregoStatusResponse, [TregoCartItem]?) {
        guard let json = await sendJSONRequest(
            path: "/api/cart/quantity",
            method: "POST",
            body: [
                "cartLineId": cartLineId,
                "quantity": quantity,
            ]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let items: [TregoCartItem]? = decodeArray(json.object["items"])
        return (response, items)
    }

    func removeFromCart(cartLineId: Int) async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/cart/remove", method: "POST", body: ["cartLineId": cartLineId])
    }

    func fetchOrders() async -> [TregoOrderItem] {
        await fetchList(path: "/api/orders", keyPreference: [.orders])
    }

    func createReturnRequest(orderItemId: Int, reason: String, details: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/returns/request",
            method: "POST",
            body: [
                "orderItemId": orderItemId,
                "reason": reason,
                "details": details,
            ]
        )
    }

    func fetchBusinessProfile() async -> TregoBusinessProfile? {
        guard let json = await sendJSONRequest(path: "/api/business-profile") else { return nil }
        guard json.ok else { return nil }
        return decode(json.object["profile"]) ?? decode(json.object["business"])
    }

    func updateBusinessProfile(payload: [String: Any]) async -> (TregoStatusResponse, TregoBusinessProfile?) {
        guard let json = await sendJSONRequest(
            path: "/api/business-profile",
            method: "POST",
            body: payload
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let profile: TregoBusinessProfile? = decode(json.object["profile"]) ?? decode(json.object["business"])
        return (response, profile)
    }

    func saveBusinessShippingSettings(payload: [String: Any]) async -> (TregoStatusResponse, TregoBusinessProfile?) {
        guard let json = await sendJSONRequest(
            path: "/api/business-profile/shipping",
            method: "POST",
            body: payload
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let profile: TregoBusinessProfile? = decode(json.object["profile"]) ?? decode(json.object["business"])
        return (response, profile)
    }

    func fetchPublicBusinessProfile(id: Int) async -> TregoPublicBusinessProfile? {
        guard let json = await sendJSONRequest(path: "/api/business/public?id=\(id)") else { return nil }
        guard json.ok else { return nil }
        return decode(json.object["business"])
    }

    func fetchPublicBusinesses() async -> [TregoPublicBusinessProfile] {
        await fetchList(path: "/api/businesses/public", keyPreference: [.businesses, .items])
    }

    func fetchPublicBusinessesResult() async -> TregoListFetchResult<TregoPublicBusinessProfile> {
        await fetchListResult(path: "/api/businesses/public", keyPreference: [.businesses, .items])
    }

    func fetchPublicBusinessProducts(id: Int, limit: Int = 24, offset: Int = 0) async -> [TregoProduct] {
        let page = await fetchPublicBusinessProductsPage(id: id, limit: limit, offset: offset)
        return page.items
    }

    func fetchPublicBusinessProductsPageResult(id: Int, limit: Int = 24, offset: Int = 0) async -> TregoPageFetchResult<TregoProduct> {
        await fetchPageResult(
            path: "/api/business/public-products?id=\(id)&limit=\(limit)&offset=\(offset)",
            keyPreference: [.products, .items]
        )
    }

    func fetchPublicBusinessProductsPage(id: Int, limit: Int = 24, offset: Int = 0) async -> TregoPaginatedPayload<TregoProduct> {
        let result = await fetchPublicBusinessProductsPageResult(id: id, limit: limit, offset: offset)
        return result.page
    }

    func toggleBusinessFollow(businessId: Int) async -> (TregoStatusResponse, TregoPublicBusinessProfile?) {
        guard let json = await sendJSONRequest(
            path: "/api/business/follow-toggle",
            method: "POST",
            body: ["businessId": businessId]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let business: TregoPublicBusinessProfile? = decode(json.object["business"])
        return (response, business)
    }

    func openBusinessConversation(businessId: Int) async -> (TregoStatusResponse, TregoConversation?) {
        guard let json = await sendJSONRequest(
            path: "/api/chat/open",
            method: "POST",
            body: ["businessId": businessId]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let conversation: TregoConversation? = decode(json.object["conversation"])
        return (response, conversation)
    }

    func openSupportConversation() async -> (TregoStatusResponse, TregoConversation?) {
        guard let json = await sendJSONRequest(
            path: "/api/chat/open",
            method: "POST",
            body: ["target": "support"]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let conversation: TregoConversation? = decode(json.object["conversation"])
        return (response, conversation)
    }

    func uploadProductImages(_ uploads: [TregoImageSearchUpload]) async -> (TregoStatusResponse, TregoUploadedImagesPayload?) {
        guard let json = await sendMultipartRequest(path: "/api/uploads", uploads: uploads, fieldName: "images") else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let paths = (json.object["paths"] as? [String]) ?? []
        return (response, paths.isEmpty ? nil : TregoUploadedImagesPayload(paths: paths))
    }

    func createProduct(payload: [String: Any]) async -> (TregoStatusResponse, TregoProduct?) {
        guard let json = await sendJSONRequest(path: "/api/products", method: "POST", body: payload) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let product: TregoProduct? = decode(json.object["product"])
        return (response, product)
    }

    func updateProduct(productId: Int, payload: [String: Any]) async -> (TregoStatusResponse, TregoProduct?) {
        var body = payload
        body["productId"] = productId
        guard let json = await sendJSONRequest(path: "/api/products/update", method: "POST", body: body) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let product: TregoProduct? = decode(json.object["product"])
        return (response, product)
    }

    func deleteProduct(productId: Int) async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/products/delete", method: "POST", body: ["productId": productId])
    }

    func updateProductPublicVisibility(productId: Int, isPublic: Bool) async -> (TregoStatusResponse, TregoProduct?) {
        guard let json = await sendJSONRequest(
            path: "/api/products/public-visibility",
            method: "POST",
            body: ["productId": productId, "isPublic": isPublic]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let product: TregoProduct? = decode(json.object["product"])
        return (response, product)
    }

    func updateAdminBusinessEditAccess(businessId: Int, status: String, notes: String = "") async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/admin/businesses/edit-access",
            method: "POST",
            body: ["businessId": businessId, "editAccessStatus": status, "editAccessNotes": notes]
        )
    }

    func updateAdminUserRole(userId: Int, role: String) async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/admin/users/role", method: "POST", body: ["userId": userId, "role": role])
    }

    func deleteAdminUser(userId: Int) async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/admin/users/delete", method: "POST", body: ["userId": userId])
    }

    func setAdminUserPassword(userId: Int, newPassword: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/admin/users/set-password",
            method: "POST",
            body: ["userId": userId, "newPassword": newPassword]
        )
    }

    func fetchBusinessProducts() async -> [TregoProduct] {
        await fetchList(path: "/api/business/products", keyPreference: [.products])
    }

    func fetchBusinessAnalytics() async -> TregoBusinessAnalytics? {
        guard let json = await sendJSONRequest(path: "/api/business/analytics") else { return nil }
        guard json.ok else { return nil }
        return decode(json.object["analytics"]) ?? decode(json.object)
    }

    func fetchBusinessOrders() async -> [TregoOrderItem] {
        await fetchList(path: "/api/business/orders", keyPreference: [.orders])
    }

    func fetchBusinessPromotions() async -> [TregoPromotion] {
        await fetchList(path: "/api/business/promotions", keyPreference: [.promotions, .items])
    }

    func fetchLaunchAds() async -> [TregoLaunchAd] {
        await fetchList(path: "/api/launch-ads", keyPreference: [.launchAds, .items])
    }

    func saveBusinessPromotion(payload: [String: Any]) async -> ([TregoPromotion], TregoStatusResponse) {
        guard let json = await sendJSONRequest(path: "/api/business/promotions", method: "POST", body: payload) else {
            return ([], TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil))
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let promotions: [TregoPromotion] = decodeArray(json.object["promotions"]) ?? []
        return (promotions, response)
    }

    func deleteBusinessPromotion(id: Int? = nil, code: String? = nil) async -> ([TregoPromotion], TregoStatusResponse) {
        var payload: [String: Any] = ["action": "delete", "deletePromotion": true]
        if let id, id > 0 {
            payload["promotionId"] = id
        }
        if let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["code"] = code
        }
        return await saveBusinessPromotion(payload: payload)
    }

    func fetchAdminLaunchAds() async -> [TregoLaunchAd] {
        await fetchList(path: "/api/admin/launch-ads", keyPreference: [.launchAds, .items])
    }

    func saveAdminLaunchAd(payload: [String: Any]) async -> ([TregoLaunchAd], TregoStatusResponse) {
        guard let json = await sendJSONRequest(path: "/api/admin/launch-ads", method: "POST", body: payload) else {
            return ([], TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil))
        }
        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let launchAds: [TregoLaunchAd] = decodeArray(json.object["launchAds"]) ?? []
        return (launchAds, response)
    }

    func deleteAdminLaunchAd(id: Int) async -> ([TregoLaunchAd], TregoStatusResponse) {
        await saveAdminLaunchAd(payload: ["action": "delete", "deleteLaunchAd": true, "launchAdId": id])
    }

    func updateOrderStatus(
        orderItemId: Int,
        status: String,
        trackingCode: String = "",
        trackingURL: String = ""
    ) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/orders/status",
            method: "POST",
            body: [
                "orderItemId": orderItemId,
                "fulfillmentStatus": status,
                "trackingCode": trackingCode,
                "trackingUrl": trackingURL,
            ]
        )
    }

    func requestBusinessVerification() async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/business-profile/verification-request", method: "POST")
    }

    func requestBusinessEditAccess() async -> TregoStatusResponse {
        await sendStatusRequest(path: "/api/business-profile/edit-request", method: "POST")
    }

    func fetchAdminUsers() async -> [TregoAdminUser] {
        await fetchList(path: "/api/admin/users", keyPreference: [.users])
    }

    func fetchAdminBusinesses() async -> [TregoAdminBusiness] {
        await fetchList(path: "/api/admin/businesses", keyPreference: [.businesses])
    }

    func fetchAdminReports() async -> [TregoAdminReport] {
        await fetchList(path: "/api/admin/reports", keyPreference: [.reports])
    }

    func fetchAdminOrders() async -> [TregoOrderItem] {
        await fetchList(path: "/api/admin/orders", keyPreference: [.orders])
    }

    func createAdminBusiness(payload: TregoAdminBusinessCreatePayload) async -> (TregoStatusResponse, TregoAdminBusiness?) {
        guard let json = await sendJSONRequest(
            path: "/api/admin/businesses/create",
            method: "POST",
            body: [
                "fullName": payload.fullName,
                "email": payload.email,
                "password": payload.password,
                "businessName": payload.businessName,
                "businessDescription": payload.businessDescription,
                "businessNumber": payload.businessNumber,
                "phoneNumber": payload.phoneNumber,
                "city": payload.city,
                "addressLine": payload.addressLine,
            ]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let business: TregoAdminBusiness? = decode(json.object["profile"]) ?? decode(json.object["business"])
        return (response, business)
    }

    func updateAdminBusiness(businessId: Int, payload: [String: Any]) async -> (TregoStatusResponse, TregoAdminBusiness?) {
        var requestPayload = payload
        requestPayload["businessId"] = businessId
        guard let json = await sendJSONRequest(
            path: "/api/admin/businesses/update",
            method: "POST",
            body: requestPayload
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let business: TregoAdminBusiness? = decode(json.object["business"])
        return (response, business)
    }

    func updateAdminBusinessVerification(businessId: Int, verificationStatus: String) async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/admin/businesses/verification",
            method: "POST",
            body: ["businessId": businessId, "verificationStatus": verificationStatus]
        )
    }

    func updateAdminReportStatus(reportId: Int, status: String, adminNotes: String = "") async -> TregoStatusResponse {
        await sendStatusRequest(
            path: "/api/admin/reports/status",
            method: "POST",
            body: ["reportId": reportId, "status": status, "adminNotes": adminNotes]
        )
    }

    func fetchConversations() async -> [TregoConversation] {
        await fetchList(path: "/api/chat/conversations", keyPreference: [.conversations])
    }

    func fetchConversationDetail(id: Int) async -> TregoConversationDetail? {
        let path = "/api/chat/messages?conversationId=\(id)"
        guard let json = await sendJSONRequest(path: path) else { return nil }
        guard json.ok else { return nil }
        let conversation: TregoConversation? = decode(json.object["conversation"])
        let messages: [TregoChatMessage] = decodeArray(json.object["messages"]) ?? []
        let typing = Bool(json.object["counterpartTyping"] as? Bool ?? false)
        return TregoConversationDetail(conversation: conversation, messages: messages, counterpartTyping: typing)
    }

    func sendMessage(conversationId: Int, body: String) async -> TregoChatMessage? {
        let (_, message, _) = await sendChatMessage(conversationId: conversationId, body: body)
        return message
    }

    func sendChatMessage(
        conversationId: Int,
        body: String,
        attachment: TregoAttachmentUpload? = nil
    ) async -> (TregoStatusResponse, TregoChatMessage?, TregoConversation?) {
        let json: TregoJSONResult?
        if let attachment {
            json = await sendMultipartRequest(
                path: "/api/chat/messages",
                uploads: [
                    TregoMultipartUpload(
                        data: attachment.data,
                        filename: attachment.filename,
                        mimeType: attachment.mimeType
                    ),
                ],
                fieldName: "attachment",
                fields: [
                    "conversationId": String(conversationId),
                    "body": body,
                ]
            )
        } else {
            json = await sendJSONRequest(
                path: "/api/chat/messages",
                method: "POST",
                body: ["conversationId": conversationId, "body": body]
            )
        }

        guard let json else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil, nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let message: TregoChatMessage? = decode(json.object["message"])
        let conversation: TregoConversation? = decode(json.object["conversation"])
        return (response, message, conversation)
    }

    func updateChatMessage(messageId: Int, body: String) async -> (TregoStatusResponse, TregoChatMessage?) {
        guard let json = await sendJSONRequest(
            path: "/api/chat/messages/update",
            method: "POST",
            body: ["messageId": messageId, "body": body]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let message: TregoChatMessage? = decode(json.object["message"])
        return (response, message)
    }

    func deleteChatMessage(messageId: Int) async -> (TregoStatusResponse, TregoChatMessage?) {
        guard let json = await sendJSONRequest(
            path: "/api/chat/messages/delete",
            method: "POST",
            body: ["messageId": messageId]
        ) else {
            return (TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil), nil)
        }

        let response = decode(json.object) as TregoStatusResponse?
            ?? TregoStatusResponse(ok: json.ok, message: json.message, errors: nil)
        let message: TregoChatMessage? = decode(json.object["message"])
        return (response, message)
    }

    private enum ListKeyPreference {
        case items
        case products
        case orders
        case users
        case businesses
        case reports
        case conversations
        case promotions
        case launchAds

        var rawKey: String {
            switch self {
            case .items: return "items"
            case .products: return "products"
            case .orders: return "orders"
            case .users: return "users"
            case .businesses: return "businesses"
            case .reports: return "reports"
            case .conversations: return "conversations"
            case .promotions: return "promotions"
            case .launchAds: return "launchAds"
            }
        }
    }

    private func fetchList<T: Decodable>(path: String, keyPreference: [ListKeyPreference]) async -> [T] {
        let result: TregoListFetchResult<T> = await fetchListResult(path: path, keyPreference: keyPreference)
        return result.items
    }

    private func fetchListResult<T: Decodable>(path: String, keyPreference: [ListKeyPreference]) async -> TregoListFetchResult<T> {
        guard let json = await sendJSONRequest(path: path) else {
            return TregoListFetchResult(items: [], didSucceed: false, message: "Lidhja me serverin deshtoi.")
        }
        guard json.ok else {
            return TregoListFetchResult(items: [], didSucceed: false, message: json.message)
        }
        for key in keyPreference {
            if let items: [T] = decodeArray(json.object[key.rawKey]) {
                return TregoListFetchResult(items: items, didSucceed: true, message: json.message)
            }
        }
        if let direct: [T] = decodeArray(json.object) {
            return TregoListFetchResult(items: direct, didSucceed: true, message: json.message)
        }
        return TregoListFetchResult(items: [], didSucceed: true, message: json.message)
    }

    private func fetchPage<T: Decodable & Equatable>(path: String, keyPreference: [ListKeyPreference]) async -> TregoPaginatedPayload<T> {
        let result: TregoPageFetchResult<T> = await fetchPageResult(path: path, keyPreference: keyPreference)
        return result.page
    }

    private func fetchPageResult<T: Decodable & Equatable>(path: String, keyPreference: [ListKeyPreference]) async -> TregoPageFetchResult<T> {
        guard let json = await sendJSONRequest(path: path) else {
            return TregoPageFetchResult(
                page: TregoPaginatedPayload(items: [], limit: 0, offset: 0, total: nil, hasMore: false),
                didSucceed: false,
                message: "Lidhja me serverin deshtoi."
            )
        }
        guard json.ok else {
            return TregoPageFetchResult(
                page: TregoPaginatedPayload(items: [], limit: 0, offset: 0, total: nil, hasMore: false),
                didSucceed: false,
                message: json.message
            )
        }

        let items: [T]
        if let decodedItems = keyPreference.compactMap({ decodeArray(json.object[$0.rawKey]) as [T]? }).first {
            items = decodedItems
        } else if let direct: [T] = decodeArray(json.object) {
            items = direct
        } else {
            items = []
        }

        return TregoPageFetchResult(
            page: TregoPaginatedPayload(
                items: items,
                limit: intValue(in: json.object["limit"]) ?? items.count,
                offset: intValue(in: json.object["offset"]) ?? 0,
                total: intValue(in: json.object["total"]),
                hasMore: boolValue(in: json.object["hasMore"]) ?? false
            ),
            didSucceed: true,
            message: json.message
        )
    }

    private func intValue(in value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let text as String:
            return Int(text)
        default:
            return nil
        }
    }

    private func boolValue(in value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let text as String:
            return NSString(string: text).boolValue
        default:
            return nil
        }
    }

    private func sendStatusRequest(path: String, method: String, body: [String: Any] = [:]) async -> TregoStatusResponse {
        guard let json = await sendJSONRequest(path: path, method: method, body: body.isEmpty ? nil : body) else {
            return TregoStatusResponse(ok: false, message: "Lidhja me serverin deshtoi.", errors: nil)
        }
        if let decoded: TregoStatusResponse = decode(json.object) {
            return decoded
        }
        return TregoStatusResponse(
            ok: json.ok,
            message: json.message,
            errors: nil,
            redirectTo: json.object["redirectTo"] as? String
        )
    }

    private func sendJSONRequest(path: String, method: String = "GET", body: [String: Any]? = nil) async -> TregoJSONResult? {
        guard let request = buildRequest(path: path, method: method, body: body) else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            return parseJSONResult(data: data, response: http)
        } catch {
            return nil
        }
    }

    private func sendMultipartRequest(path: String, upload: TregoImageSearchUpload) async -> TregoJSONResult? {
        await sendMultipartRequest(
            path: path,
            uploads: [
                TregoMultipartUpload(
                    data: upload.data,
                    filename: upload.filename,
                    mimeType: upload.mimeType
                ),
            ],
            fieldName: "image"
        )
    }

    private func sendMultipartRequest(path: String, uploads: [TregoImageSearchUpload], fieldName: String) async -> TregoJSONResult? {
        await sendMultipartRequest(
            path: path,
            uploads: uploads.map {
                TregoMultipartUpload(
                    data: $0.data,
                    filename: $0.filename,
                    mimeType: $0.mimeType
                )
            },
            fieldName: fieldName
        )
    }

    private func sendMultipartRequest(
        path: String,
        uploads: [TregoMultipartUpload],
        fieldName: String,
        fields: [String: String] = [:]
    ) async -> TregoJSONResult? {
        guard let request = buildMultipartRequest(path: path, uploads: uploads, fieldName: fieldName, fields: fields) else { return nil }

        do {
            let (data, response) = try await session.upload(for: request, from: request.httpBody ?? Data())
            guard let http = response as? HTTPURLResponse else { return nil }
            return parseJSONResult(data: data, response: http)
        } catch {
            return nil
        }
    }

    private func buildRequest(path: String, method: String, body: [String: Any]? = nil) -> URLRequest? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let relative = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed

        let url: URL
        if let querySeparatorIndex = relative.firstIndex(of: "?") {
            let rawPath = String(relative[..<querySeparatorIndex])
            let rawQuery = String(relative[relative.index(after: querySeparatorIndex)...])
            var components = URLComponents(
                url: configuration.baseURL.appendingPathComponent(rawPath),
                resolvingAgainstBaseURL: false
            )
            components?.percentEncodedQuery = rawQuery
            guard let resolved = components?.url else { return nil }
            url = resolved
        } else {
            url = configuration.baseURL.appendingPathComponent(relative)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(visitorToken, forHTTPHeaderField: "X-Trego-Visitor")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    private func buildMultipartRequest(
        path: String,
        uploads: [TregoMultipartUpload],
        fieldName: String,
        fields: [String: String] = [:]
    ) -> URLRequest? {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let base = buildRequest(path: path, method: "POST") else { return nil }
        var request = base
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        for upload in uploads {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(upload.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(upload.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(upload.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        return request
    }

    private func parseJSONResult(data: Data, response: HTTPURLResponse) -> TregoJSONResult? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            let rawText = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackMessage: String?
            if let rawText, !rawText.isEmpty {
                fallbackMessage = rawText
            } else {
                fallbackMessage = response.statusCode >= 200 && response.statusCode < 300
                    ? nil
                    : "Serveri ktheu nje gabim (\(response.statusCode))."
            }
            return TregoJSONResult(
                ok: response.statusCode >= 200 && response.statusCode < 300,
                statusCode: response.statusCode,
                message: fallbackMessage,
                object: [:]
            )
        }
        let ok = Bool(object["ok"] as? Bool ?? (response.statusCode >= 200 && response.statusCode < 300))
        let message = (object["message"] as? String) ?? ((object["errors"] as? [String])?.joined(separator: " "))
        return TregoJSONResult(ok: ok, statusCode: response.statusCode, message: message, object: object)
    }

    private func fetchCurrentUserStateOnce() async -> TregoCurrentUserFetchState? {
        guard let json = await sendJSONRequest(path: "/api/me") else { return nil }
        if json.ok, let user: TregoSessionUser = decode(json.object["user"]) {
            return .authenticated(user)
        }
        if json.statusCode == 401 || json.statusCode == 403 {
            return .unauthenticated
        }
        return .failed(json.message)
    }

    private func decode<T: Decodable>(_ value: Any?) -> T? {
        guard let value else { return nil }
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func decodeArray<T: Decodable>(_ value: Any?) -> [T]? {
        guard let value else { return nil }
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        return try? decoder.decode([T].self, from: data)
    }

    private var visitorToken: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: visitorDefaultsKey), !existing.isEmpty {
            return existing
        }
        let token = "visitor-\(UUID().uuidString.lowercased())"
        defaults.set(token, forKey: visitorDefaultsKey)
        return token
    }

    private func clearCookies() {
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

private struct TregoJSONResult {
    let ok: Bool
    let statusCode: Int
    let message: String?
    let object: [String: Any]
}

fileprivate enum TregoCurrentUserFetchState {
    case authenticated(TregoSessionUser)
    case unauthenticated
    case failed(String?)
}

struct TregoAuthenticationPrompt: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class TregoNativeAppStore: ObservableObject {
    private static let viewedHistoryStorageKey = "trego-ios-native-viewed-history"
    private let sessionRefreshThrottleSeconds: TimeInterval = 12

    @Published var selectedTab: LiquidGlassTab = .home
    @Published var user: TregoSessionUser?
    @Published var sessionLoaded = false
    @Published var sessionRefreshing = false
    @Published var appSettings = TregoAppSettings.load()
    @Published var homeProducts: [TregoProduct] = []
    @Published var homeRecommendationSections: [TregoRecommendationSection] = []
    @Published var homeLoading = false
    @Published var homeLoadingMore = false
    @Published var homeHasMore = false
    @Published var publicBusinesses: [TregoPublicBusinessProfile] = []
    @Published var publicBusinessesLoading = false
    @Published var searchQuery = ""
    @Published var searchResults: [TregoProduct] = []
    @Published var searchLoading = false
    @Published var searchLoadingMore = false
    @Published var searchHasMore = false
    @Published var viewedHistory: [TregoViewedHistoryEntry] = []
    @Published var recentlyViewedProducts: [TregoProduct] = []
    @Published var wishlist: [TregoProduct] = []
    @Published var wishlistLoading = false
    @Published var cart: [TregoCartItem] = []
    @Published var cartLoading = false
    @Published var orders: [TregoOrderItem] = []
    @Published var ordersLoading = false
    @Published var conversations: [TregoConversation] = []
    @Published var conversationsLoading = false
    @Published var businessProfile: TregoBusinessProfile?
    @Published var businessAnalytics: TregoBusinessAnalytics?
    @Published var businessProducts: [TregoProduct] = []
    @Published var businessOrders: [TregoOrderItem] = []
    @Published var businessPromotions: [TregoPromotion] = []
    @Published var businessWorkspaceLoading = false
    @Published var launchAds: [TregoLaunchAd] = []
    @Published var adminUsers: [TregoAdminUser] = []
    @Published var adminBusinesses: [TregoAdminBusiness] = []
    @Published var adminReports: [TregoAdminReport] = []
    @Published var adminOrders: [TregoOrderItem] = []
    @Published var adminLaunchAds: [TregoLaunchAd] = []
    @Published var adminWorkspaceLoading = false
    @Published var authRoute: TregoAuthRoute?
    @Published var accountAuthRoute: TregoAuthRoute = .login
    @Published var pendingEmailVerificationEmail = ""
    @Published var pendingEmailVerificationMessage: String?
    @Published var selectedProduct: TregoProduct?
    @Published var selectedConversation: TregoConversation?
    @Published var toastMessage: String?
    @Published var globalMessage: String?
    @Published var authenticationPrompt: TregoAuthenticationPrompt?

    let api = TregoAPIClient()
    private var hasLoadedHome = false
    private var toastTask: Task<Void, Never>?
    private var lastSessionRefreshAt: Date?
    private var homeOffset = 0
    private var searchOffset = 0
    private var lastSearchTerm = ""

    init() {
        let history = Self.loadViewedHistory()
        viewedHistory = history
        recentlyViewedProducts = history.map(\.product)
    }

    var tabBadges: [LiquidGlassTab: String] {
        var map: [LiquidGlassTab: String] = [:]
        let cartCount = cart.reduce(0) { $0 + max(1, $1.quantity ?? 1) }
        if cartCount > 0 {
            map[.cart] = badgeText(for: cartCount)
        }
        return map
    }

    var isResolvingSession: Bool {
        !sessionLoaded || (sessionRefreshing && user == nil)
    }

    func bootstrap() async {
        let launchAdsTask = Task { await self.api.fetchLaunchAds() }
        let homeTask = Task { await self.loadHomeIfNeeded(force: true) }
        await refreshSession(force: true)
        _ = await homeTask.value
        launchAds = await launchAdsTask.value
        if user != nil {
            Task {
                async let wishlistTask: Void = loadWishlist()
                async let cartTask: Void = loadCart()
                _ = await (wishlistTask, cartTask)
            }
        }
    }

    func refreshSession(force: Bool = false) async {
        if sessionRefreshing { return }
        if !force, let lastSessionRefreshAt, Date().timeIntervalSince(lastSessionRefreshAt) < sessionRefreshThrottleSeconds {
            return
        }

        sessionRefreshing = true
        let previousUser = user
        defer {
            sessionRefreshing = false
            sessionLoaded = true
            lastSessionRefreshAt = Date()
        }

        switch await api.fetchCurrentUserState() {
        case .authenticated(let fetchedUser):
            user = fetchedUser
            clearRoleScopedData(for: fetchedUser)
            authenticationPrompt = nil
            authRoute = nil
        case .unauthenticated:
            user = nil
            clearAuthenticatedData()
        case .failed:
            if previousUser == nil {
                user = nil
            } else {
                user = previousUser
                clearRoleScopedData(for: previousUser)
            }
        }

        if user?.role == "business" {
            homeRecommendationSections = []
        } else {
            Task { [weak self] in
                await self?.loadHomeRecommendations()
            }
        }
    }

    func warmSessionRefreshInBackground(force: Bool = false) {
        if sessionRefreshing { return }
        if !force, let lastSessionRefreshAt, Date().timeIntervalSince(lastSessionRefreshAt) < sessionRefreshThrottleSeconds {
            return
        }

        Task {
            await refreshSession(force: force)
        }
    }

    func loadHomeIfNeeded(force: Bool = false) async {
        if homeLoading && !force { return }
        guard force || !hasLoadedHome else { return }
        homeLoading = true
        defer {
            homeLoading = false
        }

        async let recommendations = api.fetchHomeRecommendations(limit: 10)
        let result = await api.fetchMarketplaceProductsPageResult(limit: 24, offset: 0)
        guard result.didSucceed else {
            homeRecommendationSections = await recommendations
            if !homeProducts.isEmpty {
                showToast(result.message ?? "Produktet aktuale u ruajten. Rifreskimi deshtoi.")
            }
            return
        }

        let page = result.page
        homeProducts = page.items
        homeRecommendationSections = await recommendations
        homeOffset = page.offset + page.items.count
        homeHasMore = page.hasMore
        hasLoadedHome = true
    }

    func loadHomeRecommendations() async {
        homeRecommendationSections = await api.fetchHomeRecommendations(limit: 10)
    }

    func loadMoreHomeIfNeeded() async {
        guard hasLoadedHome, homeHasMore, !homeLoading, !homeLoadingMore else { return }
        homeLoadingMore = true
        defer { homeLoadingMore = false }

        let result = await api.fetchMarketplaceProductsPageResult(limit: 24, offset: homeOffset)
        guard result.didSucceed else {
            showToast(result.message ?? "Produktet aktuale u ruajten. Ngarkimi i metejshem deshtoi.")
            return
        }

        let page = result.page
        homeProducts = mergeUniqueProducts(existing: homeProducts, incoming: page.items)
        homeOffset = page.offset + page.items.count
        homeHasMore = page.hasMore
    }

    var personalizationConsentPending: Bool {
        appSettings.personalizationConsentStatus == "pending"
    }

    var personalizedRecommendationsEnabled: Bool {
        appSettings.personalizationConsentStatus == "allowed" && appSettings.privacyMode != "strict"
    }

    func allowPersonalizedRecommendations() {
        appSettings.personalizationConsentStatus = "allowed"
        appSettings.persist()
        showToast("Rekomandimet personale u aktivizuan.")
    }

    func declinePersonalizedRecommendations() {
        appSettings.personalizationConsentStatus = "declined"
        appSettings.persist()
        showToast("Rekomandimet personale mbeten te fikura.")
    }

    func personalizedHomeProducts(from products: [TregoProduct]) -> [TregoProduct] {
        guard personalizedRecommendationsEnabled, !products.isEmpty else { return products }

        let recentCategories = recentlyViewedProducts.compactMap { normalizedCategoryKey(for: $0) }
        let wishlistCategories = wishlist.compactMap { normalizedCategoryKey(for: $0) }
        let preferredCategories = recentCategories + wishlistCategories

        let recentBusinesses = recentlyViewedProducts.compactMap { normalizedBusinessName(for: $0) }
        let wishlistBusinesses = wishlist.compactMap { normalizedBusinessName(for: $0) }
        let preferredBusinesses = recentBusinesses + wishlistBusinesses

        guard !preferredCategories.isEmpty || !preferredBusinesses.isEmpty else {
            return products
        }

        return products.sorted { lhs, rhs in
            let leftScore = personalizedScore(for: lhs, preferredCategories: preferredCategories, preferredBusinesses: preferredBusinesses)
            let rightScore = personalizedScore(for: rhs, preferredCategories: preferredCategories, preferredBusinesses: preferredBusinesses)
            if leftScore == rightScore {
                return lhs.id < rhs.id
            }
            return leftScore > rightScore
        }
    }

    @discardableResult
    func loadPublicBusinesses(force: Bool = false) async -> Bool {
        if publicBusinessesLoading && !force { return false }
        publicBusinessesLoading = true
        defer { publicBusinessesLoading = false }

        let result = await api.fetchPublicBusinessesResult()
        guard result.didSucceed else {
            if !publicBusinesses.isEmpty {
                showToast(result.message ?? "Bizneset dhe produktet aktuale u ruajten. Rifreskimi deshtoi.")
            }
            return false
        }

        publicBusinesses = result.items
        return true
    }

    func openSearch(with query: String = "") async {
        selectedTab = .kerko
        searchQuery = query
        await performSearch()
    }

    func performSearch(forceProductsFallback: Bool = false) async {
        await performSearch(forceProductsFallback: forceProductsFallback, append: false)
    }

    func performSearch(forceProductsFallback: Bool = false, append: Bool) async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = trimmed.lowercased()
        let isFreshSearch = !append || normalizedQuery != lastSearchTerm

        if append {
            guard searchHasMore, !searchLoadingMore else { return }
            searchLoadingMore = true
        } else {
            searchLoading = true
        }

        defer {
            if append {
                searchLoadingMore = false
            } else {
                searchLoading = false
            }
        }

        if isFreshSearch {
            lastSearchTerm = normalizedQuery
            searchOffset = 0
            searchHasMore = false
        }

        if trimmed.isEmpty {
            let page = await api.fetchMarketplaceProductsPage(limit: 18, offset: append ? searchOffset : 0)
            searchResults = append
                ? mergeUniqueProducts(existing: searchResults, incoming: page.items)
                : page.items
            searchOffset = page.offset + page.items.count
            searchHasMore = page.hasMore
            return
        }

        let page = await api.searchProductsPage(query: trimmed, limit: 18, offset: append ? searchOffset : 0)
        if page.items.isEmpty && forceProductsFallback && !append {
            let fallbackPage = await api.fetchMarketplaceProductsPage(limit: 18, offset: 0)
            searchResults = fallbackPage.items
            searchOffset = fallbackPage.offset + fallbackPage.items.count
            searchHasMore = fallbackPage.hasMore
            return
        }

        searchResults = append
            ? mergeUniqueProducts(existing: searchResults, incoming: page.items)
            : page.items
        searchOffset = page.offset + page.items.count
        searchHasMore = page.hasMore
    }

    func loadMoreSearchIfNeeded() async {
        await performSearch(append: true)
    }

    func performImageSearch(upload: TregoImageSearchUpload) async {
        selectedTab = .kerko
        searchLoading = true
        searchResults = await api.searchProducts(imageUpload: upload)
        searchOffset = searchResults.count
        searchHasMore = false
        lastSearchTerm = ""
        searchLoading = false
    }

    func trackViewedProduct(_ product: TregoProduct) {
        let entry = TregoViewedHistoryEntry(
            product: product,
            viewedAt: ISO8601DateFormatter().string(from: Date())
        )
        let filtered = viewedHistory.filter { $0.product.id != product.id }
        viewedHistory = [entry] + filtered.prefix(29)
        persistViewedHistory()
        recentlyViewedProducts = viewedHistory.map(\.product)
    }

    func removeViewedHistoryProduct(productID: Int) {
        viewedHistory.removeAll { $0.product.id == productID }
        persistViewedHistory()
        recentlyViewedProducts = viewedHistory.map(\.product)
    }

    private func mergeUniqueProducts(existing: [TregoProduct], incoming: [TregoProduct]) -> [TregoProduct] {
        var seen = Set(existing.map(\.id))
        var merged = existing
        for product in incoming where seen.insert(product.id).inserted {
            merged.append(product)
        }
        return merged
    }

    func loadWishlist() async {
        guard user != nil else {
            wishlist = []
            return
        }
        wishlistLoading = true
        wishlist = await api.fetchWishlist()
        wishlistLoading = false
    }

    func loadCart() async {
        guard user != nil else {
            cart = []
            return
        }
        cartLoading = true
        cart = await api.fetchCart()
        cartLoading = false
    }

    func loadOrders() async {
        guard user != nil else {
            orders = []
            return
        }
        ordersLoading = true
        orders = await api.fetchOrders()
        ordersLoading = false
    }

    func loadConversations() async {
        guard user != nil else {
            conversations = []
            return
        }
        conversationsLoading = true
        conversations = await api.fetchConversations()
        conversationsLoading = false
    }

    func openConversation(with conversation: TregoConversation) {
        selectedConversation = conversation
    }

    func startConversationWithBusiness(businessId: Int) async {
        guard await ensureAuthenticatedSessionOrPrompt(
            message: "Per te derguar mesazh biznesit duhet te kyqeni ose te krijoni llogari."
        ) else { return }

        let (response, conversation) = await api.openBusinessConversation(businessId: businessId)
        guard response.ok == true, let conversation else {
            globalMessage = response.message ?? "Biseda nuk u hap."
            return
        }

        selectedConversation = conversation
    }

    func startSupportConversation() async {
        guard await ensureAuthenticatedSessionOrPrompt(
            message: "Per te folur me customer support duhet te kyqeni ose te krijoni llogari."
        ) else { return }

        let (response, conversation) = await api.openSupportConversation()
        guard response.ok == true, let conversation else {
            globalMessage = response.message ?? "Customer support nuk u hap."
            return
        }

        selectedConversation = conversation
    }

    func togglePublicBusinessFollow(_ business: TregoPublicBusinessProfile) async {
        guard await ensureAuthenticatedSession(route: .login) else { return }

        let (response, updatedBusiness) = await api.toggleBusinessFollow(businessId: business.id)
        guard response.ok == true else {
            globalMessage = response.message ?? "Ndjekja nuk u perditesua."
            return
        }

        if let updatedBusiness {
            publicBusinesses = publicBusinesses.map { current in
                current.id == updatedBusiness.id ? updatedBusiness : current
            }
        } else {
            await loadPublicBusinesses(force: true)
        }

        showToast(response.message ?? "Biznesi u perditesua.")
    }

    func loadBusinessWorkspace(force: Bool = false) async {
        guard user?.role == "business" else {
            businessProfile = nil
            businessAnalytics = nil
            businessProducts = []
            businessOrders = []
            businessPromotions = []
            return
        }

        if businessWorkspaceLoading && !force { return }

        businessWorkspaceLoading = true
        async let profile = api.fetchBusinessProfile()
        async let analytics = api.fetchBusinessAnalytics()
        async let products = api.fetchBusinessProducts()
        async let orders = api.fetchBusinessOrders()
        async let promotions = api.fetchBusinessPromotions()

        businessProfile = await profile
        businessAnalytics = await analytics
        businessProducts = await products
        businessOrders = await orders
        businessPromotions = await promotions
        businessWorkspaceLoading = false
    }

    func loadLaunchAds() async {
        launchAds = await api.fetchLaunchAds()
    }

    func loadAdminWorkspace(force: Bool = false) async {
        guard user?.role == "admin" else {
            adminUsers = []
            adminBusinesses = []
            adminReports = []
            adminOrders = []
            adminLaunchAds = []
            return
        }

        if adminWorkspaceLoading && !force { return }

        adminWorkspaceLoading = true
        async let users = api.fetchAdminUsers()
        async let businesses = api.fetchAdminBusinesses()
        async let reports = api.fetchAdminReports()
        async let orders = api.fetchAdminOrders()
        async let launchAds = api.fetchAdminLaunchAds()

        adminUsers = await users
        adminBusinesses = await businesses
        adminReports = await reports
        adminOrders = await orders
        adminLaunchAds = await launchAds
        adminWorkspaceLoading = false
    }

    func isWishlisted(productId: Int) -> Bool {
        wishlist.contains(where: { $0.id == productId })
    }

    func toggleWishlist(for product: TregoProduct) async {
        guard await ensureAuthenticatedSessionOrPrompt(
            message: "Per ta ruajtur produktin ne wishlist duhet te kyqeni ose te krijoni llogari."
        ) else { return }
        let wasWishlisted = wishlist.contains(where: { $0.id == product.id })
        let previousWishlist = wishlist

        if wasWishlisted {
            wishlist.removeAll { $0.id == product.id }
        } else {
            wishlist = [product] + wishlist.filter { $0.id != product.id }
        }

        let response = await api.toggleWishlist(productId: product.id)
        if response.ok == true {
            if let items = response.items {
                wishlist = items
            }
            await loadHomeRecommendations()
            if selectedTab == .kerko {
                await performSearch()
            }
            showToast(response.message ?? "Wishlist u perditesua.")
        } else {
            wishlist = previousWishlist
            globalMessage = response.message ?? response.errors?.joined(separator: " ") ?? "Wishlist nuk u perditesua."
        }
    }

    func addToCart(product: TregoProduct) async {
        guard await ensureAuthenticatedSessionOrPrompt(
            message: "Per ta vendosur produktin ne cart duhet te kyqeni ose te krijoni llogari."
        ) else { return }

        guard let selection = resolvedCartSelection(for: product) else {
            if product.requiresVariantSelection == true {
                globalMessage = "Zgjidh madhesine ose ngjyren te faqja e produktit para se ta shtosh ne cart."
                selectedProduct = product
            } else {
                globalMessage = "Produkti nuk ka stok te disponueshem."
            }
            return
        }

        let response = await api.addToCart(
            productId: product.id,
            quantity: 1,
            variantKey: selection.variantKey,
            selectedSize: selection.selectedSize,
            selectedColor: selection.selectedColor
        )

        if response.ok == true {
            await loadCart()
            await loadHomeRecommendations()
            showToast(response.message ?? "Produkti u shtua ne cart.")
        } else {
            globalMessage = response.message ?? "Produkti nuk u shtua ne cart."
        }
    }

    private func resolvedCartSelection(for product: TregoProduct) -> (variantKey: String, selectedSize: String, selectedColor: String)? {
        let variants = (product.variantInventory ?? []).filter { max(0, $0.quantity ?? 0) > 0 }
        let requestedVariantKey = normalizedVariantToken(product.variantKey)
        let requestedSize = normalizedSizeToken(product.selectedSize ?? product.size)
        let requestedColor = normalizedColorToken(product.selectedColor ?? product.color)

        if let explicitMatch = variants.first(where: { variant in
            normalizedVariantToken(variant.key) == requestedVariantKey && !requestedVariantKey.isEmpty
        }) {
            return (
                variantKey: normalizedVariantToken(explicitMatch.key),
                selectedSize: normalizedSizeToken(explicitMatch.size),
                selectedColor: normalizedColorToken(explicitMatch.color)
            )
        }

        if !requestedSize.isEmpty || !requestedColor.isEmpty {
            if let inferredMatch = variants.first(where: { variant in
                let variantSize = normalizedSizeToken(variant.size)
                let variantColor = normalizedColorToken(variant.color)
                let sizeMatches = requestedSize.isEmpty || variantSize == requestedSize
                let colorMatches = requestedColor.isEmpty || variantColor == requestedColor
                return sizeMatches && colorMatches
            }) {
                return (
                    variantKey: normalizedVariantToken(inferredMatch.key),
                    selectedSize: normalizedSizeToken(inferredMatch.size),
                    selectedColor: normalizedColorToken(inferredMatch.color)
                )
            }
        }

        if product.requiresVariantSelection == true && variants.count > 1 {
            return nil
        }

        if let onlyVariant = variants.first {
            return (
                variantKey: normalizedVariantToken(onlyVariant.key),
                selectedSize: normalizedSizeToken(onlyVariant.size),
                selectedColor: normalizedColorToken(onlyVariant.color)
            )
        }

        if requestedVariantKey.isEmpty && requestedSize.isEmpty && requestedColor.isEmpty {
            return (variantKey: "default", selectedSize: "", selectedColor: "")
        }

        return nil
    }

    private func normalizedVariantToken(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "" : trimmed
    }

    private func normalizedSizeToken(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
    }

    private func normalizedColorToken(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    func removeFromCart(cartLineId: Int) async {
        let response = await api.removeFromCart(cartLineId: cartLineId)
        if response.ok == true {
            await loadCart()
            showToast(response.message ?? "Produkti u hoq nga cart.")
        } else {
            globalMessage = response.message ?? "Produkti nuk u hoq."
        }
    }

    func updateCartQuantity(cartLineId: Int, quantity: Int) async {
        let (response, items) = await api.updateCartQuantity(cartLineId: cartLineId, quantity: quantity)
        if response.ok == true {
            if let items {
                cart = items
            } else {
                await loadCart()
            }
            showToast(response.message ?? "Sasia u perditesua.")
        } else {
            globalMessage = response.message ?? response.errors?.joined(separator: " ") ?? "Sasia nuk u perditesua."
        }
    }

    func login(identifier: String, password: String) async -> String? {
        guard !identifier.isEmpty, !password.isEmpty else {
            return "Ploteso email ose numer telefoni dhe password."
        }

        let response = await api.login(identifier: identifier, password: password)
        guard response.ok == true else {
            if shouldOpenEmailVerification(for: response) {
                openEmailVerification(
                    email: emailFromVerificationRedirect(response.redirectTo) ?? pendingEmailVerificationEmail,
                    fallbackIdentifier: identifier,
                    message: response.message
                )
                return nil
            }
            return response.message ?? response.errors?.joined(separator: " ") ?? "Login deshtoi."
        }

        if let authenticatedUser = response.user {
            applyAuthenticatedUserSnapshot(authenticatedUser)
        }
        pendingEmailVerificationMessage = nil
        authRoute = nil
        accountAuthRoute = .login
        selectedTab = .home
        Task {
            await refreshSession(force: true)
            guard self.user != nil else { return }
            await loadWishlist()
            await loadCart()
        }
        showToast(response.message ?? "Mire se erdhe.")
        return nil
    }

    func register(fullName: String, email: String, phoneNumber: String, password: String, birthDate: String, gender: String) async -> String? {
        guard !fullName.isEmpty, !email.isEmpty, !phoneNumber.isEmpty, !password.isEmpty else {
            return "Ploteso te gjitha fushat kryesore."
        }

        let response = await api.register(
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            password: password,
            birthDate: birthDate,
            gender: gender
        )

        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Regjistrimi deshtoi."
        }

        if shouldOpenEmailVerification(for: response) {
            openEmailVerification(
                email: emailFromVerificationRedirect(response.redirectTo) ?? email,
                fallbackIdentifier: email,
                message: response.message
            )
            return nil
        }

        await refreshSession(force: true)
        if user != nil {
            async let wishlistTask: Void = loadWishlist()
            async let cartTask: Void = loadCart()
            _ = await (wishlistTask, cartTask)
            authRoute = nil
            accountAuthRoute = .login
            selectedTab = .home
        } else {
            authRoute = .login
        }
        showToast(response.message ?? "Llogaria u krijua me sukses.")
        return nil
    }

    func requestPasswordReset(email: String) async -> String? {
        guard !email.isEmpty else {
            return "Shkruaj email-in."
        }
        let response = await api.requestPasswordReset(email: email)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Kerkesa per reset deshtoi."
        }
        showToast(response.message ?? "Kodi u dergua.")
        return nil
    }

    func confirmPasswordReset(email: String, code: String, newPassword: String, confirmPassword: String) async -> String? {
        guard !email.isEmpty, !code.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            return "Ploteso te gjitha fushat."
        }
        let response = await api.confirmPasswordReset(
            email: email,
            code: code,
            newPassword: newPassword,
            confirmPassword: confirmPassword
        )
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Resetimi deshtoi."
        }
        authRoute = .login
        showToast(response.message ?? "Fjalekalimi u ndryshua.")
        return nil
    }

    func verifyEmail(email: String, code: String) async -> String? {
        guard !email.isEmpty, !code.isEmpty else {
            return "Shkruaj email-in dhe kodin e verifikimit."
        }

        let response = await api.verifyEmail(email: email, code: code)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Verifikimi deshtoi."
        }

        pendingEmailVerificationEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        pendingEmailVerificationMessage = nil
        authRoute = .login
        accountAuthRoute = .login
        showToast(response.message ?? "Email-i u verifikua me sukses.")
        return nil
    }

    func resendEmailVerification(email: String) async -> String? {
        guard !email.isEmpty else {
            return "Shkruaj email-in."
        }

        let response = await api.resendEmailVerification(email: email)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Kodi nuk u dergua."
        }

        pendingEmailVerificationEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        pendingEmailVerificationMessage = response.message
        return nil
    }

    private func isEmailVerificationRedirect(_ redirectTo: String) -> Bool {
        redirectTo.contains("/verifiko-email")
    }

    private func isEmailVerificationMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        let normalized = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return normalized.contains("verifiko") && normalized.contains("email")
    }

    private func shouldOpenEmailVerification(for response: TregoStatusResponse) -> Bool {
        if let redirectTo = response.redirectTo, isEmailVerificationRedirect(redirectTo) {
            return true
        }
        return isEmailVerificationMessage(response.message)
    }

    private func emailFromVerificationRedirect(_ redirectTo: String?) -> String? {
        guard let redirectTo, !redirectTo.isEmpty else { return nil }
        let candidate = redirectTo.hasPrefix("http")
            ? redirectTo
            : "https://www.tregos.store\(redirectTo)"
        guard let components = URLComponents(string: candidate) else { return nil }
        return components.queryItems?.first(where: { $0.name == "email" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func logout() async {
        await api.logout()
        resetSessionState()
        showToast("U ckyce me sukses.")
    }

    func resetSessionState() {
        user = nil
        sessionLoaded = true
        sessionRefreshing = false
        wishlist = []
        cart = []
        orders = []
        conversations = []
        businessProfile = nil
        businessAnalytics = nil
        businessProducts = []
        businessOrders = []
        businessPromotions = []
        adminUsers = []
        adminBusinesses = []
        adminReports = []
        adminOrders = []
        adminLaunchAds = []
        pendingEmailVerificationEmail = ""
        pendingEmailVerificationMessage = nil
        selectedTab = .home
        authRoute = nil
        accountAuthRoute = .login
        selectedConversation = nil
    }

    private func clearAuthenticatedData() {
        wishlist = []
        cart = []
        orders = []
        conversations = []
        businessProfile = nil
        businessAnalytics = nil
        businessProducts = []
        businessOrders = []
        businessPromotions = []
        adminUsers = []
        adminBusinesses = []
        adminReports = []
        adminOrders = []
        adminLaunchAds = []
    }

    private func applyAuthenticatedUserSnapshot(_ sessionUser: TregoSessionUser) {
        user = sessionUser
        sessionLoaded = true
        clearRoleScopedData(for: sessionUser)
        authenticationPrompt = nil
        authRoute = nil
    }

    private func clearRoleScopedData(for sessionUser: TregoSessionUser?) {
        guard let sessionUser else {
            clearAuthenticatedData()
            return
        }

        if sessionUser.role != "business" {
            businessProfile = nil
            businessAnalytics = nil
            businessProducts = []
            businessOrders = []
            businessPromotions = []
        }

        if sessionUser.role != "admin" {
            adminUsers = []
            adminBusinesses = []
            adminReports = []
            adminOrders = []
            adminLaunchAds = []
        }
    }

    func requireAuthentication(defaultRoute: TregoAuthRoute) {
        openAccountAuth(defaultRoute)
    }

    func openAccountAuth(_ route: TregoAuthRoute) {
        let normalizedRoute: TregoAuthRoute = route == .signup ? .signup : .login
        accountAuthRoute = normalizedRoute
        authRoute = route
        if user == nil {
            warmSessionRefreshInBackground(force: !sessionLoaded)
        }
    }

    func dismissPresentedNativeFlow() {
        selectedProduct = nil
        selectedConversation = nil
    }

    func openEmailVerification(email: String, fallbackIdentifier: String = "", message: String? = nil) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedEmail.isEmpty {
            pendingEmailVerificationEmail = trimmedEmail
        } else if fallbackIdentifier.contains("@") {
            pendingEmailVerificationEmail = fallbackIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        pendingEmailVerificationMessage = message
        authRoute = .verifyEmail
        accountAuthRoute = .login
    }

    @discardableResult
    func ensureAuthenticatedSession(route: TregoAuthRoute = .login) async -> Bool {
        if user != nil { return true }

        if sessionRefreshing {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if user != nil { return true }
        }

        warmSessionRefreshInBackground(force: !sessionLoaded)
        if !sessionLoaded {
            try? await Task.sleep(nanoseconds: 220_000_000)
            if user != nil { return true }
        }
        openAccountAuth(route)
        return false
    }

    @discardableResult
    func ensureAuthenticatedSessionOrPrompt(message: String) async -> Bool {
        if user != nil { return true }

        if sessionRefreshing {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if user != nil { return true }
        }

        warmSessionRefreshInBackground(force: !sessionLoaded)
        if !sessionLoaded {
            try? await Task.sleep(nanoseconds: 220_000_000)
            if user != nil { return true }
        }
        let hadPresentedFlow = selectedProduct != nil || selectedConversation != nil
        if hadPresentedFlow {
            dismissPresentedNativeFlow()
            try? await Task.sleep(nanoseconds: 160_000_000)
        }
        authenticationPrompt = TregoAuthenticationPrompt(
            title: "Kycu ose krijo llogari",
            message: message
        )
        return false
    }

    func requestBusinessVerification() async {
        let response = await api.requestBusinessVerification()
        if response.ok == true {
            await loadBusinessWorkspace(force: true)
            showToast(response.message ?? "Kerkesa u dergua.")
        } else {
            globalMessage = response.message ?? "Kerkesa nuk u dergua."
        }
    }

    func requestBusinessEditAccess() async {
        let response = await api.requestBusinessEditAccess()
        if response.ok == true {
            await loadBusinessWorkspace(force: true)
            showToast(response.message ?? "Kerkesa u dergua.")
        } else {
            globalMessage = response.message ?? "Kerkesa nuk u dergua."
        }
    }

    func saveBusinessPromotion(payload: [String: Any]) async -> String? {
        let (promotions, response) = await api.saveBusinessPromotion(payload: payload)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Promocioni nuk u ruajt."
        }
        businessPromotions = promotions
        if promotions.isEmpty {
            await loadBusinessWorkspace(force: true)
        }
        showToast(response.message ?? "Promocioni u ruajt.")
        return nil
    }

    func deleteBusinessPromotion(_ promotion: TregoPromotion) async -> String? {
        let (promotions, response) = await api.deleteBusinessPromotion(id: promotion.id, code: promotion.code)
        guard response.ok == true else {
            return response.message ?? "Promocioni nuk u fshi."
        }
        businessPromotions = promotions
        showToast(response.message ?? "Promocioni u fshi.")
        return nil
    }

    func updateBusinessOrderStatus(_ order: TregoOrderItem, status: String, trackingCode: String = "", trackingURL: String = "") async -> String? {
        let response = await api.updateOrderStatus(
            orderItemId: order.id,
            status: status,
            trackingCode: trackingCode,
            trackingURL: trackingURL
        )
        guard response.ok == true else {
            return response.message ?? "Statusi i porosise nuk u perditesua."
        }
        await loadBusinessWorkspace(force: true)
        showToast(response.message ?? "Statusi i porosise u perditesua.")
        return nil
    }

    func updateBusinessProfile(payload: [String: Any]) async -> String? {
        let (response, profile) = await api.updateBusinessProfile(payload: payload)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Profili i biznesit nuk u ruajt."
        }
        if let profile {
            businessProfile = profile
        }
        await loadBusinessWorkspace(force: true)
        showToast(response.message ?? "Profili i biznesit u ruajt.")
        return nil
    }

    func saveBusinessShippingSettings(payload: [String: Any]) async -> String? {
        let (response, profile) = await api.saveBusinessShippingSettings(payload: payload)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Transporti nuk u ruajt."
        }
        if let profile {
            businessProfile = profile
        }
        await loadBusinessWorkspace(force: true)
        showToast(response.message ?? "Rregullat e transportit u ruajten.")
        return nil
    }

    func updateAdminBusinessVerification(_ business: TregoAdminBusiness, status: String) async {
        let response = await api.updateAdminBusinessVerification(businessId: business.id, verificationStatus: status)
        if response.ok == true {
            await loadAdminWorkspace(force: true)
            showToast(response.message ?? "Statusi i biznesit u perditesua.")
        } else {
            globalMessage = response.message ?? "Statusi nuk u perditesua."
        }
    }

    func updateAdminBusinessEditAccess(_ business: TregoAdminBusiness, status: String) async {
        let response = await api.updateAdminBusinessEditAccess(businessId: business.id, status: status)
        if response.ok == true {
            await loadAdminWorkspace(force: true)
            showToast(response.message ?? "Qasja e editimit u perditesua.")
        } else {
            globalMessage = response.message ?? "Qasja e editimit nuk u perditesua."
        }
    }

    func updateAdminReportStatus(_ report: TregoAdminReport, status: String) async {
        let response = await api.updateAdminReportStatus(reportId: report.id, status: status)
        if response.ok == true {
            await loadAdminWorkspace(force: true)
            showToast(response.message ?? "Statusi i report-it u perditesua.")
        } else {
            globalMessage = response.message ?? "Statusi nuk u perditesua."
        }
    }

    func updateAdminUserRole(_ user: TregoAdminUser, role: String) async {
        let response = await api.updateAdminUserRole(userId: user.id, role: role)
        if response.ok == true {
            await loadAdminWorkspace(force: true)
            showToast(response.message ?? "Roli i perdoruesit u perditesua.")
        } else {
            globalMessage = response.message ?? "Roli nuk u perditesua."
        }
    }

    func deleteAdminUser(_ user: TregoAdminUser) async {
        let response = await api.deleteAdminUser(userId: user.id)
        if response.ok == true {
            await loadAdminWorkspace(force: true)
            showToast(response.message ?? "Perdoruesi u fshi.")
        } else {
            globalMessage = response.message ?? "Perdoruesi nuk u fshi."
        }
    }

    func setAdminUserPassword(_ user: TregoAdminUser, newPassword: String) async -> String? {
        guard !newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Shkruaj fjalekalimin e ri."
        }
        let response = await api.setAdminUserPassword(userId: user.id, newPassword: newPassword)
        if response.ok == true {
            await loadAdminWorkspace(force: true)
            showToast(response.message ?? "Fjalekalimi u ndryshua.")
            return nil
        }
        return response.message ?? "Fjalekalimi nuk u ndryshua."
    }

    func createAdminBusiness(payload: TregoAdminBusinessCreatePayload) async -> String? {
        let (response, _) = await api.createAdminBusiness(payload: payload)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Biznesi nuk u krijua."
        }
        await loadAdminWorkspace(force: true)
        showToast(response.message ?? "Biznesi u krijua me sukses.")
        return nil
    }

    func updateAdminBusiness(_ business: TregoAdminBusiness, payload: [String: Any]) async -> String? {
        let (response, _) = await api.updateAdminBusiness(businessId: business.id, payload: payload)
        guard response.ok == true else {
            return response.message ?? response.errors?.joined(separator: " ") ?? "Biznesi nuk u perditesua."
        }
        await loadAdminWorkspace(force: true)
        showToast(response.message ?? "Biznesi u perditesua me sukses.")
        return nil
    }

    func updateAdminOrderStatus(_ order: TregoOrderItem, status: String, trackingCode: String = "", trackingURL: String = "") async -> String? {
        let response = await api.updateOrderStatus(
            orderItemId: order.id,
            status: status,
            trackingCode: trackingCode,
            trackingURL: trackingURL
        )
        guard response.ok == true else {
            return response.message ?? "Statusi i porosise nuk u perditesua."
        }
        await loadAdminWorkspace(force: true)
        showToast(response.message ?? "Statusi i porosise u perditesua.")
        return nil
    }

    func saveAdminLaunchAd(payload: [String: Any]) async -> String? {
        let (updatedLaunchAds, response) = await api.saveAdminLaunchAd(payload: payload)
        guard response.ok == true else {
            if api.usesLocalDevelopmentServer, response.message == "Lidhja me serverin deshtoi." {
                return "Lidhja me serverin deshtoi. Backend-i lokal nuk po pergjigjet te \(api.currentBaseURLString). Nise `python3 app.py` ose vendos `TregoDebugAPIBaseURL`."
            }
            return response.message ?? response.errors?.joined(separator: " ") ?? "Launch ad nuk u ruajt."
        }
        adminLaunchAds = updatedLaunchAds
        await loadLaunchAds()
        showToast(response.message ?? "Launch ad u ruajt.")
        return nil
    }

    func deleteAdminLaunchAd(_ launchAd: TregoLaunchAd) async -> String? {
        let (updatedLaunchAds, response) = await api.deleteAdminLaunchAd(id: launchAd.id)
        guard response.ok == true else {
            return response.message ?? "Launch ad nuk u fshi."
        }
        adminLaunchAds = updatedLaunchAds
        await loadLaunchAds()
        showToast(response.message ?? "Launch ad u fshi.")
        return nil
    }

    func deleteBusinessProduct(_ product: TregoProduct) async {
        let response = await api.deleteProduct(productId: product.id)
        if response.ok == true {
            await loadBusinessWorkspace(force: true)
            showToast(response.message ?? "Produkti u fshi.")
        } else {
            globalMessage = response.message ?? "Produkti nuk u fshi."
        }
    }

    func updateBusinessProductVisibility(_ product: TregoProduct, isPublic: Bool) async {
        let response = await api.updateProductPublicVisibility(productId: product.id, isPublic: isPublic).0
        if response.ok == true {
            await loadBusinessWorkspace(force: true)
            showToast(response.message ?? "Dukshmeria u perditesua.")
        } else {
            globalMessage = response.message ?? "Dukshmeria nuk u perditesua."
        }
    }

    func updateAppTheme(_ value: String) {
        appSettings.theme = value
        appSettings.persist()
    }

    func updateAppLanguage(_ value: String) {
        appSettings.language = value
        appSettings.persist()
    }

    func updateAppCurrency(_ value: String) {
        appSettings.currency = value
        appSettings.persist()
    }

    func updateAppNotificationMode(_ value: String) {
        appSettings.notificationMode = value
        appSettings.persist()
    }

    func updateAppPrivacyMode(_ value: String) {
        appSettings.privacyMode = value
        appSettings.persist()
    }

    private func personalizedScore(
        for product: TregoProduct,
        preferredCategories: [String],
        preferredBusinesses: [String]
    ) -> Int {
        var score = 0
        if let category = normalizedCategoryKey(for: product) {
            score += preferredCategories.filter { $0 == category }.count * 6
        }
        if let business = normalizedBusinessName(for: product) {
            score += preferredBusinesses.filter { $0 == business }.count * 4
        }
        if recentlyViewedProducts.contains(where: { $0.id == product.id }) {
            score += 2
        }
        if wishlist.contains(where: { $0.id == product.id }) {
            score += 3
        }
        return score
    }

    private func normalizedCategoryKey(for product: TregoProduct) -> String? {
        let rawCategory = (product.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !rawCategory.isEmpty else { return nil }
        return TregoNativeProductCatalog.section(for: rawCategory)
    }

    private func normalizedBusinessName(for product: TregoProduct) -> String? {
        let value = (product.businessName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private static func loadViewedHistory() -> [TregoViewedHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: viewedHistoryStorageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([TregoViewedHistoryEntry].self, from: data)) ?? []
    }

    private func persistViewedHistory() {
        let trimmed = Array(viewedHistory.prefix(30))
        viewedHistory = trimmed
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: Self.viewedHistoryStorageKey)
        }
    }

    func presentToast(_ message: String) {
        showToast(message)
    }

    private func badgeText(for count: Int) -> String {
        count > 99 ? "99+" : String(count)
    }

    private func showToast(_ message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        toastTask?.cancel()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            toastMessage = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                guard let self else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    self.toastMessage = nil
                }
            }
        }
    }
}
