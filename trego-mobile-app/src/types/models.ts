export interface SessionUser {
  id: number;
  role: "client" | "business" | "admin" | "";
  fullName?: string;
  email?: string;
  profileImagePath?: string;
  businessName?: string;
  businessLogoPath?: string;
}

export interface AppPreferenceOption {
  value: string;
  label: string;
}

export interface ProductItem {
  id: number;
  articleNumber?: string;
  title: string;
  description?: string;
  imagePath?: string;
  imageGallery?: string[];
  price?: number;
  compareAtPrice?: number | null;
  saleEndsAt?: string;
  averageRating?: number;
  reviewCount?: number;
  buyersCount?: number;
  viewsCount?: number;
  wishlistCount?: number;
  cartCount?: number;
  shareCount?: number;
  stockQuantity?: number;
  category?: string;
  productType?: string;
  size?: string;
  color?: string;
  businessName?: string;
  variantInventory?: ProductVariant[];
  variantMode?: string;
  requiresVariantSelection?: boolean;
  availableSizes?: string[];
  availableColors?: string[];
  selectedSize?: string;
  selectedColor?: string;
  variantKey?: string;
  variantLabel?: string;
  packageAmountValue?: number;
  packageAmountUnit?: string;
  showStockPublic?: boolean;
  isPublic?: boolean;
  createdByUserId?: number;
  businessProfileId?: number;
  businessVerificationStatus?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface BusinessAnalytics {
  totalProducts?: number;
  publicProducts?: number;
  totalStock?: number;
  orderItems?: number;
  unitsSold?: number;
  grossSales?: number;
  sellerEarnings?: number;
  readyPayout?: number;
  pendingPayout?: number;
  reviewCount?: number;
  averageRating?: number;
  totalReturns?: number;
  openReturns?: number;
  activePromotions?: number;
  viewsCount?: number;
  wishlistCount?: number;
  cartCount?: number;
  shareCount?: number;
}

export interface ProductVariant {
  key?: string;
  label?: string;
  size?: string;
  color?: string;
  quantity?: number;
  price?: number;
  imagePath?: string;
}

export interface ProductReview {
  id: number;
  rating?: number;
  title?: string;
  body?: string;
  createdAt?: string;
  authorName?: string;
  photoPath?: string;
}

export interface BusinessItem {
  id: number;
  userId?: number;
  businessName: string;
  logoPath?: string;
  category?: string;
  description?: string;
  businessDescription?: string;
  city?: string;
  ownerName?: string;
  ownerEmail?: string;
  phoneNumber?: string;
  addressLine?: string;
  businessNumber?: string;
  verificationStatus?: string;
  profileEditAccessStatus?: string;
  ordersCount?: number;
  productsCount?: number;
  followersCount?: number;
  sellerRating?: number;
  sellerReviewCount?: number;
  isFollowed?: boolean;
  profileUrl?: string;
  updatedAt?: string;
  createdAt?: string;
}

export interface CartItem extends ProductItem {
  quantity?: number;
  productId?: number;
}

export interface OrderItem {
  id: number;
  status?: string;
  fulfillmentStatus?: string;
  totalAmount?: number;
  totalPrice?: number;
  subtotalAmount?: number;
  shippingAmount?: number;
  discountAmount?: number;
  createdAt?: string;
  confirmationDueAt?: string;
  confirmedAt?: string;
  packedAt?: string;
  shippedAt?: string;
  deliveredAt?: string;
  cancelledAt?: string;
  customerName?: string;
  customerEmail?: string;
  paymentMethod?: string;
  deliveryMethod?: string;
  deliveryLabel?: string;
  estimatedDeliveryText?: string;
  addressLine?: string;
  city?: string;
  country?: string;
  zipCode?: string;
  phoneNumber?: string;
  totalItems?: number;
  items?: CartItem[];
}

export interface ConversationItem {
  id: number;
  businessName?: string;
  clientName?: string;
  counterpartName?: string;
  counterpartRole?: string;
  counterpartImagePath?: string;
  counterpartIsOnline?: boolean;
  counterpartLastSeenAt?: string;
  lastMessagePreview?: string;
  messagesCount?: number;
  unreadCount?: number;
  createdAt?: string;
  updatedAt?: string;
  lastMessageAt?: string;
  counterpartTyping?: boolean;
}

export interface ChatMessage {
  id: number;
  conversationId: number;
  senderUserId: number;
  recipientUserId?: number;
  body?: string;
  attachmentPath?: string;
  attachmentContentType?: string;
  attachmentFileName?: string;
  createdAt?: string;
  editedAt?: string;
  deletedAt?: string;
  readAt?: string;
  senderName?: string;
  senderRole?: string;
  isOwn?: boolean;
}

export interface AdminUserItem {
  id: number;
  fullName?: string;
  email?: string;
  role?: string;
  city?: string;
  createdAt?: string;
  updatedAt?: string;
  ordersCount?: number;
}

export interface ReportItem {
  id: number;
  targetType?: string;
  targetId?: number;
  targetLabel?: string;
  reason?: string;
  details?: string;
  status?: string;
  adminNotes?: string;
  createdAt?: string;
  updatedAt?: string;
  reporterName?: string;
  reportedUserName?: string;
  businessName?: string;
}

export interface ReturnRequestItem {
  id: number;
  orderId?: number;
  orderItemId?: number;
  status?: string;
  reason?: string;
  details?: string;
  resolutionNotes?: string;
  createdAt?: string;
  updatedAt?: string;
  productTitle?: string;
  productImagePath?: string;
  fulfillmentStatus?: string;
  businessName?: string;
}

export interface PromotionItem {
  id?: number;
  code?: string;
  title?: string;
  description?: string;
  discountType?: string;
  discountValue?: number;
  minimumSubtotal?: number;
  usageLimit?: number;
  perUserLimit?: number;
  isActive?: boolean;
  pageSection?: string;
  category?: string;
  businessUserId?: number;
  startsAt?: string;
  endsAt?: string;
}
