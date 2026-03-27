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
    phone_number TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    address_line TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_business_profiles_user_id ON business_profiles(user_id);

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
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    image_path TEXT NOT NULL,
    image_gallery TEXT NOT NULL DEFAULT '[]',
    image_fingerprint TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL,
    product_type TEXT NOT NULL DEFAULT 'other',
    size TEXT NOT NULL DEFAULT '',
    color TEXT NOT NULL DEFAULT '',
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    is_public INTEGER NOT NULL DEFAULT 1,
    show_stock_public INTEGER NOT NULL DEFAULT 0,
    created_by_user_id BIGINT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_category_id ON products(is_public, category, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_public_creator_id ON products(is_public, created_by_user_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_products_title_lower ON products ((LOWER(title)));
CREATE INDEX IF NOT EXISTS idx_products_product_type ON products(product_type);
CREATE INDEX IF NOT EXISTS idx_products_public_image_fingerprint ON products(is_public, image_fingerprint);

CREATE TABLE IF NOT EXISTS wishlist_items (
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    PRIMARY KEY (user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_wishlist_user_created_at ON wishlist_items(user_id, created_at DESC);

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

CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    customer_full_name TEXT NOT NULL DEFAULT '',
    customer_email TEXT NOT NULL DEFAULT '',
    payment_method TEXT NOT NULL DEFAULT 'cash',
    status TEXT NOT NULL DEFAULT 'confirmed',
    address_line TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    phone_number TEXT NOT NULL,
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
    unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items(order_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_business_user_id
    ON order_items(business_user_id, created_at DESC);
