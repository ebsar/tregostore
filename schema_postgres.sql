CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    birth_date TEXT NOT NULL DEFAULT '',
    gender TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'client',
    is_email_verified INTEGER NOT NULL DEFAULT 1,
    email_verified_at TEXT NOT NULL DEFAULT '',
    profile_image_path TEXT NOT NULL DEFAULT '',
    marketing_emails_opt_in INTEGER NOT NULL DEFAULT 0,
    terms_accepted_at TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text
);

CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

CREATE TABLE IF NOT EXISTS user_sessions (
    token TEXT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id
    ON user_sessions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at
    ON user_sessions(expires_at);

CREATE TABLE IF NOT EXISTS email_verification_codes (
    user_id BIGINT PRIMARY KEY,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS password_reset_codes (
    user_id BIGINT PRIMARY KEY,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS app_runtime_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text
);

CREATE TABLE IF NOT EXISTS user_addresses (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    address_line TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_addresses_user_default
    ON user_addresses(user_id, is_default, updated_at DESC);

CREATE TABLE IF NOT EXISTS business_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    business_name TEXT NOT NULL,
    business_description TEXT NOT NULL DEFAULT '',
    business_number TEXT NOT NULL DEFAULT '',
    business_logo_path TEXT NOT NULL DEFAULT '',
    support_email TEXT NOT NULL DEFAULT '',
    website_url TEXT NOT NULL DEFAULT '',
    support_hours TEXT NOT NULL DEFAULT '',
    return_policy_summary TEXT NOT NULL DEFAULT '',
    verification_status TEXT NOT NULL DEFAULT 'unverified',
    verification_requested_at TEXT NOT NULL DEFAULT '',
    verification_verified_at TEXT NOT NULL DEFAULT '',
    verification_notes TEXT NOT NULL DEFAULT '',
    profile_edit_access_status TEXT NOT NULL DEFAULT 'locked',
    profile_edit_requested_at TEXT NOT NULL DEFAULT '',
    profile_edit_approved_at TEXT NOT NULL DEFAULT '',
    profile_edit_notes TEXT NOT NULL DEFAULT '',
    shipping_settings TEXT NOT NULL DEFAULT '',
    auto_reply_enabled INTEGER NOT NULL DEFAULT 0,
    auto_reply_message TEXT NOT NULL DEFAULT '',
    phone_number TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    address_line TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_business_profiles_user_id ON business_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_business_profiles_name_lower ON business_profiles ((LOWER(business_name)));
CREATE INDEX IF NOT EXISTS idx_business_profiles_name_trgm
    ON business_profiles USING gin (LOWER(business_name) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_business_profiles_updated_at ON business_profiles(updated_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_business_profiles_business_number
    ON business_profiles ((LOWER(TRIM(business_number))))
    WHERE TRIM(business_number) <> '';

CREATE TABLE IF NOT EXISTS business_followers (
    business_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    PRIMARY KEY (business_id, user_id),
    FOREIGN KEY (business_id) REFERENCES business_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_business_followers_business
    ON business_followers(business_id, created_at DESC);

CREATE TABLE IF NOT EXISTS chat_conversations (
    id BIGSERIAL PRIMARY KEY,
    client_user_id BIGINT NOT NULL,
    business_user_id BIGINT NOT NULL,
    business_profile_id BIGINT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    last_message_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (client_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (business_profile_id) REFERENCES business_profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_conversations_client_business
    ON chat_conversations(client_user_id, business_user_id);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_client_last_message
    ON chat_conversations(client_user_id, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_business_last_message
    ON chat_conversations(business_user_id, last_message_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    sender_user_id BIGINT NOT NULL,
    recipient_user_id BIGINT NOT NULL,
    body TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    read_at TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
    ON chat_messages(conversation_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_recipient_read
    ON chat_messages(recipient_user_id, read_at, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id_desc
    ON chat_messages(conversation_id, id DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_unread_recipient
    ON chat_messages(recipient_user_id, conversation_id, id DESC)
    WHERE read_at IS NULL OR read_at = '';

CREATE TABLE IF NOT EXISTS uploaded_assets (
    id BIGSERIAL PRIMARY KEY,
    stored_name TEXT NOT NULL UNIQUE,
    original_filename TEXT NOT NULL DEFAULT '',
    content_type TEXT NOT NULL,
    file_bytes BYTEA NOT NULL,
    created_by_user_id BIGINT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_uploaded_assets_created_at
    ON uploaded_assets(created_at DESC);

CREATE TABLE IF NOT EXISTS products (
    id BIGSERIAL PRIMARY KEY,
    article_number TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL,
    normalized_title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL,
    brand TEXT NOT NULL DEFAULT '',
    gtin TEXT NOT NULL DEFAULT '',
    mpn TEXT NOT NULL DEFAULT '',
    material TEXT NOT NULL DEFAULT '',
    weight_value DOUBLE PRECISION NOT NULL DEFAULT 0,
    weight_unit TEXT NOT NULL DEFAULT '',
    meta_title TEXT NOT NULL DEFAULT '',
    meta_description TEXT NOT NULL DEFAULT '',
    price DOUBLE PRECISION NOT NULL,
    compare_at_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    sale_ends_at TEXT NOT NULL DEFAULT '',
    image_path TEXT NOT NULL,
    image_gallery TEXT NOT NULL DEFAULT '[]',
    image_fingerprint TEXT NOT NULL DEFAULT '',
    ai_image_search_text TEXT NOT NULL DEFAULT '',
    ai_image_color_terms TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL,
    product_type TEXT NOT NULL DEFAULT 'other',
    size TEXT NOT NULL DEFAULT '',
    color TEXT NOT NULL DEFAULT '',
    variant_inventory TEXT NOT NULL DEFAULT '[]',
    package_amount_value DOUBLE PRECISION NOT NULL DEFAULT 0,
    package_amount_unit TEXT NOT NULL DEFAULT '',
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    is_public INTEGER NOT NULL DEFAULT 1,
    show_stock_public INTEGER NOT NULL DEFAULT 0,
    group_key TEXT NOT NULL DEFAULT '',
    source_id BIGINT NOT NULL DEFAULT 0,
    source_product_key TEXT NOT NULL DEFAULT '',
    import_metadata TEXT NOT NULL DEFAULT '{}',
    created_by_user_id BIGINT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_category_id ON products(is_public, category, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_stock_id ON products(is_public, stock_quantity, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_creator_id ON products(is_public, created_by_user_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_created_at ON products(is_public, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_title_lower ON products ((LOWER(title)));
CREATE INDEX IF NOT EXISTS idx_products_product_type ON products(product_type);
CREATE INDEX IF NOT EXISTS idx_products_public_category_created
    ON products(category, created_at DESC, id DESC)
    WHERE is_public = 1 AND stock_quantity > 0;
CREATE INDEX IF NOT EXISTS idx_products_public_type_created
    ON products(product_type, created_at DESC, id DESC)
    WHERE is_public = 1 AND stock_quantity > 0;
CREATE INDEX IF NOT EXISTS idx_products_public_price
    ON products(price, id DESC)
    WHERE is_public = 1 AND stock_quantity > 0;
CREATE INDEX IF NOT EXISTS idx_products_title_trgm
    ON products USING gin (LOWER(title) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_description_trgm
    ON products USING gin (LOWER(description) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_ai_search_trgm
    ON products USING gin (LOWER(ai_image_search_text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_brand_trgm
    ON products USING gin (LOWER(COALESCE(brand, '')) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_import_source_group ON products(created_by_user_id, source_id, group_key);
CREATE INDEX IF NOT EXISTS idx_products_import_source_product_key ON products(created_by_user_id, source_id, source_product_key);

CREATE TABLE IF NOT EXISTS catalog_import_profiles (
    id BIGSERIAL PRIMARY KEY,
    business_user_id BIGINT NOT NULL,
    profile_name TEXT NOT NULL DEFAULT '',
    source_type TEXT NOT NULL DEFAULT 'csv',
    field_mapping TEXT NOT NULL DEFAULT '{}',
    category_mapping_rules TEXT NOT NULL DEFAULT '{}',
    attribute_mapping_rules TEXT NOT NULL DEFAULT '{}',
    normalization_rules TEXT NOT NULL DEFAULT '{}',
    ai_preferences TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_catalog_import_profiles_business_updated
    ON catalog_import_profiles(business_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS catalog_import_sources (
    id BIGSERIAL PRIMARY KEY,
    business_user_id BIGINT NOT NULL,
    profile_id BIGINT,
    source_name TEXT NOT NULL DEFAULT '',
    source_type TEXT NOT NULL DEFAULT 'api-json',
    source_config TEXT NOT NULL DEFAULT '{}',
    sync_enabled INTEGER NOT NULL DEFAULT 0,
    sync_interval_minutes INTEGER NOT NULL DEFAULT 0,
    last_synced_at TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (profile_id) REFERENCES catalog_import_profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_catalog_import_sources_business_updated
    ON catalog_import_sources(business_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS catalog_import_jobs (
    id BIGSERIAL PRIMARY KEY,
    business_user_id BIGINT NOT NULL,
    source_id BIGINT,
    profile_id BIGINT,
    source_type TEXT NOT NULL DEFAULT 'csv',
    adapter_kind TEXT NOT NULL DEFAULT 'csv',
    original_filename TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'preview_ready',
    source_digest TEXT NOT NULL DEFAULT '',
    headers_json TEXT NOT NULL DEFAULT '[]',
    field_mapping_json TEXT NOT NULL DEFAULT '{}',
    category_mapping_rules_json TEXT NOT NULL DEFAULT '{}',
    ai_suggestions_json TEXT NOT NULL DEFAULT '{}',
    summary_json TEXT NOT NULL DEFAULT '{}',
    preview_payload_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    committed_at TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES catalog_import_sources(id) ON DELETE SET NULL,
    FOREIGN KEY (profile_id) REFERENCES catalog_import_profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_catalog_import_jobs_business_updated
    ON catalog_import_jobs(business_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS catalog_import_job_records (
    id BIGSERIAL PRIMARY KEY,
    job_id BIGINT NOT NULL,
    source_row_id TEXT NOT NULL DEFAULT '',
    row_index INTEGER NOT NULL DEFAULT 0,
    raw_data_json TEXT NOT NULL DEFAULT '{}',
    mapped_data_json TEXT NOT NULL DEFAULT '{}',
    normalized_data_json TEXT NOT NULL DEFAULT '{}',
    parent_data_json TEXT NOT NULL DEFAULT '{}',
    variant_data_json TEXT NOT NULL DEFAULT '{}',
    warnings_json TEXT NOT NULL DEFAULT '[]',
    errors_json TEXT NOT NULL DEFAULT '[]',
    group_key TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (job_id) REFERENCES catalog_import_jobs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_catalog_import_job_records_job_row
    ON catalog_import_job_records(job_id, row_index ASC);
CREATE INDEX IF NOT EXISTS idx_catalog_import_job_records_job_group
    ON catalog_import_job_records(job_id, group_key);

CREATE TABLE IF NOT EXISTS wishlist_items (
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    PRIMARY KEY (user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_wishlist_user_created_at ON wishlist_items(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wishlist_items_product_id ON wishlist_items(product_id);

CREATE TABLE IF NOT EXISTS cart_items (
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    PRIMARY KEY (user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cart_user_updated_at ON cart_items(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS cart_lines (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    variant_key TEXT NOT NULL DEFAULT 'default',
    variant_label TEXT NOT NULL DEFAULT 'Standard',
    selected_size TEXT NOT NULL DEFAULT '',
    selected_color TEXT NOT NULL DEFAULT '',
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cart_lines_user_product_variant
    ON cart_lines(user_id, product_id, variant_key);

CREATE INDEX IF NOT EXISTS idx_cart_lines_user_updated_at
    ON cart_lines(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS guest_cart_lines (
    id BIGSERIAL PRIMARY KEY,
    visitor_token TEXT NOT NULL,
    product_id BIGINT NOT NULL,
    variant_key TEXT NOT NULL DEFAULT 'default',
    variant_label TEXT NOT NULL DEFAULT 'Standard',
    selected_size TEXT NOT NULL DEFAULT '',
    selected_color TEXT NOT NULL DEFAULT '',
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_guest_cart_lines_visitor_product_variant
    ON guest_cart_lines(visitor_token, product_id, variant_key);

CREATE INDEX IF NOT EXISTS idx_guest_cart_lines_visitor_updated_at
    ON guest_cart_lines(visitor_token, updated_at DESC);

CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    customer_full_name TEXT NOT NULL DEFAULT '',
    customer_email TEXT NOT NULL DEFAULT '',
    payment_method TEXT NOT NULL DEFAULT 'cash',
    status TEXT NOT NULL DEFAULT 'pending_confirmation',
    address_line TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    subtotal_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    discount_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    shipping_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    promo_code TEXT NOT NULL DEFAULT '',
    delivery_method TEXT NOT NULL DEFAULT 'standard',
    delivery_label TEXT NOT NULL DEFAULT 'Dergese standard',
    estimated_delivery_text TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_user_created_at
    ON orders(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT,
    business_user_id BIGINT,
    business_name_snapshot TEXT NOT NULL DEFAULT '',
    product_title TEXT NOT NULL,
    product_description TEXT NOT NULL DEFAULT '',
    product_image_path TEXT NOT NULL DEFAULT '',
    product_category TEXT NOT NULL DEFAULT '',
    product_type TEXT NOT NULL DEFAULT '',
    product_size TEXT NOT NULL DEFAULT '',
    product_color TEXT NOT NULL DEFAULT '',
    product_variant_key TEXT NOT NULL DEFAULT '',
    product_variant_label TEXT NOT NULL DEFAULT '',
    product_variant_snapshot TEXT NOT NULL DEFAULT '[]',
    product_package_amount_value DOUBLE PRECISION NOT NULL DEFAULT 0,
    product_package_amount_unit TEXT NOT NULL DEFAULT '',
    unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1,
    fulfillment_status TEXT NOT NULL DEFAULT 'pending_confirmation',
    confirmed_at TEXT NOT NULL DEFAULT '',
    confirmation_due_at TEXT NOT NULL DEFAULT '',
    tracking_code TEXT NOT NULL DEFAULT '',
    tracking_url TEXT NOT NULL DEFAULT '',
    shipped_at TEXT NOT NULL DEFAULT '',
    delivered_at TEXT NOT NULL DEFAULT '',
    cancelled_at TEXT NOT NULL DEFAULT '',
    commission_rate DOUBLE PRECISION NOT NULL DEFAULT 0,
    commission_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    seller_earnings_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    payout_status TEXT NOT NULL DEFAULT 'pending',
    payout_due_at TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items(order_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON order_items(product_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_business_user_id
    ON order_items(business_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_fulfillment_status
    ON order_items(fulfillment_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_product_category_created
    ON order_items(product_category, created_at DESC);

CREATE TABLE IF NOT EXISTS product_engagements (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL,
    business_user_id BIGINT NOT NULL,
    event_type TEXT NOT NULL,
    actor_key TEXT NOT NULL,
    user_id BIGINT,
    visitor_token TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_product_engagements_actor_unique
    ON product_engagements(product_id, event_type, actor_key);

CREATE INDEX IF NOT EXISTS idx_product_engagements_product_event
    ON product_engagements(product_id, event_type, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_engagements_business_event
    ON product_engagements(business_user_id, event_type, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_engagements_user_event_updated
    ON product_engagements(user_id, event_type, updated_at DESC);

CREATE TABLE IF NOT EXISTS product_reviews (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    order_item_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    business_user_id BIGINT,
    rating INTEGER NOT NULL,
    review_title TEXT NOT NULL DEFAULT '',
    review_body TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'published',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_product_reviews_order_item_user
    ON product_reviews(order_item_id, user_id);

CREATE INDEX IF NOT EXISTS idx_product_reviews_product_created
    ON product_reviews(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_status_created
    ON product_reviews(product_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_reviews_business_created
    ON product_reviews(business_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS return_requests (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    order_item_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    business_user_id BIGINT,
    reason TEXT NOT NULL DEFAULT '',
    details TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'requested',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    resolved_at TEXT NOT NULL DEFAULT '',
    resolution_notes TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_return_requests_user_created
    ON return_requests(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_return_requests_business_created
    ON return_requests(business_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_return_requests_status_created
    ON return_requests(status, created_at DESC);

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    type TEXT NOT NULL DEFAULT 'info',
    title TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    href TEXT NOT NULL DEFAULT '',
    metadata TEXT NOT NULL DEFAULT '{}',
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    read_at TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read
    ON notifications(user_id, is_read, created_at DESC);

CREATE TABLE IF NOT EXISTS reports (
    id BIGSERIAL PRIMARY KEY,
    reporter_user_id BIGINT NOT NULL,
    reported_user_id BIGINT,
    business_user_id BIGINT,
    target_type TEXT NOT NULL DEFAULT 'product',
    target_id BIGINT NOT NULL DEFAULT 0,
    target_label TEXT NOT NULL DEFAULT '',
    reason TEXT NOT NULL DEFAULT '',
    details TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'open',
    admin_notes TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    resolved_at TEXT NOT NULL DEFAULT '',
    resolved_by_user_id BIGINT,
    FOREIGN KEY (reporter_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reported_user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_reports_status_created
    ON reports(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
    ON reports(reporter_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS promo_codes (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    discount_type TEXT NOT NULL DEFAULT 'percent',
    discount_value DOUBLE PRECISION NOT NULL DEFAULT 0,
    minimum_subtotal DOUBLE PRECISION NOT NULL DEFAULT 0,
    usage_limit INTEGER NOT NULL DEFAULT 0,
    per_user_limit INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1,
    page_section TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT '',
    business_user_id BIGINT,
    created_by_user_id BIGINT,
    starts_at TEXT NOT NULL DEFAULT '',
    ends_at TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_promo_codes_active_code
    ON promo_codes(is_active, code);

CREATE INDEX IF NOT EXISTS idx_promo_codes_business_created
    ON promo_codes(business_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS launch_ads (
    id BIGSERIAL PRIMARY KEY,
    badge TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '',
    subtitle TEXT NOT NULL DEFAULT '',
    image_path TEXT NOT NULL DEFAULT '',
    cta_label TEXT NOT NULL DEFAULT 'Shop now',
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    starts_at TEXT NOT NULL DEFAULT '',
    ends_at TEXT NOT NULL DEFAULT '',
    created_by_user_id BIGINT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_launch_ads_active_sort
    ON launch_ads(is_active, sort_order, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_launch_ads_schedule
    ON launch_ads(starts_at, ends_at);

CREATE TABLE IF NOT EXISTS stock_reservations (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    cart_line_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    variant_key TEXT NOT NULL DEFAULT '',
    quantity INTEGER NOT NULL DEFAULT 1,
    expires_at TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (cart_line_id) REFERENCES cart_lines(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_reservations_cart_line
    ON stock_reservations(cart_line_id);

CREATE INDEX IF NOT EXISTS idx_stock_reservations_variant_expiry
    ON stock_reservations(product_id, variant_key, expires_at);

CREATE TABLE IF NOT EXISTS stripe_payment_sessions (
    id BIGSERIAL PRIMARY KEY,
    stripe_session_id TEXT NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    checkout_signature TEXT NOT NULL DEFAULT '',
    cart_line_ids TEXT NOT NULL DEFAULT '[]',
    checkout_address TEXT NOT NULL DEFAULT '{}',
    checkout_items_snapshot TEXT NOT NULL DEFAULT '[]',
    amount_total INTEGER NOT NULL DEFAULT 0,
    discount_amount INTEGER NOT NULL DEFAULT 0,
    shipping_amount INTEGER NOT NULL DEFAULT 0,
    promo_code TEXT NOT NULL DEFAULT '',
    delivery_method TEXT NOT NULL DEFAULT 'standard',
    delivery_label TEXT NOT NULL DEFAULT 'Dergese standard',
    estimated_delivery_text TEXT NOT NULL DEFAULT '',
    currency TEXT NOT NULL DEFAULT 'eur',
    payment_status TEXT NOT NULL DEFAULT '',
    stripe_status TEXT NOT NULL DEFAULT '',
    order_id BIGINT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    confirmed_at TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_sessions_user_created
    ON stripe_payment_sessions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_sessions_order_id
    ON stripe_payment_sessions(order_id);
