CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
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
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

CREATE TABLE IF NOT EXISTS user_sessions (
    token TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id
    ON user_sessions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at
    ON user_sessions(expires_at);

CREATE TABLE IF NOT EXISTS email_verification_codes (
    user_id INTEGER PRIMARY KEY,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS password_reset_codes (
    user_id INTEGER PRIMARY KEY,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_addresses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    address_line TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_addresses_user_default
    ON user_addresses(user_id, is_default, updated_at DESC);

CREATE TABLE IF NOT EXISTS business_profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    business_name TEXT NOT NULL,
    business_description TEXT NOT NULL DEFAULT '',
    business_number TEXT NOT NULL DEFAULT '',
    business_logo_path TEXT NOT NULL DEFAULT '',
    phone_number TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    address_line TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_business_profiles_user_id ON business_profiles(user_id);

CREATE TABLE IF NOT EXISTS business_followers (
    business_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (business_id, user_id),
    FOREIGN KEY (business_id) REFERENCES business_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_business_followers_business
    ON business_followers(business_id, created_at DESC);

CREATE TABLE IF NOT EXISTS chat_conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_user_id INTEGER NOT NULL,
    business_user_id INTEGER NOT NULL,
    business_profile_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_message_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id INTEGER NOT NULL,
    sender_user_id INTEGER NOT NULL,
    recipient_user_id INTEGER NOT NULL,
    body TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
    ON chat_messages(conversation_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_recipient_read
    ON chat_messages(recipient_user_id, read_at, created_at DESC);

CREATE TABLE IF NOT EXISTS uploaded_assets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stored_name TEXT NOT NULL UNIQUE,
    original_filename TEXT NOT NULL DEFAULT '',
    content_type TEXT NOT NULL,
    file_bytes BLOB NOT NULL,
    created_by_user_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_uploaded_assets_created_at
    ON uploaded_assets(created_at DESC);

CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    article_number TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price REAL NOT NULL,
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
    package_amount_value REAL NOT NULL DEFAULT 0,
    package_amount_unit TEXT NOT NULL DEFAULT '',
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    is_public INTEGER NOT NULL DEFAULT 1,
    show_stock_public INTEGER NOT NULL DEFAULT 0,
    created_by_user_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_category_id ON products(is_public, category, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_creator_id ON products(is_public, created_by_user_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_title ON products(title);
CREATE INDEX IF NOT EXISTS idx_products_product_type ON products(product_type);

CREATE TABLE IF NOT EXISTS wishlist_items (
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_wishlist_user_created_at ON wishlist_items(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS cart_items (
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cart_user_updated_at ON cart_items(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS cart_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    variant_key TEXT NOT NULL DEFAULT 'default',
    variant_label TEXT NOT NULL DEFAULT 'Standard',
    selected_size TEXT NOT NULL DEFAULT '',
    selected_color TEXT NOT NULL DEFAULT '',
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cart_lines_user_product_variant
    ON cart_lines(user_id, product_id, variant_key);

CREATE INDEX IF NOT EXISTS idx_cart_lines_user_updated_at
    ON cart_lines(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    customer_full_name TEXT NOT NULL DEFAULT '',
    customer_email TEXT NOT NULL DEFAULT '',
    payment_method TEXT NOT NULL DEFAULT 'cash',
    status TEXT NOT NULL DEFAULT 'confirmed',
    address_line TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_user_created_at
    ON orders(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL,
    product_id INTEGER,
    business_user_id INTEGER,
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
    product_package_amount_value REAL NOT NULL DEFAULT 0,
    product_package_amount_unit TEXT NOT NULL DEFAULT '',
    unit_price REAL NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items(order_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_business_user_id
    ON order_items(business_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS stripe_payment_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stripe_session_id TEXT NOT NULL UNIQUE,
    user_id INTEGER NOT NULL,
    checkout_signature TEXT NOT NULL DEFAULT '',
    cart_line_ids TEXT NOT NULL DEFAULT '[]',
    checkout_address TEXT NOT NULL DEFAULT '{}',
    checkout_items_snapshot TEXT NOT NULL DEFAULT '[]',
    amount_total INTEGER NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'eur',
    payment_status TEXT NOT NULL DEFAULT '',
    stripe_status TEXT NOT NULL DEFAULT '',
    order_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_sessions_user_created
    ON stripe_payment_sessions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_sessions_order_id
    ON stripe_payment_sessions(order_id);
