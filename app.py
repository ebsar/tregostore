import argparse
import base64
import csv
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from email.parser import BytesParser
from email.policy import default
import hashlib
from io import BytesIO, StringIO
import html
import json
import mimetypes
import math
import os
import re
import secrets
import sqlite3
import threading
import textwrap
import time
import unicodedata
from http.cookies import CookieError, SimpleCookie
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from xml.etree import ElementTree as ET
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, quote, urlencode, urlparse
from urllib.request import Request, urlopen
import zipfile

try:
    from PIL import Image, ImageOps, UnidentifiedImageError

    PILLOW_AVAILABLE = True
except ImportError:
    Image = None
    ImageOps = None
    UnidentifiedImageError = OSError
    PILLOW_AVAILABLE = False


BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
IS_VERCEL = bool(str(os.environ.get("VERCEL", "")).strip())
RUNTIME_ROOT_DIR = Path("/tmp/trego-runtime") if IS_VERCEL else BASE_DIR
UPLOADS_DIR = RUNTIME_ROOT_DIR / "uploads" if IS_VERCEL else STATIC_DIR / "uploads"
DATA_DIR = RUNTIME_ROOT_DIR / "data" if IS_VERCEL else BASE_DIR / "data"
DB_PATH = DATA_DIR / "accounts.db"
SCHEMA_PATH = BASE_DIR / "schema.sql"
POSTGRES_SCHEMA_PATH = BASE_DIR / "schema_postgres.sql"
PRODUCT_CATALOG_PATH = BASE_DIR / "src" / "data" / "product-catalog.json"
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
OPENAI_API_KEY = str(os.environ.get("OPENAI_API_KEY", "")).strip()
OPENAI_SEARCH_MODEL = str(os.environ.get("OPENAI_SEARCH_MODEL", "")).strip() or "gpt-5-mini"
OPENAI_CHAT_MODEL = str(os.environ.get("OPENAI_CHAT_MODEL", "")).strip() or "gpt-5-mini"
OPENAI_PRODUCT_DRAFT_MODEL = (
    str(os.environ.get("OPENAI_PRODUCT_DRAFT_MODEL", "")).strip() or "gpt-5-mini"
)
OPENAI_PRODUCT_IMAGE_MODEL = (
    str(os.environ.get("OPENAI_PRODUCT_IMAGE_MODEL", "")).strip() or "gpt-4.1-mini"
)
OPENAI_RESPONSES_API_URL = "https://api.openai.com/v1/responses"
OPENAI_SEARCH_TIMEOUT_SECONDS = 8
OPENAI_CHAT_TIMEOUT_SECONDS = 10
OPENAI_PRODUCT_DRAFT_TIMEOUT_SECONDS = 12
OPENAI_PRODUCT_IMAGE_TIMEOUT_SECONDS = 12
STRIPE_SECRET_KEY = str(os.environ.get("STRIPE_SECRET_KEY", "")).strip()
STRIPE_PUBLIC_APP_URL = str(os.environ.get("TREGO_PUBLIC_APP_URL", "")).strip().rstrip("/")
STRIPE_API_BASE_URL = "https://api.stripe.com/v1"
STRIPE_TIMEOUT_SECONDS = 15
STRIPE_CURRENCY = str(os.environ.get("STRIPE_CURRENCY", "eur")).strip().lower() or "eur"
BREVO_API_KEY = str(os.environ.get("BREVO_API_KEY", "")).strip()
BREVO_SENDER_EMAIL = str(os.environ.get("BREVO_SENDER_EMAIL", "")).strip()
BREVO_SENDER_NAME = str(os.environ.get("BREVO_SENDER_NAME", "TREGO")).strip()
BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"
CRON_SECRET = str(os.environ.get("CRON_SECRET") or os.environ.get("TREGO_CRON_SECRET") or "").strip()
SEARCH_INTENT_CACHE_TTL_SECONDS = 10 * 60
SEARCH_INTENT_CACHE: dict[str, tuple[float, dict[str, object]]] = {}
PRODUCT_IMAGE_METADATA_CACHE_TTL_SECONDS = 6 * 60 * 60
PRODUCT_IMAGE_METADATA_CACHE: dict[str, tuple[float, dict[str, object]]] = {}
PUBLIC_FACETS_CACHE_TTL_SECONDS = 30
PUBLIC_PRODUCTS_ENDPOINT_CACHE_TTL_SECONDS = 15
PUBLIC_BUSINESSES_ENDPOINT_CACHE_TTL_SECONDS = 45
PUBLIC_DETAIL_ENDPOINT_CACHE_TTL_SECONDS = 20
RUNTIME_PUBLIC_CACHE: dict[str, tuple[float, object]] = {}
RUNTIME_PUBLIC_CACHE_LOCK = threading.Lock()
SESSION_COOKIE_NAME = "session_token"
SESSION_MAX_AGE_SECONDS = 86400
PRODUCTS_PAGE_DEFAULT_LIMIT = 12
PRODUCTS_PAGE_MAX_LIMIT = 24
PAGE_ROUTES = {
    "/": "/index.html",
    "/about": "/about.html",
    "/kerko": "/search.html",
    "/profili-biznesit": "/business-profile-public.html",
    "/mesazhet": "/messages.html",
    "/njoftimet": "/account.html",
    "/login": "/login.html",
    "/forgot-password": "/forgot-password.html",
    "/signup": "/signup.html",
    "/verifiko-email": "/verify-email.html",
    "/biznesi-juaj": "/index.html",
    "/llogaria": "/account.html",
    "/te-dhenat-personale": "/personal-data.html",
    "/adresat": "/addresses.html",
    "/porosite": "/orders.html",
    "/porosite-e-biznesit": "/business-orders.html",
    "/ndrysho-fjalekalimin": "/change-password.html",
    "/produkti": "/product-detail.html",
    "/wishlist": "/wishlist.html",
    "/cart": "/cart.html",
    "/adresa-e-porosise": "/checkout-address.html",
    "/menyra-e-pageses": "/payment-options.html",
    "/kafshet-shtepiake": "/pets.html",
    "/admin-products": "/index.html",
    "/bizneset-e-regjistruara": "/registered-businesses.html",
}


def load_product_catalog() -> dict[str, object]:
    try:
        return json.loads(PRODUCT_CATALOG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {
            "sections": [],
            "productTypes": {},
            "colorOptions": [],
            "clothingSizes": ["XS", "S", "M", "L", "XL", "XXL", "XXXL"],
            "amountUnits": [{"value": "ml", "label": "ml"}, {"value": "l", "label": "L"}],
        }


PRODUCT_CATALOG = load_product_catalog()
PRODUCT_SECTION_DEFINITIONS = list(PRODUCT_CATALOG.get("sections") or [])
PRODUCT_TYPE_OPTIONS_BY_CATEGORY = dict(PRODUCT_CATALOG.get("productTypes") or {})
PRODUCT_COLOR_DEFINITIONS = list(PRODUCT_CATALOG.get("colorOptions") or [])
PRODUCT_AMOUNT_UNIT_DEFINITIONS = list(PRODUCT_CATALOG.get("amountUnits") or [])
PRODUCT_CATEGORY_LABELS: dict[str, str] = {}
PRODUCT_TYPE_LABELS: dict[str, str] = {}
PRODUCT_COLOR_LABELS: dict[str, str] = {}
SECTION_AUDIENCE_CATEGORY_MAP: dict[str, dict[str, str]] = {}
CATEGORY_SECTION_MAP: dict[str, str] = {}
CATEGORY_AUDIENCE_MAP: dict[str, str] = {}

for color_option in PRODUCT_COLOR_DEFINITIONS:
    color_value = str(color_option.get("value") or "").strip().lower()
    if color_value:
        PRODUCT_COLOR_LABELS[color_value] = str(color_option.get("label") or color_value).strip()

for section_definition in PRODUCT_SECTION_DEFINITIONS:
    section_value = str(section_definition.get("value") or "").strip().lower()
    if not section_value:
        continue

    PRODUCT_CATEGORY_LABELS[section_value] = str(
        section_definition.get("label") or section_value
    ).strip()
    SECTION_AUDIENCE_CATEGORY_MAP[section_value] = {}

    for audience_definition in list(section_definition.get("audiences") or []):
        audience_value = str(audience_definition.get("value") or "").strip().lower()
        category_value = str(audience_definition.get("category") or "").strip().lower()
        audience_label = str(
            audience_definition.get("label") or category_value or audience_value
        ).strip()
        if not audience_value or not category_value:
            continue

        SECTION_AUDIENCE_CATEGORY_MAP[section_value][audience_value] = category_value
        PRODUCT_CATEGORY_LABELS[category_value] = audience_label
        CATEGORY_SECTION_MAP[category_value] = section_value
        CATEGORY_AUDIENCE_MAP[category_value] = audience_value

    if section_value not in CATEGORY_SECTION_MAP:
        CATEGORY_SECTION_MAP[section_value] = section_value
        CATEGORY_AUDIENCE_MAP[section_value] = ""

for category_value, product_type_options in PRODUCT_TYPE_OPTIONS_BY_CATEGORY.items():
    normalized_category = str(category_value or "").strip().lower()
    for option in list(product_type_options or []):
        product_type_value = str(option.get("value") or "").strip().lower()
        if not product_type_value:
            continue
        PRODUCT_TYPE_LABELS[product_type_value] = str(
            option.get("label") or product_type_value
        ).strip()
        if normalized_category and normalized_category not in CATEGORY_SECTION_MAP:
            CATEGORY_SECTION_MAP[normalized_category] = normalized_category
            CATEGORY_AUDIENCE_MAP[normalized_category] = ""

LEGACY_PRODUCT_CATEGORIES = {"pets", "agriculture", "medicine", "cosmetics-kids"}
SHOP_SECTION_PRODUCT_TYPES = {
    str(category or "").strip().lower(): {
        str(option.get("value") or "").strip().lower()
        for option in list(product_type_options or [])
        if str(option.get("value") or "").strip()
    }
    for category, product_type_options in PRODUCT_TYPE_OPTIONS_BY_CATEGORY.items()
}
LEGACY_PRODUCT_TYPES = {"clothing", "cream", "food", "tools", "other"}
PRODUCT_CATEGORIES = LEGACY_PRODUCT_CATEGORIES | set(SHOP_SECTION_PRODUCT_TYPES.keys())
PRODUCT_TYPES = LEGACY_PRODUCT_TYPES | {
    product_type
    for product_types in SHOP_SECTION_PRODUCT_TYPES.values()
    for product_type in product_types
}
CLOTHING_SIZES = {
    str(size or "").strip().upper()
    for size in list(PRODUCT_CATALOG.get("clothingSizes") or [])
    if str(size or "").strip()
}
CLOTHING_SIZE_ORDER = {
    str(size or "").strip().upper(): index
    for index, size in enumerate(list(PRODUCT_CATALOG.get("clothingSizes") or []))
    if str(size or "").strip()
}
PRODUCT_COLORS = set(PRODUCT_COLOR_LABELS.keys())
PRODUCT_AMOUNT_UNITS = {
    str(option.get("value") or "").strip().lower()
    for option in PRODUCT_AMOUNT_UNIT_DEFINITIONS
    if str(option.get("value") or "").strip()
}
SEARCH_INTENT_MARKERS = {
    "dua",
    "doja",
    "kerkoj",
    "kerko",
    "trego",
    "shfaq",
    "gjej",
}
SEARCH_INTENT_CATEGORY_KEYWORDS = {
    "clothing": {"veshje", "rroba", "maic", "pantallon", "duks", "jakn", "rollke"},
    "cosmetics": {"kozmetik", "parfum", "higjien", "krem", "makup", "thonj", "floke"},
    "sport": {"sport", "patika", "atlete", "fitnes", "stervit", "sportive"},
    "technology": {"telefon", "iphone", "android", "adapter", "degjues", "kufje", "teknologj"},
    "home": {"shtepi", "dhome", "banjo", "dekor", "gjum"},
}
SEARCH_INTENT_PRODUCT_TYPE_KEYWORDS = {
    "tshirt": {"maic", "bluz", "t-shirt"},
    "undershirt": {"maic e brendshme"},
    "pants": {"pantallon", "xhinse", "jeans", "trenerk"},
    "hoodie": {"duks", "hoodie"},
    "turtleneck": {"rollke"},
    "jacket": {"jakn"},
    "underwear": {"te brendshme", "breke"},
    "pajamas": {"pixham"},
    "perfumes": {"parfum"},
    "hygiene": {"higjien", "sapun", "shampon"},
    "creams": {"krem"},
    "makeup": {"makup", "makeup"},
    "nails": {"thonj"},
    "hair-colors": {"ngjyre flokesh", "boj flokesh"},
    "kids-care": {"kujdes per femije"},
    "room-decor": {"dekor", "dekorim"},
    "bathroom-items": {"banjo"},
    "bedroom-items": {"dhome gjumi", "gjum"},
    "kids-room-items": {"dhoma femij"},
    "sports-equipment": {"pajisje sportive"},
    "sportswear": {"veshje sportive", "patika", "atlete"},
    "sports-accessories": {"aksesor sportiv"},
    "phone-cases": {"case", "maske telefoni", "mbrojtese telefoni"},
    "headphones": {"degjues", "kufje", "headphones"},
    "phone-parts": {"pjese telefoni"},
    "phone-accessories": {"aksesor telefoni"},
}
USER_ROLES = {"client", "admin", "business"}
CHAT_PARTICIPANT_ROLES = {"client", "business", "admin"}
CHAT_MESSAGE_MAX_LENGTH = 1500
GENDER_OPTIONS = {"mashkull", "femer"}
PAYMENT_METHODS = {"cash", "card-online"}
DELIVERY_METHODS = {
    "standard": {
        "label": "Dergese standard",
        "shipping_amount": 2.5,
        "estimated_delivery_text": "2-4 dite pune",
    },
    "express": {
        "label": "Dergese express",
        "shipping_amount": 4.9,
        "estimated_delivery_text": "1-2 dite pune",
    },
    "pickup": {
        "label": "Terheqje ne biznes",
        "shipping_amount": 0.0,
        "estimated_delivery_text": "Gati per terheqje brenda 24 oresh",
    },
}
DEFAULT_BUSINESS_SHIPPING_SETTINGS = {
    "standardEnabled": True,
    "standardFee": round(float(DELIVERY_METHODS["standard"]["shipping_amount"]), 2),
    "standardEta": str(DELIVERY_METHODS["standard"]["estimated_delivery_text"]),
    "expressEnabled": True,
    "expressFee": round(float(DELIVERY_METHODS["express"]["shipping_amount"]), 2),
    "expressEta": str(DELIVERY_METHODS["express"]["estimated_delivery_text"]),
    "pickupEnabled": True,
    "pickupEta": str(DELIVERY_METHODS["pickup"]["estimated_delivery_text"]),
    "pickupAddress": "",
    "pickupHours": "Kontakto biznesin per orarin",
    "pickupMapUrl": "",
    "cityRates": [],
    "halfOffThreshold": 120.0,
    "freeShippingThreshold": 180.0,
}
DELIVERY_CITY_ZONE_RULES = [
    {
        "key": "urban",
        "label": "Qytet kryesor",
        "cities": {
            "prishtine",
            "prishtina",
            "prizren",
            "peje",
            "gjakove",
            "mitrovice",
            "ferizaj",
            "gjilan",
        },
        "surcharge": 0.0,
    },
    {
        "key": "regional",
        "label": "Qytet rajonal",
        "cities": {
            "podujeve",
            "vushtrri",
            "rahovec",
            "suhareke",
            "fushe kosove",
            "lipjan",
            "drenas",
            "istog",
            "kline",
            "decan",
            "kamenice",
            "malsheve",
            "malisheve",
        },
        "surcharge": 0.9,
    },
]
SHIPPING_DISCOUNT_THRESHOLDS = {
    "half_off": 120.0,
    "free": 180.0,
}
ORDER_ITEM_FULFILLMENT_STATUSES = {
    "pending_confirmation",
    "confirmed",
    "packed",
    "shipped",
    "delivered",
    "cancelled",
    "returned",
}
ORDER_BUSINESS_CONFIRMATION_TIMEOUT_DAYS = 3
RETURN_REQUEST_STATUSES = {"requested", "approved", "rejected", "received", "refunded"}
BUSINESS_VERIFICATION_STATUSES = {"unverified", "pending", "verified", "rejected"}
BUSINESS_PROFILE_EDIT_ACCESS_STATUSES = {"locked", "pending", "approved"}
REPORT_TARGET_TYPES = {"product", "business", "user", "message"}
REPORT_STATUSES = {"open", "reviewing", "resolved", "dismissed"}
PROMO_CODE_TYPES = {"percent", "fixed"}
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"}
CHAT_ATTACHMENT_MAX_FILE_SIZE = 16 * 1024 * 1024
CHAT_UNREAD_REMINDER_AFTER_HOURS = 2
CHAT_UNREAD_REMINDER_BATCH_LIMIT = 100
NOTIFICATIONS_PAGE_LIMIT = 50
PAYOUT_HOLD_DAYS = 14
STOCK_RESERVATION_HOLD_MINUTES = 15
PROMO_CODE_DEFAULT_PER_USER_LIMIT = 1
CHAT_ATTACHMENT_ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "image/avif": ".avif",
    "application/pdf": ".pdf",
    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",
    "audio/webm": ".webm",
    "audio/mp4": ".m4a",
    "audio/mpeg": ".mp3",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/ogg": ".ogg",
}
IMAGE_CONTENT_TYPE_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "image/avif": ".avif",
}
EXTENSION_CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".avif": "image/avif",
    ".pdf": "application/pdf",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mov": "video/quicktime",
    ".m4a": "audio/mp4",
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".ogg": "audio/ogg",
}
MAX_UPLOAD_FILES = 8
MAX_UPLOAD_FILE_SIZE = 8 * 1024 * 1024
MAX_UPLOAD_REQUEST_SIZE = MAX_UPLOAD_FILES * MAX_UPLOAD_FILE_SIZE + (1024 * 1024)
PRODUCT_IMPORT_MAX_ROWS = 100
PRODUCT_IMPORT_FIELDNAMES = [
    "articleNumber",
    "title",
    "description",
    "price",
    "pageSection",
    "audience",
    "category",
    "productType",
    "size",
    "color",
    "packageAmountValue",
    "packageAmountUnit",
    "stockQuantity",
    "imagePath",
    "imageGallery",
]
VISUAL_SEARCH_HASH_SIZE = 8
EMAIL_VERIFICATION_CODE_LENGTH = 6
EMAIL_VERIFICATION_TTL_MINUTES = 30
EMAIL_VERIFICATION_MAX_ATTEMPTS = 5
PASSWORD_RESET_CODE_LENGTH = 6
PASSWORD_RESET_TTL_MINUTES = 30
PASSWORD_RESET_MAX_ATTEMPTS = 5
APP_SCHEMA_VERSION = "2026-03-30-marketplace-6"
PUBLIC_PRODUCTS_CACHE_HEADERS = {
    "Cache-Control": "public, max-age=20, s-maxage=60, stale-while-revalidate=120"
}
PUBLIC_BUSINESSES_CACHE_HEADERS = {
    "Cache-Control": "public, max-age=60, s-maxage=180, stale-while-revalidate=300"
}
PUBLIC_STATS_CACHE_HEADERS = {
    "Cache-Control": "public, max-age=30, s-maxage=90, stale-while-revalidate=180"
}


def build_runtime_public_cache_key(prefix: str, payload: object) -> str:
    serialized_payload = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    digest = hashlib.sha1(f"{prefix}:{serialized_payload}".encode("utf-8")).hexdigest()
    return f"{prefix}:{digest}"


def read_runtime_public_cache(key: str) -> object | None:
    now_timestamp = time.time()
    with RUNTIME_PUBLIC_CACHE_LOCK:
        cached_entry = RUNTIME_PUBLIC_CACHE.get(key)
        if not cached_entry:
            return None
        expires_at, payload = cached_entry
        if expires_at <= now_timestamp:
            RUNTIME_PUBLIC_CACHE.pop(key, None)
            return None
        return payload


def write_runtime_public_cache(
    key: str,
    payload: object,
    *,
    ttl_seconds: int,
) -> None:
    with RUNTIME_PUBLIC_CACHE_LOCK:
        RUNTIME_PUBLIC_CACHE[key] = (
            time.time() + max(1, int(ttl_seconds)),
            payload,
        )
POSTGRES_MIGRATION_LOCK_ID = 90422117
CHAT_ONLINE_WINDOW_SECONDS = 180
USER_PRESENCE_HEARTBEAT_SECONDS = 45
CHAT_TYPING_WINDOW_SECONDS = 8
ADDRESS_SELECT_COLUMNS = """
    id,
    user_id,
    address_line,
    city,
    country,
    zip_code,
    phone_number,
    is_default,
    created_at,
    updated_at
"""
BUSINESS_PROFILE_SELECT_COLUMNS = """
    id,
    user_id,
    business_name,
    business_description,
    business_number,
    business_logo_path,
    verification_status,
    verification_requested_at,
    verification_verified_at,
    verification_notes,
    profile_edit_access_status,
    profile_edit_requested_at,
    profile_edit_approved_at,
    profile_edit_notes,
    shipping_settings,
    phone_number,
    city,
    address_line,
    created_at,
    updated_at
"""
USER_SELECT_COLUMNS = (
    "id, "
    "full_name, "
    "first_name, "
    "last_name, "
    "email, "
    "birth_date, "
    "gender, "
    "role, "
    "is_email_verified, "
    "email_verified_at, "
    "profile_image_path, "
    "last_seen_at, "
    "created_at"
)
USER_AUTH_SELECT_COLUMNS = USER_SELECT_COLUMNS + ", password_hash"
try:
    MARKETPLACE_COMMISSION_RATE = min(
        0.95,
        max(0.0, float(str(os.environ.get("MARKETPLACE_COMMISSION_RATE", "0.08")).strip() or 0.08)),
    )
except ValueError:
    MARKETPLACE_COMMISSION_RATE = 0.08

PRODUCT_SELECT_COLUMNS = """
    products.id AS id,
    products.article_number AS article_number,
    products.title AS title,
    products.description AS description,
    products.price AS price,
    products.image_path AS image_path,
    products.image_gallery AS image_gallery,
    products.image_fingerprint AS image_fingerprint,
    products.ai_image_search_text AS ai_image_search_text,
    products.ai_image_color_terms AS ai_image_color_terms,
    products.category AS category,
    products.product_type AS product_type,
    products.size AS size,
    products.color AS color,
    products.variant_inventory AS variant_inventory,
    products.package_amount_value AS package_amount_value,
    products.package_amount_unit AS package_amount_unit,
    products.stock_quantity AS stock_quantity,
    products.is_public AS is_public,
    products.show_stock_public AS show_stock_public,
    products.created_by_user_id AS created_by_user_id,
    products.created_at AS created_at,
    COALESCE(order_totals.buyers_count, 0) AS buyers_count,
    COALESCE(review_totals.average_rating, 0) AS average_rating,
    COALESCE(review_totals.review_count, 0) AS review_count,
    COALESCE(product_business_profile.business_name, '') AS business_name
"""
PRODUCT_SELECT_RELATION_JOINS = """
    LEFT JOIN (
        SELECT
            product_id,
            COUNT(DISTINCT order_id) AS buyers_count
        FROM order_items
        WHERE product_id IS NOT NULL
        GROUP BY product_id
    ) order_totals ON order_totals.product_id = products.id
    LEFT JOIN (
        SELECT
            product_id,
            ROUND(AVG(rating), 2) AS average_rating,
            COUNT(*) AS review_count
        FROM product_reviews
        WHERE product_id IS NOT NULL
          AND status = 'published'
        GROUP BY product_id
    ) review_totals ON review_totals.product_id = products.id
    LEFT JOIN business_profiles product_business_profile
        ON product_business_profile.user_id = products.created_by_user_id
"""
ORDER_SELECT_COLUMNS = """
    id,
    user_id,
    customer_full_name,
    customer_email,
    payment_method,
    status,
    address_line,
    city,
    country,
    zip_code,
    phone_number,
    subtotal_amount,
    discount_amount,
    shipping_amount,
    total_amount,
    promo_code,
    delivery_method,
    delivery_label,
    estimated_delivery_text,
    created_at
"""
ORDER_ITEM_SELECT_COLUMNS = """
    id,
    order_id,
    product_id,
    business_user_id,
    business_name_snapshot,
    product_title,
    product_description,
    product_image_path,
    product_category,
    product_type,
    product_size,
    product_color,
    product_variant_key,
    product_variant_label,
    product_variant_snapshot,
    product_package_amount_value,
    product_package_amount_unit,
    unit_price,
    quantity,
    fulfillment_status,
    confirmed_at,
    confirmation_due_at,
    tracking_code,
    tracking_url,
    shipped_at,
    delivered_at,
    cancelled_at,
    commission_rate,
    commission_amount,
    seller_earnings_amount,
    payout_status,
    payout_due_at,
    COALESCE((
        SELECT rr.reason
        FROM return_requests rr
        WHERE rr.order_item_id = order_items.id
        ORDER BY rr.id DESC
        LIMIT 1
    ), '') AS return_request_reason,
    COALESCE((
        SELECT rr.details
        FROM return_requests rr
        WHERE rr.order_item_id = order_items.id
        ORDER BY rr.id DESC
        LIMIT 1
    ), '') AS return_request_details,
    COALESCE((
        SELECT rr.status
        FROM return_requests rr
        WHERE rr.order_item_id = order_items.id
        ORDER BY rr.id DESC
        LIMIT 1
    ), '') AS return_request_status,
    created_at
"""

def load_local_env_file() -> None:
    env_path = BASE_DIR / ".env"
    if not env_path.exists():
        return

    try:
        raw_lines = env_path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return

    for raw_line in raw_lines:
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        env_name = key.strip()
        if not env_name or env_name in os.environ:
            continue

        normalized_value = value.strip()
        if (
            len(normalized_value) >= 2
            and normalized_value[0] == normalized_value[-1]
            and normalized_value[0] in {'"', "'"}
        ):
            normalized_value = normalized_value[1:-1]

        os.environ[env_name] = normalized_value


load_local_env_file()


def read_bool_env(name: str, default_value: bool) -> bool:
    raw_value = str(os.environ.get(name, "")).strip().lower()
    if not raw_value:
        return default_value

    return raw_value in {"1", "true", "yes", "on", "po"}


def read_text_env(name: str, default_value: str = "") -> str:
    return str(os.environ.get(name, default_value)).strip()


def get_database_url() -> str:
    return read_text_env("DATABASE_URL")


def use_postgres_database() -> bool:
    return bool(get_database_url())


def adapt_query_placeholders(query: str) -> str:
    if not use_postgres_database():
        return query

    return query.replace("?", "%s")


def iterate_sql_statements(script: str):
    current_lines: list[str] = []

    for line in script.splitlines():
        stripped = line.strip()
        if not stripped:
            continue

        current_lines.append(line)
        if stripped.endswith(";"):
            statement = "\n".join(current_lines).strip()
            if statement:
                yield statement
            current_lines = []

    statement = "\n".join(current_lines).strip()
    if statement:
        yield statement


def get_database_integrity_errors():
    error_types: list[type[BaseException]] = [sqlite3.IntegrityError]

    try:
        from psycopg import IntegrityError as PsycopgIntegrityError
    except ImportError:
        PsycopgIntegrityError = None

    if PsycopgIntegrityError is not None:
        error_types.append(PsycopgIntegrityError)

    return tuple(error_types)


DB_INTEGRITY_ERRORS = get_database_integrity_errors()


class DatabaseCursor:
    def __init__(self, cursor, backend: str):
        self._cursor = cursor
        self.backend = backend
        self.lastrowid = getattr(cursor, "lastrowid", None)

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()

    def __iter__(self):
        return iter(self._cursor)

    def __getattr__(self, name: str):
        return getattr(self._cursor, name)


class DatabaseConnection:
    def __init__(self, raw_connection, backend: str):
        self._raw_connection = raw_connection
        self.backend = backend

    def execute(self, query: str, params=()):
        cursor = self._raw_connection.execute(
            adapt_query_placeholders(query),
            () if params is None else params,
        )
        return DatabaseCursor(cursor, self.backend)

    def executescript(self, script: str):
        for statement in iterate_sql_statements(script):
            self.execute(statement)

    def commit(self):
        self._raw_connection.commit()

    def rollback(self):
        self._raw_connection.rollback()

    def close(self):
        self._raw_connection.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_type is None:
            self.commit()
        else:
            self.rollback()

        self.close()
        return False


class CheckoutProcessError(Exception):
    def __init__(self, errors: list[str] | None = None, message: str = ""):
        self.errors = list(errors or [])
        self.message = str(message or "").strip()
        super().__init__(self.message or "Checkout process failed.")


def is_postgres_connection(connection: DatabaseConnection) -> bool:
    return getattr(connection, "backend", "sqlite") == "postgres"


def get_bootstrap_admin_settings() -> dict[str, str]:
    return {
        "full_name": read_text_env("TREGO_BOOTSTRAP_ADMIN_NAME"),
        "email": read_text_env("TREGO_BOOTSTRAP_ADMIN_EMAIL").lower(),
        "password": str(os.environ.get("TREGO_BOOTSTRAP_ADMIN_PASSWORD", "")),
    }


def split_full_name(full_name: str) -> tuple[str, str]:
    clean_name = re.sub(r"\s+", " ", full_name).strip()
    if not clean_name:
        return "", ""

    name_parts = clean_name.split(" ", 1)
    if len(name_parts) == 1:
        return name_parts[0], ""

    return name_parts[0], name_parts[1]


def build_full_name(first_name: str, last_name: str) -> str:
    return " ".join(part for part in [first_name.strip(), last_name.strip()] if part).strip()


def get_business_initials(value: str) -> str:
    parts = [part for part in str(value or "").strip().split() if part][:2]
    if not parts:
        return "TR"

    return "".join(part[0].upper() for part in parts)


def get_db_connection() -> DatabaseConnection:
    if use_postgres_database():
        try:
            import psycopg
            from psycopg.rows import dict_row
        except ImportError as error:
            raise RuntimeError(
                "DATABASE_URL eshte vendosur, por mungon paketa 'psycopg'. "
                "Shtoje ne requirements.txt para deploy-it."
            ) from error

        raw_connection = psycopg.connect(
            get_database_url(),
            row_factory=dict_row,
            prepare_threshold=None,
        )
        return DatabaseConnection(raw_connection, "postgres")

    raw_connection = sqlite3.connect(DB_PATH)
    raw_connection.row_factory = sqlite3.Row
    raw_connection.execute("PRAGMA foreign_keys = ON;")
    return DatabaseConnection(raw_connection, "sqlite")


def execute_insert_and_get_id(connection: DatabaseConnection, query: str, params=()) -> int:
    if not is_postgres_connection(connection):
        cursor = connection.execute(query, params)
        return int(cursor.lastrowid)

    insert_query = query.strip().rstrip(";")
    cursor = connection.execute(f"{insert_query} RETURNING id", params)
    row = cursor.fetchone()
    if not row:
        raise RuntimeError("Nuk u kthye ID pas INSERT-it ne Postgres.")

    return int(row["id"])


def initialize_database() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

    with get_db_connection() as connection:
        acquired_postgres_lock = False
        if is_postgres_connection(connection):
            connection.execute(
                "SELECT pg_advisory_lock(?)",
                (POSTGRES_MIGRATION_LOCK_ID,),
            )
            acquired_postgres_lock = True

        try:
            schema_path = POSTGRES_SCHEMA_PATH if is_postgres_connection(connection) else SCHEMA_PATH
            current_schema_version = get_runtime_meta_value(connection, "schema_version")
            has_core_schema = table_exists(connection, "users") and table_exists(connection, "products")
            needs_schema_bootstrap = not has_core_schema
            needs_migration = current_schema_version != APP_SCHEMA_VERSION or needs_schema_bootstrap

            if needs_schema_bootstrap:
                connection.executescript(schema_path.read_text(encoding="utf-8"))

            if needs_migration:
                migrate_database(connection)
                ensure_runtime_meta_table(connection)
                set_runtime_meta_value(connection, "schema_version", APP_SCHEMA_VERSION)
            ensure_bootstrap_admin(connection)
        finally:
            if acquired_postgres_lock:
                connection.execute(
                    "SELECT pg_advisory_unlock(?)",
                    (POSTGRES_MIGRATION_LOCK_ID,),
                )


def should_store_uploads_in_database() -> bool:
    return IS_VERCEL or use_postgres_database()


def guess_content_type_for_extension(extension: str) -> str:
    return EXTENSION_CONTENT_TYPES.get(str(extension or "").strip().lower(), "application/octet-stream")


def convert_image_bytes_to_webp(file_bytes: bytes) -> bytes | None:
    if not PILLOW_AVAILABLE or not file_bytes:
        return None

    try:
        with Image.open(BytesIO(file_bytes)) as raw_image:
            prepared_image = ImageOps.exif_transpose(raw_image)
            has_alpha = "A" in prepared_image.getbands()
            target_mode = "RGBA" if has_alpha else "RGB"
            if prepared_image.mode != target_mode:
                prepared_image = prepared_image.convert(target_mode)

            output_buffer = BytesIO()
            prepared_image.save(output_buffer, "WEBP", quality=86, method=6)
            return output_buffer.getvalue()
    except (UnidentifiedImageError, OSError, ValueError):
        return None


def normalize_uploaded_image_payload(
    file_bytes: bytes,
    extension: str,
    content_type: str,
) -> tuple[bytes, str, str]:
    normalized_extension = str(extension or "").strip().lower()
    normalized_content_type = str(content_type or "").strip().lower()

    if normalized_extension in {".webp", ".gif"}:
        if not normalized_content_type.startswith("image/"):
            normalized_content_type = guess_content_type_for_extension(normalized_extension)
        return file_bytes, normalized_extension, normalized_content_type

    converted_bytes = convert_image_bytes_to_webp(file_bytes)
    if converted_bytes:
        return converted_bytes, ".webp", "image/webp"

    if not normalized_content_type.startswith("image/"):
        normalized_content_type = guess_content_type_for_extension(normalized_extension)
    return file_bytes, normalized_extension, normalized_content_type


def store_uploaded_asset(
    *,
    stored_name: str,
    original_filename: str,
    content_type: str,
    file_bytes: bytes,
    created_by_user_id: int | None = None,
) -> None:
    if should_store_uploads_in_database():
        with get_db_connection() as connection:
            connection.execute(
                """
                INSERT INTO uploaded_assets (
                    stored_name,
                    original_filename,
                    content_type,
                    file_bytes,
                    created_by_user_id
                )
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    stored_name,
                    original_filename,
                    content_type,
                    file_bytes,
                    created_by_user_id,
                ),
            )
        return

    target_path = UPLOADS_DIR / stored_name
    target_path.write_bytes(file_bytes)


def delete_uploaded_asset_by_stored_name(stored_name: str) -> None:
    clean_name = str(stored_name or "").strip()
    if not clean_name:
        return

    if should_store_uploads_in_database():
        with get_db_connection() as connection:
            connection.execute(
                """
                DELETE FROM uploaded_assets
                WHERE stored_name = ?
                """,
                (clean_name,),
            )
        return

    (UPLOADS_DIR / clean_name).unlink(missing_ok=True)


def fetch_uploaded_asset_by_stored_name(stored_name: str):
    clean_name = str(stored_name or "").strip()
    if not clean_name:
        return None

    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                stored_name,
                original_filename,
                content_type,
                file_bytes
            FROM uploaded_assets
            WHERE stored_name = ?
            LIMIT 1
            """,
            (clean_name,),
        ).fetchone()


def extract_stored_upload_name_from_path(image_path: object) -> str:
    normalized_path = normalize_image_path(image_path)
    if not normalized_path.startswith("/uploads/"):
        return ""

    return normalized_path.removeprefix("/uploads/").strip()


def guess_image_content_type_from_path(image_path: object) -> str:
    normalized_path = normalize_image_path(image_path)
    extension = Path(normalized_path).suffix.lower()
    if extension in EXTENSION_CONTENT_TYPES:
        return EXTENSION_CONTENT_TYPES[extension]

    guessed_type, _ = mimetypes.guess_type(normalized_path)
    if guessed_type and guessed_type.startswith("image/"):
        return guessed_type

    return "image/jpeg"


def fetch_uploaded_asset_payload_by_path(image_path: object) -> tuple[bytes, str]:
    stored_name = extract_stored_upload_name_from_path(image_path)
    if not stored_name:
        return b"", guess_image_content_type_from_path(image_path)

    if should_store_uploads_in_database():
        asset_row = fetch_uploaded_asset_by_stored_name(stored_name)
        if not asset_row:
            return b"", guess_image_content_type_from_path(image_path)

        file_bytes = bytes(asset_row["file_bytes"]) if asset_row["file_bytes"] else b""
        content_type = str(asset_row["content_type"] or "").strip()
        if not content_type.startswith("image/"):
            content_type = guess_image_content_type_from_path(image_path)
        return file_bytes, content_type

    file_path = UPLOADS_DIR / stored_name
    if not file_path.exists():
        return b"", guess_image_content_type_from_path(image_path)

    try:
        return file_path.read_bytes(), guess_image_content_type_from_path(file_path.name)
    except OSError:
        return b"", guess_image_content_type_from_path(image_path)


def fetch_uploaded_asset_bytes_by_path(image_path: object) -> bytes:
    file_bytes, _ = fetch_uploaded_asset_payload_by_path(image_path)
    return file_bytes


def compute_image_fingerprint(file_bytes: bytes) -> str:
    if not PILLOW_AVAILABLE or not file_bytes:
        return ""

    try:
        with Image.open(BytesIO(file_bytes)) as raw_image:
            prepared_image = ImageOps.exif_transpose(raw_image).convert("L")
            resize_mode = (
                Image.Resampling.LANCZOS
                if hasattr(Image, "Resampling")
                else Image.LANCZOS
            )
            prepared_image = prepared_image.resize(
                (VISUAL_SEARCH_HASH_SIZE, VISUAL_SEARCH_HASH_SIZE),
                resize_mode,
            )
            pixels = list(prepared_image.getdata())
    except (UnidentifiedImageError, OSError, ValueError):
        return ""

    if not pixels:
        return ""

    average_value = sum(pixels) / len(pixels)
    bits = "".join("1" if pixel >= average_value else "0" for pixel in pixels)
    return f"{int(bits, 2):0{len(bits) // 4}x}"


def compute_product_image_fingerprint(
    image_gallery: object,
    *,
    fallback_image_path: object = "",
) -> str:
    gallery_paths = normalize_image_gallery_value(
        image_gallery,
        fallback_image_path=fallback_image_path,
    )
    for image_path in gallery_paths:
        file_bytes = fetch_uploaded_asset_bytes_by_path(image_path)
        image_fingerprint = compute_image_fingerprint(file_bytes)
        if image_fingerprint:
            return image_fingerprint

    return ""


def compute_hamming_distance(left_hash: str, right_hash: str) -> int:
    if not left_hash or not right_hash or len(left_hash) != len(right_hash):
        return 10**9

    return sum(left_char != right_char for left_char, right_char in zip(left_hash, right_hash))


def ensure_bootstrap_admin(connection: DatabaseConnection) -> None:
    if count_admin_users(connection) > 0:
        return

    settings = get_bootstrap_admin_settings()
    full_name = settings["full_name"]
    email = settings["email"]
    password = settings["password"]

    if not full_name or not email or len(password) < 8 or not EMAIL_RE.match(email):
        return

    first_name, last_name = split_full_name(full_name)
    existing_user = connection.execute(
        """
        SELECT id
        FROM users
        WHERE email = ?
        LIMIT 1
        """,
        (email,),
    ).fetchone()

    if existing_user:
        connection.execute(
            """
            UPDATE users
            SET
                full_name = ?,
                first_name = ?,
                last_name = ?,
                password_hash = ?,
                role = 'admin',
                is_email_verified = 1,
                email_verified_at = COALESCE(NULLIF(email_verified_at, ''), CURRENT_TIMESTAMP)
            WHERE id = ?
            """,
            (
                full_name,
                first_name,
                last_name,
                hash_password(password),
                existing_user["id"],
            ),
        )
        print(
            f"[TREGO] Bootstrap admin u aktivizua per {email}.",
            flush=True,
        )
        return

    connection.execute(
        """
        INSERT INTO users (
            full_name,
            first_name,
            last_name,
            email,
            password_hash,
            birth_date,
            gender,
            role,
            is_email_verified,
            email_verified_at
        )
        VALUES (?, ?, ?, ?, ?, '', '', 'admin', 1, CURRENT_TIMESTAMP)
        """,
        (
            full_name,
            first_name,
            last_name,
            email,
            hash_password(password),
        ),
    )
    print(
        f"[TREGO] Bootstrap admin u krijua per {email}.",
        flush=True,
    )


def migrate_database(connection: DatabaseConnection) -> None:
    now_text_value = datetime_to_storage_text(utc_now())

    ensure_runtime_meta_table(connection)

    if not column_exists(connection, "users", "first_name"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN first_name TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "users", "last_name"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN last_name TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "users", "birth_date"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN birth_date TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "users", "gender"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN gender TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "users", "role"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'client'"
        )

    if not column_exists(connection, "users", "is_email_verified"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN is_email_verified INTEGER NOT NULL DEFAULT 1"
        )

    if not column_exists(connection, "users", "email_verified_at"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN email_verified_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "users", "profile_image_path"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN profile_image_path TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "users", "last_seen_at"):
        connection.execute(
            "ALTER TABLE users ADD COLUMN last_seen_at TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE users
        SET role = 'client'
        WHERE role IS NULL OR TRIM(role) = ''
        """
    )
    connection.execute(
        """
        UPDATE users
        SET is_email_verified = 1
        WHERE is_email_verified IS NULL
        """
    )
    connection.execute(
        """
        UPDATE users
        SET email_verified_at = created_at
        WHERE is_email_verified = 1
          AND (email_verified_at IS NULL OR TRIM(email_verified_at) = '')
        """
    )
    connection.execute(
        """
        UPDATE users
        SET last_seen_at = COALESCE(NULLIF(TRIM(last_seen_at), ''), created_at, ?)
        WHERE last_seen_at IS NULL OR TRIM(last_seen_at) = ''
        """,
        (now_text_value,),
    )

    users = connection.execute(
        """
        SELECT
            id,
            full_name,
            first_name,
            last_name,
            birth_date,
            gender,
            profile_image_path
        FROM users
        """
    ).fetchall()
    for user in users:
        stored_first_name = (user["first_name"] or "").strip()
        stored_last_name = (user["last_name"] or "").strip()
        parsed_first_name, parsed_last_name = split_full_name(user["full_name"] or "")
        next_first_name = stored_first_name or parsed_first_name
        next_last_name = stored_last_name or parsed_last_name

        if (
            next_first_name != stored_first_name
            or next_last_name != stored_last_name
            or user["birth_date"] is None
            or user["gender"] is None
        ):
            connection.execute(
                """
                UPDATE users
                SET
                    first_name = ?,
                    last_name = ?,
                    birth_date = COALESCE(birth_date, ''),
                    gender = COALESCE(gender, '')
                WHERE id = ?
                """,
                (next_first_name, next_last_name, user["id"]),
            )

        normalized_profile_image_path = normalize_image_path(user["profile_image_path"])
        if normalized_profile_image_path != str(user["profile_image_path"] or "").strip():
            connection.execute(
                """
                UPDATE users
                SET profile_image_path = ?
                WHERE id = ?
                """,
                (normalized_profile_image_path, user["id"]),
            )

    if count_admin_users(connection) == 0:
        first_user = connection.execute(
            "SELECT id FROM users ORDER BY id ASC LIMIT 1"
        ).fetchone()
        if first_user:
            connection.execute(
                "UPDATE users SET role = 'admin' WHERE id = ?",
                (first_user["id"],),
            )

    if not column_exists(connection, "business_profiles", "business_number"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN business_number TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "business_logo_path"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN business_logo_path TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "verification_status"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'unverified'"
        )

    if not column_exists(connection, "business_profiles", "verification_requested_at"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN verification_requested_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "verification_verified_at"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN verification_verified_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "verification_notes"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN verification_notes TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "profile_edit_access_status"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN profile_edit_access_status TEXT NOT NULL DEFAULT 'locked'"
        )

    if not column_exists(connection, "business_profiles", "profile_edit_requested_at"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN profile_edit_requested_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "profile_edit_approved_at"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN profile_edit_approved_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "profile_edit_notes"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN profile_edit_notes TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "business_profiles", "shipping_settings"):
        connection.execute(
            "ALTER TABLE business_profiles ADD COLUMN shipping_settings TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE business_profiles
        SET
            business_number = COALESCE(NULLIF(TRIM(business_number), ''), ''),
            business_logo_path = COALESCE(NULLIF(TRIM(business_logo_path), ''), ''),
            verification_status = CASE
                WHEN LOWER(TRIM(COALESCE(verification_status, ''))) IN ('pending', 'verified', 'rejected')
                    THEN LOWER(TRIM(COALESCE(verification_status, '')))
                ELSE 'unverified'
            END,
            verification_requested_at = COALESCE(verification_requested_at, ''),
            verification_verified_at = COALESCE(verification_verified_at, ''),
            verification_notes = COALESCE(verification_notes, ''),
            profile_edit_access_status = CASE
                WHEN LOWER(TRIM(COALESCE(verification_status, ''))) <> 'verified' THEN 'locked'
                WHEN LOWER(TRIM(COALESCE(profile_edit_access_status, ''))) IN ('pending', 'approved')
                    THEN LOWER(TRIM(COALESCE(profile_edit_access_status, '')))
                ELSE 'locked'
            END,
            profile_edit_requested_at = COALESCE(profile_edit_requested_at, ''),
            profile_edit_approved_at = COALESCE(profile_edit_approved_at, ''),
            profile_edit_notes = COALESCE(profile_edit_notes, ''),
            shipping_settings = COALESCE(shipping_settings, '')
        """
    )

    business_profiles = connection.execute(
        """
        SELECT id, business_logo_path, shipping_settings
        FROM business_profiles
        """
    ).fetchall()
    for business_profile in business_profiles:
        normalized_logo_path = normalize_image_path(business_profile["business_logo_path"])
        normalized_shipping_settings = serialize_business_shipping_settings_storage(
            normalize_business_shipping_settings(business_profile["shipping_settings"])
        )
        if (
            normalized_logo_path != str(business_profile["business_logo_path"] or "").strip()
            or normalized_shipping_settings != str(business_profile["shipping_settings"] or "").strip()
        ):
            connection.execute(
                """
                UPDATE business_profiles
                SET
                    business_logo_path = ?,
                    shipping_settings = ?
                WHERE id = ?
                """,
                (
                    normalized_logo_path,
                    normalized_shipping_settings,
                    business_profile["id"],
                ),
            )

    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_business_profiles_business_number
        ON business_profiles(business_number)
        WHERE TRIM(business_number) <> ''
        """
    )

    if not table_exists(connection, "chat_conversations"):
        if is_postgres_connection(connection):
            connection.execute(
                """
                CREATE TABLE chat_conversations (
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
                )
                """
            )
        else:
            connection.execute(
                """
                CREATE TABLE chat_conversations (
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
                )
                """
            )

    if not column_exists(connection, "chat_conversations", "business_profile_id"):
        connection.execute(
            "ALTER TABLE chat_conversations ADD COLUMN business_profile_id INTEGER"
        )

    if not column_exists(connection, "chat_conversations", "updated_at"):
        connection.execute(
            "ALTER TABLE chat_conversations ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_conversations", "last_message_at"):
        connection.execute(
            "ALTER TABLE chat_conversations ADD COLUMN last_message_at TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE chat_conversations
        SET
            updated_at = COALESCE(NULLIF(TRIM(updated_at), ''), created_at, ?),
            last_message_at = COALESCE(NULLIF(TRIM(last_message_at), ''), updated_at, created_at, ?)
        """,
        (now_text_value, now_text_value),
    )

    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_conversations_client_business
        ON chat_conversations(client_user_id, business_user_id)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_chat_conversations_client_last_message
        ON chat_conversations(client_user_id, last_message_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_chat_conversations_business_last_message
        ON chat_conversations(business_user_id, last_message_at DESC)
        """
    )

    if not table_exists(connection, "chat_messages"):
        if is_postgres_connection(connection):
            connection.execute(
                """
                CREATE TABLE chat_messages (
                    id BIGSERIAL PRIMARY KEY,
                    conversation_id BIGINT NOT NULL,
                    sender_user_id BIGINT NOT NULL,
                    recipient_user_id BIGINT NOT NULL,
                    body TEXT NOT NULL,
                    attachment_path TEXT NOT NULL DEFAULT '',
                    attachment_content_type TEXT NOT NULL DEFAULT '',
                    attachment_file_name TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
                    edited_at TEXT NOT NULL DEFAULT '',
                    deleted_at TEXT NOT NULL DEFAULT '',
                    read_at TEXT NOT NULL DEFAULT '',
                    reminder_sent_at TEXT NOT NULL DEFAULT '',
                    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
                    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
                    FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE
                )
                """
            )
        else:
            connection.execute(
                """
                CREATE TABLE chat_messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    conversation_id INTEGER NOT NULL,
                    sender_user_id INTEGER NOT NULL,
                    recipient_user_id INTEGER NOT NULL,
                    body TEXT NOT NULL,
                    attachment_path TEXT NOT NULL DEFAULT '',
                    attachment_content_type TEXT NOT NULL DEFAULT '',
                    attachment_file_name TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    edited_at TEXT NOT NULL DEFAULT '',
                    deleted_at TEXT NOT NULL DEFAULT '',
                    read_at TEXT NOT NULL DEFAULT '',
                    reminder_sent_at TEXT NOT NULL DEFAULT '',
                    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
                    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
                    FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE
                )
                """
            )

    if not column_exists(connection, "chat_messages", "read_at"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN read_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_messages", "attachment_path"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN attachment_path TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_messages", "attachment_content_type"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN attachment_content_type TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_messages", "attachment_file_name"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN attachment_file_name TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_messages", "edited_at"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN edited_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_messages", "deleted_at"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN deleted_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "chat_messages", "reminder_sent_at"):
        connection.execute(
            "ALTER TABLE chat_messages ADD COLUMN reminder_sent_at TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE chat_messages
        SET
            read_at = COALESCE(read_at, ''),
            attachment_path = COALESCE(attachment_path, ''),
            attachment_content_type = COALESCE(attachment_content_type, ''),
            attachment_file_name = COALESCE(attachment_file_name, ''),
            edited_at = COALESCE(edited_at, ''),
            deleted_at = COALESCE(deleted_at, ''),
            reminder_sent_at = COALESCE(reminder_sent_at, '')
        """
    )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
        ON chat_messages(conversation_id, created_at ASC, id ASC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_chat_messages_recipient_read
        ON chat_messages(recipient_user_id, read_at, created_at DESC)
        """
    )

    if not table_exists(connection, "chat_typing_states"):
        if is_postgres_connection(connection):
            connection.execute(
                """
                CREATE TABLE chat_typing_states (
                    id BIGSERIAL PRIMARY KEY,
                    conversation_id BIGINT NOT NULL,
                    user_id BIGINT NOT NULL,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text,
                    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                )
                """
            )
        else:
            connection.execute(
                """
                CREATE TABLE chat_typing_states (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    conversation_id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                )
                """
            )

    if not column_exists(connection, "chat_typing_states", "updated_at"):
        connection.execute(
            "ALTER TABLE chat_typing_states ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE chat_typing_states
        SET updated_at = COALESCE(NULLIF(TRIM(updated_at), ''), ?)
        WHERE updated_at IS NULL OR TRIM(updated_at) = ''
        """,
        (now_text_value,),
    )
    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_typing_states_unique
        ON chat_typing_states(conversation_id, user_id)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_chat_typing_states_updated
        ON chat_typing_states(conversation_id, updated_at DESC)
        """
    )

    if not column_exists(connection, "products", "product_type"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN product_type TEXT NOT NULL DEFAULT 'other'"
        )

    if not column_exists(connection, "products", "article_number"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN article_number TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "size"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN size TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "color"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN color TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "variant_inventory"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN variant_inventory TEXT NOT NULL DEFAULT '[]'"
        )

    if not column_exists(connection, "products", "package_amount_value"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN package_amount_value REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "products", "package_amount_unit"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN package_amount_unit TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "stock_quantity"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN stock_quantity INTEGER NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "products", "is_public"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN is_public INTEGER NOT NULL DEFAULT 1"
        )

    if not column_exists(connection, "products", "show_stock_public"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN show_stock_public INTEGER NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "products", "image_gallery"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN image_gallery TEXT NOT NULL DEFAULT '[]'"
        )

    if not column_exists(connection, "products", "image_fingerprint"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN image_fingerprint TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "ai_image_search_text"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN ai_image_search_text TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "ai_image_color_terms"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN ai_image_color_terms TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE products
        SET
            article_number = COALESCE(NULLIF(TRIM(article_number), ''), ''),
            product_type = COALESCE(NULLIF(TRIM(product_type), ''), 'other'),
            size = COALESCE(size, ''),
            color = COALESCE(NULLIF(TRIM(color), ''), ''),
            variant_inventory = COALESCE(variant_inventory, '[]'),
            package_amount_value = COALESCE(package_amount_value, 0),
            package_amount_unit = COALESCE(NULLIF(TRIM(package_amount_unit), ''), ''),
            stock_quantity = COALESCE(stock_quantity, 0),
            is_public = CASE WHEN COALESCE(is_public, 1) = 0 THEN 0 ELSE 1 END,
            show_stock_public = CASE
                WHEN COALESCE(show_stock_public, 0) = 1 THEN 1
                ELSE 0
            END,
            ai_image_search_text = COALESCE(ai_image_search_text, ''),
            ai_image_color_terms = COALESCE(ai_image_color_terms, '')
        """
    )

    product_rows = connection.execute(
        """
        SELECT
            id,
            title,
            description,
            image_path,
            image_gallery,
            category,
            product_type,
            size,
            color,
            variant_inventory,
            stock_quantity,
            ai_image_search_text,
            ai_image_color_terms,
            package_amount_value,
            package_amount_unit
        FROM products
        """
    ).fetchall()

    for product in product_rows:
        image_gallery = normalize_image_gallery_value(
            product["image_gallery"],
            fallback_image_path=product["image_path"],
        )
        primary_image_path = (
            image_gallery[0]
            if image_gallery
            else normalize_image_path(product["image_path"])
        )
        serialized_gallery = json.dumps(image_gallery, ensure_ascii=False)
        stored_gallery = str(product["image_gallery"] or "").strip()
        stored_image_path = str(product["image_path"] or "").strip()

        if (
            serialized_gallery != stored_gallery
            or primary_image_path != stored_image_path
        ):
            connection.execute(
                """
                UPDATE products
                SET image_path = ?, image_gallery = ?
                WHERE id = ?
                """,
                (primary_image_path, serialized_gallery, product["id"]),
            )

        heuristic_metadata = heuristic_product_image_search_metadata(
            title=product["title"],
            description=product["description"],
            category=product["category"],
            product_type=product["product_type"],
            color=product["color"],
        )
        stored_ai_search_text = normalize_search_intent_text(product["ai_image_search_text"])
        stored_ai_color_terms = merge_normalized_search_terms(
            product["ai_image_color_terms"],
            allowed_terms=PRODUCT_COLORS,
            max_terms=6,
        )
        if (
            not stored_ai_search_text
            or (heuristic_metadata["colorTerms"] and not stored_ai_color_terms)
        ):
            connection.execute(
                """
                UPDATE products
                SET
                    ai_image_search_text = ?,
                    ai_image_color_terms = ?
                WHERE id = ?
                """,
                (
                    heuristic_metadata["searchText"],
                    heuristic_metadata["colorTerms"],
                    product["id"],
                ),
            )

        _, normalized_inventory = normalize_variant_inventory_value(
            product["variant_inventory"],
            category=str(product["category"] or "").strip().lower(),
            fallback_size=str(product["size"] or "").strip().upper(),
            fallback_color=str(product["color"] or "").strip().lower(),
            fallback_stock_quantity=int(product["stock_quantity"] or 0),
        )
        serialized_inventory = json.dumps(normalized_inventory, ensure_ascii=False)
        inventory_stock_quantity = sum(
            max(0, int(entry["quantity"])) for entry in normalized_inventory
        )
        inventory_sizes = sorted(
            {
                str(entry.get("size", "")).strip().upper()
                for entry in normalized_inventory
                if str(entry.get("size", "")).strip()
            }
        )
        inventory_colors = sorted(
            {
                str(entry.get("color", "")).strip().lower()
                for entry in normalized_inventory
                if str(entry.get("color", "")).strip()
            }
        )
        normalized_size = inventory_sizes[0] if len(inventory_sizes) == 1 else ""
        if len(inventory_colors) == 1:
            normalized_color = inventory_colors[0]
        elif len(inventory_colors) > 1 and "shume-ngjyra" in PRODUCT_COLORS:
            normalized_color = "shume-ngjyra"
        else:
            normalized_color = ""

        if (
            serialized_inventory != str(product["variant_inventory"] or "").strip()
            or inventory_stock_quantity != int(product["stock_quantity"] or 0)
            or normalized_size != str(product["size"] or "").strip().upper()
            or normalized_color != str(product["color"] or "").strip().lower()
        ):
            connection.execute(
                """
                UPDATE products
                SET
                    variant_inventory = ?,
                    stock_quantity = ?,
                    size = ?,
                    color = ?
                WHERE id = ?
                """,
                (
                    serialized_inventory,
                    inventory_stock_quantity,
                    normalized_size,
                    normalized_color,
                    product["id"],
                ),
            )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_products_public_category_id
        ON products(is_public, category, id DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_products_public_stock_id
        ON products(is_public, stock_quantity, id DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_products_public_creator_id
        ON products(is_public, created_by_user_id, id DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_products_product_type
        ON products(product_type)
        """
    )
    if is_postgres_connection(connection):
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_products_title_lower
            ON products ((LOWER(title)))
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_business_profiles_name_lower
            ON business_profiles ((LOWER(business_name)))
            """
        )
    else:
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_products_title
            ON products(title)
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_business_profiles_name
            ON business_profiles(business_name)
            """
        )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_business_profiles_updated_at
        ON business_profiles(updated_at DESC)
        """
    )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_products_public_image_fingerprint
        ON products(is_public, image_fingerprint)
        """
    )

    if not column_exists(connection, "cart_items", "created_at"):
        connection.execute(
            "ALTER TABLE cart_items ADD COLUMN created_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "cart_items", "updated_at"):
        connection.execute(
            "ALTER TABLE cart_items ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE cart_items
        SET
            created_at = COALESCE(NULLIF(TRIM(created_at), ''), ?),
            updated_at = COALESCE(NULLIF(TRIM(updated_at), ''), COALESCE(NULLIF(TRIM(created_at), ''), ?))
        """
        ,
        (now_text_value, now_text_value),
    )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_cart_user_updated_at
        ON cart_items(user_id, updated_at DESC)
        """
    )

    if not table_exists(connection, "cart_lines"):
        connection.execute(
            """
            CREATE TABLE cart_lines (
                id BIGSERIAL PRIMARY KEY,
                user_id BIGINT NOT NULL,
                product_id BIGINT NOT NULL,
                variant_key TEXT NOT NULL DEFAULT 'default',
                variant_label TEXT NOT NULL DEFAULT 'Standard',
                selected_size TEXT NOT NULL DEFAULT '',
                selected_color TEXT NOT NULL DEFAULT '',
                quantity INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE cart_lines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                variant_key TEXT NOT NULL DEFAULT 'default',
                variant_label TEXT NOT NULL DEFAULT 'Standard',
                selected_size TEXT NOT NULL DEFAULT '',
                selected_color TEXT NOT NULL DEFAULT '',
                quantity INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
            )
            """
        )

    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_cart_lines_user_product_variant
        ON cart_lines(user_id, product_id, variant_key)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_cart_lines_user_updated_at
        ON cart_lines(user_id, updated_at DESC)
        """
    )

    connection.execute(
        """
        UPDATE cart_lines
        SET
            created_at = COALESCE(NULLIF(TRIM(created_at), ''), ?),
            updated_at = COALESCE(NULLIF(TRIM(updated_at), ''), COALESCE(NULLIF(TRIM(created_at), ''), ?)),
            selected_size = COALESCE(selected_size, ''),
            selected_color = COALESCE(selected_color, ''),
            variant_key = COALESCE(NULLIF(TRIM(variant_key), ''), 'default'),
            variant_label = COALESCE(NULLIF(TRIM(variant_label), ''), 'Standard')
        """,
        (now_text_value, now_text_value),
    )

    legacy_cart_rows = connection.execute(
        """
        SELECT
            ci.user_id,
            ci.product_id,
            ci.quantity,
            ci.created_at,
            ci.updated_at,
            p.size,
            p.color
        FROM cart_items ci
        INNER JOIN products p ON p.id = ci.product_id
        """
    ).fetchall()
    for cart_row in legacy_cart_rows:
        variant_key = build_product_variant_key(
            size=str(cart_row["size"] or "").strip().upper(),
            color=str(cart_row["color"] or "").strip().lower(),
        )
        connection.execute(
            """
            INSERT INTO cart_lines (
                user_id,
                product_id,
                variant_key,
                variant_label,
                selected_size,
                selected_color,
                quantity,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, product_id, variant_key)
            DO NOTHING
            """,
            (
                cart_row["user_id"],
                cart_row["product_id"],
                variant_key,
                build_product_variant_label(
                    size=str(cart_row["size"] or "").strip().upper(),
                    color=str(cart_row["color"] or "").strip().lower(),
                ),
                str(cart_row["size"] or "").strip().upper(),
                str(cart_row["color"] or "").strip().lower(),
                max(1, int(cart_row["quantity"] or 1)),
                str(cart_row["created_at"] or "").strip() or now_text_value,
                str(cart_row["updated_at"] or "").strip() or now_text_value,
            ),
        )

    if not column_exists(connection, "orders", "subtotal_amount"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN subtotal_amount REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "orders", "discount_amount"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "orders", "shipping_amount"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN shipping_amount REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "orders", "total_amount"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN total_amount REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "orders", "promo_code"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN promo_code TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "orders", "delivery_method"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN delivery_method TEXT NOT NULL DEFAULT 'standard'"
        )

    if not column_exists(connection, "orders", "delivery_label"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN delivery_label TEXT NOT NULL DEFAULT 'Dergese standard'"
        )

    if not column_exists(connection, "orders", "estimated_delivery_text"):
        connection.execute(
            "ALTER TABLE orders ADD COLUMN estimated_delivery_text TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE orders
        SET
            subtotal_amount = COALESCE(subtotal_amount, 0),
            discount_amount = COALESCE(discount_amount, 0),
            shipping_amount = COALESCE(shipping_amount, 0),
            total_amount = CASE
                WHEN COALESCE(total_amount, 0) > 0 THEN total_amount
                ELSE COALESCE(subtotal_amount, 0)
            END,
            promo_code = COALESCE(promo_code, ''),
            delivery_method = COALESCE(NULLIF(TRIM(delivery_method), ''), 'standard'),
            delivery_label = COALESCE(NULLIF(TRIM(delivery_label), ''), 'Dergese standard'),
            estimated_delivery_text = COALESCE(estimated_delivery_text, '')
        """
    )

    if not column_exists(connection, "order_items", "product_variant_key"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN product_variant_key TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "product_variant_label"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN product_variant_label TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "product_variant_snapshot"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN product_variant_snapshot TEXT NOT NULL DEFAULT '[]'"
        )

    if not column_exists(connection, "order_items", "product_package_amount_value"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN product_package_amount_value REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "order_items", "product_package_amount_unit"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN product_package_amount_unit TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "fulfillment_status"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN fulfillment_status TEXT NOT NULL DEFAULT 'pending_confirmation'"
        )

    if not column_exists(connection, "order_items", "confirmed_at"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN confirmed_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "confirmation_due_at"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN confirmation_due_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "tracking_code"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN tracking_code TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "tracking_url"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN tracking_url TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "shipped_at"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN shipped_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "delivered_at"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN delivered_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "cancelled_at"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN cancelled_at TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "order_items", "commission_rate"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN commission_rate REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "order_items", "commission_amount"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN commission_amount REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "order_items", "seller_earnings_amount"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN seller_earnings_amount REAL NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "order_items", "payout_status"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN payout_status TEXT NOT NULL DEFAULT 'pending'"
        )

    if not column_exists(connection, "order_items", "payout_due_at"):
        connection.execute(
            "ALTER TABLE order_items ADD COLUMN payout_due_at TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE order_items
        SET
            fulfillment_status = CASE
                WHEN LOWER(TRIM(COALESCE(fulfillment_status, ''))) IN ('pending_confirmation', 'confirmed', 'packed', 'shipped', 'delivered', 'cancelled', 'returned')
                    THEN LOWER(TRIM(COALESCE(fulfillment_status, '')))
                ELSE 'pending_confirmation'
            END,
            confirmed_at = COALESCE(confirmed_at, ''),
            confirmation_due_at = COALESCE(confirmation_due_at, ''),
            tracking_code = COALESCE(tracking_code, ''),
            tracking_url = COALESCE(tracking_url, ''),
            shipped_at = COALESCE(shipped_at, ''),
            delivered_at = COALESCE(delivered_at, ''),
            cancelled_at = COALESCE(cancelled_at, ''),
            commission_rate = CASE
                WHEN COALESCE(commission_rate, 0) > 0 THEN commission_rate
                ELSE ?
            END,
            commission_amount = CASE
                WHEN COALESCE(commission_amount, 0) > 0 THEN commission_amount
                ELSE ROUND(((COALESCE(unit_price, 0) * COALESCE(quantity, 0)) * ?) * 100.0) / 100.0
            END,
            seller_earnings_amount = CASE
                WHEN COALESCE(seller_earnings_amount, 0) > 0 THEN seller_earnings_amount
                ELSE ROUND(((COALESCE(unit_price, 0) * COALESCE(quantity, 0)) - (ROUND(((COALESCE(unit_price, 0) * COALESCE(quantity, 0)) * ?) * 100.0) / 100.0)) * 100.0) / 100.0
            END,
            payout_status = CASE
                WHEN LOWER(TRIM(COALESCE(payout_status, ''))) IN ('ready', 'paid', 'on_hold')
                    THEN LOWER(TRIM(COALESCE(payout_status, '')))
                ELSE 'pending'
            END,
            payout_due_at = COALESCE(payout_due_at, '')
        """,
        (MARKETPLACE_COMMISSION_RATE, MARKETPLACE_COMMISSION_RATE, MARKETPLACE_COMMISSION_RATE),
    )

    order_items_with_deadlines = connection.execute(
        """
        SELECT id, created_at, confirmation_due_at
        FROM order_items
        """
    ).fetchall()
    for order_item_row in order_items_with_deadlines:
        created_at_value = parse_storage_datetime(order_item_row["created_at"])
        expected_confirmation_due_at = build_order_item_confirmation_due_at(created_at_value)
        normalized_confirmation_due_at = (
            str(order_item_row["confirmation_due_at"] or "").strip() or expected_confirmation_due_at
        )
        if normalized_confirmation_due_at != str(order_item_row["confirmation_due_at"] or "").strip():
            connection.execute(
                """
                UPDATE order_items
                SET confirmation_due_at = ?
                WHERE id = ?
                """,
                (normalized_confirmation_due_at, order_item_row["id"]),
            )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_order_items_fulfillment_status
        ON order_items(fulfillment_status, created_at DESC)
        """
    )

    if not table_exists(connection, "product_reviews"):
        connection.execute(
            """
            CREATE TABLE product_reviews (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE product_reviews (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER NOT NULL,
                order_id INTEGER NOT NULL,
                order_item_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                business_user_id INTEGER,
                rating INTEGER NOT NULL,
                review_title TEXT NOT NULL DEFAULT '',
                review_body TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'published',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
                FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
            )
            """
        )

    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_product_reviews_order_item_user
        ON product_reviews(order_item_id, user_id)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_product_reviews_product_created
        ON product_reviews(product_id, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_product_reviews_product_status_created
        ON product_reviews(product_id, status, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_product_reviews_business_created
        ON product_reviews(business_user_id, created_at DESC)
        """
    )

    if not table_exists(connection, "return_requests"):
        connection.execute(
            """
            CREATE TABLE return_requests (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE return_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                order_item_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                business_user_id INTEGER,
                reason TEXT NOT NULL DEFAULT '',
                details TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'requested',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                resolved_at TEXT NOT NULL DEFAULT '',
                resolution_notes TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
                FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL
            )
            """
        )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_return_requests_user_created
        ON return_requests(user_id, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_return_requests_business_created
        ON return_requests(business_user_id, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_return_requests_status_created
        ON return_requests(status, created_at DESC)
        """
    )

    if not table_exists(connection, "notifications"):
        connection.execute(
            """
            CREATE TABLE notifications (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                type TEXT NOT NULL DEFAULT 'info',
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                href TEXT NOT NULL DEFAULT '',
                metadata TEXT NOT NULL DEFAULT '{}',
                is_read INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                read_at TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """
        )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_notifications_user_created
        ON notifications(user_id, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_notifications_user_read
        ON notifications(user_id, is_read, created_at DESC)
        """
    )

    if not table_exists(connection, "reports"):
        connection.execute(
            """
            CREATE TABLE reports (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reporter_user_id INTEGER NOT NULL,
                reported_user_id INTEGER,
                business_user_id INTEGER,
                target_type TEXT NOT NULL DEFAULT 'product',
                target_id INTEGER NOT NULL DEFAULT 0,
                target_label TEXT NOT NULL DEFAULT '',
                reason TEXT NOT NULL DEFAULT '',
                details TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'open',
                admin_notes TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                resolved_at TEXT NOT NULL DEFAULT '',
                resolved_by_user_id INTEGER,
                FOREIGN KEY (reporter_user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (reported_user_id) REFERENCES users(id) ON DELETE SET NULL,
                FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL,
                FOREIGN KEY (resolved_by_user_id) REFERENCES users(id) ON DELETE SET NULL
            )
            """
        )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_reports_status_created
        ON reports(status, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
        ON reports(reporter_user_id, created_at DESC)
        """
    )

    if not table_exists(connection, "promo_codes"):
        connection.execute(
            """
            CREATE TABLE promo_codes (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE promo_codes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL DEFAULT '',
                description TEXT NOT NULL DEFAULT '',
                discount_type TEXT NOT NULL DEFAULT 'percent',
                discount_value REAL NOT NULL DEFAULT 0,
                minimum_subtotal REAL NOT NULL DEFAULT 0,
                usage_limit INTEGER NOT NULL DEFAULT 0,
                per_user_limit INTEGER NOT NULL DEFAULT 1,
                is_active INTEGER NOT NULL DEFAULT 1,
                page_section TEXT NOT NULL DEFAULT '',
                category TEXT NOT NULL DEFAULT '',
                business_user_id INTEGER,
                created_by_user_id INTEGER,
                starts_at TEXT NOT NULL DEFAULT '',
                ends_at TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (business_user_id) REFERENCES users(id) ON DELETE SET NULL,
                FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
            )
            """
        )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_promo_codes_active_code
        ON promo_codes(is_active, code)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_promo_codes_business_created
        ON promo_codes(business_user_id, created_at DESC)
        """
    )

    if not table_exists(connection, "stock_reservations"):
        connection.execute(
            """
            CREATE TABLE stock_reservations (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE stock_reservations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                cart_line_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                variant_key TEXT NOT NULL DEFAULT '',
                quantity INTEGER NOT NULL DEFAULT 1,
                expires_at TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
                FOREIGN KEY (cart_line_id) REFERENCES cart_lines(id) ON DELETE CASCADE
            )
            """
        )

    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_reservations_cart_line
        ON stock_reservations(cart_line_id)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_stock_reservations_variant_expiry
        ON stock_reservations(product_id, variant_key, expires_at)
        """
    )

    if not table_exists(connection, "stripe_payment_sessions"):
        connection.execute(
            """
            CREATE TABLE stripe_payment_sessions (
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
            )
            """
            if is_postgres_connection(connection)
            else """
            CREATE TABLE stripe_payment_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                stripe_session_id TEXT NOT NULL UNIQUE,
                user_id INTEGER NOT NULL,
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
                order_id INTEGER,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                confirmed_at TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
            )
            """
        )

    if not column_exists(connection, "stripe_payment_sessions", "discount_amount"):
        connection.execute(
            "ALTER TABLE stripe_payment_sessions ADD COLUMN discount_amount INTEGER NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "stripe_payment_sessions", "promo_code"):
        connection.execute(
            "ALTER TABLE stripe_payment_sessions ADD COLUMN promo_code TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "stripe_payment_sessions", "shipping_amount"):
        connection.execute(
            "ALTER TABLE stripe_payment_sessions ADD COLUMN shipping_amount INTEGER NOT NULL DEFAULT 0"
        )

    if not column_exists(connection, "stripe_payment_sessions", "delivery_method"):
        connection.execute(
            "ALTER TABLE stripe_payment_sessions ADD COLUMN delivery_method TEXT NOT NULL DEFAULT 'standard'"
        )

    if not column_exists(connection, "stripe_payment_sessions", "delivery_label"):
        connection.execute(
            "ALTER TABLE stripe_payment_sessions ADD COLUMN delivery_label TEXT NOT NULL DEFAULT 'Dergese standard'"
        )

    if not column_exists(connection, "stripe_payment_sessions", "estimated_delivery_text"):
        connection.execute(
            "ALTER TABLE stripe_payment_sessions ADD COLUMN estimated_delivery_text TEXT NOT NULL DEFAULT ''"
        )

    connection.execute(
        """
        UPDATE stripe_payment_sessions
        SET
            shipping_amount = COALESCE(shipping_amount, 0),
            promo_code = COALESCE(promo_code, ''),
            delivery_method = COALESCE(NULLIF(TRIM(delivery_method), ''), 'standard'),
            delivery_label = COALESCE(NULLIF(TRIM(delivery_label), ''), 'Dergese standard'),
            estimated_delivery_text = COALESCE(estimated_delivery_text, '')
        """
    )

    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_stripe_payment_sessions_user_created
        ON stripe_payment_sessions(user_id, created_at DESC)
        """
    )
    connection.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_stripe_payment_sessions_order_id
        ON stripe_payment_sessions(order_id)
        """
    )


def column_exists(
    connection: DatabaseConnection,
    table_name: str,
    column_name: str,
) -> bool:
    if is_postgres_connection(connection):
        row = connection.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = ?
              AND column_name = ?
            LIMIT 1
            """,
            (table_name, column_name),
        ).fetchone()
        return bool(row)

    rows = connection.execute(f"PRAGMA table_info({table_name})").fetchall()
    return any(row["name"] == column_name for row in rows)


def table_exists(connection: DatabaseConnection, table_name: str) -> bool:
    if is_postgres_connection(connection):
        row = connection.execute(
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = ?
            LIMIT 1
            """,
            (table_name,),
        ).fetchone()
        return bool(row)

    row = connection.execute(
        """
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name = ?
        LIMIT 1
        """,
        (table_name,),
    ).fetchone()
    return bool(row)


def get_runtime_meta_value(connection: DatabaseConnection, key: str) -> str:
    if not table_exists(connection, "app_runtime_meta"):
        return ""

    row = connection.execute(
        """
        SELECT value
        FROM app_runtime_meta
        WHERE key = ?
        LIMIT 1
        """,
        (str(key or "").strip(),),
    ).fetchone()
    if not row:
        return ""

    return str(row["value"] or "").strip()


def ensure_runtime_meta_table(connection: DatabaseConnection) -> None:
    if table_exists(connection, "app_runtime_meta"):
        return

    connection.execute(
        """
        CREATE TABLE app_runtime_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::text
        )
        """
        if is_postgres_connection(connection)
        else """
        CREATE TABLE app_runtime_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )


def set_runtime_meta_value(connection: DatabaseConnection, key: str, value: str) -> None:
    connection.execute(
        """
        INSERT INTO app_runtime_meta (
            key,
            value,
            updated_at
        )
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(key) DO UPDATE SET
            value = excluded.value,
            updated_at = CURRENT_TIMESTAMP
        """,
        (
            str(key or "").strip(),
            str(value or "").strip(),
        ),
    )


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    iterations = 120_000
    derived_key = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt),
        iterations,
    )
    return f"pbkdf2_sha256${iterations}${salt}${derived_key.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations_text, salt, expected_hash = stored_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False

        iterations = int(iterations_text)
        derived_key = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            bytes.fromhex(salt),
            iterations,
        )
    except (TypeError, ValueError):
        return False

    return secrets.compare_digest(derived_key.hex(), expected_hash)


def utc_now() -> datetime:
    return datetime.utcnow().replace(microsecond=0)


def datetime_to_storage_text(value: datetime) -> str:
    normalized_value = value
    if normalized_value.tzinfo is not None:
        normalized_value = normalized_value.astimezone(timezone.utc).replace(tzinfo=None)

    return normalized_value.replace(microsecond=0).isoformat(sep=" ")


def parse_storage_datetime(value: object) -> datetime | None:
    parsed_value: datetime | None = None

    if isinstance(value, datetime):
        parsed_value = value
    else:
        text = str(value or "").strip()
        if not text:
            return None

        try:
            parsed_value = datetime.fromisoformat(text)
        except ValueError:
            return None

    if parsed_value.tzinfo is not None:
        parsed_value = parsed_value.astimezone(timezone.utc).replace(tzinfo=None)

    return parsed_value.replace(microsecond=0)


def generate_email_verification_code() -> str:
    return "".join(
        secrets.choice("0123456789")
        for _ in range(EMAIL_VERIFICATION_CODE_LENGTH)
    )


def generate_password_reset_code() -> str:
    return "".join(
        secrets.choice("0123456789")
        for _ in range(PASSWORD_RESET_CODE_LENGTH)
    )


def build_email_verification_redirect(email: str) -> str:
    clean_email = str(email or "").strip().lower()
    if not clean_email:
        return "/verifiko-email"
    return f"/verifiko-email?email={quote(clean_email)}"


def build_password_reset_redirect(email: str) -> str:
    clean_email = str(email or "").strip().lower()
    if not clean_email:
        return "/ndrysho-fjalekalimin?mode=reset"
    return f"/ndrysho-fjalekalimin?mode=reset&email={quote(clean_email)}"


def validate_registration(data: dict[str, str]) -> list[str]:
    errors: list[str] = []
    full_name = data.get("fullName", "").strip()
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")
    birth_date = data.get("birthDate", "").strip()
    gender = data.get("gender", "").strip().lower()

    if len(full_name) < 2:
        errors.append("Emri duhet te kete te pakten 2 shkronja.")

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid.")

    errors.extend(validate_password_strength(password, label="Fjalekalimi"))

    if not birth_date:
        errors.append("Zgjedhe daten e lindjes.")
    else:
        try:
            parsed_birth_date = date.fromisoformat(birth_date)
            if parsed_birth_date > date.today():
                errors.append("Data e lindjes nuk mund te jete ne te ardhmen.")
        except ValueError:
            errors.append("Data e lindjes nuk eshte valide.")

    if gender not in GENDER_OPTIONS:
        errors.append("Zgjedhe gjinine.")

    return errors


def validate_login(data: dict[str, str]) -> list[str]:
    errors: list[str] = []
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid.")

    if not password:
        errors.append("Shkruaje fjalekalimin.")

    return errors


def validate_email_verification(data: dict[str, object]) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    email = str(data.get("email", "")).strip().lower()
    code = re.sub(r"\D", "", str(data.get("code", "")))

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid.")

    if len(code) != EMAIL_VERIFICATION_CODE_LENGTH:
        errors.append("Kodi i verifikimit duhet te kete 6 shifra.")

    return errors, {
        "email": email,
        "code": code,
    }


def validate_email_resend(data: dict[str, object]) -> tuple[list[str], str]:
    errors: list[str] = []
    email = str(data.get("email", "")).strip().lower()

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid.")

    return errors, email


def validate_password_strength(password: str, label: str = "Fjalekalimi") -> list[str]:
    errors: list[str] = []
    if len(password) < 8:
        errors.append(f"{label} duhet te kete te pakten 8 karaktere.")
        return errors

    if not re.search(r"[A-Za-z]", password):
        errors.append(f"{label} duhet te permbaje te pakten nje shkronje.")

    if not re.search(r"\d", password):
        errors.append(f"{label} duhet te permbaje te pakten nje numer.")

    if not re.search(r"[^A-Za-z0-9]", password):
        errors.append(f"{label} duhet te permbaje te pakten nje simbol.")

    return errors


def validate_password_reset(data: dict[str, str]) -> list[str]:
    errors: list[str] = []
    email = data.get("email", "").strip().lower()
    code = re.sub(r"\D", "", str(data.get("code", "")))
    new_password = data.get("newPassword", "")
    confirm_password = data.get("confirmPassword", "")

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid.")

    if len(code) != PASSWORD_RESET_CODE_LENGTH:
        errors.append("Kodi per ndryshim te fjalekalimit duhet te kete 6 shifra.")

    errors.extend(validate_password_strength(new_password, label="Fjalekalimi i ri"))

    if new_password != confirm_password:
        errors.append("Konfirmimi i fjalekalimit nuk perputhet.")

    return errors


def validate_account_password_change(data: dict[str, str]) -> list[str]:
    errors: list[str] = []
    current_password = data.get("currentPassword", "")
    new_password = data.get("newPassword", "")
    confirm_password = data.get("confirmPassword", "")

    if not current_password:
        errors.append("Shkruaje fjalekalimin aktual.")

    errors.extend(validate_password_strength(new_password, label="Fjalekalimi i ri"))

    if new_password != confirm_password:
        errors.append("Konfirmimi i fjalekalimit nuk perputhet.")

    if current_password and current_password == new_password:
        errors.append("Fjalekalimi i ri duhet te jete ndryshe nga ai aktual.")

    return errors


def validate_admin_password_reset(data: dict[str, object]) -> list[str]:
    errors: list[str] = []
    new_password = str(data.get("newPassword", ""))

    errors.extend(validate_password_strength(new_password, label="Fjalekalimi i ri"))

    return errors


def validate_account_deletion(data: dict[str, object]) -> list[str]:
    errors: list[str] = []
    password = str(data.get("password", ""))

    if not password:
        errors.append("Shkruaje fjalekalimin per ta fshire llogarine.")

    return errors


def validate_profile_update(data: dict[str, object]) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    first_name = str(data.get("firstName", "")).strip()
    last_name = str(data.get("lastName", "")).strip()
    birth_date = str(data.get("birthDate", "")).strip()
    gender = str(data.get("gender", "")).strip().lower()
    profile_image_path = normalize_image_path(data.get("profileImagePath"))

    if len(first_name) < 2:
        errors.append("Emri duhet te kete te pakten 2 shkronja.")

    if len(last_name) < 2:
        errors.append("Mbiemri duhet te kete te pakten 2 shkronja.")

    if not birth_date:
        errors.append("Zgjedhe daten e lindjes.")
    else:
        try:
            parsed_birth_date = date.fromisoformat(birth_date)
            if parsed_birth_date > date.today():
                errors.append("Data e lindjes nuk mund te jete ne te ardhmen.")
        except ValueError:
            errors.append("Data e lindjes nuk eshte valide.")

    if gender not in GENDER_OPTIONS:
        errors.append("Zgjedhe gjinine.")

    return errors, {
        "first_name": first_name,
        "last_name": last_name,
        "birth_date": birth_date,
        "gender": gender,
        "profile_image_path": profile_image_path,
    }


def validate_address_payload(data: dict[str, object]) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    address_line = str(data.get("addressLine", "")).strip()
    city = str(data.get("city", "")).strip()
    country = str(data.get("country", "")).strip()
    zip_code = str(data.get("zipCode", "")).strip()
    phone_number = str(data.get("phoneNumber", "")).strip()
    normalized_phone = re.sub(r"\s+", " ", phone_number)
    phone_digits = re.sub(r"\D", "", phone_number)

    if len(address_line) < 5:
        errors.append("Adresa e vendbanimit duhet te kete te pakten 5 shkronja.")

    if len(city) < 2:
        errors.append("Qyteti duhet te kete te pakten 2 shkronja.")

    if len(country) < 2:
        errors.append("Shteti duhet te kete te pakten 2 shkronja.")

    if len(zip_code) < 3:
        errors.append("Zip code duhet te kete te pakten 3 karaktere.")

    if len(phone_digits) < 6:
        errors.append("Numri i telefonit duhet te jete valid.")

    return errors, {
        "address_line": address_line,
        "city": city,
        "country": country,
        "zip_code": zip_code,
        "phone_number": normalized_phone,
    }


def validate_business_profile_payload(
    data: dict[str, object],
) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    business_name = str(data.get("businessName", "")).strip()
    business_description = str(data.get("businessDescription", "")).strip()
    business_number = str(data.get("businessNumber", "")).strip()
    phone_number = str(data.get("phoneNumber", "")).strip()
    city = str(data.get("city", "")).strip()
    address_line = str(data.get("addressLine", "")).strip()
    business_logo_path = normalize_image_path(data.get("businessLogoPath", ""))
    normalized_phone = re.sub(r"\s+", " ", phone_number)
    phone_digits = re.sub(r"\D", "", phone_number)
    normalized_business_number = re.sub(r"\s+", " ", business_number)

    if len(business_name) < 2:
        errors.append("Emri i biznesit duhet te kete te pakten 2 shkronja.")

    if len(business_description) < 8:
        errors.append("Pershkrimi i biznesit duhet te kete te pakten 8 shkronja.")

    if len(normalized_business_number) < 2:
        errors.append("Numri i biznesit duhet te kete te pakten 2 karaktere.")

    if len(phone_digits) < 6:
        errors.append("Numri i telefonit te biznesit duhet te jete valid.")

    if len(city) < 2:
        errors.append("Qyteti i biznesit duhet te kete te pakten 2 shkronja.")

    if len(address_line) < 5:
        errors.append("Adresa e biznesit duhet te kete te pakten 5 shkronja.")

    return errors, {
        "business_name": business_name,
        "business_description": business_description,
        "business_number": normalized_business_number,
        "business_logo_path": business_logo_path,
        "phone_number": normalized_phone,
        "city": city,
        "address_line": address_line,
    }


def validate_admin_business_account_payload(
    data: dict[str, object],
) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    full_name = str(data.get("fullName", "")).strip()
    email = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))

    if len(full_name) < 2:
        errors.append("Emri dhe mbiemri duhet te kene te pakten 2 shkronja.")

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid per biznesin.")

    errors.extend(validate_password_strength(password, label="Fjalekalimi"))

    business_errors, business_payload = validate_business_profile_payload(data)
    errors.extend(business_errors)

    return errors, {
        "full_name": full_name,
        "email": email,
        "password": password,
        "business_name": business_payload["business_name"],
        "business_description": business_payload["business_description"],
        "business_number": business_payload["business_number"],
        "phone_number": business_payload["phone_number"],
        "city": business_payload["city"],
        "address_line": business_payload["address_line"],
    }


def normalize_image_path(value: object) -> str:
    raw_path = str(value or "").strip()
    if not raw_path:
        return ""

    if raw_path.startswith(("http://", "https://")):
        return raw_path

    clean_path = raw_path.replace("\\", "/")
    segments = [
        segment.strip()
        for segment in clean_path.split("/")
        if segment.strip() and segment not in {".", ".."}
    ]
    if not segments:
        return ""

    return "/" + "/".join(segments)


def normalize_image_gallery_value(
    raw_value: object,
    *,
    fallback_image_path: object = "",
) -> list[str]:
    candidates: list[object]
    if isinstance(raw_value, (list, tuple)):
        candidates = list(raw_value)
    elif isinstance(raw_value, str):
        stripped_value = raw_value.strip()
        if not stripped_value:
            candidates = []
        else:
            try:
                parsed_value = json.loads(stripped_value)
            except json.JSONDecodeError:
                candidates = [stripped_value]
            else:
                candidates = parsed_value if isinstance(parsed_value, list) else [stripped_value]
    else:
        candidates = []

    image_paths: list[str] = []
    for candidate in candidates:
        normalized_path = normalize_image_path(candidate)
        if normalized_path and normalized_path not in image_paths:
            image_paths.append(normalized_path)

    fallback_path = normalize_image_path(fallback_image_path)
    if not image_paths and fallback_path:
        image_paths.append(fallback_path)

    return image_paths


def derive_section_from_category(category: str | None) -> str | None:
    normalized_category = str(category or "").strip().lower()
    if not normalized_category:
        return None
    if normalized_category == "cosmetics-kids":
        return "cosmetics"

    return CATEGORY_SECTION_MAP.get(normalized_category)


def derive_audience_from_category(category: str | None) -> str | None:
    normalized_category = str(category or "").strip().lower()
    if not normalized_category:
        return None
    if normalized_category == "cosmetics-kids":
        return "women"

    audience = CATEGORY_AUDIENCE_MAP.get(normalized_category, "")
    return audience or None


def build_category_from_section_selection(
    page_section: str | None,
    audience: str | None,
) -> str:
    normalized_section = str(page_section or "").strip().lower()
    normalized_audience = str(audience or "").strip().lower()
    audience_categories = SECTION_AUDIENCE_CATEGORY_MAP.get(normalized_section, {})
    if audience_categories:
        return (
            audience_categories.get(normalized_audience)
            or next(iter(audience_categories.values()), "")
            or normalized_section
        )

    return normalized_section


def normalize_legacy_category(category: str | None) -> str:
    normalized_category = str(category or "").strip().lower()
    if normalized_category == "cosmetics-kids":
      return "cosmetics-women"
    return normalized_category


def category_requires_size_variants(category: str | None) -> bool:
    return str(category or "").strip().lower().startswith("clothing-")


def section_supports_color_inventory(section: str | None) -> bool:
    normalized_section = str(section or "").strip().lower()
    return normalized_section in {"clothing", "home", "sport", "technology"}


def section_supports_package_amount(section: str | None) -> bool:
    return str(section or "").strip().lower() == "cosmetics"


def format_product_color_label(color: str | None) -> str:
    normalized_color = str(color or "").strip().lower()
    return PRODUCT_COLOR_LABELS.get(normalized_color, normalized_color)


def build_product_variant_key(
    *,
    size: str = "",
    color: str = "",
) -> str:
    parts: list[str] = []
    normalized_color = str(color or "").strip().lower()
    normalized_size = str(size or "").strip().upper()
    if normalized_color:
        parts.append(f"color:{normalized_color}")
    if normalized_size:
        parts.append(f"size:{normalized_size}")

    return "|".join(parts) or "default"


LEGACY_PRODUCT_TYPE_ALIASES_BY_SECTION = {
    "clothing": {
        "undershirt": "tshirt",
        "turtleneck": "sweater",
    },
    "cosmetics": {
        "perfumes": "perfume",
        "hygiene": "hand-soap",
        "creams": "face-cream",
        "nails": "nail-care",
        "hair-colors": "hair-cream",
        "kids-care": "body-cream",
    },
    "home": {
        "room-decor": "lamp",
        "bathroom-items": "mirror",
        "bedroom-items": "bed",
        "kids-room-items": "shelf",
    },
    "sport": {
        "sports-equipment": "ball",
        "sportswear": "tracksuit",
        "sports-accessories": "sports-bag",
    },
    "technology": {
        "phone-cases": "phone",
        "phone-parts": "cable",
        "phone-accessories": "charger",
    },
}


def normalize_product_type_for_category(category: str | None, product_type: str | None) -> str:
    normalized_category = normalize_legacy_category(category)
    normalized_product_type = str(product_type or "").strip().lower()
    if not normalized_product_type:
        return ""

    available_types = SHOP_SECTION_PRODUCT_TYPES.get(normalized_category, set())
    if normalized_product_type in available_types:
        return normalized_product_type

    section = derive_section_from_category(normalized_category) or normalized_category
    alias = LEGACY_PRODUCT_TYPE_ALIASES_BY_SECTION.get(section, {}).get(normalized_product_type, "")
    if alias and alias in available_types:
        return alias

    if normalized_category.startswith("clothing-") and normalized_product_type in {"clothing", "other"}:
        return next(iter(available_types), "")

    return normalized_product_type


def build_product_variant_label(
    *,
    size: str = "",
    color: str = "",
) -> str:
    parts: list[str] = []
    normalized_color = str(color or "").strip().lower()
    normalized_size = str(size or "").strip().upper()
    if normalized_color:
        parts.append(format_product_color_label(normalized_color))
    if normalized_size:
        parts.append(normalized_size)

    return " / ".join(parts) or "Standard"


def normalize_variant_inventory_value(
    raw_value: object,
    *,
    category: str,
    fallback_size: str = "",
    fallback_color: str = "",
    fallback_stock_quantity: int = 0,
) -> tuple[list[str], list[dict[str, object]]]:
    errors: list[str] = []
    if isinstance(raw_value, list):
        candidates = list(raw_value)
    elif isinstance(raw_value, str) and raw_value.strip():
        try:
            parsed_value = json.loads(raw_value)
        except json.JSONDecodeError:
            candidates = []
        else:
            candidates = parsed_value if isinstance(parsed_value, list) else []
    else:
        candidates = []

    requires_size = category_requires_size_variants(category)
    allows_color = section_supports_color_inventory(derive_section_from_category(category) or "")
    normalized_entries: list[dict[str, object]] = []
    seen_keys: set[str] = set()

    for index, candidate in enumerate(candidates, start=1):
        if not isinstance(candidate, dict):
            errors.append(f"Varianti #{index} nuk eshte valid.")
            continue

        size = str(candidate.get("size", "")).strip().upper()
        color = str(candidate.get("color", "")).strip().lower()
        raw_quantity = str(candidate.get("quantity", "")).strip()

        if requires_size and size and size not in CLOTHING_SIZES:
            errors.append(f"Madhesia `{size}` nuk eshte valide te varianti #{index}.")
            continue
        if not requires_size:
            size = ""

        if color and color not in PRODUCT_COLORS:
            errors.append(f"Ngjyra `{color}` nuk eshte valide te varianti #{index}.")
            continue
        if not allows_color:
            color = ""

        try:
            quantity = int(raw_quantity)
        except ValueError:
            errors.append(f"Sasia e variantit #{index} duhet te jete numer i plote.")
            continue

        if quantity < 0:
            errors.append(f"Sasia e variantit #{index} nuk mund te jete negative.")
            continue

        variant_key = build_product_variant_key(size=size, color=color)
        if variant_key in seen_keys:
            errors.append(f"Varianti `{build_product_variant_label(size=size, color=color)}` eshte perseritur.")
            continue

        seen_keys.add(variant_key)
        normalized_entries.append(
            {
                "key": variant_key,
                "size": size,
                "color": color,
                "quantity": quantity,
                "label": build_product_variant_label(size=size, color=color),
            }
        )

    if normalized_entries:
        return errors, normalized_entries

    normalized_fallback_size = str(fallback_size or "").strip().upper()
    normalized_fallback_color = str(fallback_color or "").strip().lower()
    if requires_size and normalized_fallback_size and normalized_fallback_size not in CLOTHING_SIZES:
        normalized_fallback_size = ""
    if normalized_fallback_color and normalized_fallback_color not in PRODUCT_COLORS:
        normalized_fallback_color = ""
    if not requires_size:
        normalized_fallback_size = ""
    if not allows_color:
        normalized_fallback_color = ""

    fallback_quantity = max(0, int(fallback_stock_quantity or 0))
    if fallback_quantity <= 0:
        return errors, []

    return errors, [
        {
            "key": build_product_variant_key(
                size=normalized_fallback_size,
                color=normalized_fallback_color,
            ),
            "size": normalized_fallback_size,
            "color": normalized_fallback_color,
            "quantity": fallback_quantity,
            "label": build_product_variant_label(
                size=normalized_fallback_size,
                color=normalized_fallback_color,
            ),
        }
    ]


def parse_package_amount_payload(
    data: dict[str, object],
    *,
    page_section: str,
) -> tuple[list[str], float, str]:
    errors: list[str] = []
    raw_value = str(data.get("packageAmountValue", "")).strip()
    amount_unit = str(data.get("packageAmountUnit", "")).strip().lower()

    if not section_supports_package_amount(page_section):
        return errors, 0.0, ""

    if not raw_value and not amount_unit:
        errors.append("Vendose sasine e produktit ne ml ose L.")
        return errors, 0.0, ""

    if amount_unit not in PRODUCT_AMOUNT_UNITS:
        errors.append("Njesia e sasise duhet te jete ml ose L.")
        return errors, 0.0, ""

    try:
        amount_value = round(float(raw_value), 2)
    except ValueError:
        errors.append("Sasia e produktit duhet te jete numer valid.")
        return errors, 0.0, amount_unit

    if amount_value <= 0:
        errors.append("Sasia e produktit duhet te jete me e madhe se zero.")

    return errors, amount_value, amount_unit


def validate_product_payload(data: dict[str, object]) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    article_number = str(data.get("articleNumber", "")).strip()
    title = str(data.get("title", "")).strip()
    description = str(data.get("description", "")).strip()
    page_section = str(data.get("pageSection", "")).strip().lower()
    audience = str(data.get("audience", "")).strip().lower()
    category = str(data.get("category", "")).strip().lower()
    if page_section:
        category = build_category_from_section_selection(page_section, audience)
    elif category:
        page_section = derive_section_from_category(category) or ""
        audience = derive_audience_from_category(category) or ""
        category = normalize_legacy_category(category) or build_category_from_section_selection(page_section, audience)
    else:
        category = build_category_from_section_selection("clothing", "men")
        page_section = derive_section_from_category(category) or "clothing"
        audience = derive_audience_from_category(category) or "men"
    category = normalize_legacy_category(category)
    product_type = normalize_product_type_for_category(category, data.get("productType", ""))
    size = str(data.get("size", "")).strip().upper()
    color = str(data.get("color", "")).strip().lower()
    image_gallery = normalize_image_gallery_value(
        data.get("imageGallery"),
        fallback_image_path=data.get("imagePath", ""),
    )
    image_path = image_gallery[0] if image_gallery else ""
    price_text = str(data.get("price", "")).strip()
    stock_quantity_text = str(data.get("stockQuantity", "")).strip()
    price = 0.0
    stock_quantity = 0

    if len(title) < 2:
        errors.append("Titulli duhet te kete te pakten 2 shkronja.")

    if len(description) < 3:
        errors.append("Pershkrimi duhet te kete te pakten 3 shkronja.")

    if category not in PRODUCT_CATEGORIES:
        errors.append("Zgjidh nje kategori valide.")

    if category in SHOP_SECTION_PRODUCT_TYPES:
        if product_type not in SHOP_SECTION_PRODUCT_TYPES[category]:
            errors.append("Zgjidh nje kategori valide te produktit.")
    elif product_type not in PRODUCT_TYPES:
        errors.append("Zgjidh nje kategori valide te produktit.")

    if not image_path:
        errors.append("Ngarko te pakten nje foto te produktit.")

    try:
        price = round(float(price_text), 2)
        if price <= 0:
            errors.append("Cmimi duhet te jete me i madh se zero.")
    except ValueError:
        errors.append("Cmimi duhet te jete numer valid.")

    try:
        stock_quantity = int(stock_quantity_text)
        if stock_quantity < 0:
            errors.append("Sasia ne stok nuk mund te jete negative.")
    except ValueError:
        errors.append("Sasia ne stok duhet te jete numer i plote.")

    requires_size = category_requires_size_variants(category)
    if requires_size and size and size not in CLOTHING_SIZES:
        errors.append("Per veshje zgjidh nje madhesi valide nga XS deri ne XXXL.")
        size = ""

    if color and color not in PRODUCT_COLORS:
        errors.append("Zgjidh nje ngjyre valide te produktit.")
        color = ""

    package_amount_errors, package_amount_value, package_amount_unit = parse_package_amount_payload(
        data,
        page_section=page_section,
    )
    errors.extend(package_amount_errors)

    variant_errors, variant_inventory = normalize_variant_inventory_value(
        data.get("variantInventory"),
        category=category,
        fallback_size=size,
        fallback_color=color,
        fallback_stock_quantity=stock_quantity,
    )
    errors.extend(variant_errors)

    if requires_size and not any(str(entry.get("size", "")).strip() for entry in variant_inventory):
        errors.append("Per veshje zgjidh te pakten nje madhesi dhe sasin e saj ne stok.")

    if requires_size and not any(
        str(entry.get("color", "")).strip() for entry in variant_inventory
    ):
        errors.append("Zgjidh te pakten nje ngjyre dhe cakto stokun e saj.")

    stock_quantity = sum(max(0, int(entry["quantity"])) for entry in variant_inventory)

    unique_sizes = sorted(
        {
            str(entry.get("size", "")).strip().upper()
            for entry in variant_inventory
            if str(entry.get("size", "")).strip()
        }
    )
    unique_colors = sorted(
        {
            str(entry.get("color", "")).strip().lower()
            for entry in variant_inventory
            if str(entry.get("color", "")).strip()
        }
    )

    size = unique_sizes[0] if len(unique_sizes) == 1 else ""
    if len(unique_colors) == 1:
        color = unique_colors[0]
    elif len(unique_colors) > 1:
        color = "shume-ngjyra" if "shume-ngjyra" in PRODUCT_COLORS else ""
    else:
        color = ""

    return errors, {
        "articleNumber": article_number,
        "title": title,
        "description": description,
        "pageSection": page_section,
        "audience": audience,
        "category": category,
        "productType": product_type,
        "size": size,
        "color": color,
        "variantInventory": variant_inventory,
        "imagePath": image_path,
        "imageGallery": image_gallery,
        "price": price,
        "packageAmountValue": package_amount_value,
        "packageAmountUnit": package_amount_unit,
        "stockQuantity": stock_quantity,
    }


PRODUCT_IMPORT_TEMPLATE_ROWS = [
    {
        "articleNumber": "10025",
        "title": "Maica e kuqe per meshkuj",
        "description": "Maice pambuku per perdorim te perditshem.",
        "price": "19.90",
        "pageSection": "clothing",
        "audience": "men",
        "category": "clothing-men",
        "productType": "tshirt",
        "size": "L",
        "color": "kuqe",
        "packageAmountValue": "",
        "packageAmountUnit": "",
        "stockQuantity": "12",
        "imagePath": "/uploads/shembull-maice-kuqe.jpg",
        "imageGallery": "/uploads/shembull-maice-kuqe.jpg;/uploads/shembull-maice-kuqe-2.jpg",
    },
    {
        "articleNumber": "20014",
        "title": "Krem per duar",
        "description": "Krem hidratues per duar me perdorim ditor.",
        "price": "6.50",
        "pageSection": "cosmetics",
        "audience": "women",
        "category": "cosmetics-women",
        "productType": "hand-cream",
        "size": "",
        "color": "",
        "packageAmountValue": "250",
        "packageAmountUnit": "ml",
        "stockQuantity": "30",
        "imagePath": "/uploads/shembull-krem-duar.jpg",
        "imageGallery": "/uploads/shembull-krem-duar.jpg",
    },
    {
        "articleNumber": "30008",
        "title": "Tavoline per sallon",
        "description": "Tavoline moderne per sallon me siperfaqe druri.",
        "price": "129.00",
        "pageSection": "home",
        "audience": "",
        "category": "home",
        "productType": "table",
        "size": "",
        "color": "kafe",
        "packageAmountValue": "",
        "packageAmountUnit": "",
        "stockQuantity": "4",
        "imagePath": "/uploads/shembull-tavoline.jpg",
        "imageGallery": "/uploads/shembull-tavoline.jpg;/uploads/shembull-tavoline-2.jpg",
    },
    {
        "articleNumber": "50003",
        "title": "Ndegjues wireless",
        "description": "Ndegjues pa kabllo me bateri te gjate.",
        "price": "39.90",
        "pageSection": "technology",
        "audience": "",
        "category": "technology",
        "productType": "headphones",
        "size": "",
        "color": "zeze",
        "packageAmountValue": "",
        "packageAmountUnit": "",
        "stockQuantity": "15",
        "imagePath": "/uploads/shembull-ndegjues.jpg",
        "imageGallery": "/uploads/shembull-ndegjues.jpg",
    },
]
OOXML_SPREADSHEET_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
OOXML_PACKAGE_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
OOXML_DOCUMENT_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def build_product_import_template_csv() -> str:
    output = StringIO()
    writer = csv.DictWriter(output, fieldnames=PRODUCT_IMPORT_FIELDNAMES)
    writer.writeheader()
    for row in PRODUCT_IMPORT_TEMPLATE_ROWS:
        writer.writerow(row)
    return output.getvalue()


def _spreadsheet_column_name(column_number: int) -> str:
    letters: list[str] = []
    current = max(1, int(column_number))
    while current > 0:
        current, remainder = divmod(current - 1, 26)
        letters.append(chr(65 + remainder))
    return "".join(reversed(letters))


def _build_xlsx_worksheet_xml(rows: list[list[str]]) -> bytes:
    ET.register_namespace("", OOXML_SPREADSHEET_NS)
    worksheet = ET.Element(f"{{{OOXML_SPREADSHEET_NS}}}worksheet")
    sheet_data = ET.SubElement(worksheet, f"{{{OOXML_SPREADSHEET_NS}}}sheetData")

    for row_index, row_values in enumerate(rows, start=1):
        row_element = ET.SubElement(
            sheet_data,
            f"{{{OOXML_SPREADSHEET_NS}}}row",
            {"r": str(row_index)},
        )
        for column_index, raw_value in enumerate(row_values, start=1):
            value = str(raw_value or "")
            cell = ET.SubElement(
                row_element,
                f"{{{OOXML_SPREADSHEET_NS}}}c",
                {
                    "r": f"{_spreadsheet_column_name(column_index)}{row_index}",
                    "t": "inlineStr",
                },
            )
            inline_string = ET.SubElement(cell, f"{{{OOXML_SPREADSHEET_NS}}}is")
            text_node = ET.SubElement(inline_string, f"{{{OOXML_SPREADSHEET_NS}}}t")
            if value.strip() != value:
                text_node.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
            text_node.text = value

    return ET.tostring(worksheet, encoding="utf-8", xml_declaration=True)


def build_product_import_template_xlsx() -> bytes:
    sheet_rows = [
        PRODUCT_IMPORT_FIELDNAMES,
        *[
            [str(row.get(field, "") or "") for field in PRODUCT_IMPORT_FIELDNAMES]
            for row in PRODUCT_IMPORT_TEMPLATE_ROWS
        ],
    ]

    workbook_xml = """<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Produkte" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
"""
    workbook_rels_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>
"""
    root_rels_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"""
    content_types_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"""
    app_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>TREGO</Application>
</Properties>
"""
    current_timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    core_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>TREGO Product Import Template</dc:title>
  <dc:creator>TREGO</dc:creator>
  <cp:lastModifiedBy>TREGO</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{current_timestamp}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{current_timestamp}</dcterms:modified>
</cp:coreProperties>
"""

    output = BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types_xml)
        archive.writestr("_rels/.rels", root_rels_xml)
        archive.writestr("docProps/app.xml", app_xml)
        archive.writestr("docProps/core.xml", core_xml)
        archive.writestr("xl/workbook.xml", workbook_xml)
        archive.writestr("xl/_rels/workbook.xml.rels", workbook_rels_xml)
        archive.writestr("xl/worksheets/sheet1.xml", _build_xlsx_worksheet_xml(sheet_rows))
    return output.getvalue()


def _normalize_product_import_records(
    raw_rows: list[dict[str, object]],
) -> tuple[list[str], list[dict[str, object]]]:
    parsed_rows: list[dict[str, object]] = []
    errors: list[str] = []

    for index, raw_row in enumerate(raw_rows, start=2):
        normalized_row = {
            field: str((raw_row or {}).get(field, "") or "").strip()
            for field in PRODUCT_IMPORT_FIELDNAMES
        }
        if not any(normalized_row.values()):
            continue

        image_gallery_values = [
            normalize_image_path(value)
            for value in re.split(r"[;\n\r|]+", normalized_row["imageGallery"])
            if normalize_image_path(value)
        ]
        image_path = normalize_image_path(normalized_row["imagePath"])
        payload = {
            "articleNumber": normalized_row["articleNumber"],
            "title": normalized_row["title"],
            "description": normalized_row["description"],
            "pageSection": normalized_row["pageSection"],
            "audience": normalized_row["audience"],
            "price": normalized_row["price"],
            "category": normalized_row["category"],
            "productType": normalized_row["productType"],
            "size": normalized_row["size"],
            "color": normalized_row["color"],
            "packageAmountValue": normalized_row["packageAmountValue"],
            "packageAmountUnit": normalized_row["packageAmountUnit"],
            "stockQuantity": normalized_row["stockQuantity"],
            "imagePath": image_path,
            "imageGallery": image_gallery_values or ([image_path] if image_path else []),
        }
        row_errors, normalized_product = validate_product_payload(payload)
        if row_errors:
            errors.append(f"Rreshti {index}: {' '.join(row_errors)}")
            continue

        parsed_rows.append(normalized_product)
        if len(parsed_rows) > PRODUCT_IMPORT_MAX_ROWS:
            errors.append(f"Mund te importosh deri ne {PRODUCT_IMPORT_MAX_ROWS} produkte njeheresh.")
            break

    if not parsed_rows and not errors:
        errors.append("Skedari nuk permban asnje produkt valid.")

    return errors, parsed_rows


def parse_product_import_csv(file_bytes: bytes) -> tuple[list[str], list[dict[str, object]]]:
    if not file_bytes:
        return ["Skedari i importit eshte bosh."], []

    try:
        raw_text = file_bytes.decode("utf-8-sig")
    except UnicodeDecodeError:
        return ["Skedari duhet te jete CSV ne UTF-8 qe hapet ne Excel."], []

    if not raw_text.strip():
        return ["Skedari i importit eshte bosh."], []

    reader = csv.DictReader(StringIO(raw_text))
    if not reader.fieldnames:
        return ["Skedari CSV nuk ka header."], []

    normalized_headers = [str(field or "").strip() for field in reader.fieldnames]
    missing_headers = [field for field in PRODUCT_IMPORT_FIELDNAMES if field not in normalized_headers]
    if missing_headers:
        return [f"Mungojne kolonat: {', '.join(missing_headers)}."], []

    return _normalize_product_import_records(list(reader))


def _spreadsheet_column_index(cell_reference: str) -> int:
    letters = "".join(character for character in str(cell_reference or "") if character.isalpha()).upper()
    index = 0
    for character in letters:
        index = (index * 26) + (ord(character) - 64)
    return max(1, index)


def _read_xlsx_cell_value(cell: ET.Element, shared_strings: list[str]) -> str:
    cell_type = str(cell.attrib.get("t", "") or "").strip()
    if cell_type == "inlineStr":
        return "".join(text for text in cell.itertext()).strip()

    if cell_type == "s":
        value_node = cell.find(f"{{{OOXML_SPREADSHEET_NS}}}v")
        if value_node is None or value_node.text is None:
            return ""
        try:
            shared_index = int(str(value_node.text).strip())
        except ValueError:
            return ""
        return shared_strings[shared_index] if 0 <= shared_index < len(shared_strings) else ""

    value_node = cell.find(f"{{{OOXML_SPREADSHEET_NS}}}v")
    if value_node is None or value_node.text is None:
        return ""
    return str(value_node.text).strip()


def parse_product_import_xlsx(file_bytes: bytes) -> tuple[list[str], list[dict[str, object]]]:
    if not file_bytes:
        return ["Skedari i importit eshte bosh."], []

    try:
        workbook_archive = zipfile.ZipFile(BytesIO(file_bytes))
    except zipfile.BadZipFile:
        return ["Skedari XLSX nuk u lexua dot. Provo nje skedar valid te Excel-it."], []

    with workbook_archive:
        try:
            worksheet_xml = workbook_archive.read("xl/worksheets/sheet1.xml")
        except KeyError:
            return ["Skedari XLSX nuk ka nje worksheet te vlefshem."], []

        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in workbook_archive.namelist():
            shared_root = ET.fromstring(workbook_archive.read("xl/sharedStrings.xml"))
            for node in shared_root.findall(f".//{{{OOXML_SPREADSHEET_NS}}}si"):
                shared_strings.append("".join(text for text in node.itertext()).strip())

    worksheet_root = ET.fromstring(worksheet_xml)
    row_nodes = worksheet_root.findall(f".//{{{OOXML_SPREADSHEET_NS}}}sheetData/{{{OOXML_SPREADSHEET_NS}}}row")
    if not row_nodes:
        return ["Skedari XLSX eshte bosh."], []

    extracted_rows: list[list[str]] = []
    for row_node in row_nodes:
        cells_by_index: dict[int, str] = {}
        max_column_index = 0
        for cell in row_node.findall(f"{{{OOXML_SPREADSHEET_NS}}}c"):
            column_index = _spreadsheet_column_index(cell.attrib.get("r", ""))
            max_column_index = max(max_column_index, column_index)
            cells_by_index[column_index] = _read_xlsx_cell_value(cell, shared_strings)

        if max_column_index <= 0:
            continue

        extracted_rows.append(
            [cells_by_index.get(column_index, "") for column_index in range(1, max_column_index + 1)]
        )

    if not extracted_rows:
        return ["Skedari XLSX eshte bosh."], []

    headers = [str(value or "").strip() for value in extracted_rows[0]]
    missing_headers = [field for field in PRODUCT_IMPORT_FIELDNAMES if field not in headers]
    if missing_headers:
        return [f"Mungojne kolonat: {', '.join(missing_headers)}."], []

    records: list[dict[str, object]] = []
    for row_values in extracted_rows[1:]:
        record = {}
        for header_index, header in enumerate(headers):
            if not header:
                continue
            record[header] = row_values[header_index] if header_index < len(row_values) else ""
        records.append(record)

    return _normalize_product_import_records(records)


def parse_product_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_product_id = str(data.get("productId", "")).strip()

    try:
        product_id = int(raw_product_id)
        if product_id <= 0:
            errors.append("Produkti i zgjedhur nuk eshte valid.")
    except ValueError:
        product_id = None
        errors.append("Produkti i zgjedhur nuk eshte valid.")

    return errors, product_id


def parse_cart_line_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_cart_line_id = str(
        data.get("cartLineId", "")
        or data.get("cartItemId", "")
        or data.get("productId", "")
    ).strip()

    try:
        cart_line_id = int(raw_cart_line_id)
        if cart_line_id <= 0:
            errors.append("Artikulli i shportes nuk eshte valid.")
    except ValueError:
        cart_line_id = None
        errors.append("Artikulli i shportes nuk eshte valid.")

    return errors, cart_line_id


def parse_product_id_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], int | None]:
    return parse_product_id(
        {"productId": query_params.get("id", [""])[0] or query_params.get("productId", [""])[0]}
    )


def parse_user_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_user_id = str(data.get("userId", "")).strip()

    try:
        user_id = int(raw_user_id)
        if user_id <= 0:
            errors.append("Perdoruesi i zgjedhur nuk eshte valid.")
    except ValueError:
        user_id = None
        errors.append("Perdoruesi i zgjedhur nuk eshte valid.")

    return errors, user_id


def parse_business_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_business_id = str(data.get("businessId", "")).strip()

    try:
        business_id = int(raw_business_id)
        if business_id <= 0:
            errors.append("Biznesi i zgjedhur nuk eshte valid.")
    except ValueError:
        business_id = None
        errors.append("Biznesi i zgjedhur nuk eshte valid.")

    return errors, business_id


def parse_business_id_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], int | None]:
    return parse_business_id(
        {
            "businessId": query_params.get("id", [""])[0]
            or query_params.get("businessId", [""])[0]
        }
    )


def parse_order_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_order_id = str(data.get("orderId", "")).strip()

    try:
        order_id = int(raw_order_id)
        if order_id <= 0:
            errors.append("Porosia e zgjedhur nuk eshte valide.")
    except ValueError:
        order_id = None
        errors.append("Porosia e zgjedhur nuk eshte valide.")

    return errors, order_id


def parse_order_id_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], int | None]:
    return parse_order_id(
        {
            "orderId": query_params.get("id", [""])[0]
            or query_params.get("orderId", [""])[0]
        }
    )


def parse_order_item_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_order_item_id = str(data.get("orderItemId", "")).strip()

    try:
        order_item_id = int(raw_order_item_id)
        if order_item_id <= 0:
            errors.append("Artikulli i porosise nuk eshte valid.")
    except ValueError:
        order_item_id = None
        errors.append("Artikulli i porosise nuk eshte valid.")

    return errors, order_item_id


def parse_return_request_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_return_request_id = str(data.get("returnRequestId", "")).strip()

    try:
        return_request_id = int(raw_return_request_id)
        if return_request_id <= 0:
            errors.append("Kerkesa per kthim nuk eshte valide.")
    except ValueError:
        return_request_id = None
        errors.append("Kerkesa per kthim nuk eshte valide.")

    return errors, return_request_id


def parse_report_id(data: dict[str, object]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_report_id = str(data.get("reportId", "")).strip()

    try:
        report_id = int(raw_report_id)
        if report_id <= 0:
            errors.append("Raportimi nuk eshte valid.")
    except ValueError:
        report_id = None
        errors.append("Raportimi nuk eshte valid.")

    return errors, report_id


def parse_report_target_type(data: dict[str, object]) -> tuple[list[str], str]:
    normalized_type = str(data.get("targetType", "")).strip().lower()
    if normalized_type not in REPORT_TARGET_TYPES:
        return ["Objekti i raportimit nuk eshte valid."], ""
    return [], normalized_type


def parse_report_status(data: dict[str, object]) -> tuple[list[str], str]:
    normalized_status = str(data.get("status", "")).strip().lower()
    if normalized_status not in REPORT_STATUSES:
        return ["Statusi i raportimit nuk eshte valid."], ""
    return [], normalized_status


def parse_promo_code(data: dict[str, object], *, field_name: str = "promoCode") -> tuple[list[str], str]:
    promo_code = str(data.get(field_name, "") or "").strip().upper()
    if not promo_code:
        return [], ""
    if len(promo_code) > 40:
        return ["Kodi promocional nuk eshte valid."], ""
    return [], promo_code


def parse_promo_code_type(data: dict[str, object]) -> tuple[list[str], str]:
    normalized_type = str(data.get("discountType", "")).strip().lower()
    if normalized_type not in PROMO_CODE_TYPES:
        return ["Lloji i kuponit nuk eshte valid."], ""
    return [], normalized_type


def parse_conversation_id(
    data: dict[str, object],
) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_conversation_id = str(data.get("conversationId", "")).strip()

    try:
        conversation_id = int(raw_conversation_id)
        if conversation_id <= 0:
            errors.append("Biseda e zgjedhur nuk eshte valide.")
    except ValueError:
        conversation_id = None
        errors.append("Biseda e zgjedhur nuk eshte valide.")

    return errors, conversation_id


def parse_conversation_id_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], int | None]:
    return parse_conversation_id(
        {
            "conversationId": query_params.get("conversationId", [""])[0]
            or query_params.get("id", [""])[0]
        }
    )


def parse_chat_message_body(
    data: dict[str, object],
) -> tuple[list[str], str]:
    message_body = str(data.get("body", "") or "").strip()
    errors: list[str] = []

    if not message_body:
        errors.append("Shkruaje mesazhin para se ta dergosh.")
        return errors, ""

    if len(message_body) > CHAT_MESSAGE_MAX_LENGTH:
        errors.append(
            f"Mesazhi nuk duhet te kete me shume se {CHAT_MESSAGE_MAX_LENGTH} karaktere."
        )

    return errors, message_body


def parse_chat_message_id(
    data: dict[str, object],
) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_message_id = str(data.get("messageId", "")).strip()

    try:
        message_id = int(raw_message_id)
        if message_id <= 0:
            errors.append("Mesazhi i zgjedhur nuk eshte valid.")
    except ValueError:
        message_id = None
        errors.append("Mesazhi i zgjedhur nuk eshte valid.")

    return errors, message_id


def parse_chat_typing_state(data: dict[str, object]) -> bool:
    raw_value = str(data.get("isTyping", "1") or "1").strip().lower()
    return raw_value not in {"0", "false", "no", "off", "jo"}


def build_chat_attachment_payload_from_part(part) -> tuple[list[str], dict[str, object] | None]:
    if not part or not part.get_filename():
        return [], None

    original_filename = str(part.get_filename() or "").strip()
    content_type = str(part.get_content_type() or "").strip().lower()
    file_bytes = part.get_payload(decode=True) or b""
    errors: list[str] = []

    if not content_type or content_type not in CHAT_ATTACHMENT_ALLOWED_CONTENT_TYPES:
        errors.append("Chat supporton vetem foto, video, audio dhe PDF.")
        return errors, None

    if not file_bytes:
        errors.append("Skedari i bashkelidhur eshte bosh.")
        return errors, None

    if len(file_bytes) > CHAT_ATTACHMENT_MAX_FILE_SIZE:
        errors.append("Attachment-i i chat-it eshte shume i madh.")
        return errors, None

    extension = CHAT_ATTACHMENT_ALLOWED_CONTENT_TYPES.get(content_type, "")
    if not extension:
        extension = Path(original_filename).suffix.lower()

    if not extension:
        errors.append("Skedari i bashkelidhur nuk ka format valid.")
        return errors, None

    return errors, {
        "original_filename": original_filename or f"attachment{extension}",
        "content_type": content_type,
        "file_bytes": file_bytes,
        "extension": extension,
    }


def parse_product_ids(
    data: dict[str, object],
    field_name: str = "productIds",
) -> tuple[list[str], list[int]]:
    raw_value = data.get(field_name)
    if isinstance(raw_value, list):
        raw_candidates = raw_value
    elif raw_value is None or raw_value == "":
        raw_candidates = []
    else:
        raw_candidates = [raw_value]

    product_ids: list[int] = []
    errors: list[str] = []

    for raw_candidate in raw_candidates:
        try:
            product_id = int(str(raw_candidate).strip())
        except ValueError:
            errors.append("Lista e produkteve per porosi nuk eshte valide.")
            continue

        if product_id <= 0:
            errors.append("Lista e produkteve per porosi nuk eshte valide.")
            continue

        if product_id not in product_ids:
            product_ids.append(product_id)

    if not product_ids:
        errors.append("Zgjidh te pakten nje produkt per te vazhduar me porosi.")

    return errors, product_ids


def parse_cart_line_ids(
    data: dict[str, object],
    field_name: str = "cartItemIds",
) -> tuple[list[str], list[int]]:
    raw_value = data.get(field_name)
    if raw_value is None and field_name != "productIds":
        raw_value = data.get("productIds")

    if isinstance(raw_value, list):
        raw_candidates = raw_value
    elif raw_value is None or raw_value == "":
        raw_candidates = []
    else:
        raw_candidates = [raw_value]

    cart_line_ids: list[int] = []
    errors: list[str] = []
    for raw_candidate in raw_candidates:
        try:
            cart_line_id = int(str(raw_candidate).strip())
        except ValueError:
            errors.append("Lista e artikujve te shportes nuk eshte valide.")
            continue

        if cart_line_id <= 0:
            errors.append("Lista e artikujve te shportes nuk eshte valide.")
            continue

        if cart_line_id not in cart_line_ids:
            cart_line_ids.append(cart_line_id)

    if not cart_line_ids:
        errors.append("Zgjidh te pakten nje artikull ne shporte per te vazhduar me porosi.")

    return errors, cart_line_ids


def parse_products_pagination_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], int, int]:
    errors: list[str] = []
    raw_limit = str(query_params.get("limit", [""])[0]).strip()
    raw_offset = str(query_params.get("offset", [""])[0]).strip()

    limit = PRODUCTS_PAGE_DEFAULT_LIMIT
    offset = 0

    if raw_limit:
        try:
            parsed_limit = int(raw_limit)
            if parsed_limit <= 0:
                errors.append("Limiti i produkteve duhet te jete me i madh se 0.")
            else:
                limit = min(parsed_limit, PRODUCTS_PAGE_MAX_LIMIT)
        except ValueError:
            errors.append("Limiti i produkteve nuk eshte valid.")

    if raw_offset:
        try:
            parsed_offset = int(raw_offset)
            if parsed_offset < 0:
                errors.append("Offset-i i produkteve nuk mund te jete negativ.")
            else:
                offset = parsed_offset
        except ValueError:
            errors.append("Offset-i i produkteve nuk eshte valid.")

    return errors, limit, offset


def parse_include_facets_query(query_params: dict[str, list[str]]) -> bool:
    raw_value = str(query_params.get("includeFacets", [""])[0]).strip().lower()
    if not raw_value:
        return False

    return raw_value in {"1", "true", "yes", "on"}


def parse_catalog_filters_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], str | None, str | None, str | None]:
    errors: list[str] = []
    product_type = str(query_params.get("productType", [""])[0]).strip().lower() or None
    size = str(query_params.get("size", [""])[0]).strip().upper() or None
    color = str(query_params.get("color", [""])[0]).strip().lower() or None

    if product_type and product_type not in PRODUCT_TYPES:
        errors.append("Lloji i produktit nuk eshte valid.")

    if size and size not in CLOTHING_SIZES:
        errors.append("Madhesia nuk eshte valide.")

    if color and color not in PRODUCT_COLORS:
        errors.append("Ngjyra nuk eshte valide.")

    return errors, product_type, size, color


def parse_catalog_scope_query(
    query_params: dict[str, list[str]],
) -> tuple[list[str], str | None, str | None, str | None, str | None]:
    errors: list[str] = []
    page_section = str(query_params.get("pageSection", [""])[0]).strip().lower() or None
    audience = str(query_params.get("audience", [""])[0]).strip().lower() or None
    category: str | None = None
    category_group: str | None = None

    known_sections = {
        str(section.get("value") or "").strip().lower()
        for section in PRODUCT_SECTION_DEFINITIONS
        if str(section.get("value") or "").strip()
    }

    if page_section and page_section not in known_sections:
        errors.append("Kategoria e faqes nuk eshte valide.")
        return errors, None, None, None, None

    if not page_section:
        return errors, None, None, None, None

    audience_categories = SECTION_AUDIENCE_CATEGORY_MAP.get(page_section, {})
    if audience_categories:
        if audience:
            if audience not in audience_categories:
                errors.append("Nenkategoria e zgjedhur nuk eshte valide.")
            else:
                category = build_category_from_section_selection(page_section, audience)
        else:
            category_group = page_section
    else:
        if audience:
            errors.append("Kjo kategori e faqes nuk ka nenkategori.")
        category = page_section

    return errors, page_section, audience, category, category_group


def normalize_search_intent_text(value: str) -> str:
    return re.sub(r"\s+", " ", str(value or "").strip().lower())


def tokenize_search_intent_text(value: str) -> list[str]:
    return [token for token in re.split(r"[^a-zA-Z0-9\-]+", normalize_search_intent_text(value)) if token]


def derive_category_group_from_category(category: str | None) -> str | None:
    if not category:
        return None
    if category.startswith("clothing-"):
        return "clothing"
    if category.startswith("cosmetics-"):
        return "cosmetics"
    return None


def infer_category_from_product_type(product_type: str | None) -> str | None:
    if not product_type:
        return None

    for category, product_types in SHOP_SECTION_PRODUCT_TYPES.items():
        if product_type in product_types and category in {"home", "sport", "technology"}:
            return category

    return None


def infer_category_group_from_product_type(product_type: str | None) -> str | None:
    if not product_type:
        return None

    for category, product_types in SHOP_SECTION_PRODUCT_TYPES.items():
        if product_type not in product_types:
            continue

        inferred_group = derive_category_group_from_category(category)
        if inferred_group:
            return inferred_group

    return None


def sanitize_search_intent(raw_intent: dict[str, object] | None) -> dict[str, object]:
    if not isinstance(raw_intent, dict):
        return {
            "searchText": "",
            "categoryGroup": None,
            "category": None,
            "productType": None,
            "size": None,
            "color": None,
            "businessName": None,
        }

    search_text = re.sub(r"\s+", " ", str(raw_intent.get("searchText", "") or "").strip())
    category_group = str(raw_intent.get("categoryGroup", "") or "").strip().lower() or None
    category = str(raw_intent.get("category", "") or "").strip().lower() or None
    product_type = str(raw_intent.get("productType", "") or "").strip().lower() or None
    size = str(raw_intent.get("size", "") or "").strip().upper() or None
    color = str(raw_intent.get("color", "") or "").strip().lower() or None
    business_name = re.sub(r"\s+", " ", str(raw_intent.get("businessName", "") or "").strip()) or None

    if category_group not in {"clothing", "cosmetics"}:
        category_group = None

    if category not in PRODUCT_CATEGORIES:
        category = None

    if product_type not in PRODUCT_TYPES:
        product_type = None

    if size not in CLOTHING_SIZES:
        size = None

    if color not in PRODUCT_COLORS:
        color = None

    if category and derive_category_group_from_category(category):
        category_group = derive_category_group_from_category(category)
    elif not category and product_type:
        category = infer_category_from_product_type(product_type)
        if not category_group:
            category_group = infer_category_group_from_product_type(product_type)

    return {
        "searchText": search_text[:80],
        "categoryGroup": category_group,
        "category": category,
        "productType": product_type,
        "size": size,
        "color": color,
        "businessName": business_name[:80] if business_name else None,
    }


def should_use_openai_search_interpreter(query_text: str) -> bool:
    normalized_query = normalize_search_intent_text(query_text)
    if not normalized_query or not OPENAI_API_KEY:
        return False

    tokens = tokenize_search_intent_text(normalized_query)
    token_count = len(tokens)
    if token_count >= 4:
        return True

    if any(marker in tokens for marker in SEARCH_INTENT_MARKERS):
        return token_count >= 2

    return token_count >= 3


def heuristic_search_intent(query_text: str) -> dict[str, object]:
    normalized_query = normalize_search_intent_text(query_text)
    intent = {
        "searchText": "",
        "categoryGroup": None,
        "category": None,
        "productType": None,
        "size": None,
        "color": None,
        "businessName": None,
    }

    if not normalized_query:
        return intent

    if "meshkuj" in normalized_query or "meshkujve" in normalized_query:
        if any(keyword in normalized_query for keyword in SEARCH_INTENT_CATEGORY_KEYWORDS["cosmetics"]):
            intent["category"] = "cosmetics-men"
            intent["categoryGroup"] = "cosmetics"
        else:
            intent["category"] = "clothing-men"
            intent["categoryGroup"] = "clothing"
    elif "femra" in normalized_query or "grave" in normalized_query:
        if any(keyword in normalized_query for keyword in SEARCH_INTENT_CATEGORY_KEYWORDS["cosmetics"]):
            intent["category"] = "cosmetics-women"
            intent["categoryGroup"] = "cosmetics"
        else:
            intent["category"] = "clothing-women"
            intent["categoryGroup"] = "clothing"
    elif "femij" in normalized_query or "bebe" in normalized_query:
        if any(keyword in normalized_query for keyword in SEARCH_INTENT_CATEGORY_KEYWORDS["cosmetics"]):
            intent["category"] = "cosmetics-kids"
            intent["categoryGroup"] = "cosmetics"
        else:
            intent["category"] = "clothing-kids"
            intent["categoryGroup"] = "clothing"

    for next_color in PRODUCT_COLORS:
        if next_color in normalized_query:
            intent["color"] = next_color
            break

    for next_size in CLOTHING_SIZES:
        if re.search(rf"(?<![A-Z0-9]){re.escape(next_size.lower())}(?![A-Z0-9])", normalized_query):
            intent["size"] = next_size
            break

    canonical_search_terms: list[str] = []
    canonical_type_terms = {
        "tshirt": "maica",
        "undershirt": "maica e brendshme",
        "pants": "pantallona",
        "hoodie": "duks",
        "turtleneck": "rollke",
        "jacket": "jakne",
        "underwear": "te brendshme",
        "pajamas": "pixhama",
        "perfumes": "parfume",
        "hygiene": "higjiene",
        "creams": "krem",
        "makeup": "makup",
        "nails": "thonje",
        "hair-colors": "ngjyre flokesh",
        "kids-care": "kujdes per femije",
        "room-decor": "dekor",
        "bathroom-items": "banjo",
        "bedroom-items": "dhome gjumi",
        "kids-room-items": "dhome femijesh",
        "sports-equipment": "pajisje sportive",
        "sportswear": "patika",
        "sports-accessories": "aksesor sportiv",
        "phone-cases": "mbrojtese telefoni",
        "headphones": "degjues",
        "phone-parts": "pjese telefoni",
        "phone-accessories": "aksesor telefoni",
    }

    for next_product_type, keywords in SEARCH_INTENT_PRODUCT_TYPE_KEYWORDS.items():
        if any(keyword in normalized_query for keyword in keywords):
            intent["productType"] = next_product_type
            canonical_search_terms.append(canonical_type_terms.get(next_product_type, ""))
            break

    if not intent["category"] and not intent["categoryGroup"]:
        for next_category, keywords in SEARCH_INTENT_CATEGORY_KEYWORDS.items():
            if any(keyword in normalized_query for keyword in keywords):
                if next_category in {"clothing", "cosmetics"}:
                    intent["categoryGroup"] = next_category
                else:
                    intent["category"] = next_category
                break

    if not intent["category"] and intent["productType"]:
        inferred_category = infer_category_from_product_type(intent["productType"])
        if inferred_category:
            intent["category"] = inferred_category

    if not intent["categoryGroup"] and intent["productType"]:
        intent["categoryGroup"] = infer_category_group_from_product_type(intent["productType"])

    business_name_match = re.search(
        r"\bnga\s+(?:butiku|biznesi|dyqani|shopi)?\s*([a-zA-Z0-9][a-zA-Z0-9\s\-]{1,60})$",
        normalized_query,
    )
    if business_name_match:
        captured_business_name = re.sub(r"\s+", " ", business_name_match.group(1).strip())
        if captured_business_name:
            intent["businessName"] = captured_business_name

    if not canonical_search_terms and normalized_query:
        cleaned_query = normalized_query
        for marker in SEARCH_INTENT_MARKERS:
            cleaned_query = re.sub(rf"\b{re.escape(marker)}\b", " ", cleaned_query)
        cleaned_query = re.sub(r"\b(te|nje|nje pale|dua|do|me|ma|per|vera|veres|gjerë|gjera)\b", " ", cleaned_query)
        if intent["color"]:
            cleaned_query = re.sub(r"\b(ngjyr|ngjyre|tone|nuance)\b", " ", cleaned_query)
            cleaned_query = re.sub(rf"\b{re.escape(str(intent['color']))}\b", " ", cleaned_query)
        if intent["businessName"]:
            cleaned_query = re.sub(
                r"\bnga\s+(?:butiku|biznesi|dyqani|shopi)?\s*"
                + re.escape(str(intent["businessName"])),
                " ",
                cleaned_query,
            )
        cleaned_query = re.sub(r"\s+", " ", cleaned_query).strip()
        if cleaned_query:
            canonical_search_terms.append(cleaned_query)

    intent["searchText"] = canonical_search_terms[0] if canonical_search_terms else ""
    return sanitize_search_intent(intent)


def extract_openai_output_text(payload: dict[str, object]) -> str:
    output_text = payload.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()

    output_items = payload.get("output")
    if not isinstance(output_items, list):
        return ""

    for item in output_items:
        if not isinstance(item, dict):
            continue
        content_items = item.get("content")
        if not isinstance(content_items, list):
            continue
        for content in content_items:
            if not isinstance(content, dict):
                continue
            text_value = content.get("text")
            if isinstance(text_value, str) and text_value.strip():
                return text_value.strip()
            json_value = content.get("json")
            if isinstance(json_value, dict):
                return json.dumps(json_value, ensure_ascii=False)

    return ""


def request_openai_structured_output(
    *,
    model: str,
    instructions: str,
    input_payload: object,
    schema_name: str,
    schema: dict[str, object],
    max_output_tokens: int,
    timeout_seconds: int,
) -> dict[str, object] | None:
    if not OPENAI_API_KEY:
        return None

    payload = {
        "model": model,
        "instructions": instructions,
        "input": input_payload,
        "max_output_tokens": max_output_tokens,
        "text": {
            "format": {
                "type": "json_schema",
                "name": schema_name,
                "strict": True,
                "schema": schema,
            }
        },
    }

    request = Request(
        OPENAI_RESPONSES_API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=timeout_seconds) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"OpenAI structured output failed: {error}")
        return None

    response_text = extract_openai_output_text(response_payload)
    if not response_text:
        return None

    try:
        parsed_output = json.loads(response_text)
    except json.JSONDecodeError as error:
        print(f"OpenAI structured output parse failed: {error}")
        return None

    return parsed_output if isinstance(parsed_output, dict) else None


def request_openai_search_intent(query_text: str) -> dict[str, object] | None:
    if not OPENAI_API_KEY:
        return None

    schema = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "searchText": {"type": "string"},
            "categoryGroup": {
                "anyOf": [
                    {"type": "string", "enum": ["clothing", "cosmetics"]},
                    {"type": "null"},
                ]
            },
            "category": {
                "anyOf": [
                    {"type": "string", "enum": sorted(PRODUCT_CATEGORIES)},
                    {"type": "null"},
                ]
            },
            "productType": {
                "anyOf": [
                    {"type": "string", "enum": sorted(PRODUCT_TYPES)},
                    {"type": "null"},
                ]
            },
            "size": {
                "anyOf": [
                    {"type": "string", "enum": sorted(CLOTHING_SIZES)},
                    {"type": "null"},
                ]
            },
            "businessName": {
                "anyOf": [
                    {"type": "string"},
                    {"type": "null"},
                ]
            },
            "color": {
                "anyOf": [
                    {"type": "string", "enum": sorted(PRODUCT_COLORS)},
                    {"type": "null"},
                ]
            },
        },
        "required": [
            "searchText",
            "categoryGroup",
            "category",
            "productType",
            "size",
            "color",
            "businessName",
        ],
    }

    instructions = (
        "Ti je motor interpretimi per kerkimin e produkteve ne nje marketplace shqiptar. "
        "Nxirr nje JSON te thjeshte qe e shnderron pyetjen natyrale ne filtra katalogu. "
        "searchText duhet te jete version i shkurter dhe praktik per kerkimin ne databaze, jo fjalia e plote. "
        "Per shembull, nga 'me trego maica te kuqe' kthe searchText='maica', productType='tshirt', color='kuqe'. "
        "Nga 'dua pantallona te gjera' kthe searchText='pantallona', productType='pants'. "
        "Nga pyetje si 'ngjyre kuqe' ose 'dua dicka te kuqe', kthe searchText bosh dhe perdor vetem color='kuqe'. "
        "Nese perdoruesi permend nje butik ose biznes, p.sh. 'pantallona nga Sheilla', kthe businessName='Sheilla'. "
        "Nga 'patika te veres' kthe searchText='patika' dhe category='sport' ose productType='sportswear' kur eshte e arsyeshme. "
        "Nese nje fushe nuk dihet, kthe null. Mos shpik kategori qe nuk ekzistojne."
    )

    payload = {
        "model": OPENAI_SEARCH_MODEL,
        "instructions": instructions,
        "input": query_text,
        "max_output_tokens": 200,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "trego_search_intent",
                "strict": True,
                "schema": schema,
            }
        },
    }

    request = Request(
        OPENAI_RESPONSES_API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=OPENAI_SEARCH_TIMEOUT_SECONDS) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"OpenAI search intent failed: {error}")
        return None

    response_text = extract_openai_output_text(response_payload)
    if not response_text:
        return None

    try:
        return sanitize_search_intent(json.loads(response_text))
    except json.JSONDecodeError as error:
        print(f"OpenAI search intent parse failed: {error}")
        return None


def interpret_search_query(query_text: str) -> dict[str, object]:
    normalized_query = normalize_search_intent_text(query_text)
    if not normalized_query:
        return sanitize_search_intent({})

    cached_entry = SEARCH_INTENT_CACHE.get(normalized_query)
    if cached_entry and cached_entry[0] > time.time():
        return sanitize_search_intent(cached_entry[1])

    interpreted_intent = heuristic_search_intent(query_text)

    if should_use_openai_search_interpreter(query_text):
        openai_intent = request_openai_search_intent(query_text)
        if openai_intent:
            interpreted_intent = openai_intent

    SEARCH_INTENT_CACHE[normalized_query] = (
        time.time() + SEARCH_INTENT_CACHE_TTL_SECONDS,
        interpreted_intent,
    )
    return sanitize_search_intent(interpreted_intent)


def merge_normalized_search_terms(
    *values: object,
    allowed_terms: set[str] | None = None,
    max_terms: int = 24,
) -> str:
    merged_terms: list[str] = []
    seen_terms: set[str] = set()

    for value in values:
        if isinstance(value, str):
            raw_terms = tokenize_search_intent_text(value)
        elif isinstance(value, (list, tuple, set)):
            raw_terms = []
            for item in value:
                raw_terms.extend(tokenize_search_intent_text(str(item or "")))
        else:
            raw_terms = tokenize_search_intent_text(str(value or ""))

        for raw_term in raw_terms:
            normalized_term = normalize_search_intent_text(raw_term)
            if not normalized_term:
                continue
            if allowed_terms is not None and normalized_term not in allowed_terms:
                continue
            if normalized_term in seen_terms:
                continue
            seen_terms.add(normalized_term)
            merged_terms.append(normalized_term)
            if len(merged_terms) >= max_terms:
                return " ".join(merged_terms)

    return " ".join(merged_terms)


def sanitize_product_image_search_metadata(raw_metadata: dict[str, object] | None) -> dict[str, str]:
    if not isinstance(raw_metadata, dict):
        return {"searchText": "", "colorTerms": ""}

    search_text = merge_normalized_search_terms(raw_metadata.get("searchText", ""), max_terms=24)
    color_terms = merge_normalized_search_terms(
        raw_metadata.get("colorTerms", []),
        allowed_terms=PRODUCT_COLORS,
        max_terms=6,
    )
    return {
        "searchText": search_text[:240],
        "colorTerms": color_terms,
    }


def merge_product_image_search_metadata(*metadata_items: dict[str, object] | None) -> dict[str, str]:
    return sanitize_product_image_search_metadata(
        {
            "searchText": merge_normalized_search_terms(
                *(item.get("searchText", "") if isinstance(item, dict) else "" for item in metadata_items),
                max_terms=24,
            ),
            "colorTerms": merge_normalized_search_terms(
                *(item.get("colorTerms", "") if isinstance(item, dict) else "" for item in metadata_items),
                allowed_terms=PRODUCT_COLORS,
                max_terms=6,
            ),
        }
    )


def heuristic_product_image_search_metadata(
    *,
    title: object,
    description: object,
    category: object,
    product_type: object,
    color: object,
) -> dict[str, str]:
    product_type_aliases = {
        "tshirt": "maica bluze",
        "undershirt": "maica brendshme",
        "pants": "pantallona",
        "hoodie": "duks",
        "turtleneck": "rollke",
        "jacket": "jakne",
        "underwear": "brendshme",
        "pajamas": "pixhama",
        "perfumes": "parfum",
        "hygiene": "higjiene",
        "creams": "krem",
        "makeup": "makup",
        "nails": "thonje",
        "hair-colors": "ngjyre flokesh",
        "kids-care": "kujdes femije",
        "room-decor": "dekor shtepie",
        "bathroom-items": "banjo",
        "bedroom-items": "dhome gjumi",
        "kids-room-items": "dhome femijesh",
        "sports-equipment": "pajisje sportive",
        "sportswear": "sportive",
        "sports-accessories": "aksesor sportiv",
        "phone-cases": "mbrojtese telefoni",
        "headphones": "degjues kufje",
        "phone-parts": "pjese telefoni",
        "phone-accessories": "aksesor telefoni",
    }

    category_aliases = {
        "clothing-men": "veshje meshkuj",
        "clothing-women": "veshje femra",
        "clothing-kids": "veshje femije",
        "cosmetics-men": "kozmetike meshkuj",
        "cosmetics-women": "kozmetike femra",
        "cosmetics-kids": "kozmetike femije",
        "home": "shtepi",
        "sport": "sport",
        "technology": "teknologji",
    }

    return sanitize_product_image_search_metadata(
        {
            "searchText": merge_normalized_search_terms(
                title,
                description,
                product_type_aliases.get(str(product_type or "").strip().lower(), ""),
                category_aliases.get(str(category or "").strip().lower(), ""),
                max_terms=24,
            ),
            "colorTerms": merge_normalized_search_terms(
                color,
                allowed_terms=PRODUCT_COLORS,
                max_terms=6,
            ),
        }
    )


def build_openai_input_image_urls(
    image_gallery: object,
    *,
    fallback_image_path: object = "",
    max_images: int = 3,
) -> list[str]:
    data_urls: list[str] = []
    gallery_paths = normalize_image_gallery_value(
        image_gallery,
        fallback_image_path=fallback_image_path,
    )

    for image_path in gallery_paths[:max_images]:
        file_bytes, content_type = fetch_uploaded_asset_payload_by_path(image_path)
        if not file_bytes:
            continue
        encoded_bytes = base64.b64encode(file_bytes).decode("ascii")
        data_urls.append(f"data:{content_type};base64,{encoded_bytes}")

    return data_urls


def request_openai_product_image_search_metadata(
    *,
    title: object,
    description: object,
    category: object,
    product_type: object,
    color: object,
    image_gallery: object,
    fallback_image_path: object = "",
) -> dict[str, object] | None:
    if not OPENAI_API_KEY:
        return None

    image_urls = build_openai_input_image_urls(
        image_gallery,
        fallback_image_path=fallback_image_path,
    )
    if not image_urls:
        return None

    schema = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "searchText": {"type": "string"},
            "colorTerms": {
                "type": "array",
                "items": {"type": "string", "enum": sorted(PRODUCT_COLORS)},
            },
        },
        "required": ["searchText", "colorTerms"],
    }

    product_context = {
        "title": str(title or "").strip(),
        "description": str(description or "").strip(),
        "category": str(category or "").strip().lower(),
        "productType": str(product_type or "").strip().lower(),
        "color": str(color or "").strip().lower(),
    }

    instructions = (
        "Ti analizon foto produktesh per nje marketplace shqiptar. "
        "Kthe JSON per kerkimin e katalogut. "
        "searchText duhet te jete i shkurter, praktik, ne shqip, me fjale kyce qe nje bleres real do te perdorte. "
        "Per shembull: 'maica e kuqe', 'krem per duar', 'tepih', 'patika vere', 'adapter iphone'. "
        "Perdor foton si burim kryesor, por shfrytezo edhe kontekstin e produktit kur ndihmon. "
        "Mos pershkruaj sfondin, duart e modelit ose elemente qe nuk jane produkti. "
        "Nese ngjyra duket qarte, ktheje vetem nga lista e lejuar. "
        "Nese fotoja eshte e paqarte, searchText le te mbetet i shkurter dhe konservativ."
    )

    content: list[dict[str, object]] = [
        {
            "type": "input_text",
            "text": (
                "Analizo fotot e produktit dhe nxirr fjale kyce kerkimi ne shqip.\n"
                f"Konteksti i produktit: {json.dumps(product_context, ensure_ascii=False)}"
            ),
        }
    ]
    content.extend(
        {"type": "input_image", "image_url": image_url}
        for image_url in image_urls
    )

    payload = {
        "model": OPENAI_PRODUCT_IMAGE_MODEL,
        "instructions": instructions,
        "input": [{"role": "user", "content": content}],
        "max_output_tokens": 250,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "trego_product_image_search_metadata",
                "strict": True,
                "schema": schema,
            }
        },
    }

    request = Request(
        OPENAI_RESPONSES_API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=OPENAI_PRODUCT_IMAGE_TIMEOUT_SECONDS) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"OpenAI product image metadata failed: {error}")
        return None

    response_text = extract_openai_output_text(response_payload)
    if not response_text:
        return None

    try:
        return sanitize_product_image_search_metadata(json.loads(response_text))
    except json.JSONDecodeError as error:
        print(f"OpenAI product image metadata parse failed: {error}")
        return None


def generate_product_image_search_metadata(
    *,
    title: object,
    description: object,
    category: object,
    product_type: object,
    color: object,
    image_gallery: object,
    fallback_image_path: object = "",
    image_fingerprint: object = "",
    existing_metadata: dict[str, object] | None = None,
) -> dict[str, str]:
    heuristic_metadata = heuristic_product_image_search_metadata(
        title=title,
        description=description,
        category=category,
        product_type=product_type,
        color=color,
    )

    normalized_existing_metadata = sanitize_product_image_search_metadata(existing_metadata)
    fingerprint_key = str(image_fingerprint or "").strip()
    if fingerprint_key:
        cached_metadata = PRODUCT_IMAGE_METADATA_CACHE.get(fingerprint_key)
        if cached_metadata and cached_metadata[0] > time.time():
            return merge_product_image_search_metadata(
                cached_metadata[1],
                normalized_existing_metadata,
                heuristic_metadata,
            )

    if not OPENAI_API_KEY:
        return merge_product_image_search_metadata(normalized_existing_metadata, heuristic_metadata)

    openai_metadata = request_openai_product_image_search_metadata(
        title=title,
        description=description,
        category=category,
        product_type=product_type,
        color=color,
        image_gallery=image_gallery,
        fallback_image_path=fallback_image_path,
    )
    merged_metadata = merge_product_image_search_metadata(
        openai_metadata,
        normalized_existing_metadata,
        heuristic_metadata,
    )

    if fingerprint_key and (merged_metadata["searchText"] or merged_metadata["colorTerms"]):
        PRODUCT_IMAGE_METADATA_CACHE[fingerprint_key] = (
            time.time() + PRODUCT_IMAGE_METADATA_CACHE_TTL_SECONDS,
            merged_metadata,
        )

    return merged_metadata


def build_openai_input_image_urls_from_upload_payloads(
    image_payloads: list[dict[str, object]] | None,
    *,
    max_images: int = 3,
) -> list[str]:
    data_urls: list[str] = []
    for payload in list(image_payloads or [])[:max_images]:
        if not isinstance(payload, dict):
            continue
        file_bytes = payload.get("file_bytes")
        content_type = str(payload.get("content_type") or "").strip().lower() or "image/jpeg"
        if not isinstance(file_bytes, (bytes, bytearray)) or not file_bytes:
            continue
        encoded_bytes = base64.b64encode(bytes(file_bytes)).decode("ascii")
        data_urls.append(f"data:{content_type};base64,{encoded_bytes}")

    return data_urls


def heuristic_chat_reply_suggestions(
    *,
    viewer_role: str,
    viewer_user_id: int,
    conversation: sqlite3.Row | None,
    messages: list[sqlite3.Row],
) -> list[str]:
    last_message_body = ""
    for message in reversed(messages):
        if int(message["sender_user_id"] or 0) != int(viewer_user_id):
            last_message_body = str(message["body"] or "").strip().lower()
            break

    if viewer_role == "business":
        if any(keyword in last_message_body for keyword in {"stok", "gjendje", "disponim"}):
            return [
                "Pershendetje! Po e kontrolloj stokun dhe ju konfirmoj menjehere.",
                "Po, mund ta verifikoj stokun per ju. Me tregoni ngjyren ose madhesine qe doni.",
                "Nese doni, ju tregoj cilat variante jane ende ne dispozicion.",
            ]
        if any(keyword in last_message_body for keyword in {"cmim", "kushton", "sa ben"}):
            return [
                "Pershendetje! Cmimi aktual eshte ai qe shfaqet ne platforme.",
                "Mund t'ju ndihmoj me detajet e produktit dhe opsionet qe kemi ne dispozicion.",
                "Nese doni, ju tregoj edhe variantet ose produktet e ngjashme qe kemi.",
            ]
        return [
            "Pershendetje! Po, me kenaqesi ju ndihmoj. Me tregoni pak me sakte cfare po kerkoni.",
            "Faleminderit per interesimin. Mund t'ju ndihmoj me stokun, madhesite dhe detajet e produktit.",
            "Nese doni, ju tregoj menjehere cilat variante i kemi aktualisht ne dispozicion.",
        ]

    if viewer_role == "admin":
        return [
            "Pershendetje! Jam nga customer support. Me tregoni si mund t'ju ndihmoj.",
            "Faleminderit qe na kontaktuat. Po e shqyrtojme kerkesen dhe ju ndihmojme menjehere.",
            "Mund t'ju asistojme me kete ceshtje. Na dergoni pak me shume detaje, ju lutem.",
        ]

    if any(keyword in last_message_body for keyword in {"pershendetje", "hello", "hi"}):
        return [
            "Pershendetje! A eshte ende ne stok ky produkt?",
            "Pershendetje! A mund te me tregoni cilat madhesi ose ngjyra jane ne dispozicion?",
            "Pershendetje! Dua pak me shume informata per kete produkt.",
        ]

    return [
        "A eshte ende ne stok ky produkt?",
        "Cilat madhesi ose ngjyra keni aktualisht ne dispozicion?",
        "A mund te me tregoni pak me shume per kete produkt?",
    ]


def request_openai_chat_reply_suggestions(
    *,
    viewer_role: str,
    viewer_user_id: int,
    conversation: sqlite3.Row | None,
    messages: list[sqlite3.Row],
) -> list[str] | None:
    if not OPENAI_API_KEY or not conversation or not messages:
        return None

    schema = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "suggestions": {
                "type": "array",
                "minItems": 3,
                "maxItems": 3,
                "items": {"type": "string"},
            }
        },
        "required": ["suggestions"],
    }

    chat_history = [
        {
            "sender": "Ti" if int(message["sender_user_id"] or 0) == int(viewer_user_id) else str(message["sender_name"] or "").strip() or "Tjetri",
            "body": str(message["body"] or "").strip(),
        }
        for message in messages[-10:]
    ]
    participant_one = extract_chat_participant(conversation, prefix="participant_one")
    participant_two = extract_chat_participant(conversation, prefix="participant_two")
    counterpart = (
        participant_two
        if int(participant_one["userId"]) == int(viewer_user_id)
        else participant_one
    )
    counterpart_role = get_chat_role_label(str(counterpart["role"]))
    counterpart_name = str(counterpart["displayName"] or "").strip() or counterpart_role.title()

    instructions = (
        "Ti gjeneron 3 pergjigje te shkurtra, natyrale dhe profesionale per nje chat marketplace ne shqip. "
        "Pergjigjet duhet te jene gati per t'u derguar, jo shpjegime. "
        "Ruaj tonin e sjellshem dhe praktik. "
        "Nese perdoruesi qe po merr sugjerimet eshte biznes, pergjigjet duhet te ndihmojne klientin dhe te shtyjne qartesine per stokun, madhesite, ngjyrat ose porosine. "
        "Nese eshte klient, pergjigjet duhet te jene pyetje te qarta ose kerkesa per sqarim. "
        "Mos shpik cmime, stok ose detaje qe nuk shihen ne biseden ekzistuese."
    )

    input_payload = [{
        "role": "user",
        "content": [
            {
                "type": "input_text",
                "text": (
                    f"Roli i shikuesit: {viewer_role}\n"
                    f"Po flet me: {counterpart_name} ({counterpart_role})\n"
                    f"Historia e fundit e bisedes: {json.dumps(chat_history, ensure_ascii=False)}"
                ),
            }
        ],
    }]

    parsed_output = request_openai_structured_output(
        model=OPENAI_CHAT_MODEL,
        instructions=instructions,
        input_payload=input_payload,
        schema_name="trego_chat_reply_suggestions",
        schema=schema,
        max_output_tokens=220,
        timeout_seconds=OPENAI_CHAT_TIMEOUT_SECONDS,
    )
    if not parsed_output:
        return None

    suggestions = [
        re.sub(r"\s+", " ", str(item or "").strip())
        for item in list(parsed_output.get("suggestions") or [])
        if str(item or "").strip()
    ]
    unique_suggestions: list[str] = []
    seen_suggestions: set[str] = set()
    for suggestion in suggestions:
        normalized_suggestion = suggestion.lower()
        if normalized_suggestion in seen_suggestions:
            continue
        seen_suggestions.add(normalized_suggestion)
        unique_suggestions.append(suggestion[:220])
        if len(unique_suggestions) >= 3:
            break

    return unique_suggestions or None


def infer_package_amount_from_text(*values: object) -> tuple[str, str]:
    combined_text = " ".join(str(value or "").strip() for value in values if str(value or "").strip())
    if not combined_text:
        return "", ""

    amount_match = re.search(r"(\d+(?:[.,]\d+)?)\s*(ml|l)\b", combined_text, re.IGNORECASE)
    if not amount_match:
        return "", ""

    amount_value = str(amount_match.group(1) or "").replace(",", ".").strip()
    amount_unit = str(amount_match.group(2) or "").strip().lower()
    return amount_value, amount_unit if amount_unit in PRODUCT_AMOUNT_UNITS else ""


def heuristic_product_draft_suggestion(
    *,
    title: str,
    description: str,
    page_section: str,
    audience: str,
    product_type: str,
    image_search_text: str,
    image_color_terms: str,
) -> dict[str, object]:
    combined_text = " ".join(
        value
        for value in [
            str(title or "").strip(),
            str(description or "").strip(),
            str(image_search_text or "").strip(),
        ]
        if value
    )
    interpreted_intent = interpret_search_query(combined_text)

    next_page_section = str(page_section or "").strip().lower()
    if next_page_section not in SECTION_AUDIENCE_CATEGORY_MAP and next_page_section not in {
        str(section.get("value") or "").strip().lower() for section in PRODUCT_SECTION_DEFINITIONS
    }:
        next_page_section = derive_section_from_category(
            str(interpreted_intent.get("category") or "").strip().lower()
        ) or "clothing"

    audience_options = SECTION_AUDIENCE_CATEGORY_MAP.get(next_page_section, {})
    next_audience = str(audience or "").strip().lower()
    if audience_options:
      if next_audience not in audience_options:
          next_audience = derive_audience_from_category(
              str(interpreted_intent.get("category") or "").strip().lower()
          ) or next(iter(audience_options.keys()), "")
    else:
      next_audience = ""

    next_category = build_category_from_section_selection(next_page_section, next_audience)
    available_product_types = SHOP_SECTION_PRODUCT_TYPES.get(next_category, set())
    suggested_product_type = normalize_product_type_for_category(
        next_category,
        str(product_type or "").strip().lower() or str(interpreted_intent.get("productType") or "").strip().lower(),
    )
    if suggested_product_type not in available_product_types:
        suggested_product_type = next(iter(available_product_types), "")

    inferred_colors = [
        color
        for color in tokenize_search_intent_text(image_color_terms)
        if color in PRODUCT_COLORS
    ]
    if str(interpreted_intent.get("color") or "").strip().lower() in PRODUCT_COLORS:
        inferred_colors.insert(0, str(interpreted_intent.get("color") or "").strip().lower())
    selected_colors: list[str] = []
    for color in inferred_colors:
        if color not in selected_colors:
            selected_colors.append(color)
        if len(selected_colors) >= 4:
            break

    if not section_supports_color_inventory(next_page_section):
        selected_colors = []

    amount_value, amount_unit = infer_package_amount_from_text(title, description, image_search_text)

    normalized_title = re.sub(r"\s+", " ", str(title or "").strip())
    if not normalized_title:
        title_parts = [PRODUCT_TYPE_LABELS.get(suggested_product_type, "Produkt")]
        if selected_colors:
            title_parts.append(format_product_color_label(selected_colors[0]).capitalize())
        normalized_title = " ".join(part for part in title_parts if part).strip()

    normalized_description = re.sub(r"\s+", " ", str(description or "").strip())
    if not normalized_description:
        category_label = PRODUCT_CATEGORY_LABELS.get(next_category, PRODUCT_CATEGORY_LABELS.get(next_page_section, "kategorine"))
        normalized_description = (
            f"{PRODUCT_TYPE_LABELS.get(suggested_product_type, 'Produkti')} per {category_label.lower()}."
        )

    return {
        "title": normalized_title[:120],
        "description": normalized_description[:600],
        "pageSection": next_page_section,
        "audience": next_audience,
        "productType": suggested_product_type,
        "selectedColors": selected_colors,
        "packageAmountValue": amount_value,
        "packageAmountUnit": amount_unit,
    }


def sanitize_ai_product_draft_suggestion(
    raw_draft: dict[str, object] | None,
    *,
    current_title: str,
    current_description: str,
    current_page_section: str,
    current_audience: str,
    current_product_type: str,
    image_search_text: str,
    image_color_terms: str,
) -> dict[str, object]:
    heuristic_draft = heuristic_product_draft_suggestion(
        title=current_title,
        description=current_description,
        page_section=current_page_section,
        audience=current_audience,
        product_type=current_product_type,
        image_search_text=image_search_text,
        image_color_terms=image_color_terms,
    )
    if not isinstance(raw_draft, dict):
        return heuristic_draft

    known_sections = {
        str(section.get("value") or "").strip().lower()
        for section in PRODUCT_SECTION_DEFINITIONS
        if str(section.get("value") or "").strip()
    }
    next_page_section = str(raw_draft.get("pageSection") or "").strip().lower()
    if next_page_section not in known_sections:
        next_page_section = str(heuristic_draft["pageSection"] or "clothing")

    audience_options = SECTION_AUDIENCE_CATEGORY_MAP.get(next_page_section, {})
    next_audience = str(raw_draft.get("audience") or "").strip().lower()
    if audience_options:
        if next_audience not in audience_options:
            next_audience = str(heuristic_draft["audience"] or next(iter(audience_options.keys()), ""))
    else:
        next_audience = ""

    next_category = build_category_from_section_selection(next_page_section, next_audience)
    available_product_types = SHOP_SECTION_PRODUCT_TYPES.get(next_category, set())
    next_product_type = normalize_product_type_for_category(
        next_category,
        raw_draft.get("productType") or heuristic_draft["productType"],
    )
    if next_product_type not in available_product_types:
        next_product_type = str(heuristic_draft["productType"] or next(iter(available_product_types), ""))

    next_title = re.sub(r"\s+", " ", str(raw_draft.get("title") or "").strip()) or str(heuristic_draft["title"])
    next_description = (
        re.sub(r"\s+", " ", str(raw_draft.get("description") or "").strip())
        or str(heuristic_draft["description"])
    )

    next_colors: list[str] = []
    for color in list(raw_draft.get("selectedColors") or []):
        normalized_color = str(color or "").strip().lower()
        if normalized_color in PRODUCT_COLORS and normalized_color not in next_colors:
            next_colors.append(normalized_color)
        if len(next_colors) >= 4:
            break

    if not next_colors:
        next_colors = list(heuristic_draft["selectedColors"] or [])

    if not section_supports_color_inventory(next_page_section):
        next_colors = []

    amount_value = str(raw_draft.get("packageAmountValue") or "").replace(",", ".").strip()
    amount_unit = str(raw_draft.get("packageAmountUnit") or "").strip().lower()
    if not section_supports_package_amount(next_page_section):
        amount_value = ""
        amount_unit = ""
    else:
        if not amount_value:
            amount_value = str(heuristic_draft["packageAmountValue"] or "")
        if amount_unit not in PRODUCT_AMOUNT_UNITS:
            amount_unit = str(heuristic_draft["packageAmountUnit"] or "")

    return {
        "title": next_title[:120],
        "description": next_description[:600],
        "pageSection": next_page_section,
        "audience": next_audience,
        "productType": next_product_type,
        "selectedColors": next_colors,
        "packageAmountValue": amount_value[:16],
        "packageAmountUnit": amount_unit[:8],
    }


def request_openai_product_draft_suggestion(
    *,
    title: str,
    description: str,
    page_section: str,
    audience: str,
    product_type: str,
    image_urls: list[str],
    image_search_text: str,
    image_color_terms: str,
) -> dict[str, object] | None:
    if not OPENAI_API_KEY:
        return None

    schema = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "title": {"type": "string"},
            "description": {"type": "string"},
            "pageSection": {
                "type": "string",
                "enum": sorted(
                    {
                        str(section.get("value") or "").strip().lower()
                        for section in PRODUCT_SECTION_DEFINITIONS
                        if str(section.get("value") or "").strip()
                    }
                ),
            },
            "audience": {
                "anyOf": [
                    {
                        "type": "string",
                        "enum": sorted(
                            {
                                audience_key
                                for audience_map in SECTION_AUDIENCE_CATEGORY_MAP.values()
                                for audience_key in audience_map.keys()
                            }
                        ),
                    },
                    {"type": "null"},
                ]
            },
            "productType": {
                "type": "string",
                "enum": sorted(PRODUCT_TYPES),
            },
            "selectedColors": {
                "type": "array",
                "items": {"type": "string", "enum": sorted(PRODUCT_COLORS)},
            },
            "packageAmountValue": {
                "anyOf": [{"type": "string"}, {"type": "null"}],
            },
            "packageAmountUnit": {
                "anyOf": [
                    {"type": "string", "enum": sorted(PRODUCT_AMOUNT_UNITS)},
                    {"type": "null"},
                ]
            },
        },
        "required": [
            "title",
            "description",
            "pageSection",
            "audience",
            "productType",
            "selectedColors",
            "packageAmountValue",
            "packageAmountUnit",
        ],
    }

    catalog_context = {
        "sections": [
            {
                "pageSection": str(section.get("value") or "").strip().lower(),
                "audiences": sorted(SECTION_AUDIENCE_CATEGORY_MAP.get(str(section.get("value") or "").strip().lower(), {}).keys()),
            }
            for section in PRODUCT_SECTION_DEFINITIONS
        ],
        "productTypeLabels": PRODUCT_TYPE_LABELS,
        "colorLabels": PRODUCT_COLOR_LABELS,
    }

    instructions = (
        "Ti je asistenti AI per krijimin e produkteve ne nje marketplace shqiptar. "
        "Bazohu ne fotot dhe tekstin ekzistues per te sugjeruar nje titull te qarte, pershkrim te shkurter, kategori te faqes, audience, llojin e produktit dhe ngjyrat e dukshme. "
        "Mos shpik specifika teknike qe nuk duken. "
        "Per kozmetike, nese teksti tregon qarte ml ose L, ktheje packageAmountValue dhe packageAmountUnit. "
        "Per audience perdor null kur kategoria nuk ka audience. "
        "Kthe vetem vlera qe pershtaten me katalogun e lejuar."
    )

    context_payload = json.dumps(
        {
            "title": title,
            "description": description,
            "pageSection": page_section,
            "audience": audience,
            "productType": product_type,
            "imageSearchText": image_search_text,
            "imageColorTerms": image_color_terms,
            "catalog": catalog_context,
        },
        ensure_ascii=False,
    )

    content: list[dict[str, object]] = [
        {
            "type": "input_text",
            "text": (
                "Konteksti aktual i formes:\n"
                f"{context_payload}"
            ),
        }
    ]
    content.extend({"type": "input_image", "image_url": image_url} for image_url in image_urls[:3])

    return request_openai_structured_output(
        model=OPENAI_PRODUCT_DRAFT_MODEL,
        instructions=instructions,
        input_payload=[{"role": "user", "content": content}],
        schema_name="trego_product_draft_assistant",
        schema=schema,
        max_output_tokens=500,
        timeout_seconds=OPENAI_PRODUCT_DRAFT_TIMEOUT_SECONDS,
    )


def parse_positive_quantity(
    data: dict[str, object],
    field_name: str = "quantity",
) -> tuple[list[str], int | None]:
    errors: list[str] = []
    raw_value = str(data.get(field_name, "")).strip()

    try:
        quantity = int(raw_value)
        if quantity <= 0:
            errors.append("Sasia duhet te jete numer me i madh se zero.")
    except ValueError:
        quantity = None
        errors.append("Sasia duhet te jete numer i plote.")

    return errors, quantity


def parse_optional_positive_quantity(
    data: dict[str, object],
    field_name: str = "quantity",
    default: int = 1,
) -> tuple[list[str], int | None]:
    raw_value = str(data.get(field_name, "")).strip()
    if not raw_value:
        return [], max(1, int(default))

    return parse_positive_quantity(data, field_name)


def parse_boolean_flag(
    data: dict[str, object],
    field_name: str,
) -> tuple[list[str], bool | None]:
    value = data.get(field_name)
    if isinstance(value, bool):
        return [], value

    normalized = str(value).strip().lower()
    if normalized in {"1", "true", "po", "yes", "on"}:
        return [], True
    if normalized in {"0", "false", "jo", "no", "off"}:
        return [], False

    return [f"Vlera `{field_name}` nuk eshte valide."], None


def parse_user_role(data: dict[str, object]) -> tuple[list[str], str | None]:
    role = str(data.get("role", "")).strip().lower()
    if role not in USER_ROLES:
        return ["Roli i zgjedhur nuk eshte valid."], None
    return [], role


def parse_payment_method(data: dict[str, object]) -> tuple[list[str], str | None]:
    payment_method = str(data.get("paymentMethod", "")).strip().lower()
    if payment_method not in PAYMENT_METHODS:
        return ["Menyra e pageses nuk eshte valide."], None
    return [], payment_method


def get_delivery_method_details(delivery_method: str | None) -> dict[str, object]:
    normalized_delivery_method = str(delivery_method or "").strip().lower() or "standard"
    details = DELIVERY_METHODS.get(normalized_delivery_method) or DELIVERY_METHODS["standard"]
    return {
        "value": normalized_delivery_method if normalized_delivery_method in DELIVERY_METHODS else "standard",
        "label": str(details.get("label") or "Dergese standard").strip(),
        "shippingAmount": round(float(details.get("shipping_amount") or 0), 2),
        "estimatedDeliveryText": str(details.get("estimated_delivery_text") or "").strip(),
    }


def normalize_business_shipping_settings(
    raw_settings: object,
    *,
    ensure_available: bool = True,
) -> dict[str, object]:
    if isinstance(raw_settings, str):
        raw_text = str(raw_settings or "").strip()
        if raw_text:
            try:
                parsed_settings = json.loads(raw_text)
            except (TypeError, ValueError, json.JSONDecodeError):
                parsed_settings = {}
        else:
            parsed_settings = {}
    elif hasattr(raw_settings, "keys"):
        parsed_settings = {key: raw_settings[key] for key in raw_settings.keys()}
    elif isinstance(raw_settings, dict):
        parsed_settings = dict(raw_settings)
    else:
        parsed_settings = {}

    def coerce_bool(key: str, fallback: bool) -> bool:
        value = parsed_settings.get(key, fallback)
        if isinstance(value, bool):
            return value
        normalized = str(value).strip().lower()
        if normalized in {"1", "true", "po", "yes", "on"}:
            return True
        if normalized in {"0", "false", "jo", "no", "off"}:
            return False
        return fallback

    def coerce_amount(key: str, fallback: float) -> float:
        try:
            amount = round(float(parsed_settings.get(key, fallback) or 0), 2)
        except (TypeError, ValueError):
            amount = fallback
        return max(0.0, amount)

    def coerce_threshold(key: str, fallback: float) -> float:
        try:
            threshold = round(float(parsed_settings.get(key, fallback) or 0), 2)
        except (TypeError, ValueError):
            threshold = fallback
        return max(0.0, threshold)

    def coerce_text(key: str, fallback: str, max_length: int = 80) -> str:
        value = re.sub(r"\s+", " ", str(parsed_settings.get(key, fallback) or "").strip())
        return value[:max_length] or fallback

    def coerce_city_rates(raw_value: object) -> list[dict[str, object]]:
        if isinstance(raw_value, str):
            raw_text = str(raw_value or "").strip()
            if raw_text:
                try:
                    parsed_value = json.loads(raw_text)
                except (TypeError, ValueError, json.JSONDecodeError):
                    parsed_value = []
            else:
                parsed_value = []
        elif isinstance(raw_value, list):
            parsed_value = list(raw_value)
        elif isinstance(raw_value, tuple):
            parsed_value = list(raw_value)
        elif isinstance(raw_value, dict):
            parsed_value = [
                {"city": key, "surcharge": value}
                for key, value in raw_value.items()
            ]
        else:
            parsed_value = []

        normalized_entries: dict[str, dict[str, object]] = {}
        for entry in parsed_value[:20]:
            if hasattr(entry, "keys"):
                city_value = str(entry.get("city") or "").strip()
                surcharge_value = entry.get("surcharge", 0)
            elif isinstance(entry, (list, tuple)) and len(entry) >= 2:
                city_value = str(entry[0] or "").strip()
                surcharge_value = entry[1]
            else:
                continue

            city_value = re.sub(r"\s+", " ", city_value)[:80]
            city_lookup = normalize_city_lookup(city_value)
            if not city_lookup:
                continue

            try:
                surcharge_amount = round(float(surcharge_value or 0), 2)
            except (TypeError, ValueError):
                surcharge_amount = 0.0

            normalized_entries[city_lookup] = {
                "city": city_value,
                "surcharge": max(0.0, surcharge_amount),
            }

        return sorted(
            normalized_entries.values(),
            key=lambda entry: normalize_city_lookup(entry["city"]),
        )

    normalized_settings = {
        "standardEnabled": coerce_bool("standardEnabled", bool(DEFAULT_BUSINESS_SHIPPING_SETTINGS["standardEnabled"])),
        "standardFee": coerce_amount("standardFee", float(DEFAULT_BUSINESS_SHIPPING_SETTINGS["standardFee"])),
        "standardEta": coerce_text("standardEta", str(DEFAULT_BUSINESS_SHIPPING_SETTINGS["standardEta"])),
        "expressEnabled": coerce_bool("expressEnabled", bool(DEFAULT_BUSINESS_SHIPPING_SETTINGS["expressEnabled"])),
        "expressFee": coerce_amount("expressFee", float(DEFAULT_BUSINESS_SHIPPING_SETTINGS["expressFee"])),
        "expressEta": coerce_text("expressEta", str(DEFAULT_BUSINESS_SHIPPING_SETTINGS["expressEta"])),
        "pickupEnabled": coerce_bool("pickupEnabled", bool(DEFAULT_BUSINESS_SHIPPING_SETTINGS["pickupEnabled"])),
        "pickupEta": coerce_text("pickupEta", str(DEFAULT_BUSINESS_SHIPPING_SETTINGS["pickupEta"])),
        "pickupAddress": coerce_text("pickupAddress", str(DEFAULT_BUSINESS_SHIPPING_SETTINGS["pickupAddress"]), 180),
        "pickupHours": coerce_text("pickupHours", str(DEFAULT_BUSINESS_SHIPPING_SETTINGS["pickupHours"]), 120),
        "pickupMapUrl": coerce_text("pickupMapUrl", str(DEFAULT_BUSINESS_SHIPPING_SETTINGS["pickupMapUrl"]), 500),
        "cityRates": coerce_city_rates(parsed_settings.get("cityRates", DEFAULT_BUSINESS_SHIPPING_SETTINGS["cityRates"])),
        "halfOffThreshold": coerce_threshold("halfOffThreshold", float(DEFAULT_BUSINESS_SHIPPING_SETTINGS["halfOffThreshold"])),
        "freeShippingThreshold": coerce_threshold("freeShippingThreshold", float(DEFAULT_BUSINESS_SHIPPING_SETTINGS["freeShippingThreshold"])),
    }

    if (
        normalized_settings["halfOffThreshold"] > 0
        and normalized_settings["freeShippingThreshold"] > 0
        and normalized_settings["freeShippingThreshold"] < normalized_settings["halfOffThreshold"]
    ):
        normalized_settings["halfOffThreshold"] = normalized_settings["freeShippingThreshold"]

    if ensure_available and not any(
        bool(normalized_settings[key])
        for key in ("standardEnabled", "expressEnabled", "pickupEnabled")
    ):
        normalized_settings["standardEnabled"] = True

    return normalized_settings


def serialize_business_shipping_settings_storage(settings: object) -> str:
    return json.dumps(
        normalize_business_shipping_settings(settings),
        ensure_ascii=False,
        separators=(",", ":"),
    )


def validate_business_shipping_settings_payload(
    data: dict[str, object],
) -> tuple[list[str], dict[str, object]]:
    raw_payload = data.get("shippingSettings", data)
    normalized_settings = normalize_business_shipping_settings(raw_payload, ensure_available=False)
    errors: list[str] = []

    if not any(
        bool(normalized_settings[key])
        for key in ("standardEnabled", "expressEnabled", "pickupEnabled")
    ):
        errors.append("Lejo te pakten nje metode dergese per biznesin.")

    if normalized_settings["freeShippingThreshold"] > 0 and normalized_settings["halfOffThreshold"] > normalized_settings["freeShippingThreshold"]:
        errors.append("Pragu i transportit falas duhet te jete me i madh ose i barabarte me pragun e zbritjes 50%.")

    if normalized_settings["pickupEnabled"]:
        if len(str(normalized_settings["pickupAddress"] or "").strip()) < 5:
            errors.append("Vendos adresen e terheqjes per pickup.")
        if len(str(normalized_settings["pickupHours"] or "").strip()) < 4:
            errors.append("Vendos orarin e terheqjes per pickup.")
        pickup_map_url = str(normalized_settings["pickupMapUrl"] or "").strip()
        if pickup_map_url:
            parsed_pickup_url = urlparse(pickup_map_url)
            if parsed_pickup_url.scheme not in {"http", "https"} or not parsed_pickup_url.netloc:
                errors.append("Linku i maps per pickup duhet te jete URL valide me http ose https.")

    return errors, normalize_business_shipping_settings(normalized_settings)


def normalize_city_lookup(value: object) -> str:
    normalized_value = unicodedata.normalize("NFKD", str(value or ""))
    ascii_value = normalized_value.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", ascii_value).strip().lower()


def resolve_delivery_city_zone(city: str | None) -> dict[str, object]:
    normalized_city = normalize_city_lookup(city)
    for zone in DELIVERY_CITY_ZONE_RULES:
        if normalized_city and normalized_city in zone["cities"]:
            return {
                "key": str(zone["key"]),
                "label": str(zone["label"]),
                "surcharge": round(float(zone["surcharge"] or 0), 2),
                "city": str(city or "").strip(),
            }

    return {
        "key": "extended",
        "label": "Zone e zgjeruar",
        "surcharge": 1.7,
        "city": str(city or "").strip(),
    }


def resolve_business_delivery_city_rule(
    city: str | None,
    shipping_settings: dict[str, object] | None = None,
) -> dict[str, object]:
    normalized_city = normalize_city_lookup(city)
    normalized_settings = normalize_business_shipping_settings(shipping_settings)
    for entry in normalized_settings.get("cityRates", []):
        city_label = str(entry.get("city") or "").strip()
        if normalized_city and normalize_city_lookup(city_label) == normalized_city:
            return {
                "key": f"business-{normalized_city}",
                "label": city_label,
                "surcharge": round(float(entry.get("surcharge") or 0), 2),
                "city": str(city or "").strip(),
                "source": "business",
            }

    fallback_zone = resolve_delivery_city_zone(city)
    return {
        **fallback_zone,
        "source": "marketplace",
    }


def is_delivery_method_enabled_for_settings(
    shipping_settings: dict[str, object],
    delivery_method: str,
) -> bool:
    normalized_method = str(get_delivery_method_details(delivery_method)["value"])
    return bool(
        normalize_business_shipping_settings(shipping_settings).get(
            f"{normalized_method}Enabled",
            normalized_method == "pickup",
        )
    )


def build_business_shipping_quote(
    *,
    delivery_method: str,
    subtotal: float,
    destination_city: str = "",
    shipping_settings: dict[str, object] | None = None,
) -> dict[str, object]:
    delivery_details = get_delivery_method_details(delivery_method)
    normalized_method = str(delivery_details.get("value") or "standard")
    normalized_settings = normalize_business_shipping_settings(shipping_settings)

    if not is_delivery_method_enabled_for_settings(normalized_settings, normalized_method):
        raise CheckoutProcessError(message="Kjo metode dergese nuk eshte aktive per biznesin e zgjedhur.")

    if normalized_method == "pickup":
        return {
            "deliveryMethod": normalized_method,
            "deliveryLabel": str(delivery_details.get("label") or "Terheqje ne biznes"),
            "estimatedDeliveryText": str(normalized_settings.get("pickupEta") or delivery_details.get("estimatedDeliveryText") or "").strip(),
            "shippingAmount": 0.0,
            "baseAmount": 0.0,
            "citySurcharge": 0.0,
            "subtotalDiscount": 0.0,
            "cityZoneLabel": "Pa transport",
            "ruleMessage": "Terheqja ne biznes nuk ka kosto transporti dhe varet nga disponueshmeria e biznesit.",
            "pickupAddress": str(normalized_settings.get("pickupAddress") or "").strip(),
            "pickupHours": str(normalized_settings.get("pickupHours") or "").strip(),
            "pickupMapUrl": str(normalized_settings.get("pickupMapUrl") or "").strip(),
        }

    city_zone = resolve_business_delivery_city_rule(destination_city, normalized_settings)
    eta_key = "expressEta" if normalized_method == "express" else "standardEta"
    fee_key = "expressFee" if normalized_method == "express" else "standardFee"
    base_amount = round(float(normalized_settings.get(fee_key) or delivery_details.get("shippingAmount") or 0), 2)
    city_surcharge = round(float(city_zone.get("surcharge") or 0), 2)
    pre_discount_amount = round(base_amount + city_surcharge, 2)
    subtotal_discount = 0.0
    if str(city_zone.get("source") or "") == "business":
        rule_message = (
            f"Transporti per {str(city_zone.get('label') or 'qytetin e zgjedhur')} u llogarit sipas tarifes se vendosur nga biznesi."
        )
    else:
        rule_message = (
            f"Transporti llogaritet sipas qytetit dhe rregullave te biznesit per {str(city_zone.get('label') or 'qytetin e zgjedhur')}."
        )

    free_shipping_threshold = round(float(normalized_settings.get("freeShippingThreshold") or 0), 2)
    half_off_threshold = round(float(normalized_settings.get("halfOffThreshold") or 0), 2)

    if free_shipping_threshold > 0 and subtotal >= free_shipping_threshold:
        subtotal_discount = pre_discount_amount
        rule_message = (
            f"Transporti u be falas sepse shporta e ketij biznesi kaloi {free_shipping_threshold:.2f}€."
        )
    elif half_off_threshold > 0 and subtotal >= half_off_threshold:
        subtotal_discount = round(pre_discount_amount * 0.5, 2)
        rule_message = (
            f"Transporti mori 50% zbritje sepse shporta e ketij biznesi kaloi {half_off_threshold:.2f}€."
        )

    shipping_amount = round(max(0.0, pre_discount_amount - subtotal_discount), 2)
    return {
        "deliveryMethod": normalized_method,
        "deliveryLabel": str(delivery_details.get("label") or "Dergese standard"),
        "estimatedDeliveryText": str(normalized_settings.get(eta_key) or delivery_details.get("estimatedDeliveryText") or "").strip(),
        "shippingAmount": shipping_amount,
        "baseAmount": base_amount,
        "citySurcharge": city_surcharge,
        "subtotalDiscount": subtotal_discount,
        "cityZoneLabel": str(city_zone.get("label") or "Zone e zgjeruar"),
        "cityRateSource": str(city_zone.get("source") or "marketplace"),
        "ruleMessage": rule_message,
    }


def fetch_business_shipping_profiles_by_user_ids(
    connection: DatabaseConnection,
    user_ids: list[int],
) -> dict[int, sqlite3.Row]:
    filtered_user_ids = sorted({int(user_id) for user_id in user_ids if int(user_id) > 0})
    if not filtered_user_ids:
        return {}

    placeholders = ", ".join("?" for _ in filtered_user_ids)
    rows = connection.execute(
        """
        SELECT
            user_id,
            business_name,
            address_line,
            shipping_settings
        FROM business_profiles
        WHERE user_id IN ("""
        + placeholders
        + """)
        """,
        filtered_user_ids,
    ).fetchall()
    return {int(row["user_id"]): row for row in rows}


def build_checkout_shipping_groups(
    connection: DatabaseConnection,
    checkout_items: list[dict[str, object]],
) -> list[dict[str, object]]:
    grouped_items: dict[int, dict[str, object]] = {}
    for item in checkout_items:
        business_user_id = int(item.get("businessUserId") or 0)
        group = grouped_items.setdefault(
            business_user_id,
            {
                "businessUserId": business_user_id,
                "businessName": str(item.get("businessName") or "").strip(),
                "items": [],
            },
        )
        group["items"].append(item)
        if not group["businessName"]:
            group["businessName"] = str(item.get("businessName") or "").strip()

    rows_by_user_id = fetch_business_shipping_profiles_by_user_ids(connection, list(grouped_items.keys()))
    shipping_groups: list[dict[str, object]] = []
    for business_user_id, grouped in grouped_items.items():
        business_row = rows_by_user_id.get(int(business_user_id))
        subtotal = round(
            sum(
                round(float(item.get("price") or 0), 2) * max(1, int(item.get("quantity") or 1))
                for item in grouped["items"]
            ),
            2,
        )
        normalized_shipping_settings = normalize_business_shipping_settings(
            business_row["shipping_settings"] if business_row else None
        )
        business_name = (
            str(grouped.get("businessName") or "").strip()
            or (str(business_row["business_name"] or "").strip() if business_row else "")
            or "Marketplace"
        )
        shipping_groups.append(
            {
                "businessUserId": int(business_user_id),
                "businessName": business_name,
                "subtotal": subtotal,
                "items": list(grouped["items"]),
                "shippingSettings": {
                    **normalized_shipping_settings,
                    "pickupAddress": (
                        str(normalized_shipping_settings.get("pickupAddress") or "").strip()
                        or (str(business_row["address_line"] or "").strip() if business_row else "")
                    ),
                },
            }
        )

    return sorted(
        shipping_groups,
        key=lambda group: (
            str(group.get("businessName") or "").strip().lower(),
            int(group.get("businessUserId") or 0),
        ),
    )


def build_checkout_shipping_quote(
    *,
    shipping_groups: list[dict[str, object]],
    delivery_method: str,
    destination_city: str = "",
) -> dict[str, object]:
    normalized_method = str(get_delivery_method_details(delivery_method)["value"])
    group_quotes: list[dict[str, object]] = []
    for group in shipping_groups:
        quote_payload = build_business_shipping_quote(
            delivery_method=normalized_method,
            subtotal=round(float(group.get("subtotal") or 0), 2),
            destination_city=destination_city,
            shipping_settings=group.get("shippingSettings"),
        )
        group_quotes.append(
            {
                **quote_payload,
                "businessUserId": int(group.get("businessUserId") or 0),
                "businessName": str(group.get("businessName") or "").strip() or "Marketplace",
                "subtotal": round(float(group.get("subtotal") or 0), 2),
            }
        )

    if not group_quotes:
        fallback_quote = build_business_shipping_quote(
            delivery_method=normalized_method,
            subtotal=0,
            destination_city=destination_city,
            shipping_settings=DEFAULT_BUSINESS_SHIPPING_SETTINGS,
        )
        group_quotes.append(
            {
                **fallback_quote,
                "businessUserId": 0,
                "businessName": "Marketplace",
                "subtotal": 0.0,
            }
        )

    estimated_delivery_values = [
        str(quote.get("estimatedDeliveryText") or "").strip()
        for quote in group_quotes
        if str(quote.get("estimatedDeliveryText") or "").strip()
    ]
    unique_estimates = list(dict.fromkeys(estimated_delivery_values))
    zone_labels = [
        str(quote.get("cityZoneLabel") or "").strip()
        for quote in group_quotes
        if str(quote.get("cityZoneLabel") or "").strip()
    ]
    unique_zone_labels = list(dict.fromkeys(zone_labels))
    total_shipping_amount = round(sum(float(quote.get("shippingAmount") or 0) for quote in group_quotes), 2)
    total_base_amount = round(sum(float(quote.get("baseAmount") or 0) for quote in group_quotes), 2)
    total_city_surcharge = round(sum(float(quote.get("citySurcharge") or 0) for quote in group_quotes), 2)
    total_subtotal_discount = round(sum(float(quote.get("subtotalDiscount") or 0) for quote in group_quotes), 2)

    if len(group_quotes) == 1:
        rule_message = str(group_quotes[0].get("ruleMessage") or "").strip()
    else:
        rule_message = "Transporti llogaritet vecmas per secilin biznes ne shporte."
        if total_subtotal_discount > 0:
            rule_message += " Zbritja e transportit u aplikua sipas pragjeve te bizneseve."

    return {
        "deliveryMethod": normalized_method,
        "deliveryLabel": str(get_delivery_method_details(normalized_method)["label"]),
        "estimatedDeliveryText": (
            unique_estimates[0]
            if len(unique_estimates) == 1
            else ("Sipas biznesit ne shporte" if unique_estimates else "")
        ),
        "shippingAmount": total_shipping_amount,
        "baseAmount": total_base_amount,
        "citySurcharge": total_city_surcharge,
        "subtotalDiscount": total_subtotal_discount,
        "cityZoneLabel": (
            unique_zone_labels[0]
            if len(unique_zone_labels) == 1
            else ("Zona te kombinuara" if unique_zone_labels else "Qyteti i zgjedhur")
        ),
        "ruleMessage": rule_message,
        "breakdown": group_quotes,
    }


def build_checkout_delivery_option_summaries(
    *,
    shipping_groups: list[dict[str, object]],
    destination_city: str = "",
) -> tuple[list[dict[str, object]], dict[str, dict[str, object]]]:
    available_options: list[dict[str, object]] = []
    quotes_by_method: dict[str, dict[str, object]] = {}
    descriptions = {
        "standard": (
            "Tarifa dhe pragjet e transportit vendosen nga biznesi. "
            "Kur ke disa biznese ne shporte, llogaritja mblidhet per secilin."
        ),
        "express": (
            "Opsion me i shpejte kur bizneset ne shporte e kane aktiv. "
            "Tarifa llogaritet vecmas per secilin biznes."
        ),
        "pickup": (
            "Shfaqet vetem kur te gjitha bizneset ne shporte lejojne pickup. "
            "Adresa dhe orari shfaqen poshte sipas secilit biznes."
        ),
    }

    for index, method in enumerate(DELIVERY_METHODS.keys(), start=1):
        if shipping_groups and not all(
            is_delivery_method_enabled_for_settings(group.get("shippingSettings", {}), method)
            for group in shipping_groups
        ):
            continue

        method_quote = build_checkout_shipping_quote(
            shipping_groups=shipping_groups,
            delivery_method=method,
            destination_city=destination_city,
        )
        quotes_by_method[method] = method_quote
        available_options.append(
            {
                "value": method,
                "label": str(method_quote.get("deliveryLabel") or get_delivery_method_details(method)["label"]),
                "description": descriptions.get(method, "Opsion i rregulluar sipas biznesit."),
                "shippingAmount": round(float(method_quote.get("shippingAmount") or 0), 2),
                "estimatedDeliveryText": str(method_quote.get("estimatedDeliveryText") or "").strip(),
                "badge": f"Opsioni {index:02d}",
            }
        )

    return available_options, quotes_by_method


def build_shipping_quote(
    *,
    connection: DatabaseConnection,
    checkout_items: list[dict[str, object]],
    delivery_method: str,
    destination_city: str = "",
) -> dict[str, object]:
    shipping_groups = build_checkout_shipping_groups(connection, checkout_items)
    available_delivery_options, quotes_by_method = build_checkout_delivery_option_summaries(
        shipping_groups=shipping_groups,
        destination_city=destination_city,
    )
    if not available_delivery_options:
        raise CheckoutProcessError(
            message=(
                "Bizneset ne shporte nuk kane metode te perbashket dergese. "
                "Ndrysho produktet ne shporte ose kontakto bizneset per transportin."
            )
        )

    requested_method = str(get_delivery_method_details(delivery_method)["value"])
    selected_option = next(
        (option for option in available_delivery_options if str(option.get("value") or "") == requested_method),
        None,
    ) or available_delivery_options[0]
    selected_method = str(selected_option.get("value") or "standard")
    selected_quote = quotes_by_method.get(selected_method) or build_checkout_shipping_quote(
        shipping_groups=shipping_groups,
        delivery_method=selected_method,
        destination_city=destination_city,
    )
    selected_quote["availableDeliveryMethods"] = available_delivery_options
    selected_quote["deliveryNotice"] = (
        f"Metoda e dergeses u kalua te `{selected_option['label']}` sepse ishte opsioni i perbashket per bizneset ne shporte."
        if requested_method != selected_method
        else ""
    )
    return selected_quote


def parse_delivery_method(data: dict[str, object]) -> tuple[list[str], str | None]:
    delivery_method = str(data.get("deliveryMethod", "")).strip().lower() or "standard"
    if delivery_method not in DELIVERY_METHODS:
        return ["Menyra e dergeses nuk eshte valide."], None
    return [], delivery_method


def parse_review_rating(data: dict[str, object], field_name: str = "rating") -> tuple[list[str], int | None]:
    raw_value = str(data.get(field_name, "")).strip()
    if not raw_value:
        return ["Zgjidh vleresimin me yje nga 1 deri ne 5."], None

    try:
        rating = int(raw_value)
    except ValueError:
        return ["Vleresimi duhet te jete numer i plote nga 1 deri ne 5."], None

    if rating < 1 or rating > 5:
        return ["Vleresimi duhet te jete nga 1 deri ne 5."], None

    return [], rating


def parse_fulfillment_status(
    data: dict[str, object],
    field_name: str = "fulfillmentStatus",
) -> tuple[list[str], str | None]:
    status = str(data.get(field_name, "")).strip().lower()
    if status not in ORDER_ITEM_FULFILLMENT_STATUSES:
        return ["Statusi i porosise nuk eshte valid."], None
    return [], status


def parse_return_status(
    data: dict[str, object],
    field_name: str = "status",
) -> tuple[list[str], str | None]:
    status = str(data.get(field_name, "")).strip().lower()
    if status not in RETURN_REQUEST_STATUSES:
        return ["Statusi i kerkeses per kthim nuk eshte valid."], None
    return [], status


def parse_business_verification_status(
    data: dict[str, object],
    field_name: str = "verificationStatus",
) -> tuple[list[str], str | None]:
    status = str(data.get(field_name, "")).strip().lower()
    if status not in BUSINESS_VERIFICATION_STATUSES:
        return ["Statusi i verifikimit nuk eshte valid."], None
    return [], status


def parse_business_profile_edit_access_status(
    data: dict[str, object],
    field_name: str = "editAccessStatus",
) -> tuple[list[str], str | None]:
    status = str(data.get(field_name, "")).strip().lower()
    if status not in BUSINESS_PROFILE_EDIT_ACCESS_STATUSES:
        return ["Statusi i editimit te biznesit nuk eshte valid."], None
    return [], status


def parse_stripe_session_id(
    data: dict[str, object],
    field_name: str = "stripeSessionId",
) -> tuple[list[str], str | None]:
    session_id = str(data.get(field_name, "")).strip()
    if not session_id:
        return [f"Sesionit te Stripe i mungon fusha `{field_name}`."], None

    if not session_id.startswith("cs_"):
        return ["Sesioni i Stripe nuk eshte valid."], None

    return [], session_id


def deserialize_product_variant_inventory(
    raw_value: object,
    *,
    category: object = "",
    size: object = "",
    color: object = "",
    stock_quantity: object = 0,
) -> list[dict[str, object]]:
    normalized_category = str(category or "").strip().lower()
    _, normalized_entries = normalize_variant_inventory_value(
        raw_value,
        category=normalized_category,
        fallback_size=str(size or ""),
        fallback_color=str(color or ""),
        fallback_stock_quantity=int(stock_quantity or 0),
    )
    return normalized_entries


def derive_product_variant_mode(variant_inventory: list[dict[str, object]]) -> str:
    has_size = any(str(entry.get("size", "")).strip() for entry in variant_inventory)
    has_color = any(str(entry.get("color", "")).strip() for entry in variant_inventory)
    if has_size and has_color:
        return "color-size"
    if has_size:
        return "size"
    if has_color:
        return "color"
    return "simple"


def serialize_user(row: sqlite3.Row) -> dict[str, object]:
    full_name = (row["full_name"] or "").strip() or build_full_name(
        row["first_name"] or "",
        row["last_name"] or "",
    )
    return {
        "id": row["id"],
        "fullName": full_name,
        "firstName": row["first_name"],
        "lastName": row["last_name"],
        "email": row["email"],
        "birthDate": row["birth_date"],
        "gender": row["gender"],
        "role": row["role"],
        "isEmailVerified": bool(row["is_email_verified"]),
        "emailVerifiedAt": row["email_verified_at"],
        "profileImagePath": normalize_image_path(row["profile_image_path"]),
        "createdAt": row["created_at"],
    }


def serialize_address(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "userId": row["user_id"],
        "addressLine": row["address_line"],
        "city": row["city"],
        "country": row["country"],
        "zipCode": row["zip_code"],
        "phoneNumber": row["phone_number"],
        "isDefault": bool(row["is_default"]),
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


def serialize_business_profile(row: sqlite3.Row) -> dict[str, object]:
    payload = {
        "id": row["id"],
        "userId": row["user_id"],
        "businessName": row["business_name"],
        "businessDescription": row["business_description"],
        "businessNumber": row["business_number"],
        "logoPath": normalize_image_path(row["business_logo_path"]),
        "verificationStatus": (
            str(row["verification_status"] or "").strip().lower()
            if "verification_status" in row.keys()
            else "unverified"
        ),
        "verificationRequestedAt": (
            str(row["verification_requested_at"] or "").strip()
            if "verification_requested_at" in row.keys()
            else ""
        ),
        "verificationVerifiedAt": (
            str(row["verification_verified_at"] or "").strip()
            if "verification_verified_at" in row.keys()
            else ""
        ),
        "verificationNotes": (
            str(row["verification_notes"] or "").strip()
            if "verification_notes" in row.keys()
            else ""
        ),
        "profileEditAccessStatus": (
            str(row["profile_edit_access_status"] or "").strip().lower()
            if "profile_edit_access_status" in row.keys()
            else "locked"
        ),
        "profileEditRequestedAt": (
            str(row["profile_edit_requested_at"] or "").strip()
            if "profile_edit_requested_at" in row.keys()
            else ""
        ),
        "profileEditApprovedAt": (
            str(row["profile_edit_approved_at"] or "").strip()
            if "profile_edit_approved_at" in row.keys()
            else ""
        ),
        "profileEditNotes": (
            str(row["profile_edit_notes"] or "").strip()
            if "profile_edit_notes" in row.keys()
            else ""
        ),
        "phoneNumber": row["phone_number"],
        "city": row["city"],
        "addressLine": row["address_line"],
        "shippingSettings": normalize_business_shipping_settings(
            row["shipping_settings"] if "shipping_settings" in row.keys() else None
        ),
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }
    if "owner_email" in row.keys():
        payload["ownerEmail"] = row["owner_email"]
    if "followers_count" in row.keys():
        payload["followersCount"] = row["followers_count"]
    if "products_count" in row.keys():
        payload["productsCount"] = row["products_count"]
    if "orders_count" in row.keys():
        payload["ordersCount"] = row["orders_count"]
    if "seller_rating" in row.keys():
        payload["sellerRating"] = round(float(row["seller_rating"] or 0), 2)
    if "seller_review_count" in row.keys():
        payload["sellerReviewCount"] = max(0, int(row["seller_review_count"] or 0))
    payload["publicProfileUrl"] = f"/profili-biznesit?id={row['id']}"
    return payload


def serialize_public_business_profile(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "businessName": row["business_name"],
        "businessDescription": row["business_description"],
        "logoPath": normalize_image_path(row["business_logo_path"]),
        "verificationStatus": (
            str(row["verification_status"] or "").strip().lower()
            if "verification_status" in row.keys()
            else "unverified"
        ),
        "city": row["city"],
        "phoneNumber": row["phone_number"],
        "addressLine": row["address_line"],
        "followersCount": row["followers_count"],
        "productsCount": row["products_count"],
        "sellerRating": round(float(row["seller_rating"] or 0), 2)
        if "seller_rating" in row.keys()
        else 0,
        "sellerReviewCount": max(0, int(row["seller_review_count"] or 0))
        if "seller_review_count" in row.keys()
        else 0,
        "profileUrl": f"/profili-biznesit?id={row['id']}",
    }


def serialize_public_business_detail(
    row: sqlite3.Row,
    *,
    is_followed: bool = False,
) -> dict[str, object]:
    payload = serialize_public_business_profile(row)
    payload.update(
        {
            "userId": row["user_id"],
            "businessNumber": row["business_number"],
            "ownerEmail": row["owner_email"],
            "createdAt": row["created_at"],
            "updatedAt": row["updated_at"],
            "isFollowed": is_followed,
        }
    )
    return payload


def serialize_admin_business_profile(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "userId": row["user_id"],
        "businessNumber": row["business_number"],
        "businessName": row["business_name"],
        "businessDescription": row["business_description"],
        "logoPath": normalize_image_path(row["business_logo_path"]),
        "verificationStatus": (
            str(row["verification_status"] or "").strip().lower()
            if "verification_status" in row.keys()
            else "unverified"
        ),
        "verificationRequestedAt": (
            str(row["verification_requested_at"] or "").strip()
            if "verification_requested_at" in row.keys()
            else ""
        ),
        "verificationVerifiedAt": (
            str(row["verification_verified_at"] or "").strip()
            if "verification_verified_at" in row.keys()
            else ""
        ),
        "verificationNotes": (
            str(row["verification_notes"] or "").strip()
            if "verification_notes" in row.keys()
            else ""
        ),
        "profileEditAccessStatus": (
            str(row["profile_edit_access_status"] or "").strip().lower()
            if "profile_edit_access_status" in row.keys()
            else "locked"
        ),
        "profileEditRequestedAt": (
            str(row["profile_edit_requested_at"] or "").strip()
            if "profile_edit_requested_at" in row.keys()
            else ""
        ),
        "profileEditApprovedAt": (
            str(row["profile_edit_approved_at"] or "").strip()
            if "profile_edit_approved_at" in row.keys()
            else ""
        ),
        "profileEditNotes": (
            str(row["profile_edit_notes"] or "").strip()
            if "profile_edit_notes" in row.keys()
            else ""
        ),
        "city": row["city"],
        "addressLine": row["address_line"],
        "phoneNumber": row["phone_number"],
        "shippingSettings": normalize_business_shipping_settings(
            row["shipping_settings"] if "shipping_settings" in row.keys() else None
        ),
        "ownerName": row["owner_full_name"],
        "ownerEmail": row["owner_email"],
        "productsCount": row["products_count"],
        "ordersCount": row["orders_count"],
        "sellerRating": round(float(row["seller_rating"] or 0), 2)
        if "seller_rating" in row.keys()
        else 0,
        "sellerReviewCount": max(0, int(row["seller_review_count"] or 0))
        if "seller_review_count" in row.keys()
        else 0,
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


def serialize_session_user(row: sqlite3.Row) -> dict[str, object]:
    payload = serialize_user(row)
    if row["role"] == "business":
        business_profile = fetch_business_profile_for_user(row["id"])
        if business_profile:
            serialized_profile = serialize_business_profile(business_profile)
            payload["businessName"] = serialized_profile["businessName"]
            payload["businessLogoPath"] = serialized_profile["logoPath"]

    return payload


def serialize_product(row: sqlite3.Row) -> dict[str, object]:
    image_gallery = normalize_image_gallery_value(
        row["image_gallery"],
        fallback_image_path=row["image_path"],
    )
    image_path = image_gallery[0] if image_gallery else normalize_image_path(row["image_path"])
    business_name = None
    if "business_name" in row.keys():
        business_name = str(row["business_name"] or "").strip() or None
    buyers_count = 0
    if "buyers_count" in row.keys():
        try:
            buyers_count = max(0, int(row["buyers_count"] or 0))
        except (TypeError, ValueError):
            buyers_count = 0
    variant_inventory = deserialize_product_variant_inventory(
        row["variant_inventory"] if "variant_inventory" in row.keys() else [],
        category=row["category"] if "category" in row.keys() else "",
        size=row["size"] if "size" in row.keys() else "",
        color=row["color"] if "color" in row.keys() else "",
        stock_quantity=row["stock_quantity"] if "stock_quantity" in row.keys() else 0,
    )
    available_sizes = sorted(
        {
            str(entry.get("size", "")).strip().upper()
            for entry in variant_inventory
            if str(entry.get("size", "")).strip()
        },
        key=lambda next_size: CLOTHING_SIZE_ORDER.get(next_size, 999),
    )
    available_colors = sorted(
        {
            str(entry.get("color", "")).strip().lower()
            for entry in variant_inventory
            if str(entry.get("color", "")).strip()
        }
    )
    package_amount_value = 0.0
    if "package_amount_value" in row.keys():
        try:
            package_amount_value = round(float(row["package_amount_value"] or 0), 2)
        except (TypeError, ValueError):
            package_amount_value = 0.0
    package_amount_unit = (
        str(row["package_amount_unit"] or "").strip().lower()
        if "package_amount_unit" in row.keys()
        else ""
    )
    requires_variant_selection = len(variant_inventory) > 1 and any(
        str(entry.get("size", "")).strip() or str(entry.get("color", "")).strip()
        for entry in variant_inventory
    )

    return {
        "id": row["id"],
        "articleNumber": (
            str(row["article_number"] or "").strip()
            if "article_number" in row.keys()
            else ""
        ),
        "title": row["title"],
        "description": row["description"],
        "price": row["price"],
        "imagePath": image_path,
        "imageGallery": image_gallery,
        "category": row["category"],
        "productType": row["product_type"],
        "size": row["size"],
        "color": row["color"],
        "variantInventory": variant_inventory,
        "variantMode": derive_product_variant_mode(variant_inventory),
        "requiresVariantSelection": requires_variant_selection,
        "availableSizes": available_sizes,
        "availableColors": available_colors,
        "packageAmountValue": package_amount_value,
        "packageAmountUnit": package_amount_unit,
        "stockQuantity": row["stock_quantity"],
        "isPublic": bool(row["is_public"]),
        "showStockPublic": bool(row["show_stock_public"]),
        "createdByUserId": row["created_by_user_id"],
        "createdAt": row["created_at"],
        "businessName": business_name,
        "buyersCount": buyers_count,
        "averageRating": round(float(row["average_rating"] or 0), 2)
        if "average_rating" in row.keys()
        else 0,
        "reviewCount": max(0, int(row["review_count"] or 0))
        if "review_count" in row.keys()
        else 0,
    }


def serialize_cart_item(row: sqlite3.Row) -> dict[str, object]:
    payload = serialize_product(row)
    payload["productId"] = payload["id"]
    if "cart_line_id" in row.keys():
        payload["id"] = row["cart_line_id"]
        payload["cartLineId"] = row["cart_line_id"]
    payload["variantKey"] = (
        str(row["variant_key"] or "").strip() if "variant_key" in row.keys() else ""
    )
    payload["selectedSize"] = (
        str(row["selected_size"] or "").strip().upper()
        if "selected_size" in row.keys()
        else str(payload.get("size") or "").strip().upper()
    )
    payload["selectedColor"] = (
        str(row["selected_color"] or "").strip().lower()
        if "selected_color" in row.keys()
        else str(payload.get("color") or "").strip().lower()
    )
    payload["size"] = payload["selectedSize"]
    payload["color"] = payload["selectedColor"]
    payload["variantLabel"] = (
        str(row["variant_label"] or "").strip()
        if "variant_label" in row.keys()
        else build_product_variant_label(
            size=payload["selectedSize"],
            color=payload["selectedColor"],
        )
    )
    payload["quantity"] = row["quantity"]
    return payload


def serialize_order_item(row: sqlite3.Row) -> dict[str, object]:
    quantity = max(1, int(row["quantity"] or 1))
    unit_price = round(float(row["unit_price"] or 0), 2)
    variant_snapshot: list[dict[str, object]] = []
    if "product_variant_snapshot" in row.keys():
        try:
            parsed_variant_snapshot = json.loads(str(row["product_variant_snapshot"] or "[]"))
        except json.JSONDecodeError:
            parsed_variant_snapshot = []
        if isinstance(parsed_variant_snapshot, list):
            variant_snapshot = parsed_variant_snapshot

    return {
        "id": row["id"],
        "orderId": row["order_id"],
        "productId": row["product_id"],
        "businessUserId": row["business_user_id"],
        "businessName": row["business_name_snapshot"],
        "title": row["product_title"],
        "description": row["product_description"],
        "imagePath": normalize_image_path(row["product_image_path"]),
        "category": row["product_category"],
        "productType": row["product_type"],
        "size": row["product_size"],
        "color": row["product_color"],
        "variantKey": str(row["product_variant_key"] or "").strip()
        if "product_variant_key" in row.keys()
        else "",
        "variantLabel": str(row["product_variant_label"] or "").strip()
        if "product_variant_label" in row.keys()
        else "",
        "variantSnapshot": variant_snapshot,
        "packageAmountValue": round(float(row["product_package_amount_value"] or 0), 2)
        if "product_package_amount_value" in row.keys()
        else 0,
        "packageAmountUnit": str(row["product_package_amount_unit"] or "").strip().lower()
        if "product_package_amount_unit" in row.keys()
        else "",
        "unitPrice": unit_price,
        "quantity": quantity,
        "totalPrice": round(unit_price * quantity, 2),
        "fulfillmentStatus": (
            str(row["fulfillment_status"] or "").strip().lower()
            if "fulfillment_status" in row.keys()
            else "confirmed"
        ),
        "confirmedAt": str(row["confirmed_at"] or "").strip()
        if "confirmed_at" in row.keys()
        else "",
        "confirmationDueAt": str(row["confirmation_due_at"] or "").strip()
        if "confirmation_due_at" in row.keys()
        else "",
        "trackingCode": str(row["tracking_code"] or "").strip()
        if "tracking_code" in row.keys()
        else "",
        "trackingUrl": str(row["tracking_url"] or "").strip()
        if "tracking_url" in row.keys()
        else "",
        "shippedAt": str(row["shipped_at"] or "").strip()
        if "shipped_at" in row.keys()
        else "",
        "deliveredAt": str(row["delivered_at"] or "").strip()
        if "delivered_at" in row.keys()
        else "",
        "cancelledAt": str(row["cancelled_at"] or "").strip()
        if "cancelled_at" in row.keys()
        else "",
        "commissionRate": round(float(row["commission_rate"] or 0), 4)
        if "commission_rate" in row.keys()
        else 0,
        "commissionAmount": round(float(row["commission_amount"] or 0), 2)
        if "commission_amount" in row.keys()
        else 0,
        "sellerEarningsAmount": round(float(row["seller_earnings_amount"] or 0), 2)
        if "seller_earnings_amount" in row.keys()
        else 0,
        "payoutStatus": str(row["payout_status"] or "").strip().lower()
        if "payout_status" in row.keys()
        else "pending",
        "payoutDueAt": str(row["payout_due_at"] or "").strip()
        if "payout_due_at" in row.keys()
        else "",
        "returnRequestReason": str(row["return_request_reason"] or "").strip()
        if "return_request_reason" in row.keys()
        else "",
        "returnRequestDetails": str(row["return_request_details"] or "").strip()
        if "return_request_details" in row.keys()
        else "",
        "returnRequestStatus": str(row["return_request_status"] or "").strip().lower()
        if "return_request_status" in row.keys()
        else "",
        "createdAt": row["created_at"],
    }


def summarize_order_fulfillment_status(items: list[dict[str, object]]) -> str:
    statuses = [str(item.get("fulfillmentStatus") or "").strip().lower() for item in items if str(item.get("fulfillmentStatus") or "").strip()]
    if not statuses:
        return "pending_confirmation"
    unique_statuses = set(statuses)
    if "pending_confirmation" in unique_statuses:
        return "pending_confirmation"
    if unique_statuses == {"returned"}:
        return "returned"
    if unique_statuses == {"cancelled"}:
        return "cancelled"
    if "cancelled" in unique_statuses and len(unique_statuses) > 1:
        return "partially_confirmed"
    if unique_statuses.issubset({"delivered", "returned"}):
        return "delivered"
    if unique_statuses.issubset({"shipped", "delivered", "returned"}):
        return "shipped"
    if unique_statuses.issubset({"packed", "shipped", "delivered", "returned"}):
        return "packed"
    if unique_statuses.issubset({"confirmed", "packed", "shipped", "delivered", "returned"}):
        if "delivered" in unique_statuses:
            return "delivered"
        if "shipped" in unique_statuses:
            return "shipped"
        if "packed" in unique_statuses:
            return "packed"
    return "confirmed"


def serialize_order(
    row: sqlite3.Row,
    items: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    normalized_items = list(items or [])
    total_items = sum(max(0, int(item.get("quantity", 0) or 0)) for item in normalized_items)
    calculated_total_price = round(
        sum(float(item.get("totalPrice", 0) or 0) for item in normalized_items),
        2,
    )
    subtotal_amount = round(float(row["subtotal_amount"] or calculated_total_price), 2) if "subtotal_amount" in row.keys() else calculated_total_price
    discount_amount = round(float(row["discount_amount"] or 0), 2) if "discount_amount" in row.keys() else 0
    shipping_amount = round(float(row["shipping_amount"] or 0), 2) if "shipping_amount" in row.keys() else 0
    total_price = round(float(row["total_amount"] or calculated_total_price), 2) if "total_amount" in row.keys() else calculated_total_price

    return {
        "id": row["id"],
        "userId": row["user_id"],
        "customerName": row["customer_full_name"],
        "customerEmail": row["customer_email"],
        "paymentMethod": row["payment_method"],
        "status": row["status"],
        "fulfillmentStatus": summarize_order_fulfillment_status(normalized_items),
        "addressLine": row["address_line"],
        "city": row["city"],
        "country": row["country"],
        "zipCode": row["zip_code"],
        "phoneNumber": row["phone_number"],
        "createdAt": row["created_at"],
        "totalItems": total_items,
        "subtotalAmount": subtotal_amount,
        "discountAmount": discount_amount,
        "shippingAmount": shipping_amount,
        "totalPrice": total_price,
        "promoCode": str(row["promo_code"] or "").strip().upper() if "promo_code" in row.keys() else "",
        "deliveryMethod": str(row["delivery_method"] or "").strip().lower() if "delivery_method" in row.keys() else "standard",
        "deliveryLabel": str(row["delivery_label"] or "").strip() if "delivery_label" in row.keys() else "",
        "estimatedDeliveryText": str(row["estimated_delivery_text"] or "").strip()
        if "estimated_delivery_text" in row.keys()
        else "",
        "items": normalized_items,
    }


def serialize_notification(row: sqlite3.Row) -> dict[str, object]:
    try:
        metadata = json.loads(str(row["metadata"] or "{}"))
    except (TypeError, ValueError, json.JSONDecodeError):
        metadata = {}

    return {
        "id": row["id"],
        "type": str(row["type"] or "info").strip().lower() or "info",
        "title": str(row["title"] or "").strip(),
        "body": str(row["body"] or "").strip(),
        "href": str(row["href"] or "").strip(),
        "isRead": bool(row["is_read"]),
        "createdAt": str(row["created_at"] or "").strip(),
        "readAt": str(row["read_at"] or "").strip(),
        "metadata": metadata if isinstance(metadata, dict) else {},
    }


def serialize_product_review(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "productId": row["product_id"],
        "orderItemId": row["order_item_id"],
        "userId": row["user_id"],
        "rating": max(1, min(5, int(row["rating"] or 1))),
        "title": str(row["review_title"] or "").strip(),
        "body": str(row["review_body"] or "").strip(),
        "status": str(row["status"] or "").strip().lower() or "published",
        "createdAt": str(row["created_at"] or "").strip(),
        "updatedAt": str(row["updated_at"] or "").strip(),
        "authorName": str(row["author_name"] or "").strip() or "User",
        "authorInitials": get_business_initials(str(row["author_name"] or "").strip() or "U"),
    }


def serialize_return_request(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "orderId": row["order_id"],
        "orderItemId": row["order_item_id"],
        "userId": row["user_id"],
        "businessUserId": row["business_user_id"],
        "reason": str(row["reason"] or "").strip(),
        "details": str(row["details"] or "").strip(),
        "status": str(row["status"] or "").strip().lower() or "requested",
        "resolutionNotes": str(row["resolution_notes"] or "").strip(),
        "resolvedAt": str(row["resolved_at"] or "").strip(),
        "createdAt": str(row["created_at"] or "").strip(),
        "updatedAt": str(row["updated_at"] or "").strip(),
        "productTitle": str(row["product_title"] or "").strip() if "product_title" in row.keys() else "",
        "productImagePath": normalize_image_path(row["product_image_path"])
        if "product_image_path" in row.keys()
        else "",
        "businessName": str(row["business_name_snapshot"] or "").strip()
        if "business_name_snapshot" in row.keys()
        else "",
        "customerName": str(row["customer_full_name"] or "").strip()
        if "customer_full_name" in row.keys()
        else "",
    }


def can_use_chat(user: sqlite3.Row | None) -> bool:
    return bool(user and str(user["role"] or "").strip() in CHAT_PARTICIPANT_ROLES)


def is_user_online_from_last_seen(value: object) -> bool:
    last_seen_at = parse_storage_datetime(value)
    if not last_seen_at:
        return False

    return (utc_now() - last_seen_at).total_seconds() <= CHAT_ONLINE_WINDOW_SECONDS


def get_chat_role_label(role: str | None) -> str:
    normalized_role = str(role or "").strip().lower()
    if normalized_role == "business":
        return "biznes"
    if normalized_role == "admin":
        return "customer support"
    return "klient"


def get_chat_display_name(
    *,
    role: str | None,
    full_name: str | None = None,
    business_name: str | None = None,
) -> str:
    normalized_role = str(role or "").strip().lower()
    normalized_full_name = str(full_name or "").strip()
    normalized_business_name = str(business_name or "").strip()

    if normalized_role == "business":
        return normalized_business_name or normalized_full_name or "Biznes"
    if normalized_role == "admin":
        return "Customer Support"
    return normalized_full_name or "Klient"


def extract_chat_participant(
    row: sqlite3.Row,
    *,
    prefix: str,
) -> dict[str, object]:
    role = str(row[f"{prefix}_role"] or "").strip().lower() or "client"
    business_profile_id = 0
    try:
        business_profile_id = max(0, int(row[f"{prefix}_business_profile_id"] or 0))
    except (TypeError, ValueError):
        business_profile_id = 0

    display_name = get_chat_display_name(
        role=role,
        full_name=str(row[f"{prefix}_full_name"] or "").strip(),
        business_name=str(row[f"{prefix}_business_name"] or "").strip(),
    )

    image_path = normalize_image_path(
        row[f"{prefix}_business_logo_path"] if role == "business" else row[f"{prefix}_profile_image_path"]
    )

    return {
        "userId": int(row[f"{prefix}_user_id"]),
        "role": role,
        "displayName": display_name,
        "imagePath": image_path,
        "isOnline": is_user_online_from_last_seen(row[f"{prefix}_last_seen_at"]),
        "lastSeenAt": str(row[f"{prefix}_last_seen_at"] or "").strip(),
        "businessProfileId": business_profile_id,
        "profileUrl": f"/profili-biznesit?id={business_profile_id}" if role == "business" and business_profile_id > 0 else "",
    }


def serialize_chat_conversation(
    row: sqlite3.Row,
    *,
    viewer_user_id: int,
) -> dict[str, object]:
    participant_one = extract_chat_participant(row, prefix="participant_one")
    participant_two = extract_chat_participant(row, prefix="participant_two")
    is_first_participant_view = int(participant_one["userId"]) == int(viewer_user_id)
    counterpart = participant_two if is_first_participant_view else participant_one
    unread_count = 0
    messages_count = 0

    if "unread_count" in row.keys():
        try:
            unread_count = max(0, int(row["unread_count"] or 0))
        except (TypeError, ValueError):
            unread_count = 0

    if "messages_count" in row.keys():
        try:
            messages_count = max(0, int(row["messages_count"] or 0))
        except (TypeError, ValueError):
            messages_count = 0

    return {
        "id": int(row["id"]),
        "clientUserId": int(row["client_user_id"]),
        "businessUserId": int(row["business_user_id"]),
        "businessProfileId": int(counterpart["businessProfileId"]),
        "businessName": (
            str(participant_two["displayName"])
            if str(participant_two["role"]) == "business"
            else str(participant_one["displayName"])
            if str(participant_one["role"]) == "business"
            else ""
        ),
        "clientName": (
            str(participant_two["displayName"])
            if str(participant_two["role"]) == "client"
            else str(participant_one["displayName"])
            if str(participant_one["role"]) == "client"
            else ""
        ),
        "counterpartName": str(counterpart["displayName"]),
        "counterpartRole": str(counterpart["role"]),
        "counterpartImagePath": str(counterpart["imagePath"]),
        "counterpartIsOnline": bool(counterpart["isOnline"]),
        "counterpartLastSeenAt": str(counterpart["lastSeenAt"]),
        "profileUrl": str(counterpart["profileUrl"]),
        "lastMessagePreview": str(row["last_message_body"] or "").strip(),
        "messagesCount": messages_count,
        "unreadCount": unread_count,
        "createdAt": str(row["created_at"] or "").strip(),
        "updatedAt": str(row["updated_at"] or "").strip(),
        "lastMessageAt": str(row["last_message_at"] or row["updated_at"] or row["created_at"] or "").strip(),
    }


def serialize_chat_message(
    row: sqlite3.Row,
    *,
    viewer_user_id: int,
) -> dict[str, object]:
    sender_role = str(row["sender_role"] or "").strip() or "client"
    sender_name = get_chat_display_name(
        role=sender_role,
        full_name=str(row["sender_full_name"] or "").strip(),
        business_name=str(row["sender_business_name"] or "").strip(),
    )

    return {
        "id": int(row["id"]),
        "conversationId": int(row["conversation_id"]),
        "senderUserId": int(row["sender_user_id"]),
        "recipientUserId": int(row["recipient_user_id"]),
        "body": str(row["body"] or "").strip(),
        "attachmentPath": normalize_image_path(row["attachment_path"]) if str(row["attachment_path"] or "").startswith("/uploads/") else str(row["attachment_path"] or "").strip(),
        "attachmentContentType": str(row["attachment_content_type"] or "").strip(),
        "attachmentFileName": str(row["attachment_file_name"] or "").strip(),
        "createdAt": str(row["created_at"] or "").strip(),
        "editedAt": str(row["edited_at"] or "").strip(),
        "deletedAt": str(row["deleted_at"] or "").strip(),
        "readAt": str(row["read_at"] or "").strip(),
        "senderName": sender_name,
        "senderRole": sender_role,
        "isOwn": int(row["sender_user_id"]) == int(viewer_user_id),
    }


def fetch_chat_conversations_for_user(user_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                c.id,
                c.client_user_id,
                c.business_user_id,
                c.business_profile_id,
                c.created_at,
                c.updated_at,
                c.last_message_at,
                c.client_user_id AS participant_one_user_id,
                COALESCE(participant_one.role, 'client') AS participant_one_role,
                COALESCE(participant_one.full_name, 'Klient') AS participant_one_full_name,
                COALESCE(participant_one.profile_image_path, '') AS participant_one_profile_image_path,
                COALESCE(participant_one.last_seen_at, '') AS participant_one_last_seen_at,
                COALESCE(
                    participant_one_business.id,
                    CASE
                        WHEN COALESCE(participant_one.role, '') = 'business' THEN c.business_profile_id
                        ELSE 0
                    END,
                    0
                ) AS participant_one_business_profile_id,
                COALESCE(participant_one_business.business_name, '') AS participant_one_business_name,
                COALESCE(participant_one_business.business_logo_path, '') AS participant_one_business_logo_path,
                c.business_user_id AS participant_two_user_id,
                COALESCE(participant_two.role, 'client') AS participant_two_role,
                COALESCE(participant_two.full_name, 'Klient') AS participant_two_full_name,
                COALESCE(participant_two.profile_image_path, '') AS participant_two_profile_image_path,
                COALESCE(participant_two.last_seen_at, '') AS participant_two_last_seen_at,
                COALESCE(
                    participant_two_business.id,
                    CASE
                        WHEN COALESCE(participant_two.role, '') = 'business' THEN c.business_profile_id
                        ELSE 0
                    END,
                    0
                ) AS participant_two_business_profile_id,
                COALESCE(participant_two_business.business_name, '') AS participant_two_business_name,
                COALESCE(participant_two_business.business_logo_path, '') AS participant_two_business_logo_path,
                COALESCE((
                    SELECT COUNT(*)
                    FROM chat_messages cm
                    WHERE cm.conversation_id = c.id
                ), 0) AS messages_count,
                COALESCE((
                    SELECT COUNT(*)
                    FROM chat_messages cm
                    WHERE cm.conversation_id = c.id
                      AND cm.recipient_user_id = ?
                      AND COALESCE(TRIM(cm.read_at), '') = ''
                ), 0) AS unread_count,
                COALESCE((
                    SELECT cm.body
                    FROM chat_messages cm
                    WHERE cm.conversation_id = c.id
                    ORDER BY cm.id DESC
                    LIMIT 1
                ), '') AS last_message_body
            FROM chat_conversations c
            LEFT JOIN users participant_one ON participant_one.id = c.client_user_id
            LEFT JOIN business_profiles participant_one_business ON participant_one_business.user_id = c.client_user_id
            LEFT JOIN users participant_two ON participant_two.id = c.business_user_id
            LEFT JOIN business_profiles participant_two_business ON participant_two_business.user_id = c.business_user_id
            WHERE c.client_user_id = ?
               OR c.business_user_id = ?
            ORDER BY c.last_message_at DESC, c.id DESC
            """,
            (user_id, user_id, user_id),
        ).fetchall()


def fetch_chat_conversation_for_user(
    conversation_id: int,
    user_id: int,
) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                c.id,
                c.client_user_id,
                c.business_user_id,
                c.business_profile_id,
                c.created_at,
                c.updated_at,
                c.last_message_at,
                c.client_user_id AS participant_one_user_id,
                COALESCE(participant_one.role, 'client') AS participant_one_role,
                COALESCE(participant_one.full_name, 'Klient') AS participant_one_full_name,
                COALESCE(participant_one.profile_image_path, '') AS participant_one_profile_image_path,
                COALESCE(participant_one.last_seen_at, '') AS participant_one_last_seen_at,
                COALESCE(
                    participant_one_business.id,
                    CASE
                        WHEN COALESCE(participant_one.role, '') = 'business' THEN c.business_profile_id
                        ELSE 0
                    END,
                    0
                ) AS participant_one_business_profile_id,
                COALESCE(participant_one_business.business_name, '') AS participant_one_business_name,
                COALESCE(participant_one_business.business_logo_path, '') AS participant_one_business_logo_path,
                c.business_user_id AS participant_two_user_id,
                COALESCE(participant_two.role, 'client') AS participant_two_role,
                COALESCE(participant_two.full_name, 'Klient') AS participant_two_full_name,
                COALESCE(participant_two.profile_image_path, '') AS participant_two_profile_image_path,
                COALESCE(participant_two.last_seen_at, '') AS participant_two_last_seen_at,
                COALESCE(
                    participant_two_business.id,
                    CASE
                        WHEN COALESCE(participant_two.role, '') = 'business' THEN c.business_profile_id
                        ELSE 0
                    END,
                    0
                ) AS participant_two_business_profile_id,
                COALESCE(participant_two_business.business_name, '') AS participant_two_business_name,
                COALESCE(participant_two_business.business_logo_path, '') AS participant_two_business_logo_path,
                COALESCE((
                    SELECT COUNT(*)
                    FROM chat_messages cm
                    WHERE cm.conversation_id = c.id
                ), 0) AS messages_count,
                COALESCE((
                    SELECT COUNT(*)
                    FROM chat_messages cm
                    WHERE cm.conversation_id = c.id
                      AND cm.recipient_user_id = ?
                      AND COALESCE(TRIM(cm.read_at), '') = ''
                ), 0) AS unread_count,
                COALESCE((
                    SELECT cm.body
                    FROM chat_messages cm
                    WHERE cm.conversation_id = c.id
                    ORDER BY cm.id DESC
                    LIMIT 1
                ), '') AS last_message_body
            FROM chat_conversations c
            LEFT JOIN users participant_one ON participant_one.id = c.client_user_id
            LEFT JOIN business_profiles participant_one_business ON participant_one_business.user_id = c.client_user_id
            LEFT JOIN users participant_two ON participant_two.id = c.business_user_id
            LEFT JOIN business_profiles participant_two_business ON participant_two_business.user_id = c.business_user_id
            WHERE c.id = ?
              AND (c.client_user_id = ? OR c.business_user_id = ?)
            LIMIT 1
            """,
            (user_id, conversation_id, user_id, user_id),
        ).fetchone()


def fetch_chat_messages_for_conversation(conversation_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                m.id,
                m.conversation_id,
                m.sender_user_id,
                m.recipient_user_id,
                m.body,
                m.attachment_path,
                m.attachment_content_type,
                m.attachment_file_name,
                m.created_at,
                m.edited_at,
                m.deleted_at,
                m.read_at,
                COALESCE(sender.full_name, 'Perdorues') AS sender_full_name,
                COALESCE(sender.role, 'client') AS sender_role,
                COALESCE(sender_business.business_name, '') AS sender_business_name
            FROM chat_messages m
            LEFT JOIN users sender ON sender.id = m.sender_user_id
            LEFT JOIN business_profiles sender_business ON sender_business.user_id = m.sender_user_id
            WHERE m.conversation_id = ?
            ORDER BY m.id ASC
            """,
            (conversation_id,),
        ).fetchall()


def fetch_pending_chat_unread_reminder_rows(
    *,
    limit: int = CHAT_UNREAD_REMINDER_BATCH_LIMIT,
) -> list[sqlite3.Row]:
    normalized_limit = max(1, int(limit or CHAT_UNREAD_REMINDER_BATCH_LIMIT))
    cutoff_value = datetime_to_storage_text(
        utc_now() - timedelta(hours=CHAT_UNREAD_REMINDER_AFTER_HOURS)
    )
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                m.id,
                m.conversation_id,
                m.sender_user_id,
                m.recipient_user_id,
                m.body,
                m.created_at,
                COALESCE(sender.full_name, '') AS sender_full_name,
                COALESCE(sender.role, 'client') AS sender_role,
                COALESCE(sender_business.business_name, '') AS sender_business_name,
                COALESCE(recipient.first_name, '') AS recipient_first_name,
                COALESCE(recipient.full_name, '') AS recipient_full_name,
                COALESCE(recipient.email, '') AS recipient_email
            FROM chat_messages m
            INNER JOIN (
                SELECT
                    conversation_id,
                    recipient_user_id,
                    MAX(id) AS latest_unread_message_id
                FROM chat_messages
                WHERE COALESCE(TRIM(read_at), '') = ''
                  AND COALESCE(TRIM(reminder_sent_at), '') = ''
                  AND created_at <= ?
                GROUP BY conversation_id, recipient_user_id
            ) pending ON pending.latest_unread_message_id = m.id
            LEFT JOIN users sender ON sender.id = m.sender_user_id
            LEFT JOIN business_profiles sender_business ON sender_business.user_id = m.sender_user_id
            LEFT JOIN users recipient ON recipient.id = m.recipient_user_id
            WHERE COALESCE(TRIM(recipient.email), '') != ''
              AND COALESCE(recipient.role, 'client') = 'client'
              AND m.id = (
                    SELECT latest_message.id
                    FROM chat_messages latest_message
                    WHERE latest_message.conversation_id = m.conversation_id
                    ORDER BY latest_message.id DESC
                    LIMIT 1
              )
            ORDER BY m.created_at ASC, m.id ASC
            LIMIT ?
            """,
            (cutoff_value, normalized_limit),
        ).fetchall()


def mark_chat_unread_reminder_sent(message_id: int) -> None:
    reminder_timestamp = datetime_to_storage_text(utc_now())
    with get_db_connection() as connection:
        connection.execute(
            """
            UPDATE chat_messages
            SET reminder_sent_at = ?
            WHERE id = ?
            """,
            (reminder_timestamp, message_id),
        )


def mark_chat_messages_as_read(
    conversation_id: int,
    recipient_user_id: int,
) -> None:
    read_at_value = datetime_to_storage_text(utc_now())
    with get_db_connection() as connection:
        connection.execute(
            """
            UPDATE chat_messages
            SET read_at = ?
            WHERE conversation_id = ?
              AND recipient_user_id = ?
              AND COALESCE(TRIM(read_at), '') = ''
            """,
            (read_at_value, conversation_id, recipient_user_id),
        )


def set_chat_typing_state(
    conversation_id: int,
    user_id: int,
    *,
    is_typing: bool,
) -> None:
    with get_db_connection() as connection:
        if not is_typing:
            connection.execute(
                """
                DELETE FROM chat_typing_states
                WHERE conversation_id = ? AND user_id = ?
                """,
                (conversation_id, user_id),
            )
            return

        timestamp = datetime_to_storage_text(utc_now())
        connection.execute(
            """
            DELETE FROM chat_typing_states
            WHERE conversation_id = ? AND user_id = ?
            """,
            (conversation_id, user_id),
        )
        connection.execute(
            """
            INSERT INTO chat_typing_states (
                conversation_id,
                user_id,
                updated_at
            )
            VALUES (?, ?, ?)
            """,
            (conversation_id, user_id, timestamp),
        )


def is_counterpart_typing(
    conversation_id: int,
    viewer_user_id: int,
) -> bool:
    cutoff_value = datetime_to_storage_text(
        utc_now() - timedelta(seconds=CHAT_TYPING_WINDOW_SECONDS)
    )
    with get_db_connection() as connection:
        row = connection.execute(
            """
            SELECT 1
            FROM chat_typing_states
            WHERE conversation_id = ?
              AND user_id != ?
              AND updated_at >= ?
            LIMIT 1
            """,
            (conversation_id, viewer_user_id, cutoff_value),
        ).fetchone()
        return bool(row)


def ensure_chat_conversation_between_users(
    first_user_id: int,
    second_user_id: int,
    business_profile_id: int | None = None,
) -> int:
    with get_db_connection() as connection:
        existing_row = connection.execute(
            """
            SELECT id
            FROM chat_conversations
            WHERE (client_user_id = ? AND business_user_id = ?)
               OR (client_user_id = ? AND business_user_id = ?)
            LIMIT 1
            """,
            (first_user_id, second_user_id, second_user_id, first_user_id),
        ).fetchone()
        if existing_row:
            return int(existing_row["id"])

        timestamp = datetime_to_storage_text(utc_now())
        return execute_insert_and_get_id(
            connection,
            """
            INSERT INTO chat_conversations (
                client_user_id,
                business_user_id,
                business_profile_id,
                created_at,
                updated_at,
                last_message_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                first_user_id,
                second_user_id,
                business_profile_id,
                timestamp,
                timestamp,
                timestamp,
            ),
        )


def insert_chat_message(
    conversation_id: int,
    sender_user_id: int,
    recipient_user_id: int,
    body: str,
    *,
    attachment_path: str = "",
    attachment_content_type: str = "",
    attachment_file_name: str = "",
) -> int:
    timestamp = datetime_to_storage_text(utc_now())
    with get_db_connection() as connection:
        message_id = execute_insert_and_get_id(
            connection,
            """
            INSERT INTO chat_messages (
                conversation_id,
                sender_user_id,
                recipient_user_id,
                body,
                attachment_path,
                attachment_content_type,
                attachment_file_name,
                created_at,
                edited_at,
                deleted_at,
                read_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, '', '', '')
            """,
            (
                conversation_id,
                sender_user_id,
                recipient_user_id,
                body,
                str(attachment_path or "").strip(),
                str(attachment_content_type or "").strip(),
                str(attachment_file_name or "").strip(),
                timestamp,
            ),
        )
        connection.execute(
            """
            UPDATE chat_conversations
            SET
                updated_at = ?,
                last_message_at = ?
            WHERE id = ?
            """,
            (timestamp, timestamp, conversation_id),
        )
        return message_id


def fetch_chat_message_by_id(message_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                m.id,
                m.conversation_id,
                m.sender_user_id,
                m.recipient_user_id,
                m.body,
                m.attachment_path,
                m.attachment_content_type,
                m.attachment_file_name,
                m.created_at,
                m.edited_at,
                m.deleted_at,
                m.read_at,
                COALESCE(sender.full_name, 'Perdorues') AS sender_full_name,
                COALESCE(sender.role, 'client') AS sender_role,
                COALESCE(sender_business.business_name, '') AS sender_business_name
            FROM chat_messages m
            LEFT JOIN users sender ON sender.id = m.sender_user_id
            LEFT JOIN business_profiles sender_business ON sender_business.user_id = m.sender_user_id
            WHERE m.id = ?
            LIMIT 1
            """,
            (message_id,),
        ).fetchone()


def update_chat_message_content(
    message_id: int,
    *,
    next_body: str,
) -> None:
    timestamp = datetime_to_storage_text(utc_now())
    with get_db_connection() as connection:
        connection.execute(
            """
            UPDATE chat_messages
            SET
                body = ?,
                edited_at = ?
            WHERE id = ?
            """,
            (next_body, timestamp, message_id),
        )


def delete_chat_message(message_id: int) -> None:
    timestamp = datetime_to_storage_text(utc_now())
    with get_db_connection() as connection:
        connection.execute(
            """
            UPDATE chat_messages
            SET
                body = 'Mesazhi u fshi.',
                attachment_path = '',
                attachment_content_type = '',
                attachment_file_name = '',
                deleted_at = ?,
                edited_at = ''
            WHERE id = ?
            """,
            (timestamp, message_id),
        )


def fetch_user_by_email(email: str) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
            """
            + USER_AUTH_SELECT_COLUMNS
            + """
            FROM users
            WHERE email = ?
            """,
            (email,),
        ).fetchone()


def fetch_user_by_id(user_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
            """
            + USER_AUTH_SELECT_COLUMNS
            + """
            FROM users
            WHERE id = ?
            """,
            (user_id,),
        ).fetchone()


def fetch_support_admin_user(exclude_user_id: int | None = None) -> sqlite3.Row | None:
    query = (
        """
        SELECT
        """
        + USER_AUTH_SELECT_COLUMNS
        + """
        FROM users
        WHERE role = 'admin'
        """
    )
    params: list[object] = []
    if exclude_user_id is not None and int(exclude_user_id) > 0:
        query += " AND id != ?"
        params.append(int(exclude_user_id))

    query += " ORDER BY id ASC LIMIT 1"

    with get_db_connection() as connection:
        return connection.execute(query, tuple(params)).fetchone()


def touch_user_presence(user_id: int, known_last_seen_at: object = "") -> None:
    normalized_user_id = int(user_id or 0)
    if normalized_user_id <= 0:
        return

    parsed_last_seen_at = parse_storage_datetime(known_last_seen_at)
    if parsed_last_seen_at and (
        utc_now() - parsed_last_seen_at
    ).total_seconds() < USER_PRESENCE_HEARTBEAT_SECONDS:
        return

    with get_db_connection() as connection:
        connection.execute(
            """
            UPDATE users
            SET last_seen_at = ?
            WHERE id = ?
            """,
            (datetime_to_storage_text(utc_now()), normalized_user_id),
        )


def fetch_email_verification_row(
    connection: sqlite3.Connection,
    user_id: int,
) -> sqlite3.Row | None:
    return connection.execute(
        """
        SELECT
            user_id,
            code_hash,
            expires_at,
            attempts,
            created_at,
            updated_at
        FROM email_verification_codes
        WHERE user_id = ?
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()


def save_email_verification_code(
    connection: sqlite3.Connection,
    user_id: int,
    code: str,
) -> str:
    expires_at = datetime_to_storage_text(
        utc_now() + timedelta(minutes=EMAIL_VERIFICATION_TTL_MINUTES)
    )
    code_hash = hash_password(code)
    connection.execute(
        """
        INSERT INTO email_verification_codes (
            user_id,
            code_hash,
            expires_at,
            attempts,
            created_at,
            updated_at
        )
        VALUES (?, ?, ?, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT(user_id) DO UPDATE SET
            code_hash = excluded.code_hash,
            expires_at = excluded.expires_at,
            attempts = 0,
            updated_at = CURRENT_TIMESTAMP
        """,
        (user_id, code_hash, expires_at),
    )
    return expires_at


def delete_email_verification_code(
    connection: sqlite3.Connection,
    user_id: int,
) -> None:
    connection.execute(
        "DELETE FROM email_verification_codes WHERE user_id = ?",
        (user_id,),
    )


def is_email_verification_expired(row: sqlite3.Row | None) -> bool:
    if not row:
        return True

    expires_at = parse_storage_datetime(row["expires_at"])
    if not expires_at:
        return True

    return expires_at < utc_now()


def fetch_password_reset_row(
    connection: sqlite3.Connection,
    user_id: int,
) -> sqlite3.Row | None:
    return connection.execute(
        """
        SELECT
            user_id,
            code_hash,
            expires_at,
            attempts,
            created_at,
            updated_at
        FROM password_reset_codes
        WHERE user_id = ?
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()


def save_password_reset_code(
    connection: sqlite3.Connection,
    user_id: int,
    code: str,
) -> str:
    expires_at = datetime_to_storage_text(
        utc_now() + timedelta(minutes=PASSWORD_RESET_TTL_MINUTES)
    )
    code_hash = hash_password(code)
    connection.execute(
        """
        INSERT INTO password_reset_codes (
            user_id,
            code_hash,
            expires_at,
            attempts,
            created_at,
            updated_at
        )
        VALUES (?, ?, ?, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT(user_id) DO UPDATE SET
            code_hash = excluded.code_hash,
            expires_at = excluded.expires_at,
            attempts = 0,
            updated_at = CURRENT_TIMESTAMP
        """,
        (user_id, code_hash, expires_at),
    )
    return expires_at


def delete_password_reset_code(
    connection: sqlite3.Connection,
    user_id: int,
) -> None:
    connection.execute(
        "DELETE FROM password_reset_codes WHERE user_id = ?",
        (user_id,),
    )


def is_password_reset_expired(row: sqlite3.Row | None) -> bool:
    if not row:
        return True

    expires_at = parse_storage_datetime(row["expires_at"])
    if not expires_at:
        return True

    return expires_at < utc_now()


def build_email_verification_message(
    user: sqlite3.Row | dict[str, object],
    code: str,
) -> dict[str, str]:
    first_name = str(
        user["first_name"]
        if isinstance(user, sqlite3.Row)
        else user.get("first_name", "")
    ).strip()
    full_name = str(
        user["full_name"]
        if isinstance(user, sqlite3.Row)
        else user.get("full_name", "")
    ).strip()
    greeting_name = first_name or full_name or "perdorues"
    recipient_email = str(
        user["email"] if isinstance(user, sqlite3.Row) else user.get("email", "")
    ).strip()

    body = (
        f"Pershendetje {greeting_name},\n\n"
        f"Faleminderit qe krijove llogari ne TREGO.\n"
        f"Kodi yt i verifikimit eshte: {code}\n\n"
        f"Ky kod skadon per {EMAIL_VERIFICATION_TTL_MINUTES} minuta.\n"
        f"Nese nuk e ke kerkuar ti kete llogari, injoroje kete email.\n\n"
        f"TREGO"
    )

    return {
        "to_email": recipient_email,
        "subject": "Kodi i verifikimit per TREGO",
        "body": body,
    }


def build_password_reset_message(
    user: sqlite3.Row | dict[str, object],
    code: str,
) -> dict[str, str]:
    first_name = str(
        user["first_name"]
        if isinstance(user, sqlite3.Row)
        else user.get("first_name", "")
    ).strip()
    full_name = str(
        user["full_name"]
        if isinstance(user, sqlite3.Row)
        else user.get("full_name", "")
    ).strip()
    greeting_name = first_name or full_name or "perdorues"
    recipient_email = str(
        user["email"] if isinstance(user, sqlite3.Row) else user.get("email", "")
    ).strip()

    body = (
        f"Pershendetje {greeting_name},\n\n"
        f"Kerkuat ndryshim te fjalekalimit ne TREGO.\n"
        f"Kodi yt per ndryshim te fjalekalimit eshte: {code}\n\n"
        f"Ky kod skadon per {PASSWORD_RESET_TTL_MINUTES} minuta.\n"
        f"Nese nuk e ke kerkuar ti, injoroje kete email.\n\n"
        f"TREGO"
    )

    return {
        "to_email": recipient_email,
        "subject": "Kodi per ndryshim te fjalekalimit ne TREGO",
        "body": body,
    }


def build_chat_unread_reminder_message(
    reminder_row: sqlite3.Row | dict[str, object],
    *,
    public_app_origin: str,
) -> dict[str, str]:
    recipient_first_name = str(
        reminder_row["recipient_first_name"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("recipient_first_name", "")
    ).strip()
    recipient_full_name = str(
        reminder_row["recipient_full_name"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("recipient_full_name", "")
    ).strip()
    sender_full_name = str(
        reminder_row["sender_full_name"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("sender_full_name", "")
    ).strip()
    sender_business_name = str(
        reminder_row["sender_business_name"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("sender_business_name", "")
    ).strip()
    sender_role = str(
        reminder_row["sender_role"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("sender_role", "")
    ).strip()
    recipient_email = str(
        reminder_row["recipient_email"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("recipient_email", "")
    ).strip()
    conversation_id = int(
        reminder_row["conversation_id"]
        if isinstance(reminder_row, sqlite3.Row)
        else reminder_row.get("conversation_id", 0)
    )

    recipient_name = recipient_first_name or recipient_full_name or "perdorues"
    sender_name = get_chat_display_name(
        role=sender_role,
        full_name=sender_full_name,
        business_name=sender_business_name,
    )
    normalized_origin = public_app_origin.rstrip("/")
    messages_url = f"{normalized_origin}/mesazhet?conversationId={conversation_id}"
    logo_url = f"{normalized_origin}/trego-logo.webp"
    preview_text = (
        f"Keni nje mesazh te pa lexuar nga {sender_name}. "
        f"Hapeni biseden ne TREGO."
    )
    body = (
        f"Pershendetje {recipient_name},\n\n"
        f"Hey {recipient_name} keni mesazh te pa lexuar nga {sender_name}.\n\n"
        f"Hape biseden ketu:\n{messages_url}\n\n"
        f"TREGO"
    )
    html_body = f"""
    <style>
      :root {{
        color-scheme: light dark;
        supported-color-schemes: light dark;
      }}
      @media (prefers-color-scheme: dark) {{
        .trego-reminder-shell {{
          background: #16181d !important;
        }}
        .trego-reminder-card {{
          background: rgba(30, 33, 39, 0.96) !important;
          border-color: rgba(255, 255, 255, 0.08) !important;
          box-shadow: 0 20px 50px rgba(0, 0, 0, 0.32) !important;
        }}
        .trego-reminder-text,
        .trego-reminder-title,
        .trego-reminder-note {{
          color: #f5f2ee !important;
        }}
        .trego-reminder-muted {{
          color: #d4cbc3 !important;
        }}
        .trego-reminder-info {{
          background: linear-gradient(180deg, #2a2f38, #232831) !important;
          border-color: rgba(255, 255, 255, 0.08) !important;
          color: #ddd3ca !important;
        }}
        .trego-reminder-button {{
          background: #4f8dff !important;
          color: #ffffff !important;
        }}
      }}
    </style>
    <div class="trego-reminder-shell" style="margin:0;padding:32px 18px;background:#f6efe7;font-family:Arial,sans-serif;color:#33251f;">
      <div class="trego-reminder-card" style="max-width:560px;margin:0 auto;padding:28px 24px;border-radius:28px;background:rgba(255,255,255,0.92);border:1px solid rgba(214,195,182,0.8);box-shadow:0 20px 50px rgba(120,88,70,0.12);">
        <div style="display:none!important;visibility:hidden;opacity:0;color:transparent;height:0;width:0;overflow:hidden;mso-hide:all;">
          {html.escape(preview_text)}
        </div>
        <div style="text-align:center;margin-bottom:20px;">
          <img src="{html.escape(logo_url, quote=True)}" alt="TREGO" style="width:132px;max-width:100%;height:auto;display:inline-block;">
        </div>
        <p class="trego-reminder-text" style="margin:0 0 14px;font-size:15px;line-height:1.7;color:#33251f;">Pershendetje {html.escape(recipient_name)},</p>
        <h2 class="trego-reminder-title" style="margin:0 0 14px;font-size:28px;line-height:1.1;color:#2f201d;">Keni mesazh te pa lexuar</h2>
        <p class="trego-reminder-muted" style="margin:0 0 18px;font-size:15px;line-height:1.7;color:#5f4b40;">
          Hey {html.escape(recipient_name)}, keni mesazh te pa lexuar nga <strong style="color:#2f201d;">{html.escape(sender_name)}</strong>.
        </p>
        <div class="trego-reminder-info" style="margin:0 0 20px;padding:16px 18px;border-radius:18px;background:linear-gradient(180deg,#fffaf6,#f7efe8);border:1px solid rgba(221,203,191,0.88);color:#6e5649;font-size:14px;line-height:1.6;">
          Hape biseden dhe ktheji pergjigje sa me shpejt.
        </div>
        <div style="text-align:center;margin:24px 0 12px;">
          <a class="trego-reminder-button" href="{html.escape(messages_url, quote=True)}" style="display:inline-block;padding:14px 22px;border-radius:999px;background:#1f5eff;color:#ffffff;text-decoration:none;font-size:14px;font-weight:700;">
            Hap mesazhin
          </a>
        </div>
        <p class="trego-reminder-note trego-reminder-muted" style="margin:18px 0 0;font-size:12px;line-height:1.6;color:#8a7468;text-align:center;">
          Ky email u dergua automatikisht nga TREGO per t'ju kujtuar nje mesazh te palexuar.
        </p>
      </div>
    </div>
    """.strip()

    return {
        "to_email": recipient_email,
        "subject": "Keni nje mesazh qe po ju pret ne TREGO",
        "body": body,
        "html_body": html_body,
    }


def convert_email_body_to_html(body: str) -> str:
    escaped = html.escape(str(body or ""))
    return f"<p>{escaped.replace(chr(10), '<br>')}</p>"


def is_brevo_configured() -> bool:
    return bool(BREVO_API_KEY and BREVO_SENDER_EMAIL)


def send_email_messages_via_brevo(messages: list[dict[str, str]]) -> list[str]:
    warnings: list[str] = []
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "api-key": BREVO_API_KEY,
    }
    sender = {
        "email": BREVO_SENDER_EMAIL,
        "name": BREVO_SENDER_NAME or "TREGO",
    }

    for message_payload in messages:
        payload = {
            "sender": sender,
            "to": [{"email": message_payload["to_email"]}],
            "subject": message_payload["subject"],
            "textContent": message_payload["body"],
            "htmlContent": str(
                message_payload.get("html_body")
                or convert_email_body_to_html(message_payload["body"])
            ),
        }

        request = Request(
            BREVO_API_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )

        try:
            with urlopen(request, timeout=20) as response:
                if response.status >= 400:
                    resp_body = response.read().decode("utf-8", errors="ignore")
                    warnings.append(
                        f"Brevo dërgoi kod gabimi {response.status}: {resp_body}"
                    )
        except HTTPError as error:
            body = error.read().decode("utf-8", errors="ignore") if error.fp else ""
            warnings.append(f"Brevo HTTP gabim {error.code}: {body}")
        except URLError as error:
            warnings.append(f"Brevo nuk u arrit: {error.reason}")
        except Exception as error:
            warnings.append(f"Brevo: {error}")

    return warnings


def send_email_messages(messages: list[dict[str, str]]) -> list[str]:
    if not messages:
        return []

    if not is_brevo_configured():
        return [
            "Brevo API key dhe sender email nuk jane te vendosura. Vendos BREVO_API_KEY dhe BREVO_SENDER_EMAIL per te dërguar kodet."
        ]

    return send_email_messages_via_brevo(messages)


def send_email_notifications(messages: list[dict[str, str]]) -> list[str]:
    return send_email_messages(messages)


def send_email_verification_code(
    user: sqlite3.Row | dict[str, object],
    code: str,
) -> list[str]:
    message_payload = build_email_verification_message(user, code)
    warnings = send_email_messages([message_payload])

    if warnings:
        recipient_email = str(
            user["email"] if isinstance(user, sqlite3.Row) else user.get("email", "")
        ).strip()
        print(
            f"[TREGO] Kodi i verifikimit per {recipient_email}: {code}",
            flush=True,
        )

    return warnings


def send_password_reset_code(
    user: sqlite3.Row | dict[str, object],
    code: str,
) -> list[str]:
    message_payload = build_password_reset_message(user, code)
    warnings = send_email_messages([message_payload])

    if warnings:
        recipient_email = str(
            user["email"] if isinstance(user, sqlite3.Row) else user.get("email", "")
        ).strip()
        print(
            f"[TREGO] Kodi per ndryshim te fjalekalimit per {recipient_email}: {code}",
            flush=True,
        )

    return warnings


def fetch_users_for_admin() -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
            """
            + USER_SELECT_COLUMNS
            + """
            FROM users
            ORDER BY
                CASE
                    WHEN role = 'admin' THEN 0
                    WHEN role = 'business' THEN 1
                    ELSE 2
                END,
                id ASC
            """
        ).fetchall()


def fetch_default_address_for_user(user_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
            """
            + ADDRESS_SELECT_COLUMNS
            + """
            FROM user_addresses
            WHERE user_id = ? AND is_default = 1
            ORDER BY updated_at DESC, id DESC
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()


def fetch_business_profile_for_user(user_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                bp.id,
                bp.user_id,
                bp.business_name,
                bp.business_description,
                bp.business_number,
                bp.business_logo_path,
                bp.verification_status,
                bp.verification_requested_at,
                bp.verification_verified_at,
                bp.verification_notes,
                bp.profile_edit_access_status,
                bp.profile_edit_requested_at,
                bp.profile_edit_approved_at,
                bp.profile_edit_notes,
                bp.shipping_settings,
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.email AS owner_email,
                COALESCE(follower_totals.total_followers, 0) AS followers_count,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(order_totals.total_orders, 0) AS orders_count,
                COALESCE(review_totals.average_rating, 0) AS seller_rating,
                COALESCE(review_totals.review_count, 0) AS seller_review_count
            FROM business_profiles bp
            INNER JOIN users u ON u.id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_id,
                    COUNT(*) AS total_followers
                FROM business_followers
                GROUP BY business_id
            ) follower_totals ON follower_totals.business_id = bp.id
            LEFT JOIN (
                SELECT
                    created_by_user_id,
                    COUNT(*) AS total_products
                FROM products
                WHERE created_by_user_id IS NOT NULL
                GROUP BY created_by_user_id
            ) product_totals ON product_totals.created_by_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    COUNT(DISTINCT order_id) AS total_orders
                FROM order_items
                WHERE business_user_id IS NOT NULL
                GROUP BY business_user_id
            ) order_totals ON order_totals.business_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    ROUND(AVG(rating), 2) AS average_rating,
                    COUNT(*) AS review_count
                FROM product_reviews
                WHERE business_user_id IS NOT NULL
                  AND status = 'published'
                GROUP BY business_user_id
            ) review_totals ON review_totals.business_user_id = bp.user_id
            WHERE bp.user_id = ?
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()


def fetch_business_profiles_for_admin() -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                bp.id,
                bp.user_id,
                bp.business_name,
                bp.business_description,
                bp.business_number,
                bp.business_logo_path,
                bp.verification_status,
                bp.verification_requested_at,
                bp.verification_verified_at,
                bp.verification_notes,
                bp.profile_edit_access_status,
                bp.profile_edit_requested_at,
                bp.profile_edit_approved_at,
                bp.profile_edit_notes,
                bp.shipping_settings,
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.full_name AS owner_full_name,
                u.email AS owner_email,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(order_totals.total_orders, 0) AS orders_count,
                COALESCE(review_totals.average_rating, 0) AS seller_rating,
                COALESCE(review_totals.review_count, 0) AS seller_review_count
            FROM business_profiles bp
            INNER JOIN users u ON u.id = bp.user_id
            LEFT JOIN (
                SELECT
                    created_by_user_id,
                    COUNT(*) AS total_products
                FROM products
                WHERE created_by_user_id IS NOT NULL
                GROUP BY created_by_user_id
            ) product_totals ON product_totals.created_by_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    COUNT(DISTINCT order_id) AS total_orders
                FROM order_items
                WHERE business_user_id IS NOT NULL
                GROUP BY business_user_id
            ) order_totals ON order_totals.business_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    ROUND(AVG(rating), 2) AS average_rating,
                    COUNT(*) AS review_count
                FROM product_reviews
                WHERE business_user_id IS NOT NULL
                  AND status = 'published'
                GROUP BY business_user_id
            ) review_totals ON review_totals.business_user_id = bp.user_id
            ORDER BY bp.updated_at DESC, bp.id DESC
            """
        ).fetchall()


def fetch_business_profile_for_admin_by_id(business_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                bp.id,
                bp.user_id,
                bp.business_name,
                bp.business_description,
                bp.business_number,
                bp.business_logo_path,
                bp.verification_status,
                bp.verification_requested_at,
                bp.verification_verified_at,
                bp.verification_notes,
                bp.profile_edit_access_status,
                bp.profile_edit_requested_at,
                bp.profile_edit_approved_at,
                bp.profile_edit_notes,
                bp.shipping_settings,
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.full_name AS owner_full_name,
                u.email AS owner_email,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(order_totals.total_orders, 0) AS orders_count,
                COALESCE(review_totals.average_rating, 0) AS seller_rating,
                COALESCE(review_totals.review_count, 0) AS seller_review_count
            FROM business_profiles bp
            INNER JOIN users u ON u.id = bp.user_id
            LEFT JOIN (
                SELECT
                    created_by_user_id,
                    COUNT(*) AS total_products
                FROM products
                WHERE created_by_user_id IS NOT NULL
                GROUP BY created_by_user_id
            ) product_totals ON product_totals.created_by_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    COUNT(DISTINCT order_id) AS total_orders
                FROM order_items
                WHERE business_user_id IS NOT NULL
                GROUP BY business_user_id
            ) order_totals ON order_totals.business_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    ROUND(AVG(rating), 2) AS average_rating,
                    COUNT(*) AS review_count
                FROM product_reviews
                WHERE business_user_id IS NOT NULL
                  AND status = 'published'
                GROUP BY business_user_id
            ) review_totals ON review_totals.business_user_id = bp.user_id
            WHERE bp.id = ?
            LIMIT 1
            """,
            (business_id,),
        ).fetchone()


def fetch_public_business_profiles() -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                bp.id,
                bp.user_id,
                bp.business_name,
                bp.business_description,
                bp.business_number,
                bp.business_logo_path,
                bp.verification_status,
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                COALESCE(follower_totals.total_followers, 0) AS followers_count,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(review_totals.average_rating, 0) AS seller_rating,
                COALESCE(review_totals.review_count, 0) AS seller_review_count
            FROM business_profiles bp
            LEFT JOIN (
                SELECT
                    business_id,
                    COUNT(*) AS total_followers
                FROM business_followers
                GROUP BY business_id
            ) follower_totals ON follower_totals.business_id = bp.id
            LEFT JOIN (
                SELECT
                    created_by_user_id,
                    COUNT(*) AS total_products
                FROM products
                WHERE is_public = 1
                  AND created_by_user_id IS NOT NULL
                GROUP BY created_by_user_id
            ) product_totals ON product_totals.created_by_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    ROUND(AVG(rating), 2) AS average_rating,
                    COUNT(*) AS review_count
                FROM product_reviews
                WHERE business_user_id IS NOT NULL
                  AND status = 'published'
                GROUP BY business_user_id
            ) review_totals ON review_totals.business_user_id = bp.user_id
            WHERE TRIM(business_name) <> ''
            ORDER BY updated_at DESC, id DESC
            """
        ).fetchall()


def search_public_business_profiles(
    search_text: str,
    *,
    limit: int = 4,
) -> list[sqlite3.Row]:
    normalized_search_text = normalize_search_intent_text(search_text)
    if not normalized_search_text:
        return []

    safe_limit = max(1, min(8, int(limit or 4)))
    search_pattern = f"%{normalized_search_text}%"
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                bp.id,
                bp.user_id,
                bp.business_name,
                bp.business_description,
                bp.business_number,
                bp.business_logo_path,
                bp.verification_status,
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                COALESCE(follower_totals.total_followers, 0) AS followers_count,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(review_totals.average_rating, 0) AS seller_rating,
                COALESCE(review_totals.review_count, 0) AS seller_review_count
            FROM business_profiles bp
            LEFT JOIN (
                SELECT
                    business_id,
                    COUNT(*) AS total_followers
                FROM business_followers
                GROUP BY business_id
            ) follower_totals ON follower_totals.business_id = bp.id
            LEFT JOIN (
                SELECT
                    created_by_user_id,
                    COUNT(*) AS total_products
                FROM products
                WHERE is_public = 1
                  AND created_by_user_id IS NOT NULL
                GROUP BY created_by_user_id
            ) product_totals ON product_totals.created_by_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    ROUND(AVG(rating), 2) AS average_rating,
                    COUNT(*) AS review_count
                FROM product_reviews
                WHERE business_user_id IS NOT NULL
                  AND status = 'published'
                GROUP BY business_user_id
            ) review_totals ON review_totals.business_user_id = bp.user_id
            WHERE TRIM(bp.business_name) <> ''
              AND (
                LOWER(bp.business_name) LIKE ?
                OR LOWER(COALESCE(bp.business_description, '')) LIKE ?
                OR LOWER(COALESCE(bp.city, '')) LIKE ?
              )
            ORDER BY
                CASE
                    WHEN LOWER(bp.business_name) LIKE ? THEN 0
                    ELSE 1
                END,
                bp.updated_at DESC,
                bp.id DESC
            LIMIT ?
            """,
            (
                search_pattern,
                search_pattern,
                search_pattern,
                f"{normalized_search_text}%",
                safe_limit,
            ),
        ).fetchall()


def fetch_public_business_profile_by_id(business_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                bp.id,
                bp.user_id,
                bp.business_name,
                bp.business_description,
                bp.business_number,
                bp.business_logo_path,
                bp.verification_status,
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.email AS owner_email,
                COALESCE(follower_totals.total_followers, 0) AS followers_count,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(review_totals.average_rating, 0) AS seller_rating,
                COALESCE(review_totals.review_count, 0) AS seller_review_count
            FROM business_profiles bp
            INNER JOIN users u ON u.id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_id,
                    COUNT(*) AS total_followers
                FROM business_followers
                GROUP BY business_id
            ) follower_totals ON follower_totals.business_id = bp.id
            LEFT JOIN (
                SELECT
                    created_by_user_id,
                    COUNT(*) AS total_products
                FROM products
                WHERE is_public = 1
                  AND created_by_user_id IS NOT NULL
                GROUP BY created_by_user_id
            ) product_totals ON product_totals.created_by_user_id = bp.user_id
            LEFT JOIN (
                SELECT
                    business_user_id,
                    ROUND(AVG(rating), 2) AS average_rating,
                    COUNT(*) AS review_count
                FROM product_reviews
                WHERE business_user_id IS NOT NULL
                  AND status = 'published'
                GROUP BY business_user_id
            ) review_totals ON review_totals.business_user_id = bp.user_id
            WHERE bp.id = ?
            LIMIT 1
            """,
            (business_id,),
        ).fetchone()


def count_public_products_for_business(business_id: int) -> int:
    with get_db_connection() as connection:
        row = connection.execute(
            """
            SELECT COUNT(*)
            FROM products p
            INNER JOIN business_profiles bp ON bp.user_id = p.created_by_user_id
            WHERE bp.id = ?
              AND p.is_public = 1
              AND p.stock_quantity > 0
            """,
            (business_id,),
        ).fetchone()
    return int(row[0]) if row else 0


def fetch_public_products_for_business(
    business_id: int,
    *,
    limit: int | None = None,
    offset: int = 0,
) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        query = (
            """
            SELECT
            """
            + PRODUCT_SELECT_COLUMNS
            + """
            FROM products
            """
            + PRODUCT_SELECT_RELATION_JOINS
            + """
            INNER JOIN business_profiles bp ON bp.user_id = products.created_by_user_id
            WHERE bp.id = ?
              AND products.is_public = 1
              AND products.stock_quantity > 0
            ORDER BY products.id DESC
        """
        )
        params: list[object] = [business_id]

        if limit is not None:
            query += "\n            LIMIT ? OFFSET ?"
            params.extend([limit, offset])

        return connection.execute(query, params).fetchall()


def fetch_public_products_page_for_business(
    business_id: int,
    *,
    limit: int = 10,
    offset: int = 0,
) -> tuple[list[sqlite3.Row], bool]:
    safe_limit = max(1, int(limit))
    rows = fetch_public_products_for_business(
        business_id,
        limit=safe_limit + 1,
        offset=offset,
    )
    has_more = len(rows) > safe_limit
    return rows[:safe_limit], has_more


def is_business_followed_by_user(business_id: int, user_id: int) -> bool:
    with get_db_connection() as connection:
        existing_row = connection.execute(
            """
            SELECT 1
            FROM business_followers
            WHERE business_id = ? AND user_id = ?
            LIMIT 1
            """,
            (business_id, user_id),
        ).fetchone()
    return bool(existing_row)


def fetch_products(
    category: str | None = None,
    *,
    category_group: str | None = None,
    product_type: str | None = None,
    size: str | None = None,
    color: str | None = None,
    business_name_search: str | None = None,
    include_hidden: bool = False,
    created_by_user_id: int | None = None,
    search_text: str | None = None,
    limit: int | None = None,
    offset: int = 0,
) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        where_clause, parameters = build_product_query_filters(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
            business_name_search=business_name_search,
            include_hidden=include_hidden,
            created_by_user_id=created_by_user_id,
            search_text=search_text,
        )

        limit_offset_clause = ""
        if limit is not None:
            limit_offset_clause = "\nLIMIT ?\nOFFSET ?"
            parameters = [*parameters, limit, max(0, int(offset))]

        return connection.execute(
            """
            SELECT
            """
            + PRODUCT_SELECT_COLUMNS
            + """
            FROM products
            """
            + PRODUCT_SELECT_RELATION_JOINS
            + """
            """
            + where_clause
            + """
            ORDER BY products.id DESC
            """
            + limit_offset_clause
            + """
            """,
            parameters,
        ).fetchall()


def fetch_products_page(
    category: str | None = None,
    *,
    category_group: str | None = None,
    product_type: str | None = None,
    size: str | None = None,
    color: str | None = None,
    business_name_search: str | None = None,
    include_hidden: bool = False,
    created_by_user_id: int | None = None,
    search_text: str | None = None,
    limit: int = 10,
    offset: int = 0,
) -> tuple[list[sqlite3.Row], bool]:
    safe_limit = max(1, int(limit))
    rows = fetch_products(
        category,
        category_group=category_group,
        product_type=product_type,
        size=size,
        color=color,
        business_name_search=business_name_search,
        include_hidden=include_hidden,
        created_by_user_id=created_by_user_id,
        search_text=search_text,
        limit=safe_limit + 1,
        offset=offset,
    )
    has_more = len(rows) > safe_limit
    return rows[:safe_limit], has_more


def build_product_query_filters(
    category: str | None = None,
    *,
    category_group: str | None = None,
    product_type: str | None = None,
    size: str | None = None,
    color: str | None = None,
    business_name_search: str | None = None,
    include_hidden: bool = False,
    created_by_user_id: int | None = None,
    search_text: str | None = None,
) -> tuple[str, list[object]]:
    conditions: list[str] = []
    parameters: list[object] = []

    if category:
        conditions.append("category = ?")
        parameters.append(category)
    elif category_group:
        if category_group in {"home", "sport", "technology"}:
            conditions.append("category = ?")
            parameters.append(category_group)
        else:
            conditions.append("category LIKE ?")
            parameters.append(f"{category_group}-%")

    if product_type:
        conditions.append("product_type = ?")
        parameters.append(product_type)

    if size:
        conditions.append("(size = ? OR variant_inventory LIKE ?)")
        parameters.extend([size, f'%\"size\": \"{size}\"%'])

    if color:
        conditions.append("(color = ? OR LOWER(ai_image_color_terms) LIKE ? OR variant_inventory LIKE ?)")
        parameters.extend([color, f"%{color.lower()}%", f'%\"color\": \"{color}\"%'])

    if created_by_user_id is not None:
        conditions.append("created_by_user_id = ?")
        parameters.append(created_by_user_id)

    if business_name_search:
        conditions.append(
            "EXISTS ("
            "SELECT 1 FROM business_profiles bp "
            "WHERE bp.user_id = products.created_by_user_id "
            "AND LOWER(bp.business_name) LIKE ?"
            ")"
        )
        parameters.append(f"%{business_name_search.lower()}%")

    if search_text:
        conditions.append(
            "("
            "LOWER(title) LIKE ? "
            "OR LOWER(description) LIKE ? "
            "OR LOWER(ai_image_search_text) LIKE ?"
            ")"
        )
        search_pattern = f"%{search_text.lower()}%"
        parameters.extend([search_pattern, search_pattern, search_pattern])

    if not include_hidden:
        conditions.append("is_public = 1")
        conditions.append("stock_quantity > 0")

    where_clause = ""
    if conditions:
        where_clause = "WHERE " + " AND ".join(conditions)

    return where_clause, parameters


def build_product_catalog_facets(
    category: str | None = None,
    *,
    category_group: str | None = None,
    product_type: str | None = None,
    size: str | None = None,
    color: str | None = None,
    business_name_search: str | None = None,
    include_hidden: bool = False,
    created_by_user_id: int | None = None,
    search_text: str | None = None,
) -> dict[str, list[dict[str, object]]]:
    cache_key = build_runtime_public_cache_key(
        "catalog:facets",
        {
            "category": category or "",
            "categoryGroup": category_group or "",
            "productType": product_type or "",
            "size": size or "",
            "color": color or "",
            "businessName": business_name_search or "",
            "includeHidden": bool(include_hidden),
            "createdByUserId": int(created_by_user_id or 0),
            "searchText": search_text or "",
        },
    )
    cached_facets = read_runtime_public_cache(cache_key)
    if isinstance(cached_facets, dict):
        return cached_facets

    with get_db_connection() as connection:
        where_clause, parameters = build_product_query_filters(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
            business_name_search=business_name_search,
            include_hidden=include_hidden,
            created_by_user_id=created_by_user_id,
            search_text=search_text,
        )
        rows = connection.execute(
            """
            SELECT
                category,
                product_type,
                size,
                color,
                stock_quantity,
                variant_inventory,
                ai_image_color_terms
            FROM products
            """
            + where_clause
            + """
            ORDER BY products.id DESC
            """,
            parameters,
        ).fetchall()

    page_sections: dict[str, dict[str, object]] = {}
    categories: dict[str, dict[str, object]] = {}
    product_types: dict[tuple[str, str], dict[str, object]] = {}
    sizes: set[str] = set()
    colors: set[str] = set()

    section_order = {
        str(section.get("value") or "").strip().lower(): index
        for index, section in enumerate(PRODUCT_SECTION_DEFINITIONS)
        if str(section.get("value") or "").strip()
    }
    color_order = {
        str(color_definition.get("value") or "").strip().lower(): index
        for index, color_definition in enumerate(PRODUCT_COLOR_DEFINITIONS)
        if str(color_definition.get("value") or "").strip()
    }

    for row in rows:
        row_category = str(row["category"] or "").strip().lower()
        if not row_category:
            continue

        row_section = derive_section_from_category(row_category) or row_category
        row_audience = derive_audience_from_category(row_category) or ""

        if row_section:
            page_sections[row_section] = {
                "value": row_section,
                "label": PRODUCT_CATEGORY_LABELS.get(row_section, row_section),
            }

        categories[row_category] = {
            "value": row_category,
            "label": PRODUCT_CATEGORY_LABELS.get(row_category, row_category),
            "pageSection": row_section,
            "audience": row_audience,
        }

        row_product_type = str(row["product_type"] or "").strip().lower()
        if row_product_type:
            product_types[(row_category, row_product_type)] = {
                "value": row_product_type,
                "label": PRODUCT_TYPE_LABELS.get(row_product_type, row_product_type),
                "category": row_category,
                "pageSection": row_section,
            }

        variant_inventory = deserialize_product_variant_inventory(
            row["variant_inventory"],
            category=row_category,
            size=row["size"],
            color=row["color"],
            stock_quantity=row["stock_quantity"],
        )
        if variant_inventory:
            for entry in variant_inventory:
                normalized_size = str(entry.get("size") or "").strip().upper()
                normalized_color = str(entry.get("color") or "").strip().lower()
                if normalized_size in CLOTHING_SIZES:
                    sizes.add(normalized_size)
                if normalized_color in PRODUCT_COLORS:
                    colors.add(normalized_color)
        else:
            normalized_size = str(row["size"] or "").strip().upper()
            normalized_color = str(row["color"] or "").strip().lower()
            if normalized_size in CLOTHING_SIZES:
                sizes.add(normalized_size)
            if normalized_color in PRODUCT_COLORS:
                colors.add(normalized_color)

        for color_term in tokenize_search_intent_text(str(row["ai_image_color_terms"] or "")):
            if color_term in PRODUCT_COLORS:
                colors.add(color_term)

    sorted_page_sections = sorted(
        page_sections.values(),
        key=lambda item: (section_order.get(str(item["value"]), 999), str(item["label"])),
    )
    sorted_categories = sorted(
        categories.values(),
        key=lambda item: (
            section_order.get(str(item["pageSection"]), 999),
            str(item["label"]),
        ),
    )
    sorted_product_types = sorted(
        product_types.values(),
        key=lambda item: (
            section_order.get(str(item["pageSection"]), 999),
            str(item["category"]),
            str(item["label"]),
        ),
    )
    sorted_sizes = sorted(
        [{"value": size_value, "label": size_value} for size_value in sizes],
        key=lambda item: CLOTHING_SIZE_ORDER.get(str(item["value"]), 999),
    )
    sorted_colors = sorted(
        [
            {
                "value": color_value,
                "label": PRODUCT_COLOR_LABELS.get(color_value, color_value),
            }
            for color_value in colors
        ],
        key=lambda item: (color_order.get(str(item["value"]), 999), str(item["label"])),
    )

    facets_payload = {
        "pageSections": sorted_page_sections,
        "categories": sorted_categories,
        "productTypes": sorted_product_types,
        "sizes": sorted_sizes,
        "colors": sorted_colors,
    }
    write_runtime_public_cache(
        cache_key,
        facets_payload,
        ttl_seconds=PUBLIC_FACETS_CACHE_TTL_SECONDS,
    )
    return facets_payload


def build_catalog_autocomplete_matches(
    search_text: str,
    *,
    limit: int = 6,
) -> list[dict[str, str]]:
    normalized_query = normalize_search_intent_text(search_text)
    if not normalized_query:
        return []

    tokens = [token for token in tokenize_search_intent_text(normalized_query) if token]
    matches: list[dict[str, str]] = []
    seen_hrefs: set[str] = set()

    def add_match(*, label: str, href: str, subtitle: str = "", kind: str = "category") -> None:
        cleaned_label = str(label or "").strip()
        cleaned_href = str(href or "").strip()
        if not cleaned_label or not cleaned_href or cleaned_href in seen_hrefs:
            return

        haystack = normalize_search_intent_text(f"{cleaned_label} {subtitle}")
        if normalized_query not in haystack and not all(token in haystack for token in tokens):
            return

        seen_hrefs.add(cleaned_href)
        matches.append(
            {
                "label": cleaned_label,
                "href": cleaned_href,
                "subtitle": str(subtitle or "").strip(),
                "kind": kind,
            }
        )

    for section_definition in PRODUCT_SECTION_DEFINITIONS:
        section_value = str(section_definition.get("value") or "").strip().lower()
        section_label = str(section_definition.get("label") or section_value).strip()
        if not section_value or not section_label:
            continue

        section_href = (
            f"/kerko?categoryGroup={quote(section_value)}"
            if SECTION_AUDIENCE_CATEGORY_MAP.get(section_value)
            else f"/kerko?category={quote(section_value)}"
        )
        add_match(
            label=section_label,
            href=section_href,
            subtitle="Kategori",
            kind="category",
        )

        for audience_definition in list(section_definition.get("audiences") or []):
            category_value = str(audience_definition.get("category") or "").strip().lower()
            audience_label = str(
                audience_definition.get("label") or PRODUCT_CATEGORY_LABELS.get(category_value, category_value)
            ).strip()
            if not category_value or not audience_label:
                continue

            add_match(
                label=audience_label,
                href=f"/kerko?category={quote(category_value)}",
                subtitle=section_label,
                kind="category",
            )

    for category_value, product_type_options in PRODUCT_TYPE_OPTIONS_BY_CATEGORY.items():
        normalized_category = str(category_value or "").strip().lower()
        category_label = PRODUCT_CATEGORY_LABELS.get(normalized_category, normalized_category)
        for option in list(product_type_options or []):
            product_type_value = str(option.get("value") or "").strip().lower()
            product_type_label = str(option.get("label") or product_type_value).strip()
            if not product_type_value or not product_type_label:
                continue

            add_match(
                label=product_type_label,
                href=(
                    f"/kerko?category={quote(normalized_category)}&productType={quote(product_type_value)}"
                ),
                subtitle=category_label,
                kind="category",
            )

    return matches[: max(1, min(8, int(limit or 6)))]


def count_products(
    category: str | None = None,
    *,
    category_group: str | None = None,
    product_type: str | None = None,
    size: str | None = None,
    color: str | None = None,
    business_name_search: str | None = None,
    include_hidden: bool = False,
    created_by_user_id: int | None = None,
    search_text: str | None = None,
) -> int:
    with get_db_connection() as connection:
        where_clause, parameters = build_product_query_filters(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
            business_name_search=business_name_search,
            include_hidden=include_hidden,
            created_by_user_id=created_by_user_id,
            search_text=search_text,
        )

        row = connection.execute(
            """
            SELECT COUNT(*) AS total_count
            FROM products
            """
            + where_clause,
            parameters,
        ).fetchone()

    return int(row["total_count"] or 0)


def update_product_image_fingerprint(
    connection: DatabaseConnection,
    product_id: int,
    image_fingerprint: str,
) -> None:
    connection.execute(
        """
        UPDATE products
        SET image_fingerprint = ?
        WHERE id = ?
        """,
        (str(image_fingerprint or "").strip(), product_id),
    )


def fetch_visual_search_candidates(
    category: str | None = None,
    *,
    category_group: str | None = None,
    product_type: str | None = None,
    size: str | None = None,
    color: str | None = None,
) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        where_clause, parameters = build_product_query_filters(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
        )

        return connection.execute(
            """
            SELECT
            """
            + PRODUCT_SELECT_COLUMNS
            + """
            FROM products
            """
            + PRODUCT_SELECT_RELATION_JOINS
            + """
            """
            + where_clause
            + """
            ORDER BY id DESC
            """,
            parameters,
        ).fetchall()


def score_products_by_visual_similarity(
    query_fingerprint: str,
    candidates: list[sqlite3.Row],
) -> list[sqlite3.Row]:
    if not query_fingerprint:
        return []

    scored_rows: list[tuple[int, int, sqlite3.Row]] = []

    with get_db_connection() as connection:
        for row in candidates:
            image_fingerprint = str(row["image_fingerprint"] or "").strip()
            if not image_fingerprint:
                image_fingerprint = compute_product_image_fingerprint(
                    row["image_gallery"],
                    fallback_image_path=row["image_path"],
                )
                if image_fingerprint:
                    update_product_image_fingerprint(connection, int(row["id"]), image_fingerprint)

            if not image_fingerprint:
                continue

            distance = compute_hamming_distance(query_fingerprint, image_fingerprint)
            if distance >= 10**9:
                continue

            scored_rows.append((distance, -int(row["id"]), row))

    scored_rows.sort(key=lambda item: (item[0], item[1]))
    return [row for _, _, row in scored_rows]


def fetch_product_by_id(product_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
            """
            + PRODUCT_SELECT_COLUMNS
            + """
            FROM products
            """
            + PRODUCT_SELECT_RELATION_JOINS
            + """
            WHERE products.id = ?
            """,
            (product_id,),
        ).fetchone()


def insert_product_for_owner(
    connection: DatabaseConnection,
    *,
    normalized_product: dict[str, object],
    owner_user_id: int,
) -> int:
    image_fingerprint = compute_product_image_fingerprint(
        normalized_product["imageGallery"],
        fallback_image_path=normalized_product["imagePath"],
    )
    image_search_metadata = generate_product_image_search_metadata(
        title=normalized_product["title"],
        description=normalized_product["description"],
        category=normalized_product["category"],
        product_type=normalized_product["productType"],
        color=normalized_product["color"],
        image_gallery=normalized_product["imageGallery"],
        fallback_image_path=normalized_product["imagePath"],
        image_fingerprint=image_fingerprint,
    )

    return execute_insert_and_get_id(
        connection,
        """
        INSERT INTO products (
            article_number,
            title,
            description,
            price,
            image_path,
            image_gallery,
            image_fingerprint,
            ai_image_search_text,
            ai_image_color_terms,
            category,
            product_type,
            size,
            color,
            variant_inventory,
            package_amount_value,
            package_amount_unit,
            stock_quantity,
            created_by_user_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            normalized_product["articleNumber"],
            normalized_product["title"],
            normalized_product["description"],
            normalized_product["price"],
            normalized_product["imagePath"],
            json.dumps(normalized_product["imageGallery"], ensure_ascii=False),
            image_fingerprint,
            image_search_metadata["searchText"],
            image_search_metadata["colorTerms"],
            normalized_product["category"],
            normalized_product["productType"],
            normalized_product["size"],
            normalized_product["color"],
            json.dumps(normalized_product["variantInventory"], ensure_ascii=False),
            normalized_product["packageAmountValue"],
            normalized_product["packageAmountUnit"],
            normalized_product["stockQuantity"],
            owner_user_id,
        ),
    )


def fetch_wishlist_products(user_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                p.id,
                p.title,
                p.description,
                p.price,
                p.image_path,
                p.image_gallery,
                p.category,
                p.product_type,
                p.size,
                p.color,
                p.variant_inventory,
                p.package_amount_value,
                p.package_amount_unit,
                p.stock_quantity,
                p.is_public,
                p.show_stock_public,
                p.created_by_user_id,
                wi.created_at,
                COALESCE(bp.business_name, '') AS business_name
            FROM wishlist_items wi
            INNER JOIN products p ON p.id = wi.product_id
            LEFT JOIN business_profiles bp ON bp.user_id = p.created_by_user_id
            WHERE wi.user_id = ?
              AND p.is_public = 1
            ORDER BY wi.created_at DESC
            """,
            (user_id,),
        ).fetchall()


def fetch_cart_items(user_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                cl.id AS cart_line_id,
                p.id,
                p.title,
                p.description,
                p.price,
                p.image_path,
                p.image_gallery,
                p.category,
                p.product_type,
                p.size,
                p.color,
                p.variant_inventory,
                p.package_amount_value,
                p.package_amount_unit,
                p.stock_quantity,
                p.is_public,
                p.show_stock_public,
                p.created_by_user_id,
                cl.created_at,
                cl.quantity,
                cl.variant_key,
                cl.variant_label,
                cl.selected_size,
                cl.selected_color,
                COALESCE(bp.business_name, '') AS business_name
            FROM cart_lines cl
            INNER JOIN products p ON p.id = cl.product_id
            LEFT JOIN business_profiles bp ON bp.user_id = p.created_by_user_id
            WHERE cl.user_id = ?
              AND p.is_public = 1
            ORDER BY cl.updated_at DESC
            """,
            (user_id,),
        ).fetchall()


def fetch_cart_items_for_checkout(
    connection: DatabaseConnection,
    user_id: int,
    cart_line_ids: list[int],
) -> list[sqlite3.Row]:
    if not cart_line_ids:
        return []

    placeholders = ", ".join("?" for _ in cart_line_ids)
    parameters: list[object] = [user_id, *cart_line_ids]

    return connection.execute(
        """
        SELECT
            cl.id AS cart_line_id,
            p.id,
            p.title,
            p.description,
            p.price,
            p.image_path,
            p.image_gallery,
            p.category,
            p.product_type,
            p.size,
            p.color,
            p.variant_inventory,
            p.package_amount_value,
            p.package_amount_unit,
            p.stock_quantity,
            p.is_public,
            p.show_stock_public,
            p.created_by_user_id,
            cl.created_at,
            cl.quantity,
            cl.variant_key,
            cl.variant_label,
            cl.selected_size,
            cl.selected_color,
            COALESCE(bp.business_name, '') AS business_name
        FROM cart_lines cl
        INNER JOIN products p ON p.id = cl.product_id
        LEFT JOIN business_profiles bp ON bp.user_id = p.created_by_user_id
        WHERE cl.user_id = ?
          AND cl.id IN ("""
        + placeholders
        + """)
          AND p.is_public = 1
        ORDER BY cl.updated_at DESC, cl.id DESC
        """,
        parameters,
    ).fetchall()


def normalize_checkout_item_record(raw_item: object) -> dict[str, object]:
    if hasattr(raw_item, "keys"):
        mapping = {key: raw_item[key] for key in raw_item.keys()}
    elif isinstance(raw_item, dict):
        mapping = dict(raw_item)
    else:
        mapping = {}

    return {
        "cartLineId": int(mapping.get("cart_line_id") or mapping.get("cartLineId") or 0),
        "productId": int(mapping.get("id") or mapping.get("productId") or 0),
        "title": str(mapping.get("title") or "").strip(),
        "description": str(mapping.get("description") or "").strip(),
        "price": round(float(mapping.get("price") or 0), 2),
        "imagePath": normalize_image_path(mapping.get("image_path") or mapping.get("imagePath") or ""),
        "category": str(mapping.get("category") or "").strip().lower(),
        "productType": str(mapping.get("product_type") or mapping.get("productType") or "").strip().lower(),
        "size": str(mapping.get("size") or "").strip().upper(),
        "color": str(mapping.get("color") or "").strip().lower(),
        "variantKey": str(mapping.get("variant_key") or mapping.get("variantKey") or "").strip() or "default",
        "variantLabel": str(mapping.get("variant_label") or mapping.get("variantLabel") or "").strip(),
        "selectedSize": str(mapping.get("selected_size") or mapping.get("selectedSize") or "").strip().upper(),
        "selectedColor": str(mapping.get("selected_color") or mapping.get("selectedColor") or "").strip().lower(),
        "businessUserId": (
            int(mapping.get("business_user_id") or mapping.get("created_by_user_id") or mapping.get("businessUserId") or 0)
            or None
        ),
        "businessName": str(mapping.get("business_name") or mapping.get("businessName") or "").strip(),
        "packageAmountValue": round(
            float(mapping.get("package_amount_value") or mapping.get("packageAmountValue") or 0),
            2,
        ),
        "packageAmountUnit": str(
            mapping.get("package_amount_unit") or mapping.get("packageAmountUnit") or ""
        ).strip().lower(),
        "quantity": max(1, int(mapping.get("quantity") or 1)),
    }


def load_checkout_items_for_order_or_raise(
    connection: DatabaseConnection,
    *,
    user_id: int,
    cart_line_ids: list[int],
) -> list[dict[str, object]]:
    checkout_rows = fetch_cart_items_for_checkout(connection, user_id, cart_line_ids)
    if not checkout_rows:
        raise CheckoutProcessError(
            message="Produktet e zgjedhura nuk u gjeten ne shporte."
        )

    available_cart_line_ids = {int(item["cart_line_id"]) for item in checkout_rows}
    missing_cart_line_ids = [
        cart_line_id
        for cart_line_id in cart_line_ids
        if cart_line_id not in available_cart_line_ids
    ]
    if missing_cart_line_ids:
        raise CheckoutProcessError(
            message="Disa produkte nuk jane me te disponueshme per kete porosi."
        )

    checkout_items = [normalize_checkout_item_record(item) for item in checkout_rows]
    validate_checkout_stock_or_raise(
        connection,
        checkout_items,
        exclude_reserved_for_user_id=user_id,
    )
    return checkout_items


def serialize_checkout_items_snapshot(checkout_items: list[object]) -> str:
    normalized_items = [
        normalize_checkout_item_record(item)
        for item in checkout_items
    ]
    return json.dumps(normalized_items, ensure_ascii=False)


def deserialize_checkout_items_snapshot(raw_value: object) -> list[dict[str, object]]:
    try:
        parsed_value = json.loads(str(raw_value or "[]"))
    except (TypeError, ValueError, json.JSONDecodeError):
        parsed_value = []

    if not isinstance(parsed_value, list):
        return []

    return [normalize_checkout_item_record(item) for item in parsed_value]


def fetch_products_for_checkout_records(
    connection: DatabaseConnection,
    checkout_items: list[dict[str, object]],
) -> dict[int, sqlite3.Row]:
    product_ids = sorted(
        {
            int(item["productId"])
            for item in checkout_items
            if int(item.get("productId") or 0) > 0
        }
    )
    if not product_ids:
        return {}

    placeholders = ", ".join("?" for _ in product_ids)
    rows = connection.execute(
        """
        SELECT
        """
        + PRODUCT_SELECT_COLUMNS
        + """
        FROM products
        """
        + PRODUCT_SELECT_RELATION_JOINS
        + """
        WHERE products.id IN ("""
        + placeholders
        + """)
        """,
        product_ids,
    ).fetchall()
    return {int(row["id"]): row for row in rows}


def build_checkout_signature(
    user_id: int,
    cleaned_address: dict[str, str],
    checkout_items: list[dict[str, object]],
    promo_code: str = "",
    delivery_method: str = "standard",
) -> str:
    normalized_items = sorted(
        [
            {
                "cartLineId": int(item.get("cartLineId") or 0),
                "productId": int(item.get("productId") or 0),
                "variantKey": str(item.get("variantKey") or "").strip(),
                "quantity": max(1, int(item.get("quantity") or 1)),
                "price": round(float(item.get("price") or 0), 2),
            }
            for item in checkout_items
        ],
        key=lambda item: (
            int(item["cartLineId"]),
            int(item["productId"]),
            str(item["variantKey"]),
        ),
    )

    signature_payload = {
        "userId": int(user_id),
        "currency": STRIPE_CURRENCY,
        "address": {
            "addressLine": str(cleaned_address.get("address_line") or "").strip(),
            "city": str(cleaned_address.get("city") or "").strip(),
            "country": str(cleaned_address.get("country") or "").strip(),
            "zipCode": str(cleaned_address.get("zip_code") or "").strip(),
            "phoneNumber": str(cleaned_address.get("phone_number") or "").strip(),
        },
        "items": normalized_items,
        "promoCode": str(promo_code or "").strip().upper(),
        "deliveryMethod": get_delivery_method_details(delivery_method)["value"],
    }
    payload_text = json.dumps(
        signature_payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload_text.encode("utf-8")).hexdigest()


def validate_checkout_stock_or_raise(
    connection: DatabaseConnection,
    checkout_items: list[dict[str, object]],
    *,
    exclude_reserved_for_user_id: int | None = None,
) -> None:
    purge_expired_stock_reservations(connection)
    product_rows_by_id = fetch_products_for_checkout_records(connection, checkout_items)
    stock_errors: list[str] = []

    for item in checkout_items:
        product_row = product_rows_by_id.get(int(item["productId"]))
        if not product_row:
            stock_errors.append(
                f"Produkti `{item['title']}` nuk eshte me i disponueshem."
            )
            continue

        variant_inventory = deserialize_product_variant_inventory(
            product_row["variant_inventory"],
            category=product_row["category"],
            size=product_row["size"],
            color=product_row["color"],
            stock_quantity=product_row["stock_quantity"],
        )
        selected_variant = next(
            (
                entry
                for entry in variant_inventory
                if str(entry.get("key", "")).strip() == str(item["variantKey"]).strip()
            ),
            None,
        )
        variant_label = (
            str(item["variantLabel"] or "").strip()
            or build_product_variant_label(
                size=str(item["selectedSize"] or "").strip().upper(),
                color=str(item["selectedColor"] or "").strip().lower(),
            )
        )
        if not selected_variant:
            stock_errors.append(
                f"Produkti `{item['title']}` nuk e ka me variantin `{variant_label}`."
            )
            continue

        stock_quantity = max(0, int(selected_variant.get("quantity") or 0))
        reserved_quantity = fetch_reserved_variant_quantity(
            connection,
            product_id=int(product_row["id"]),
            variant_key=str(selected_variant.get("key") or "").strip(),
            exclude_user_id=exclude_reserved_for_user_id,
        )
        available_quantity = max(0, stock_quantity - reserved_quantity)
        if available_quantity < max(1, int(item["quantity"] or 1)):
            stock_errors.append(
                f"Produkti `{item['title']}` nuk ka stok te mjaftueshem per variantin `{variant_label}`. Mbeten {available_quantity} cope te lira."
            )

    if stock_errors:
        raise CheckoutProcessError(errors=stock_errors)


def create_order_from_checkout_items(
    connection: DatabaseConnection,
    *,
    user: sqlite3.Row | dict[str, object],
    payment_method: str,
    cleaned_address: dict[str, str],
    checkout_items: list[dict[str, object]],
    cart_line_ids: list[int] | None = None,
    pricing_summary: dict[str, object] | None = None,
) -> tuple[int, sqlite3.Row | None, list[sqlite3.Row]]:
    validate_checkout_stock_or_raise(
        connection,
        checkout_items,
        exclude_reserved_for_user_id=int(user["id"]),
    )
    product_rows_by_id = fetch_products_for_checkout_records(connection, checkout_items)
    normalized_pricing_summary = pricing_summary or build_checkout_pricing_summary(
        connection,
        checkout_items=checkout_items,
        user_id=int(user["id"]),
        destination_city=str(cleaned_address.get("city") or "").strip(),
    )
    subtotal_amount = round(float(normalized_pricing_summary.get("subtotal") or 0), 2)
    discount_amount = round(float(normalized_pricing_summary.get("discountAmount") or 0), 2)
    shipping_amount = round(float(normalized_pricing_summary.get("shippingAmount") or 0), 2)
    total_amount = round(float(normalized_pricing_summary.get("total") or 0), 2)
    promo_code = str(normalized_pricing_summary.get("promoCode") or "").strip().upper()
    delivery_method = str(normalized_pricing_summary.get("deliveryMethod") or "standard").strip().lower() or "standard"
    delivery_label = str(normalized_pricing_summary.get("deliveryLabel") or "").strip() or str(
        get_delivery_method_details(delivery_method)["label"]
    )
    estimated_delivery_text = str(
        normalized_pricing_summary.get("estimatedDeliveryText") or ""
    ).strip() or str(get_delivery_method_details(delivery_method)["estimatedDeliveryText"] or "").strip()

    customer_full_name = (
        str(user["full_name"] or "").strip()
        or build_full_name(
            str(user["first_name"] or ""),
            str(user["last_name"] or ""),
        )
        or str(user["email"] or "").strip()
    )

    order_id = execute_insert_and_get_id(
        connection,
        """
        INSERT INTO orders (
            user_id,
            customer_full_name,
            customer_email,
            payment_method,
            status,
            address_line,
            city,
            country,
            zip_code,
            phone_number,
            subtotal_amount,
            discount_amount,
            shipping_amount,
            total_amount,
            promo_code,
            delivery_method,
            delivery_label,
            estimated_delivery_text
        )
        VALUES (?, ?, ?, ?, 'pending_confirmation', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            user["id"],
            customer_full_name,
            str(user["email"] or "").strip(),
            payment_method,
            cleaned_address["address_line"],
            cleaned_address["city"],
            cleaned_address["country"],
            cleaned_address["zip_code"],
            cleaned_address["phone_number"],
            subtotal_amount,
            discount_amount,
            shipping_amount,
            total_amount,
            promo_code,
            delivery_method,
            delivery_label,
            estimated_delivery_text,
        ),
    )

    for item in checkout_items:
        product_row = product_rows_by_id.get(int(item["productId"]))
        product_id = int(item["productId"]) if product_row else None
        business_user_id = item["businessUserId"] or (
            int(product_row["created_by_user_id"]) if product_row and product_row["created_by_user_id"] else None
        )
        quantity = max(1, int(item["quantity"] or 1))
        unit_price = round(float(item["price"] or 0), 2)
        line_total = round(unit_price * quantity, 2)
        commission_rate = MARKETPLACE_COMMISSION_RATE
        commission_amount = round(line_total * commission_rate, 2)
        seller_earnings_amount = round(line_total - commission_amount, 2)
        variant_label = (
            str(item["variantLabel"] or "").strip()
            or build_product_variant_label(
                size=str(item["selectedSize"] or "").strip().upper(),
                color=str(item["selectedColor"] or "").strip().lower(),
            )
        )

        connection.execute(
            """
            INSERT INTO order_items (
                order_id,
                product_id,
                business_user_id,
                business_name_snapshot,
                product_title,
                product_description,
                product_image_path,
                product_category,
                product_type,
                product_size,
                product_color,
                product_variant_key,
                product_variant_label,
                product_variant_snapshot,
                product_package_amount_value,
                product_package_amount_unit,
                unit_price,
                quantity,
                fulfillment_status,
                commission_rate,
                commission_amount,
                seller_earnings_amount,
                payout_status,
                payout_due_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                order_id,
                product_id,
                business_user_id,
                str(item["businessName"] or "").strip(),
                str(item["title"] or "").strip(),
                str(item["description"] or "").strip(),
                normalize_image_path(item["imagePath"]),
                str(item["category"] or "").strip(),
                str(item["productType"] or "").strip(),
                str(item["selectedSize"] or item["size"] or "").strip(),
                str(item["selectedColor"] or item["color"] or "").strip(),
                str(item["variantKey"] or "").strip(),
                variant_label,
                json.dumps(
                    [
                        {
                            "key": str(item["variantKey"] or "").strip(),
                            "size": str(item["selectedSize"] or "").strip().upper(),
                            "color": str(item["selectedColor"] or "").strip().lower(),
                            "quantity": quantity,
                        }
                    ],
                    ensure_ascii=False,
                ),
                round(float(item["packageAmountValue"] or 0), 2),
                str(item["packageAmountUnit"] or "").strip().lower(),
                unit_price,
                quantity,
                "pending_confirmation",
                "",
                build_order_item_confirmation_due_at(),
                commission_rate,
                commission_amount,
                seller_earnings_amount,
                "pending",
                build_order_item_payout_due_at(),
            ),
        )

        if product_row:
            stock_errors, _ = decrement_product_variant_stock(
                connection,
                product_row,
                variant_key=str(item["variantKey"] or "").strip(),
                quantity=quantity,
            )
            if stock_errors:
                raise CheckoutProcessError(errors=stock_errors)

    if cart_line_ids:
        clear_stock_reservations_for_user(
            connection,
            user_id=int(user["id"]),
            cart_line_ids=cart_line_ids,
        )
        placeholders = ", ".join("?" for _ in cart_line_ids)
        connection.execute(
            """
            DELETE FROM cart_lines
            WHERE user_id = ?
              AND id IN ("""
            + placeholders
            + """)
            """,
            [user["id"], *cart_line_ids],
        )

    saved_order = connection.execute(
        """
        SELECT
        """
        + ORDER_SELECT_COLUMNS
        + """
        FROM orders
        WHERE id = ?
        LIMIT 1
        """,
        (order_id,),
    ).fetchone()
    saved_items = connection.execute(
        """
        SELECT
        """
        + ORDER_ITEM_SELECT_COLUMNS
        + """
        FROM order_items
        WHERE order_id = ?
        ORDER BY id DESC
        """,
        (order_id,),
    ).fetchall()
    return order_id, saved_order, saved_items


def build_stripe_api_auth_header() -> str:
    raw_token = f"{STRIPE_SECRET_KEY}:".encode("utf-8")
    return f"Basic {base64.b64encode(raw_token).decode('ascii')}"


def is_stripe_configured() -> bool:
    return bool(STRIPE_SECRET_KEY)


def request_stripe_api(
    path: str,
    *,
    method: str = "GET",
    form_fields: list[tuple[str, str]] | None = None,
) -> tuple[bool, dict[str, object]]:
    if not is_stripe_configured():
        return False, {
            "error": {
                "message": "Stripe test nuk eshte konfiguruar ende ne server.",
            }
        }

    headers = {
        "Authorization": build_stripe_api_auth_header(),
    }
    body: bytes | None = None
    if form_fields is not None:
        body = urlencode(form_fields).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    request = Request(
        f"{STRIPE_API_BASE_URL}{path}",
        data=body,
        headers=headers,
        method=method.upper(),
    )

    try:
        with urlopen(request, timeout=STRIPE_TIMEOUT_SECONDS) as response:
            return True, json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        try:
            payload = json.loads(error.read().decode("utf-8"))
        except (OSError, ValueError, json.JSONDecodeError):
            payload = {
                "error": {
                    "message": str(error),
                }
            }
        return False, payload
    except (URLError, TimeoutError, json.JSONDecodeError) as error:
        return False, {
            "error": {
                "message": f"Stripe nuk po pergjigjet: {error}",
            }
        }


def resolve_stripe_error_message(payload: dict[str, object], fallback_message: str) -> str:
    error_payload = payload.get("error")
    if isinstance(error_payload, dict):
        message = str(error_payload.get("message") or "").strip()
        if message:
            return message
    return fallback_message


def build_stripe_checkout_line_items(
    checkout_items: list[dict[str, object]],
    *,
    discount_amount: float = 0.0,
    shipping_amount: float = 0.0,
    delivery_label: str = "",
) -> tuple[list[tuple[str, str]], int]:
    form_fields: list[tuple[str, str]] = []
    unit_entries: list[dict[str, object]] = []

    for item in checkout_items:
        quantity = max(1, int(item["quantity"] or 1))
        unit_amount = max(1, int(round(float(item["price"] or 0) * 100)))
        variant_label = str(item["variantLabel"] or "").strip()
        product_name = str(item["title"] or "").strip() or "Produkt"
        if variant_label and variant_label.lower() != "standard":
            product_name = f"{product_name} ({variant_label})"
        for _ in range(quantity):
            unit_entries.append({"unitAmount": unit_amount, "name": product_name[:120]})

    total_amount = sum(int(entry["unitAmount"]) for entry in unit_entries)
    discount_cents = min(total_amount, max(0, int(round(float(discount_amount or 0) * 100))))
    if total_amount > 1 and discount_cents >= total_amount:
        discount_cents = total_amount - 1
    if total_amount > 0 and discount_cents > 0:
        weighted_entries: list[tuple[int, float]] = []
        discount_shares = [0 for _ in unit_entries]
        distributed_discount = 0
        for index, entry in enumerate(unit_entries):
            raw_share = (int(entry["unitAmount"]) * discount_cents) / total_amount
            base_share = int(math.floor(raw_share))
            discount_shares[index] = base_share
            distributed_discount += base_share
            weighted_entries.append((index, raw_share - base_share))

        remaining_discount = max(0, discount_cents - distributed_discount)
        for index, _remainder in sorted(weighted_entries, key=lambda item: item[1], reverse=True)[:remaining_discount]:
            discount_shares[index] += 1

        for index, entry in enumerate(unit_entries):
            entry["unitAmount"] = max(1, int(entry["unitAmount"]) - discount_shares[index])

        total_amount = sum(int(entry["unitAmount"]) for entry in unit_entries)

    for index, entry in enumerate(unit_entries):
        form_fields.extend(
            [
                (f"line_items[{index}][price_data][currency]", STRIPE_CURRENCY),
                (f"line_items[{index}][price_data][unit_amount]", str(int(entry["unitAmount"]))),
                (f"line_items[{index}][price_data][product_data][name]", str(entry["name"])),
                (f"line_items[{index}][quantity]", "1"),
            ]
        )

    shipping_cents = max(0, int(round(float(shipping_amount or 0) * 100)))
    if shipping_cents > 0:
        shipping_index = len(unit_entries)
        form_fields.extend(
            [
                (f"line_items[{shipping_index}][price_data][currency]", STRIPE_CURRENCY),
                (f"line_items[{shipping_index}][price_data][unit_amount]", str(shipping_cents)),
                (
                    f"line_items[{shipping_index}][price_data][product_data][name]",
                    str(delivery_label or "Dergese").strip() or "Dergese",
                ),
                (f"line_items[{shipping_index}][quantity]", "1"),
            ]
        )
        total_amount += shipping_cents

    return form_fields, total_amount


def persist_stripe_payment_session(
    connection: DatabaseConnection,
    *,
    stripe_session_id: str,
    user_id: int,
    checkout_signature: str,
    cart_line_ids: list[int],
    cleaned_address: dict[str, str],
    checkout_items: list[dict[str, object]],
    amount_total: int,
    discount_amount: int = 0,
    shipping_amount: int = 0,
    promo_code: str = "",
    delivery_method: str = "standard",
    delivery_label: str = "",
    estimated_delivery_text: str = "",
    currency: str,
    payment_status: str = "",
    stripe_status: str = "",
) -> None:
    now_text = datetime_to_storage_text(utc_now())
    connection.execute(
        """
        INSERT INTO stripe_payment_sessions (
            stripe_session_id,
            user_id,
            checkout_signature,
            cart_line_ids,
            checkout_address,
            checkout_items_snapshot,
            amount_total,
            discount_amount,
            shipping_amount,
            promo_code,
            delivery_method,
            delivery_label,
            estimated_delivery_text,
            currency,
            payment_status,
            stripe_status,
            created_at,
            updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(stripe_session_id)
        DO UPDATE SET
            user_id = excluded.user_id,
            checkout_signature = excluded.checkout_signature,
            cart_line_ids = excluded.cart_line_ids,
            checkout_address = excluded.checkout_address,
            checkout_items_snapshot = excluded.checkout_items_snapshot,
            amount_total = excluded.amount_total,
            discount_amount = excluded.discount_amount,
            shipping_amount = excluded.shipping_amount,
            promo_code = excluded.promo_code,
            delivery_method = excluded.delivery_method,
            delivery_label = excluded.delivery_label,
            estimated_delivery_text = excluded.estimated_delivery_text,
            currency = excluded.currency,
            payment_status = excluded.payment_status,
            stripe_status = excluded.stripe_status,
            updated_at = excluded.updated_at
        """,
        (
            stripe_session_id,
            user_id,
            checkout_signature,
            json.dumps(cart_line_ids, ensure_ascii=False),
            json.dumps(cleaned_address, ensure_ascii=False),
            json.dumps(checkout_items, ensure_ascii=False),
            amount_total,
            max(0, int(discount_amount or 0)),
            max(0, int(shipping_amount or 0)),
            str(promo_code or "").strip().upper(),
            str(delivery_method or "").strip().lower() or "standard",
            str(delivery_label or "").strip(),
            str(estimated_delivery_text or "").strip(),
            str(currency or STRIPE_CURRENCY).strip().lower() or STRIPE_CURRENCY,
            str(payment_status or "").strip().lower(),
            str(stripe_status or "").strip().lower(),
            now_text,
            now_text,
        ),
    )


def fetch_stripe_payment_session(
    connection: DatabaseConnection,
    stripe_session_id: str,
) -> sqlite3.Row | None:
    return connection.execute(
        """
        SELECT
            id,
            stripe_session_id,
            user_id,
            checkout_signature,
            cart_line_ids,
            checkout_address,
            checkout_items_snapshot,
            amount_total,
            discount_amount,
            shipping_amount,
            promo_code,
            delivery_method,
            delivery_label,
            estimated_delivery_text,
            currency,
            payment_status,
            stripe_status,
            order_id,
            created_at,
            updated_at,
            confirmed_at
        FROM stripe_payment_sessions
        WHERE stripe_session_id = ?
        LIMIT 1
        """,
        (stripe_session_id,),
    ).fetchone()


def update_stripe_payment_session_state(
    connection: DatabaseConnection,
    stripe_session_id: str,
    *,
    payment_status: str,
    stripe_status: str,
    order_id: int | None = None,
) -> None:
    now_text = datetime_to_storage_text(utc_now())
    if order_id is None:
        connection.execute(
            """
            UPDATE stripe_payment_sessions
            SET
                payment_status = ?,
                stripe_status = ?,
                updated_at = ?
            WHERE stripe_session_id = ?
            """,
            (
                str(payment_status or "").strip().lower(),
                str(stripe_status or "").strip().lower(),
                now_text,
                stripe_session_id,
            ),
        )
        return

    connection.execute(
        """
        UPDATE stripe_payment_sessions
        SET
            payment_status = ?,
            stripe_status = ?,
            order_id = ?,
            confirmed_at = ?,
            updated_at = ?
        WHERE stripe_session_id = ?
        """,
        (
            str(payment_status or "").strip().lower(),
            str(stripe_status or "").strip().lower(),
            order_id,
            now_text,
            now_text,
            stripe_session_id,
        ),
    )


def fetch_cart_line_for_user(
    connection: DatabaseConnection,
    user_id: int,
    cart_line_id: int,
) -> sqlite3.Row | None:
    return connection.execute(
        """
        SELECT
            id,
            user_id,
            product_id,
            variant_key,
            variant_label,
            selected_size,
            selected_color,
            quantity,
            created_at,
            updated_at
        FROM cart_lines
        WHERE user_id = ? AND id = ?
        LIMIT 1
        """,
        (user_id, cart_line_id),
    ).fetchone()


def resolve_requested_product_variant(
    product: sqlite3.Row,
    payload: dict[str, object],
) -> tuple[list[str], dict[str, object] | None]:
    variant_inventory = deserialize_product_variant_inventory(
        product["variant_inventory"] if "variant_inventory" in product.keys() else [],
        category=product["category"] if "category" in product.keys() else "",
        size=product["size"] if "size" in product.keys() else "",
        color=product["color"] if "color" in product.keys() else "",
        stock_quantity=product["stock_quantity"] if "stock_quantity" in product.keys() else 0,
    )
    if not variant_inventory:
        return ["Produkti nuk ka stok te disponueshem."], None

    requested_variant_key = str(payload.get("variantKey", "")).strip()
    requested_size = str(payload.get("size", "") or payload.get("selectedSize", "")).strip().upper()
    requested_color = str(payload.get("color", "") or payload.get("selectedColor", "")).strip().lower()
    requested_key = requested_variant_key or build_product_variant_key(
        size=requested_size,
        color=requested_color,
    )

    selected_variant = None
    if requested_variant_key or requested_size or requested_color:
        selected_variant = next(
            (entry for entry in variant_inventory if str(entry.get("key", "")).strip() == requested_key),
            None,
        )
        if not selected_variant:
            return ["Varianti i zgjedhur nuk ekziston me."], None
    elif len(variant_inventory) == 1:
        selected_variant = variant_inventory[0]
    else:
        return ["Zgjidh ngjyren dhe madhesine para se ta shtosh produktin ne shporte."], None

    if max(0, int(selected_variant.get("quantity") or 0)) <= 0:
        return [f"Varianti `{selected_variant['label']}` nuk ka stok."], None

    return [], selected_variant


def summarize_variant_inventory_for_storage(
    variant_inventory: list[dict[str, object]],
) -> tuple[str, str, int, str]:
    total_stock_quantity = sum(max(0, int(entry.get("quantity") or 0)) for entry in variant_inventory)
    unique_sizes = sorted(
        {
            str(entry.get("size", "")).strip().upper()
            for entry in variant_inventory
            if str(entry.get("size", "")).strip()
        }
    )
    unique_colors = sorted(
        {
            str(entry.get("color", "")).strip().lower()
            for entry in variant_inventory
            if str(entry.get("color", "")).strip()
        }
    )
    normalized_size = unique_sizes[0] if len(unique_sizes) == 1 else ""
    if len(unique_colors) == 1:
        normalized_color = unique_colors[0]
    elif len(unique_colors) > 1 and "shume-ngjyra" in PRODUCT_COLORS:
        normalized_color = "shume-ngjyra"
    else:
        normalized_color = ""

    return (
        normalized_size,
        normalized_color,
        total_stock_quantity,
        json.dumps(variant_inventory, ensure_ascii=False),
    )


def decrement_product_variant_stock(
    connection: DatabaseConnection,
    product_row: sqlite3.Row,
    *,
    variant_key: str,
    quantity: int,
) -> tuple[list[str], list[dict[str, object]]]:
    variant_inventory = deserialize_product_variant_inventory(
        product_row["variant_inventory"] if "variant_inventory" in product_row.keys() else [],
        category=product_row["category"] if "category" in product_row.keys() else "",
        size=product_row["size"] if "size" in product_row.keys() else "",
        color=product_row["color"] if "color" in product_row.keys() else "",
        stock_quantity=product_row["stock_quantity"] if "stock_quantity" in product_row.keys() else 0,
    )
    selected_variant = next(
        (entry for entry in variant_inventory if str(entry.get("key", "")).strip() == variant_key),
        None,
    )
    if not selected_variant:
        return ["Varianti i produktit nuk u gjet gjate porosise."], variant_inventory

    available_quantity = max(0, int(selected_variant.get("quantity") or 0))
    if available_quantity < quantity:
        return [
            f"Produkti `{product_row['title']}` nuk ka stok te mjaftueshem per variantin `{selected_variant['label']}`."
        ], variant_inventory

    selected_variant["quantity"] = max(0, available_quantity - quantity)
    normalized_size, normalized_color, total_stock_quantity, serialized_inventory = summarize_variant_inventory_for_storage(
        variant_inventory
    )
    connection.execute(
        """
        UPDATE products
        SET
            variant_inventory = ?,
            size = ?,
            color = ?,
            stock_quantity = ?,
            show_stock_public = CASE
                WHEN ? <= 0 THEN 0
                ELSE show_stock_public
            END
        WHERE id = ?
        """,
        (
            serialized_inventory,
            normalized_size,
            normalized_color,
            total_stock_quantity,
            total_stock_quantity,
            product_row["id"],
        ),
    )
    return [], variant_inventory


def build_order_item_payout_due_at(base_time: datetime | None = None) -> str:
    return datetime_to_storage_text((base_time or utc_now()) + timedelta(days=PAYOUT_HOLD_DAYS))


def build_order_item_confirmation_due_at(base_time: datetime | None = None) -> str:
    return datetime_to_storage_text(
        (base_time or utc_now()) + timedelta(days=ORDER_BUSINESS_CONFIRMATION_TIMEOUT_DAYS)
    )


def update_order_item_fulfillment_state(
    connection: DatabaseConnection,
    *,
    order_item_id: int,
    fulfillment_status: str,
    tracking_code: str = "",
    tracking_url: str = "",
) -> None:
    now_text = datetime_to_storage_text(utc_now())
    normalized_status = str(fulfillment_status or "").strip().lower() or "confirmed"
    normalized_tracking_code = str(tracking_code or "").strip()
    normalized_tracking_url = str(tracking_url or "").strip()

    confirmed_at = ""
    shipped_at = ""
    delivered_at = ""
    cancelled_at = ""
    payout_status = "pending"
    payout_due_at = ""

    if normalized_status == "confirmed":
        confirmed_at = now_text
    if normalized_status == "shipped":
        shipped_at = now_text
    elif normalized_status == "delivered":
        confirmed_at = now_text
        shipped_at = now_text
        delivered_at = now_text
        payout_status = "ready"
        payout_due_at = build_order_item_payout_due_at()
    elif normalized_status == "cancelled":
        cancelled_at = now_text
        payout_status = "on_hold"
    elif normalized_status == "returned":
        delivered_at = now_text
        payout_status = "on_hold"

    connection.execute(
        """
        UPDATE order_items
        SET
            fulfillment_status = ?,
            confirmed_at = CASE
                WHEN ? = 'confirmed' THEN CASE
                    WHEN COALESCE(confirmed_at, '') = '' THEN ?
                    ELSE COALESCE(confirmed_at, '')
                END
                ELSE COALESCE(confirmed_at, '')
            END,
            tracking_code = CASE
                WHEN ? <> '' THEN ?
                ELSE COALESCE(tracking_code, '')
            END,
            tracking_url = CASE
                WHEN ? <> '' THEN ?
                ELSE COALESCE(tracking_url, '')
            END,
            shipped_at = CASE
                WHEN ? <> '' THEN ?
                ELSE COALESCE(shipped_at, '')
            END,
            delivered_at = CASE
                WHEN ? <> '' THEN ?
                ELSE CASE
                    WHEN ? = 'delivered' AND COALESCE(delivered_at, '') = '' THEN ?
                    ELSE COALESCE(delivered_at, '')
                END
            END,
            cancelled_at = CASE
                WHEN ? <> '' THEN ?
                ELSE CASE
                    WHEN ? = 'cancelled' AND COALESCE(cancelled_at, '') = '' THEN ?
                    ELSE COALESCE(cancelled_at, '')
                END
            END,
            payout_status = ?,
            payout_due_at = CASE
                WHEN ? <> '' THEN ?
                ELSE COALESCE(payout_due_at, '')
            END
        WHERE id = ?
        """,
        (
            normalized_status,
            normalized_status,
            now_text,
            normalized_tracking_code,
            normalized_tracking_code,
            normalized_tracking_url,
            normalized_tracking_url,
            shipped_at,
            shipped_at,
            delivered_at,
            delivered_at,
            normalized_status,
            now_text,
            cancelled_at,
            cancelled_at,
            normalized_status,
            now_text,
            payout_status,
            payout_due_at,
            payout_due_at,
            order_item_id,
        ),
    )


def refresh_order_status_from_items(
    connection: DatabaseConnection,
    order_id: int,
) -> str:
    item_rows = connection.execute(
        """
        SELECT fulfillment_status
        FROM order_items
        WHERE order_id = ?
        ORDER BY id ASC
        """,
        (order_id,),
    ).fetchall()
    next_status = summarize_order_fulfillment_status(
        [{"fulfillmentStatus": row["fulfillment_status"]} for row in item_rows]
    )
    connection.execute(
        """
        UPDATE orders
        SET status = ?
        WHERE id = ?
        """,
        (next_status, order_id),
    )
    return next_status


def create_timeout_refund_request_for_order_item(
    connection: DatabaseConnection,
    order_item_row: sqlite3.Row,
) -> int | None:
    existing_request = connection.execute(
        """
        SELECT id
        FROM return_requests
        WHERE order_item_id = ?
          AND status IN ('requested', 'approved', 'received')
        LIMIT 1
        """,
        (int(order_item_row["id"]),),
    ).fetchone()
    if existing_request:
        return None

    reason = "Refund automatik: biznesi nuk e konfirmoi porosine brenda afatit."
    product_title = str(order_item_row["product_title"] or "").strip() or "Produkti"
    business_name = str(order_item_row["business_name_snapshot"] or "").strip() or "Biznesi"
    confirmation_due_at = str(order_item_row["confirmation_due_at"] or "").strip()
    details = (
        f"Artikulli `{product_title}` nga `{business_name}` u anulua automatikisht dhe kaloi ne refund "
        f"sepse nuk u konfirmua brenda afatit{f' deri me {confirmation_due_at}' if confirmation_due_at else ''}."
    )

    return execute_insert_and_get_id(
        connection,
        """
        INSERT INTO return_requests (
            order_id,
            order_item_id,
            user_id,
            business_user_id,
            reason,
            details,
            status,
            created_at,
            updated_at,
            resolved_at,
            resolution_notes
        )
        VALUES (?, ?, ?, ?, ?, ?, 'requested', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, '', '')
        """,
        (
            int(order_item_row["order_id"]),
            int(order_item_row["id"]),
            int(order_item_row["customer_user_id"] or 0),
            int(order_item_row["business_user_id"] or 0) or None,
            reason,
            details,
        ),
    )


def process_expired_order_confirmations(connection: DatabaseConnection) -> dict[str, int]:
    now_text = datetime_to_storage_text(utc_now())
    expired_order_items = connection.execute(
        """
        SELECT
            oi.id,
            oi.order_id,
            oi.business_user_id,
            oi.business_name_snapshot,
            oi.product_title,
            oi.fulfillment_status,
            oi.confirmation_due_at,
            oi.created_at,
            o.user_id AS customer_user_id,
            o.customer_full_name,
            o.customer_email
        FROM order_items oi
        INNER JOIN orders o ON o.id = oi.order_id
        WHERE LOWER(TRIM(COALESCE(oi.fulfillment_status, ''))) = 'pending_confirmation'
          AND TRIM(COALESCE(oi.confirmation_due_at, '')) <> ''
          AND oi.confirmation_due_at <= ?
        ORDER BY oi.confirmation_due_at ASC, oi.created_at ASC, oi.id ASC
        """,
        (now_text,),
    ).fetchall()

    if not expired_order_items:
        return {"expiredItems": 0, "refundedRequests": 0, "refreshedOrders": 0}

    refreshed_order_ids: set[int] = set()
    created_refund_requests = 0

    for order_item_row in expired_order_items:
        refund_request_id = create_timeout_refund_request_for_order_item(connection, order_item_row)
        if refund_request_id is not None:
            created_refund_requests += 1

        update_order_item_fulfillment_state(
            connection,
            order_item_id=int(order_item_row["id"]),
            fulfillment_status="cancelled",
        )

        customer_user_id = int(order_item_row["customer_user_id"] or 0)
        business_user_id = int(order_item_row["business_user_id"] or 0)
        product_title = str(order_item_row["product_title"] or "").strip() or "Produkti"
        business_name = str(order_item_row["business_name_snapshot"] or "").strip() or "Biznesi"
        if customer_user_id > 0:
            create_notification(
                connection,
                user_id=customer_user_id,
                notification_type="refund",
                title="Refund automatik po shqyrtohet",
                body=(
                    f"`{product_title}` nga `{business_name}` nuk u konfirmua brenda afatit dhe refund "
                    "procedura u hap automatikisht."
                ),
                href="/refund-returne",
                metadata={
                    "orderId": int(order_item_row["order_id"]),
                    "orderItemId": int(order_item_row["id"]),
                },
            )
        if business_user_id > 0:
            create_notification(
                connection,
                user_id=business_user_id,
                notification_type="order",
                title="Porosia u anulua automatikisht",
                body=(
                    f"`{product_title}` nuk u konfirmua brenda afatit dhe kaloi ne refund automatik per klientin."
                ),
                href="/porosite-e-biznesit",
                metadata={
                    "orderId": int(order_item_row["order_id"]),
                    "orderItemId": int(order_item_row["id"]),
                },
            )

        refreshed_order_ids.add(int(order_item_row["order_id"]))

    for order_id in refreshed_order_ids:
        refresh_order_status_from_items(connection, order_id)

    return {
        "expiredItems": len(expired_order_items),
        "refundedRequests": created_refund_requests,
        "refreshedOrders": len(refreshed_order_ids),
    }


def fetch_orders_for_user(user_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        process_expired_order_confirmations(connection)
        return connection.execute(
            """
            SELECT
            """
            + ORDER_SELECT_COLUMNS
            + """
            FROM orders
            WHERE user_id = ?
            ORDER BY id DESC
            """,
            (user_id,),
        ).fetchall()


def fetch_order_items_for_orders(order_ids: list[int]) -> list[sqlite3.Row]:
    if not order_ids:
        return []

    placeholders = ", ".join("?" for _ in order_ids)

    with get_db_connection() as connection:
        process_expired_order_confirmations(connection)
        return connection.execute(
            """
            SELECT
            """
            + ORDER_ITEM_SELECT_COLUMNS
            + """
            FROM order_items
            WHERE order_id IN ("""
            + placeholders
            + """)
            ORDER BY order_id DESC, id DESC
            """,
            order_ids,
        ).fetchall()


def build_orders_payload(orders: list[sqlite3.Row], order_items: list[sqlite3.Row]) -> list[dict[str, object]]:
    items_by_order_id: dict[int, list[dict[str, object]]] = {}
    for item_row in order_items:
        order_id = int(item_row["order_id"])
        items_by_order_id.setdefault(order_id, []).append(serialize_order_item(item_row))

    return [
        serialize_order(order_row, items_by_order_id.get(int(order_row["id"]), []))
        for order_row in orders
    ]


def fetch_order_row_by_id(
    connection: DatabaseConnection,
    order_id: int,
) -> sqlite3.Row | None:
    process_expired_order_confirmations(connection)
    return connection.execute(
        """
        SELECT
        """
        + ORDER_SELECT_COLUMNS
        + """
        FROM orders
        WHERE id = ?
        LIMIT 1
        """,
        (order_id,),
    ).fetchone()


def fetch_order_items_for_order_id(
    connection: DatabaseConnection,
    order_id: int,
) -> list[sqlite3.Row]:
    process_expired_order_confirmations(connection)
    return connection.execute(
        """
        SELECT
        """
        + ORDER_ITEM_SELECT_COLUMNS
        + """
        FROM order_items
        WHERE order_id = ?
        ORDER BY id DESC
        """,
        (order_id,),
    ).fetchall()


def user_can_access_order_invoice(
    connection: DatabaseConnection,
    *,
    user: sqlite3.Row,
    order_row: sqlite3.Row,
) -> bool:
    if user["role"] == "admin":
        return True

    if user["role"] == "client":
        return int(order_row["user_id"] or 0) == int(user["id"])

    if user["role"] == "business":
        row = connection.execute(
            """
            SELECT 1
            FROM order_items
            WHERE order_id = ?
              AND business_user_id = ?
            LIMIT 1
            """,
            (int(order_row["id"]), int(user["id"])),
        ).fetchone()
        return bool(row)

    return False


def fetch_business_orders_for_user(business_user_id: int) -> list[dict[str, object]]:
    with get_db_connection() as connection:
        process_expired_order_confirmations(connection)
        order_rows = connection.execute(
            """
            SELECT
            """
            + ORDER_SELECT_COLUMNS
            + """
            FROM orders
            WHERE EXISTS (
                SELECT 1
                FROM order_items oi
                WHERE oi.order_id = orders.id
                  AND oi.business_user_id = ?
            )
            ORDER BY id DESC
            """,
            (business_user_id,),
        ).fetchall()

        order_items = connection.execute(
            """
            SELECT
            """
            + ORDER_ITEM_SELECT_COLUMNS
            + """
            FROM order_items
            WHERE business_user_id = ?
            ORDER BY order_id DESC, id DESC
            """,
            (business_user_id,),
        ).fetchall()

    return build_orders_payload(order_rows, order_items)


def fetch_all_orders_for_admin() -> list[dict[str, object]]:
    with get_db_connection() as connection:
        process_expired_order_confirmations(connection)
        order_rows = connection.execute(
            """
            SELECT
            """
            + ORDER_SELECT_COLUMNS
            + """
            FROM orders
            ORDER BY id DESC
            """
        ).fetchall()
        order_items = connection.execute(
            """
            SELECT
            """
            + ORDER_ITEM_SELECT_COLUMNS
            + """
            FROM order_items
            ORDER BY order_id DESC, id DESC
            """
        ).fetchall()

    return build_orders_payload(order_rows, order_items)


def fetch_product_reviews(product_id: int, *, limit: int = 12) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                pr.id,
                pr.product_id,
                pr.order_item_id,
                pr.user_id,
                pr.rating,
                pr.review_title,
                pr.review_body,
                pr.status,
                pr.created_at,
                pr.updated_at,
                u.full_name AS author_name
            FROM product_reviews pr
            INNER JOIN users u ON u.id = pr.user_id
            WHERE pr.product_id = ?
              AND pr.status = 'published'
            ORDER BY pr.created_at DESC, pr.id DESC
            LIMIT ?
            """,
            (product_id, max(1, int(limit))),
        ).fetchall()


def find_reviewable_order_item(
    *,
    connection: DatabaseConnection,
    user_id: int,
    product_id: int,
) -> sqlite3.Row | None:
    return connection.execute(
        """
        SELECT
            oi.id,
            oi.order_id,
            oi.product_id,
            oi.business_user_id,
            oi.fulfillment_status
        FROM order_items oi
        INNER JOIN orders o ON o.id = oi.order_id
        LEFT JOIN product_reviews pr
            ON pr.order_item_id = oi.id
           AND pr.user_id = o.user_id
        WHERE o.user_id = ?
          AND oi.product_id = ?
          AND oi.fulfillment_status = 'delivered'
          AND pr.id IS NULL
        ORDER BY oi.delivered_at DESC, oi.id DESC
        LIMIT 1
        """,
        (user_id, product_id),
    ).fetchone()


def fetch_notifications_for_user(user_id: int, *, limit: int = NOTIFICATIONS_PAGE_LIMIT) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                id,
                user_id,
                type,
                title,
                body,
                href,
                metadata,
                is_read,
                created_at,
                read_at
            FROM notifications
            WHERE user_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            (user_id, max(1, int(limit))),
        ).fetchall()


def create_notification(
    connection: DatabaseConnection,
    *,
    user_id: int,
    notification_type: str,
    title: str,
    body: str,
    href: str = "",
    metadata: dict[str, object] | None = None,
) -> None:
    connection.execute(
        """
        INSERT INTO notifications (
            user_id,
            type,
            title,
            body,
            href,
            metadata,
            is_read,
            created_at,
            read_at
        )
        VALUES (?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP, '')
        """,
        (
            user_id,
            str(notification_type or "info").strip().lower() or "info",
            str(title or "").strip(),
            str(body or "").strip(),
            str(href or "").strip(),
            json.dumps(metadata or {}, ensure_ascii=False),
        ),
    )


def fetch_unread_notifications_count(user_id: int) -> int:
    with get_db_connection() as connection:
        row = connection.execute(
            """
            SELECT COUNT(*) AS total
            FROM notifications
            WHERE user_id = ?
              AND COALESCE(is_read, 0) = 0
            """,
            (user_id,),
        ).fetchone()
    return int(row["total"] or 0) if row else 0


def mark_notifications_as_read(connection: DatabaseConnection, *, user_id: int) -> None:
    now_text = datetime_to_storage_text(utc_now())
    connection.execute(
        """
        UPDATE notifications
        SET
            is_read = 1,
            read_at = CASE
                WHEN TRIM(COALESCE(read_at, '')) <> '' THEN read_at
                ELSE ?
            END
        WHERE user_id = ?
          AND COALESCE(is_read, 0) = 0
        """,
        (now_text, user_id),
    )


def fetch_return_requests_for_user(user: sqlite3.Row) -> list[sqlite3.Row]:
    normalized_role = str(user["role"] or "").strip().lower()
    with get_db_connection() as connection:
        process_expired_order_confirmations(connection)
        if normalized_role == "admin":
            return connection.execute(
                """
                SELECT
                    rr.*,
                    oi.product_title,
                    oi.product_image_path,
                    oi.business_name_snapshot,
                    o.customer_full_name
                FROM return_requests rr
                INNER JOIN order_items oi ON oi.id = rr.order_item_id
                INNER JOIN orders o ON o.id = rr.order_id
                ORDER BY rr.created_at DESC, rr.id DESC
                """
            ).fetchall()

        if normalized_role == "business":
            return connection.execute(
                """
                SELECT
                    rr.*,
                    oi.product_title,
                    oi.product_image_path,
                    oi.business_name_snapshot,
                    o.customer_full_name
                FROM return_requests rr
                INNER JOIN order_items oi ON oi.id = rr.order_item_id
                INNER JOIN orders o ON o.id = rr.order_id
                WHERE rr.business_user_id = ?
                ORDER BY rr.created_at DESC, rr.id DESC
                """,
                (user["id"],),
            ).fetchall()

        return connection.execute(
            """
            SELECT
                rr.*,
                oi.product_title,
                oi.product_image_path,
                oi.business_name_snapshot,
                o.customer_full_name
            FROM return_requests rr
            INNER JOIN order_items oi ON oi.id = rr.order_item_id
            INNER JOIN orders o ON o.id = rr.order_id
            WHERE rr.user_id = ?
            ORDER BY rr.created_at DESC, rr.id DESC
            """,
            (user["id"],),
        ).fetchall()


def purge_expired_stock_reservations(connection: DatabaseConnection) -> None:
    now_text = datetime_to_storage_text(utc_now())
    connection.execute(
        """
        DELETE FROM stock_reservations
        WHERE TRIM(COALESCE(expires_at, '')) <> ''
          AND expires_at <= ?
        """,
        (now_text,),
    )


def fetch_reserved_variant_quantity(
    connection: DatabaseConnection,
    *,
    product_id: int,
    variant_key: str,
    exclude_user_id: int | None = None,
) -> int:
    query = """
        SELECT COALESCE(SUM(quantity), 0) AS total
        FROM stock_reservations
        WHERE product_id = ?
          AND variant_key = ?
          AND TRIM(COALESCE(expires_at, '')) <> ''
          AND expires_at > ?
    """
    parameters: list[object] = [
        product_id,
        str(variant_key or "").strip(),
        datetime_to_storage_text(utc_now()),
    ]
    if exclude_user_id is not None:
        query += " AND user_id <> ?"
        parameters.append(int(exclude_user_id))
    row = connection.execute(query, parameters).fetchone()
    return int(row["total"] or 0) if row else 0


def clear_stock_reservations_for_user(
    connection: DatabaseConnection,
    *,
    user_id: int,
    cart_line_ids: list[int] | None = None,
) -> None:
    purge_expired_stock_reservations(connection)
    if cart_line_ids:
        placeholders = ", ".join("?" for _ in cart_line_ids)
        connection.execute(
            """
            DELETE FROM stock_reservations
            WHERE user_id = ?
              AND cart_line_id IN ("""
            + placeholders
            + """)
            """,
            [user_id, *cart_line_ids],
        )
        return
    connection.execute(
        """
        DELETE FROM stock_reservations
        WHERE user_id = ?
        """,
        (user_id,),
    )


def reserve_checkout_stock(
    connection: DatabaseConnection,
    *,
    user_id: int,
    cart_line_ids: list[int],
    checkout_items: list[dict[str, object]],
) -> str:
    purge_expired_stock_reservations(connection)
    validate_checkout_stock_or_raise(connection, checkout_items, exclude_reserved_for_user_id=user_id)
    expires_at = datetime_to_storage_text(utc_now() + timedelta(minutes=STOCK_RESERVATION_HOLD_MINUTES))
    valid_cart_line_ids = {int(cart_line_id) for cart_line_id in cart_line_ids}
    clear_stock_reservations_for_user(connection, user_id=user_id)
    for item in checkout_items:
        cart_line_id = int(item.get("cartLineId") or 0)
        if cart_line_id <= 0 or cart_line_id not in valid_cart_line_ids:
            continue
        connection.execute(
            """
            INSERT INTO stock_reservations (
                user_id,
                cart_line_id,
                product_id,
                variant_key,
                quantity,
                expires_at,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT(cart_line_id)
            DO UPDATE SET
                user_id = excluded.user_id,
                product_id = excluded.product_id,
                variant_key = excluded.variant_key,
                quantity = excluded.quantity,
                expires_at = excluded.expires_at,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                user_id,
                cart_line_id,
                int(item.get("productId") or 0),
                str(item.get("variantKey") or "").strip(),
                max(1, int(item.get("quantity") or 1)),
                expires_at,
            ),
        )
    return expires_at


def fetch_reports_for_admin() -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                r.*,
                reporter.full_name AS reporter_name,
                reported.full_name AS reported_name
            FROM reports r
            INNER JOIN users reporter ON reporter.id = r.reporter_user_id
            LEFT JOIN users reported ON reported.id = r.reported_user_id
            ORDER BY r.created_at DESC, r.id DESC
            """
        ).fetchall()


def serialize_report(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "reporterUserId": row["reporter_user_id"],
        "reportedUserId": row["reported_user_id"] if "reported_user_id" in row.keys() else None,
        "businessUserId": row["business_user_id"] if "business_user_id" in row.keys() else None,
        "targetType": str(row["target_type"] or "").strip().lower(),
        "targetId": int(row["target_id"] or 0),
        "targetLabel": str(row["target_label"] or "").strip(),
        "reason": str(row["reason"] or "").strip(),
        "details": str(row["details"] or "").strip(),
        "status": str(row["status"] or "").strip().lower(),
        "adminNotes": str(row["admin_notes"] or "").strip() if "admin_notes" in row.keys() else "",
        "createdAt": str(row["created_at"] or "").strip(),
        "updatedAt": str(row["updated_at"] or "").strip(),
        "resolvedAt": str(row["resolved_at"] or "").strip() if "resolved_at" in row.keys() else "",
        "reporterName": str(row["reporter_name"] or "").strip() if "reporter_name" in row.keys() else "",
        "reportedName": str(row["reported_name"] or "").strip() if "reported_name" in row.keys() else "",
    }


def fetch_business_promotions(user: sqlite3.Row) -> list[sqlite3.Row]:
    normalized_role = str(user["role"] or "").strip().lower()
    with get_db_connection() as connection:
        if normalized_role == "admin":
            return connection.execute(
                """
                SELECT *
                FROM promo_codes
                ORDER BY created_at DESC, id DESC
                """
            ).fetchall()
        return connection.execute(
            """
            SELECT *
            FROM promo_codes
            WHERE COALESCE(business_user_id, 0) = ?
            ORDER BY created_at DESC, id DESC
            """,
            (user["id"],),
        ).fetchall()


def serialize_promo_code(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "code": str(row["code"] or "").strip().upper(),
        "title": str(row["title"] or "").strip(),
        "description": str(row["description"] or "").strip(),
        "discountType": str(row["discount_type"] or "").strip().lower(),
        "discountValue": round(float(row["discount_value"] or 0), 2),
        "minimumSubtotal": round(float(row["minimum_subtotal"] or 0), 2),
        "usageLimit": max(0, int(row["usage_limit"] or 0)),
        "perUserLimit": max(0, int(row["per_user_limit"] or 0)),
        "isActive": bool(row["is_active"]),
        "pageSection": str(row["page_section"] or "").strip(),
        "category": str(row["category"] or "").strip(),
        "startsAt": str(row["starts_at"] or "").strip(),
        "endsAt": str(row["ends_at"] or "").strip(),
        "createdAt": str(row["created_at"] or "").strip(),
    }


def fetch_promo_code_by_code(connection: DatabaseConnection, promo_code: str) -> sqlite3.Row | None:
    normalized_code = str(promo_code or "").strip().upper()
    if not normalized_code:
        return None
    return connection.execute(
        """
        SELECT *
        FROM promo_codes
        WHERE UPPER(code) = ?
        LIMIT 1
        """,
        (normalized_code,),
    ).fetchone()


def count_promo_code_usage(
    connection: DatabaseConnection,
    *,
    promo_code: str,
    user_id: int | None = None,
) -> int:
    query = """
        SELECT COUNT(*) AS total
        FROM orders
        WHERE UPPER(COALESCE(promo_code, '')) = ?
    """
    parameters: list[object] = [str(promo_code or "").strip().upper()]
    if user_id is not None:
        query += " AND COALESCE(user_id, 0) = ?"
        parameters.append(int(user_id))
    row = connection.execute(query, parameters).fetchone()
    return int(row["total"] or 0) if row else 0


def build_checkout_pricing_summary(
    connection: DatabaseConnection,
    *,
    checkout_items: list[dict[str, object]],
    promo_code: str = "",
    user_id: int | None = None,
    delivery_method: str = "standard",
    destination_city: str = "",
) -> dict[str, object]:
    subtotal = round(
        sum(round(float(item.get("price") or 0), 2) * max(1, int(item.get("quantity") or 1)) for item in checkout_items),
        2,
    )
    normalized_code = str(promo_code or "").strip().upper()
    discount_amount = 0.0
    promo_row = None
    message = ""

    if normalized_code:
        promo_row = fetch_promo_code_by_code(connection, normalized_code)
        if not promo_row:
            raise CheckoutProcessError(message="Kodi promocional nuk ekziston.")

        if not bool(promo_row["is_active"]):
            raise CheckoutProcessError(message="Kodi promocional nuk eshte aktiv.")

        starts_at = parse_storage_datetime(promo_row["starts_at"])
        ends_at = parse_storage_datetime(promo_row["ends_at"])
        now_value = utc_now()
        if starts_at and starts_at > now_value:
            raise CheckoutProcessError(message="Ky kupon ende nuk ka nisur.")
        if ends_at and ends_at < now_value:
            raise CheckoutProcessError(message="Ky kupon ka skaduar.")

        minimum_subtotal = round(float(promo_row["minimum_subtotal"] or 0), 2)
        if subtotal < minimum_subtotal:
            raise CheckoutProcessError(
                message=f"Ky kupon kerkon minimumin {minimum_subtotal:.2f}€ ne shporte."
            )

        required_page_section = str(promo_row["page_section"] or "").strip().lower()
        required_category = str(promo_row["category"] or "").strip().lower()
        if required_page_section:
            matches_page_section = any(
                build_section_value_from_category(str(item.get("category") or "").strip().lower()) == required_page_section
                for item in checkout_items
            )
            if not matches_page_section:
                raise CheckoutProcessError(message="Ky kupon nuk vlen per kete seksion produktesh.")
        if required_category:
            matches_category = any(
                str(item.get("category") or "").strip().lower() == required_category
                for item in checkout_items
            )
            if not matches_category:
                raise CheckoutProcessError(message="Ky kupon nuk vlen per kete kategori produktesh.")

        usage_limit = max(0, int(promo_row["usage_limit"] or 0))
        if usage_limit > 0 and count_promo_code_usage(connection, promo_code=normalized_code) >= usage_limit:
            raise CheckoutProcessError(message="Ky kupon ka arritur limitin e perdorimit.")

        per_user_limit = max(0, int(promo_row["per_user_limit"] or 0))
        if user_id and per_user_limit > 0 and count_promo_code_usage(connection, promo_code=normalized_code, user_id=user_id) >= per_user_limit:
            raise CheckoutProcessError(message="E ke perdorur maksimumin e lejuar per kete kupon.")

        discount_type = str(promo_row["discount_type"] or "").strip().lower()
        discount_value = round(float(promo_row["discount_value"] or 0), 2)
        if discount_type == "percent":
            discount_amount = round(subtotal * (discount_value / 100), 2)
        else:
            discount_amount = round(discount_value, 2)
        discount_amount = max(0.0, min(subtotal, discount_amount))
        message = str(promo_row["title"] or "").strip() or f"Kuponi {normalized_code} u aplikua."

    shipping_quote = build_shipping_quote(
        connection=connection,
        checkout_items=checkout_items,
        delivery_method=delivery_method,
        destination_city=destination_city,
    )
    shipping_amount = round(float(shipping_quote.get("shippingAmount") or 0), 2)
    total = round(max(0.0, subtotal - discount_amount + shipping_amount), 2)
    return {
        "promoCode": normalized_code,
        "promo": serialize_promo_code(promo_row) if promo_row else None,
        "subtotal": subtotal,
        "discountAmount": discount_amount,
        "shippingAmount": shipping_amount,
        "total": total,
        "deliveryMethod": str(shipping_quote.get("deliveryMethod") or "standard"),
        "deliveryLabel": str(shipping_quote.get("deliveryLabel") or "Dergese standard"),
        "estimatedDeliveryText": str(shipping_quote.get("estimatedDeliveryText") or "").strip(),
        "cityZoneLabel": str(shipping_quote.get("cityZoneLabel") or "").strip(),
        "shippingRuleMessage": str(shipping_quote.get("ruleMessage") or "").strip(),
        "shippingBaseAmount": round(float(shipping_quote.get("baseAmount") or 0), 2),
        "shippingCitySurcharge": round(float(shipping_quote.get("citySurcharge") or 0), 2),
        "shippingSubtotalDiscount": round(float(shipping_quote.get("subtotalDiscount") or 0), 2),
        "availableDeliveryMethods": (
            list(shipping_quote.get("availableDeliveryMethods") or [])
            if isinstance(shipping_quote.get("availableDeliveryMethods"), list)
            else []
        ),
        "shippingBreakdown": (
            list(shipping_quote.get("breakdown") or [])
            if isinstance(shipping_quote.get("breakdown"), list)
            else []
        ),
        "deliveryNotice": str(shipping_quote.get("deliveryNotice") or "").strip(),
        "message": message,
    }


def fetch_business_analytics(user_id: int) -> dict[str, object]:
    with get_db_connection() as connection:
        products_row = connection.execute(
            """
            SELECT
                COUNT(*) AS total_products,
                SUM(CASE WHEN COALESCE(is_public, 0) = 1 THEN 1 ELSE 0 END) AS public_products,
                SUM(COALESCE(stock_quantity, 0)) AS total_stock
            FROM products
            WHERE created_by_user_id = ?
            """,
            (user_id,),
        ).fetchone()
        orders_row = connection.execute(
            """
            SELECT
                COUNT(*) AS total_order_items,
                SUM(COALESCE(quantity, 0)) AS units_sold,
                SUM(COALESCE(unit_price, 0) * COALESCE(quantity, 0)) AS gross_sales,
                SUM(COALESCE(seller_earnings_amount, 0)) AS seller_earnings,
                SUM(CASE WHEN COALESCE(payout_status, '') = 'ready' THEN COALESCE(seller_earnings_amount, 0) ELSE 0 END) AS ready_payout,
                SUM(CASE WHEN COALESCE(payout_status, '') = 'pending' THEN COALESCE(seller_earnings_amount, 0) ELSE 0 END) AS pending_payout
            FROM order_items
            WHERE business_user_id = ?
            """,
            (user_id,),
        ).fetchone()
        reviews_row = connection.execute(
            """
            SELECT
                COUNT(*) AS review_count,
                AVG(COALESCE(rating, 0)) AS average_rating
            FROM product_reviews
            WHERE business_user_id = ?
              AND COALESCE(status, 'published') = 'published'
            """,
            (user_id,),
        ).fetchone()
        returns_row = connection.execute(
            """
            SELECT
                COUNT(*) AS total_returns,
                SUM(CASE WHEN COALESCE(status, '') IN ('requested', 'approved', 'received') THEN 1 ELSE 0 END) AS open_returns
            FROM return_requests
            WHERE business_user_id = ?
            """,
            (user_id,),
        ).fetchone()
        promotions_row = connection.execute(
            """
            SELECT COUNT(*) AS total_promotions
            FROM promo_codes
            WHERE business_user_id = ?
              AND COALESCE(is_active, 0) = 1
            """,
            (user_id,),
        ).fetchone()

    return {
        "totalProducts": int(products_row["total_products"] or 0) if products_row else 0,
        "publicProducts": int(products_row["public_products"] or 0) if products_row else 0,
        "totalStock": int(products_row["total_stock"] or 0) if products_row else 0,
        "orderItems": int(orders_row["total_order_items"] or 0) if orders_row else 0,
        "unitsSold": int(orders_row["units_sold"] or 0) if orders_row else 0,
        "grossSales": round(float(orders_row["gross_sales"] or 0), 2) if orders_row else 0,
        "sellerEarnings": round(float(orders_row["seller_earnings"] or 0), 2) if orders_row else 0,
        "readyPayout": round(float(orders_row["ready_payout"] or 0), 2) if orders_row else 0,
        "pendingPayout": round(float(orders_row["pending_payout"] or 0), 2) if orders_row else 0,
        "reviewCount": int(reviews_row["review_count"] or 0) if reviews_row else 0,
        "averageRating": round(float(reviews_row["average_rating"] or 0), 2) if reviews_row else 0,
        "totalReturns": int(returns_row["total_returns"] or 0) if returns_row else 0,
        "openReturns": int(returns_row["open_returns"] or 0) if returns_row else 0,
        "activePromotions": int(promotions_row["total_promotions"] or 0) if promotions_row else 0,
    }


def create_order_notifications(
    connection: DatabaseConnection,
    *,
    order_row: sqlite3.Row | None,
    saved_items: list[sqlite3.Row],
) -> None:
    if not order_row:
        return

    order_id = int(order_row["id"])
    customer_id = int(order_row["user_id"] or 0)
    if customer_id > 0:
        create_notification(
            connection,
            user_id=customer_id,
            notification_type="order",
            title=f"Porosia #{order_id} pret konfirmim",
            body="Porosia juaj u regjistrua me sukses dhe tani pret konfirmimin e biznesit.",
            href="/porosite",
            metadata={"orderId": order_id},
        )

    notified_businesses: set[int] = set()
    for item in saved_items:
        business_user_id = int(item["business_user_id"] or 0)
        if business_user_id <= 0 or business_user_id in notified_businesses:
            continue
        notified_businesses.add(business_user_id)
        create_notification(
            connection,
            user_id=business_user_id,
            notification_type="order",
            title="Keni porosi te re per konfirmim",
            body=f"Porosia #{order_id} permban artikuj nga biznesi juaj dhe pret konfirmim.",
            href="/porosite-e-biznesit",
            metadata={"orderId": order_id},
        )


def fetch_order_notification_rows(order_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                o.id AS order_id,
                o.customer_full_name,
                o.customer_email,
                o.payment_method,
                o.address_line,
                o.city,
                o.country,
                o.zip_code,
                o.phone_number,
                o.created_at,
                oi.business_user_id,
                oi.business_name_snapshot,
                oi.product_title,
                oi.product_description,
                oi.product_category,
                oi.product_type,
                oi.product_size,
                oi.product_color,
                oi.unit_price,
                oi.quantity,
                u.full_name AS recipient_name,
                u.email AS recipient_email
            FROM order_items oi
            INNER JOIN orders o ON o.id = oi.order_id
            LEFT JOIN users u ON u.id = oi.business_user_id
            WHERE oi.order_id = ?
            ORDER BY oi.id ASC
            """,
            (order_id,),
        ).fetchall()


def fetch_order_item_by_id(order_item_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                oi.id,
                oi.order_id,
                oi.product_id,
                oi.business_user_id,
                oi.business_name_snapshot,
                oi.product_title,
                oi.product_image_path,
                oi.fulfillment_status,
                oi.confirmed_at,
                oi.confirmation_due_at,
                oi.tracking_code,
                oi.tracking_url,
                oi.shipped_at,
                oi.delivered_at,
                oi.cancelled_at,
                oi.commission_rate,
                oi.commission_amount,
                oi.seller_earnings_amount,
                oi.payout_status,
                oi.payout_due_at,
                o.user_id AS customer_user_id,
                o.customer_full_name,
                o.customer_email
            FROM order_items oi
            INNER JOIN orders o ON o.id = oi.order_id
            WHERE oi.id = ?
            LIMIT 1
            """,
            (order_item_id,),
        ).fetchone()


def fetch_return_request_by_id(return_request_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
                rr.*,
                oi.product_title,
                oi.product_image_path,
                oi.business_name_snapshot,
                oi.fulfillment_status,
                o.customer_full_name
            FROM return_requests rr
            INNER JOIN order_items oi ON oi.id = rr.order_item_id
            INNER JOIN orders o ON o.id = rr.order_id
            WHERE rr.id = ?
            LIMIT 1
            """,
            (return_request_id,),
        ).fetchone()


def format_notification_payment_method(payment_method: str) -> str:
    labels = {
        "cash": "Pages cash",
        "card-online": "Pages me kartel online",
    }
    return labels.get(str(payment_method or "").strip(), "Pagesa")


def build_business_notification_messages(
    order_rows: list[sqlite3.Row],
) -> tuple[list[dict[str, str]], list[str]]:
    grouped_rows: dict[str, list[sqlite3.Row]] = defaultdict(list)
    warnings: list[str] = []

    for row in order_rows:
        recipient_email = str(row["recipient_email"] or "").strip()
        if not recipient_email:
            business_name = str(row["business_name_snapshot"] or "").strip() or str(
                row["recipient_name"] or ""
            ).strip() or "Ky biznes"
            warning = f"Email-i per `{business_name}` mungon, prandaj njoftimi nuk u dergua."
            if warning not in warnings:
                warnings.append(warning)
            continue

        grouped_rows[recipient_email.lower()].append(row)

    messages: list[dict[str, str]] = []
    for recipient_email, recipient_rows in grouped_rows.items():
        first_row = recipient_rows[0]
        business_name = str(first_row["business_name_snapshot"] or "").strip() or str(
            first_row["recipient_name"] or ""
        ).strip() or "Biznes"
        customer_name = str(first_row["customer_full_name"] or "").strip() or "Klient"
        customer_email = str(first_row["customer_email"] or "").strip() or "-"
        address_line = str(first_row["address_line"] or "").strip() or "-"
        city = str(first_row["city"] or "").strip() or "-"
        country = str(first_row["country"] or "").strip() or "-"
        zip_code = str(first_row["zip_code"] or "").strip() or "-"
        phone_number = str(first_row["phone_number"] or "").strip() or "-"
        payment_method = format_notification_payment_method(str(first_row["payment_method"] or ""))
        created_at = str(first_row["created_at"] or "").strip() or "-"

        item_lines: list[str] = []
        total_amount = 0.0
        for item_row in recipient_rows:
            quantity = max(1, int(item_row["quantity"] or 1))
            unit_price = round(float(item_row["unit_price"] or 0), 2)
            total_amount += unit_price * quantity

            details = [
                str(item_row["product_category"] or "").strip(),
                str(item_row["product_type"] or "").strip(),
                str(item_row["product_size"] or "").strip(),
                str(item_row["product_color"] or "").strip(),
            ]
            detail_copy = ", ".join(detail for detail in details if detail)
            suffix = f" ({detail_copy})" if detail_copy else ""
            item_lines.append(
                f"- {str(item_row['product_title'] or '').strip()} x{quantity} — €{unit_price:.2f}{suffix}"
            )

        body = (
            f"Pershendetje {business_name},\n\n"
            f"U krijua nje porosi e re ne TREGO qe pret konfirmimin tuaj.\n\n"
            f"Porosia #{first_row['order_id']}\n"
            f"Data: {created_at}\n"
            f"Menyra e pageses: {payment_method}\n\n"
            f"Klienti:\n"
            f"- Emri: {customer_name}\n"
            f"- Email: {customer_email}\n"
            f"- Telefoni: {phone_number}\n\n"
            f"Adresa e dergeses:\n"
            f"- {address_line}\n"
            f"- {city}, {country}, {zip_code}\n\n"
            f"Produktet e porositura nga biznesi juaj:\n"
            f"{chr(10).join(item_lines)}\n\n"
            f"Totali per keto artikuj: €{total_amount:.2f}\n\n"
            f"TREGO"
        )

        messages.append(
            {
                "to_email": recipient_email,
                "subject": f"Porosi e re #{first_row['order_id']} ne TREGO",
                "body": body,
            }
        )

    return messages, warnings


def normalize_pdf_text(value: object) -> str:
    normalized_value = unicodedata.normalize("NFKD", str(value or ""))
    ascii_value = normalized_value.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", ascii_value).strip()


def escape_pdf_text(value: object) -> str:
    text_value = normalize_pdf_text(value)
    return (
        text_value.replace("\\", "\\\\")
        .replace("(", "\\(")
        .replace(")", "\\)")
    )


def build_simple_text_pdf(lines: list[str]) -> bytes:
    page_width = 595
    page_height = 842
    line_height = 15
    top_offset = 792
    left_offset = 48
    bottom_margin = 58
    max_lines_per_page = max(1, int((top_offset - bottom_margin) / line_height))
    normalized_lines = [normalize_pdf_text(line) for line in lines] or [""]
    page_chunks = [
        normalized_lines[index : index + max_lines_per_page]
        for index in range(0, len(normalized_lines), max_lines_per_page)
    ] or [[""]]

    objects: list[bytes] = []

    def add_object(payload: str | bytes) -> int:
        if isinstance(payload, str):
            payload_bytes = payload.encode("latin-1")
        else:
            payload_bytes = payload
        objects.append(payload_bytes)
        return len(objects)

    pages_object_number = add_object(b"<< /Type /Pages /Count 0 /Kids [] >>")
    font_object_number = add_object(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    page_object_numbers: list[int] = []

    for page_index, page_lines in enumerate(page_chunks, start=1):
        content_lines = [
            "BT",
            "/F1 12 Tf",
            f"1 0 0 1 {left_offset} {top_offset} Tm",
            f"{line_height} TL",
        ]
        for line in page_lines:
            content_lines.append(f"({escape_pdf_text(line)}) Tj")
            content_lines.append("T*")
        content_lines.append("ET")
        content_stream = "\n".join(content_lines).encode("latin-1")
        content_object_number = add_object(
            b"<< /Length "
            + str(len(content_stream)).encode("ascii")
            + b" >>\nstream\n"
            + content_stream
            + b"\nendstream"
        )
        page_object_number = add_object(
            (
                f"<< /Type /Page /Parent {pages_object_number} 0 R "
                f"/MediaBox [0 0 {page_width} {page_height}] "
                f"/Resources << /Font << /F1 {font_object_number} 0 R >> >> "
                f"/Contents {content_object_number} 0 R >>"
            ).encode("latin-1")
        )
        page_object_numbers.append(page_object_number)

    objects[pages_object_number - 1] = (
        f"<< /Type /Pages /Count {len(page_object_numbers)} /Kids "
        f"[{' '.join(f'{page_number} 0 R' for page_number in page_object_numbers)}] >>"
    ).encode("latin-1")
    catalog_object_number = add_object(
        f"<< /Type /Catalog /Pages {pages_object_number} 0 R >>".encode("latin-1")
    )

    payload = b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n"
    offsets = [0]
    for object_number, object_payload in enumerate(objects, start=1):
        offsets.append(len(payload))
        payload += (
            f"{object_number} 0 obj\n".encode("ascii")
            + object_payload
            + b"\nendobj\n"
        )

    xref_offset = len(payload)
    payload += f"xref\n0 {len(objects) + 1}\n".encode("ascii")
    payload += b"0000000000 65535 f \n"
    for offset in offsets[1:]:
        payload += f"{offset:010d} 00000 n \n".encode("ascii")

    payload += (
        f"trailer\n<< /Size {len(objects) + 1} /Root {catalog_object_number} 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF"
    ).encode("ascii")
    return payload


def format_invoice_price(amount: object) -> str:
    return f"EUR {round(float(amount or 0), 2):.2f}"


def build_order_invoice_pdf(order_payload: dict[str, object]) -> bytes:
    order_items = list(order_payload.get("items") or [])
    lines: list[str] = [
        "TREGO",
        "Fature / Invoice",
        f"Porosia #{int(order_payload.get('id') or 0)}",
        "",
        "Te dhenat e klientit",
        f"Emri: {order_payload.get('customerName') or '-'}",
        f"Email: {order_payload.get('customerEmail') or '-'}",
        f"Telefoni: {order_payload.get('phoneNumber') or '-'}",
        "",
        "Adresa e dergeses",
        f"Adresa: {order_payload.get('addressLine') or '-'}",
        f"Qyteti: {order_payload.get('city') or '-'}",
        f"Shteti: {order_payload.get('country') or '-'}",
        f"ZIP: {order_payload.get('zipCode') or '-'}",
        "",
        "Pagesa dhe dergesa",
        f"Pagesa: {format_notification_payment_method(str(order_payload.get('paymentMethod') or ''))}",
        f"Dergesa: {order_payload.get('deliveryLabel') or 'Dergese standard'}",
        f"Afati: {order_payload.get('estimatedDeliveryText') or '-'}",
        f"Data e porosise: {order_payload.get('createdAt') or '-'}",
        "",
        "Artikujt",
    ]

    if not order_items:
        lines.append("Nuk ka artikuj te ruajtur ne kete fature.")
    else:
        for item in order_items:
            quantity = max(1, int(item.get("quantity") or 1))
            title = str(item.get("title") or "Produkt").strip()
            variant_label = str(item.get("variantLabel") or "").strip()
            business_name = str(item.get("businessName") or "").strip()
            details = f"{title} x{quantity} - {format_invoice_price(item.get('totalPrice') or 0)}"
            lines.extend(textwrap.wrap(details, width=84) or [details])
            if variant_label:
                lines.append(f"  Varianti: {variant_label}")
            if business_name:
                lines.append(f"  Biznesi: {business_name}")

    lines.extend(
        [
            "",
            "Permbledhja",
            f"Nentotali: {format_invoice_price(order_payload.get('subtotalAmount') or 0)}",
            f"Zbritja: {format_invoice_price(order_payload.get('discountAmount') or 0)}",
            f"Transporti: {format_invoice_price(order_payload.get('shippingAmount') or 0)}",
            f"Totali: {format_invoice_price(order_payload.get('totalPrice') or 0)}",
        ]
    )
    promo_code = str(order_payload.get("promoCode") or "").strip()
    if promo_code:
        lines.append(f"Kuponi: {promo_code}")
    lines.extend(
        [
            "",
            "Faleminderit qe perdorni TREGO.",
        ]
    )
    return build_simple_text_pdf(lines)


def fetch_stats() -> dict[str, object]:
    with get_db_connection() as connection:
        total_users_row = connection.execute(
            "SELECT COUNT(*) AS total_users FROM users"
        ).fetchone()
        recent_rows = connection.execute(
            """
            SELECT id, full_name, email, created_at
            FROM users
            ORDER BY id DESC
            LIMIT 6
            """
        ).fetchall()

    recent_users = [
        {
            "id": row["id"],
            "fullName": row["full_name"],
            "email": row["email"],
            "createdAt": row["created_at"],
        }
        for row in recent_rows
    ]

    return {
        "totalUsers": total_users_row["total_users"],
        "recentUsers": recent_users,
    }


def count_admin_users(connection: sqlite3.Connection) -> int:
    row = connection.execute(
        "SELECT COUNT(*) AS admin_count FROM users WHERE role = 'admin'"
    ).fetchone()
    return int(row["admin_count"])


def can_upload_product_assets(user: sqlite3.Row) -> bool:
    return user["role"] in {"admin", "business"}


def can_create_products(user: sqlite3.Row) -> bool:
    return user["role"] in {"admin", "business"}


def is_business_profile_verified(profile: sqlite3.Row | dict[str, object] | None) -> bool:
    if not profile:
        return False
    raw_status = profile["verification_status"] if hasattr(profile, "__getitem__") and "verification_status" in profile.keys() else profile.get("verificationStatus")  # type: ignore[union-attr]
    return str(raw_status or "").strip().lower() == "verified"


def is_business_profile_edit_unlocked(profile: sqlite3.Row | dict[str, object] | None) -> bool:
    if not profile:
        return False
    raw_status = (
        profile["profile_edit_access_status"]
        if hasattr(profile, "__getitem__") and "profile_edit_access_status" in profile.keys()
        else profile.get("profileEditAccessStatus")  # type: ignore[union-attr]
    )
    return str(raw_status or "").strip().lower() == "approved"


def can_manage_product(user: sqlite3.Row, product: sqlite3.Row) -> bool:
    if user["role"] == "admin":
        return True

    if user["role"] == "business":
        return product["created_by_user_id"] == user["id"]

    return False


def fetch_verified_business_profile_for_user(user_id: int) -> sqlite3.Row | None:
    business_profile = fetch_business_profile_for_user(user_id)
    if not business_profile or not is_business_profile_verified(business_profile):
        return None
    return business_profile


def require_verified_business_catalog_profile(user: sqlite3.Row) -> tuple[list[str], sqlite3.Row | None]:
    if user["role"] != "business":
        return [], None

    business_profile = fetch_business_profile_for_user(int(user["id"]))
    if not business_profile:
        return ["Regjistroje fillimisht biznesin para se te menaxhosh produktet."], None

    if not is_business_profile_verified(business_profile):
        return ["Biznesi duhet te verifikohet nga admini para se te menaxhosh produktet."], None

    return [], business_profile


def create_session(user_id: int) -> str:
    session_token = secrets.token_urlsafe(32)
    expires_at = datetime_to_storage_text(utc_now() + timedelta(seconds=SESSION_MAX_AGE_SECONDS))

    with get_db_connection() as connection:
        connection.execute(
            """
            DELETE FROM user_sessions
            WHERE expires_at <= ?
            """,
            (datetime_to_storage_text(utc_now()),),
        )
        connection.execute(
            """
            INSERT INTO user_sessions (token, user_id, expires_at)
            VALUES (?, ?, ?)
            """,
            (session_token, user_id, expires_at),
        )

    return session_token


def delete_session(session_token: str | None) -> None:
    if session_token:
        with get_db_connection() as connection:
            connection.execute(
                """
                DELETE FROM user_sessions
                WHERE token = ?
                """,
                (session_token,),
            )


def delete_sessions_for_user(user_id: int) -> None:
    with get_db_connection() as connection:
        connection.execute(
            """
            DELETE FROM user_sessions
            WHERE user_id = ?
            """,
            (user_id,),
        )


def fetch_session_user_id(session_token: str) -> int | None:
    now_value = utc_now()

    with get_db_connection() as connection:
        row = connection.execute(
            """
            SELECT user_id, expires_at
            FROM user_sessions
            WHERE token = ?
            LIMIT 1
            """,
            (session_token,),
        ).fetchone()

        if not row:
            return None

        expires_at = parse_storage_datetime(row["expires_at"])
        if not expires_at or expires_at <= now_value:
            connection.execute(
                """
                DELETE FROM user_sessions
                WHERE token = ?
                """,
                (session_token,),
            )
            return None

        return int(row["user_id"])


def build_session_cookie(session_token: str) -> str:
    cookie = (
        f"{SESSION_COOKIE_NAME}={session_token}; "
        f"HttpOnly; Path=/; SameSite=Lax; Max-Age={SESSION_MAX_AGE_SECONDS}"
    )
    if IS_VERCEL:
        cookie += "; Secure"
    return cookie


def build_expired_session_cookie() -> str:
    cookie = (
        f"{SESSION_COOKIE_NAME}=; "
        "HttpOnly; Path=/; SameSite=Lax; Max-Age=0"
    )
    if IS_VERCEL:
        cookie += "; Secure"
    return cookie


def parse_session_token(cookie_header: str | None) -> str | None:
    if not cookie_header:
        return None

    cookie = SimpleCookie()

    try:
        cookie.load(cookie_header)
    except (CookieError, ValueError):
        return None

    session_morsel = cookie.get(SESSION_COOKIE_NAME)
    return session_morsel.value if session_morsel else None


class AppHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC_DIR), **kwargs)

    def do_GET(self) -> None:
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        query_params = parse_qs(parsed_url.query)

        if path.startswith("/uploads/"):
            self.handle_uploaded_file(path)
            return

        if path == "/api/chat/unread-reminders":
            self.handle_chat_unread_reminders()
            return
        if path == "/api/stats":
            self.handle_stats()
            return
        if path == "/api/me":
            self.handle_me()
            return
        if path == "/api/admin/users":
            self.handle_admin_users_list()
            return
        if path == "/api/admin/businesses":
            self.handle_admin_businesses_list()
            return
        if path == "/api/businesses/public":
            self.handle_public_businesses_list()
            return
        if path == "/api/search/autocomplete":
            self.handle_search_autocomplete(query_params)
            return
        if path == "/api/address":
            self.handle_default_address()
            return
        if path == "/api/business-profile":
            self.handle_business_profile()
            return
        if path == "/api/business/products":
            self.handle_business_products_list()
            return
        if path == "/api/business/products/import-template":
            self.handle_business_products_import_template()
            return
        if path == "/api/business/public":
            self.handle_public_business_detail(query_params)
            return
        if path == "/api/business/public-products":
            self.handle_public_business_products(query_params)
            return
        if path == "/api/chat/conversations":
            self.handle_chat_conversations()
            return
        if path == "/api/chat/messages":
            self.handle_chat_messages(query_params)
            return
        if path == "/api/chat/reply-suggestions":
            self.handle_chat_reply_suggestions(query_params)
            return
        if path == "/api/products/search":
            self.handle_products_search(query_params)
            return
        if path == "/api/product":
            self.handle_product_detail(query_params)
            return
        if path == "/api/product/reviews":
            self.handle_product_reviews_list(query_params)
            return
        if path == "/api/products":
            self.handle_products_list(query_params)
            return
        if path == "/api/admin/products":
            self.handle_admin_products_list()
            return
        if path == "/api/wishlist":
            self.handle_wishlist()
            return
        if path == "/api/cart":
            self.handle_cart()
            return
        if path == "/api/orders":
            self.handle_orders_list()
            return
        if path == "/api/orders/invoice":
            self.handle_order_invoice(query_params)
            return
        if path == "/api/business/orders":
            self.handle_business_orders_list()
            return
        if path == "/api/business/analytics":
            self.handle_business_analytics()
            return
        if path == "/api/business/promotions":
            self.handle_business_promotions_list()
            return
        if path == "/api/admin/orders":
            self.handle_admin_orders_list()
            return
        if path == "/api/admin/reports":
            self.handle_admin_reports_list()
            return
        if path == "/api/returns":
            self.handle_returns_list()
            return
        if path == "/api/notifications":
            self.handle_notifications_list()
            return
        if path == "/api/notifications/count":
            self.handle_notifications_count()
            return

        if path in {"/admin-products", "/bizneset-e-regjistruara"}:
            user = self.get_current_user()
            if not user:
                self.send_redirect("/login")
                return

            if user["role"] != "admin":
                self.send_redirect("/")
                return

        if path == "/biznesi-juaj":
            user = self.get_current_user()
            if not user:
                self.send_redirect("/login")
                return

            if user["role"] == "admin":
                self.send_redirect("/admin-products")
                return

            if user["role"] != "business":
                self.send_redirect("/")
                return

        if path == "/porosite-e-biznesit":
            user = self.get_current_user()
            if not user:
                self.send_redirect("/login")
                return

            if user["role"] == "admin":
                self.send_redirect("/admin-products")
                return

            if user["role"] != "business":
                self.send_redirect("/")
                return

        if path == "/mesazhet":
            user = self.get_current_user()
            if not user:
                self.send_redirect("/login")
                return

            if not can_use_chat(user):
                self.send_redirect("/admin-products" if user["role"] == "admin" else "/")
                return

        if path in {
            "/llogaria",
            "/te-dhenat-personale",
            "/adresat",
            "/adresa-e-porosise",
            "/menyra-e-pageses",
            "/porosite",
            "/njoftimet",
            "/ndrysho-fjalekalimin",
        }:
            is_password_reset_mode = (
                path == "/ndrysho-fjalekalimin"
                and str(query_params.get("mode", [""])[0]).strip().lower() == "reset"
            )
            if not is_password_reset_mode:
                user = self.get_current_user()
                if not user:
                    self.send_redirect("/login")
                    return

        if path in PAGE_ROUTES:
            self.path = PAGE_ROUTES[path]

        super().do_GET()

    def do_POST(self) -> None:
        path = urlparse(self.path).path

        if path == "/api/register":
            self.handle_register()
            return
        if path == "/api/login":
            self.handle_login()
            return
        if path == "/api/email/verify":
            self.handle_email_verification()
            return
        if path == "/api/email/resend":
            self.handle_email_verification_resend()
            return
        if path == "/api/forgot-password":
            self.handle_forgot_password()
            return
        if path == "/api/password-reset/confirm":
            self.handle_password_reset_confirm()
            return
        if path == "/api/logout":
            self.handle_logout()
            return
        if path == "/api/change-password":
            self.handle_change_password()
            return
        if path == "/api/profile":
            self.handle_profile_update()
            return
        if path == "/api/profile/photo":
            self.handle_profile_photo_upload()
            return
        if path == "/api/account/delete":
            self.handle_delete_own_account()
            return
        if path == "/api/address":
            self.handle_save_default_address()
            return
        if path == "/api/address/geocode":
            self.handle_reverse_geocode_address()
            return
        if path == "/api/business-profile":
            self.handle_save_business_profile()
            return
        if path == "/api/business-profile/shipping":
            self.handle_save_business_shipping_settings()
            return
        if path == "/api/business-profile/verification-request":
            self.handle_business_verification_request()
            return
        if path == "/api/business-profile/edit-request":
            self.handle_business_profile_edit_request()
            return
        if path == "/api/admin/users/role":
            self.handle_admin_user_role()
            return
        if path == "/api/admin/users/delete":
            self.handle_admin_delete_user()
            return
        if path == "/api/admin/users/set-password":
            self.handle_admin_set_user_password()
            return
        if path == "/api/admin/businesses/create":
            self.handle_admin_create_business_account()
            return
        if path == "/api/admin/businesses/update":
            self.handle_admin_update_business()
            return
        if path == "/api/admin/businesses/verification":
            self.handle_admin_update_business_verification()
            return
        if path == "/api/admin/businesses/edit-access":
            self.handle_admin_update_business_edit_access()
            return
        if path == "/api/admin/businesses/logo":
            self.handle_admin_update_business_logo()
            return
        if path == "/api/uploads":
            self.handle_image_uploads()
            return
        if path == "/api/products/visual-search":
            self.handle_products_visual_search()
            return
        if path == "/api/products/ai-draft":
            self.handle_product_ai_draft()
            return
        if path == "/api/products":
            self.handle_create_product()
            return
        if path == "/api/products/update":
            self.handle_update_product()
            return
        if path == "/api/products/delete":
            self.handle_delete_product()
            return
        if path == "/api/products/public-visibility":
            self.handle_product_public_visibility()
            return
        if path == "/api/products/public-stock":
            self.handle_product_public_stock()
            return
        if path == "/api/products/restock":
            self.handle_restock_product()
            return
        if path == "/api/products/reduce-stock":
            self.handle_reduce_stock_product()
            return
        if path == "/api/business/products/import":
            self.handle_business_products_import()
            return
        if path == "/api/chat/open":
            self.handle_chat_open()
            return
        if path == "/api/chat/typing":
            self.handle_chat_typing()
            return
        if path == "/api/chat/messages":
            self.handle_chat_send_message()
            return
        if path == "/api/chat/messages/update":
            self.handle_chat_update_message()
            return
        if path == "/api/chat/messages/delete":
            self.handle_chat_delete_message()
            return
        if path == "/api/payments/stripe/checkout":
            self.handle_create_stripe_checkout_session()
            return
        if path == "/api/payments/stripe/confirm":
            self.handle_confirm_stripe_checkout_session()
            return
        if path == "/api/wishlist/toggle":
            self.handle_toggle_wishlist()
            return
        if path == "/api/cart/add":
            self.handle_add_to_cart()
            return
        if path == "/api/cart/quantity":
            self.handle_update_cart_quantity()
            return
        if path == "/api/cart/remove":
            self.handle_remove_from_cart()
            return
        if path == "/api/checkout/reserve":
            self.handle_checkout_reserve_stock()
            return
        if path == "/api/business/follow-toggle":
            self.handle_business_follow_toggle()
            return
        if path == "/api/promotions/apply":
            self.handle_apply_promotion()
            return
        if path == "/api/business/promotions":
            self.handle_save_business_promotion()
            return
        if path == "/api/orders/create":
            self.handle_create_order()
            return
        if path == "/api/orders/status":
            self.handle_update_order_status()
            return
        if path == "/api/reports":
            self.handle_create_report()
            return
        if path == "/api/admin/reports/status":
            self.handle_admin_update_report_status()
            return
        if path == "/api/product/reviews":
            self.handle_create_product_review()
            return
        if path == "/api/returns/request":
            self.handle_create_return_request()
            return
        if path == "/api/returns/status":
            self.handle_update_return_request_status()
            return
        if path == "/api/notifications/read":
            self.handle_mark_notifications_read()
            return

        self.send_json(404, {"ok": False, "message": "Rruga nuk u gjet."})

    def handle_stats(self) -> None:
        self.send_json(
            200,
            {"ok": True, "data": fetch_stats()},
            headers=PUBLIC_STATS_CACHE_HEADERS,
        )

    def handle_me(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Nuk ka perdorues te kyqur."},
            )
            return

        self.send_json(200, {"ok": True, "user": serialize_session_user(user)})

    def handle_register(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors = validate_registration(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        full_name = payload["fullName"].strip()
        first_name, last_name = split_full_name(full_name)
        email = payload["email"].strip().lower()
        password_hash = hash_password(payload["password"])
        birth_date = payload["birthDate"].strip()
        gender = payload["gender"].strip().lower()
        verification_code = generate_email_verification_code()

        try:
            with get_db_connection() as connection:
                user_id = execute_insert_and_get_id(
                    connection,
                    """
                    INSERT INTO users (
                        full_name,
                        first_name,
                        last_name,
                        email,
                        password_hash,
                        birth_date,
                        gender,
                        role,
                        is_email_verified,
                        email_verified_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        full_name,
                        first_name,
                        last_name,
                        email,
                        password_hash,
                        birth_date,
                        gender,
                        "client",
                        0,
                        "",
                    ),
                )
                save_email_verification_code(connection, user_id, verification_code)
        except DB_INTEGRITY_ERRORS:
            self.send_json(
                409,
                {"ok": False, "message": "Ky email ekziston tashme ne databaze."},
            )
            return

        email_warnings = send_email_verification_code(
            {
                "full_name": full_name,
                "first_name": first_name,
                "email": email,
            },
            verification_code,
        )
        message = "Llogaria u krijua me sukses. Po kalon te verifikimi i email-it."
        if email_warnings:
            message = (
                "Llogaria u krijua, por kodi i verifikimit nuk u dergua me email. "
                "Kontrollo SMTP-ne ose terminalin lokal te serverit."
            )

        self.send_json(
            201,
            {
                "ok": True,
                "message": message,
                "warnings": email_warnings,
                "user": {
                    "id": user_id,
                    "fullName": full_name,
                    "email": email,
                    "role": "client",
                    "profileImagePath": "",
                },
                "redirectTo": build_email_verification_redirect(email),
            },
        )

    def handle_login(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors = validate_login(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        email = payload["email"].strip().lower()
        password = payload["password"]
        user = fetch_user_by_email(email)

        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Nuk ekziston nje llogari me kete email.",
                },
            )
            return

        if not verify_password(password, user["password_hash"]):
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Fjalekalimi nuk eshte i sakte.",
                },
            )
            return

        if not bool(user["is_email_verified"]):
            self.send_json(
                403,
                {
                    "ok": False,
                    "message": (
                        "Duhet ta verifikosh email-in para se te kyçesh. "
                        "Po kalon te faqja e verifikimit."
                    ),
                    "redirectTo": build_email_verification_redirect(email),
                },
            )
            return

        session_token = create_session(user["id"])
        self.send_json(
            200,
            {
                "ok": True,
                "message": "U kyqe me sukses.",
                "redirectTo": "/",
                "user": serialize_session_user(user),
            },
            headers={"Set-Cookie": build_session_cookie(session_token)},
        )

    def handle_email_verification(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, cleaned_payload = validate_email_verification(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            user = connection.execute(
                """
                SELECT
                """
                + USER_AUTH_SELECT_COLUMNS
                + """
                FROM users
                WHERE email = ?
                LIMIT 1
                """,
                (cleaned_payload["email"],),
            ).fetchone()

            if not user:
                self.send_json(
                    404,
                    {"ok": False, "message": "Llogaria me kete email nuk u gjet."},
                )
                return

            if bool(user["is_email_verified"]):
                self.send_json(
                    200,
                    {
                        "ok": True,
                        "message": "Email-i eshte verifikuar tashme. Mund te kyçesh.",
                        "redirectTo": "/login",
                    },
                )
                return

            verification_row = fetch_email_verification_row(connection, user["id"])
            if not verification_row:
                self.send_json(
                    404,
                    {
                        "ok": False,
                        "message": "Nuk u gjet kod aktiv. Kerko dergim te ri te kodit.",
                    },
                )
                return

            if is_email_verification_expired(verification_row):
                delete_email_verification_code(connection, user["id"])
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": (
                            "Kodi ka skaduar pas 30 minutash. "
                            "Kerko dergim te ri te kodit."
                        ),
                    },
                )
                return

            attempts = int(verification_row["attempts"] or 0)
            if attempts >= EMAIL_VERIFICATION_MAX_ATTEMPTS:
                self.send_json(
                    429,
                    {
                        "ok": False,
                        "message": (
                            "Ke kaluar numrin e tentativave. "
                            "Kerko nje kod te ri verifikimi."
                        ),
                    },
                )
                return

            if not verify_password(cleaned_payload["code"], verification_row["code_hash"]):
                connection.execute(
                    """
                    UPDATE email_verification_codes
                    SET attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP
                    WHERE user_id = ?
                    """,
                    (user["id"],),
                )
                next_attempts = attempts + 1
                remaining_attempts = max(
                    0,
                    EMAIL_VERIFICATION_MAX_ATTEMPTS - next_attempts,
                )
                message = "Kodi i verifikimit nuk eshte i sakte."
                if remaining_attempts > 0:
                    message += f" Te kane mbetur edhe {remaining_attempts} tentativa."
                else:
                    message += " Kerko nje kod te ri verifikimi."

                self.send_json(400, {"ok": False, "message": message})
                return

            verified_at = datetime_to_storage_text(utc_now())
            connection.execute(
                """
                UPDATE users
                SET
                    is_email_verified = 1,
                    email_verified_at = ?
                WHERE id = ?
                """,
                (verified_at, user["id"]),
            )
            delete_email_verification_code(connection, user["id"])

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Email-i u verifikua me sukses. Tani mund te kyçesh.",
                "redirectTo": "/login",
            },
        )

    def handle_email_verification_resend(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, email = validate_email_resend(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            user = connection.execute(
                """
                SELECT
                """
                + USER_AUTH_SELECT_COLUMNS
                + """
                FROM users
                WHERE email = ?
                LIMIT 1
                """,
                (email,),
            ).fetchone()

            if not user:
                self.send_json(
                    404,
                    {"ok": False, "message": "Llogaria me kete email nuk u gjet."},
                )
                return

            if bool(user["is_email_verified"]):
                self.send_json(
                    200,
                    {
                        "ok": True,
                        "message": "Email-i eshte verifikuar tashme. Mund te kyçesh.",
                        "redirectTo": "/login",
                    },
                )
                return

            verification_code = generate_email_verification_code()
            save_email_verification_code(connection, user["id"], verification_code)

        email_warnings = send_email_verification_code(user, verification_code)
        message = "Kodi i verifikimit u dergua me email."
        if email_warnings:
            message = (
                "Kodi u krijua, por email-i nuk u dergua. "
                "Kontrollo SMTP-ne ose terminalin lokal te serverit."
            )

        self.send_json(
            200,
            {
                "ok": True,
                "message": message,
                "warnings": email_warnings,
            },
        )

    def handle_products_list(self, query_params: dict[str, list[str]]) -> None:
        scope_errors, scoped_page_section, scoped_audience, scoped_category, scoped_category_group = parse_catalog_scope_query(
            query_params
        )
        include_facets = parse_include_facets_query(query_params)
        category = query_params.get("category", [""])[0].strip().lower() or None
        category_group = query_params.get("categoryGroup", [""])[0].strip().lower() or None
        pagination_errors, limit, offset = parse_products_pagination_query(query_params)
        filter_errors, product_type, size, color = parse_catalog_filters_query(query_params)
        category = category or scoped_category
        category_group = category_group or scoped_category_group

        if category and category not in PRODUCT_CATEGORIES:
            self.send_json(
                400,
                {"ok": False, "message": "Kategoria e kerkuar nuk eshte valide."},
            )
            return

        if category_group and category_group not in {"clothing", "cosmetics"}:
            self.send_json(
                400,
                {"ok": False, "message": "Grupi i kategorise nuk eshte valid."},
            )
            return

        if pagination_errors or filter_errors or scope_errors:
            self.send_json(400, {"ok": False, "errors": pagination_errors + filter_errors + scope_errors})
            return

        cache_key = build_runtime_public_cache_key(
            "products:list",
            {
                "category": category or "",
                "categoryGroup": category_group or "",
                "pageSection": scoped_page_section or "",
                "audience": scoped_audience or "",
                "productType": product_type or "",
                "size": size or "",
                "color": color or "",
                "limit": limit,
                "offset": offset,
                "includeFacets": bool(include_facets),
            },
        )
        cached_payload = read_runtime_public_cache(cache_key)
        if isinstance(cached_payload, dict):
            self.send_json(200, cached_payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)
            return

        product_rows, has_more = fetch_products_page(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
            limit=limit,
            offset=offset,
        )
        products = [
            serialize_product(row)
            for row in product_rows
        ]
        facets = None
        if include_facets:
            facets = build_product_catalog_facets(
                category,
                category_group=category_group,
                product_type=product_type,
                size=size,
                color=color,
            )
        payload = {
            "ok": True,
            "products": products,
            "facets": facets,
            "activeFilters": {
                "pageSection": scoped_page_section or derive_section_from_category(category) or category_group or "",
                "audience": scoped_audience or derive_audience_from_category(category) or "",
                "category": category or "",
                "categoryGroup": category_group or "",
                "productType": product_type or "",
                "size": size or "",
                "color": color or "",
            },
            "limit": limit,
            "offset": offset,
            "total": None,
            "hasMore": has_more,
        }
        write_runtime_public_cache(
            cache_key,
            payload,
            ttl_seconds=PUBLIC_PRODUCTS_ENDPOINT_CACHE_TTL_SECONDS,
        )
        self.send_json(200, payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)

    def handle_products_search(self, query_params: dict[str, list[str]]) -> None:
        raw_search_text = query_params.get("q", [""])[0].strip()
        include_facets = parse_include_facets_query(query_params)
        scope_errors, scoped_page_section, scoped_audience, scoped_category, scoped_category_group = parse_catalog_scope_query(
            query_params
        )
        explicit_category = query_params.get("category", [""])[0].strip().lower() or None
        explicit_category_group = query_params.get("categoryGroup", [""])[0].strip().lower() or None
        pagination_errors, limit, offset = parse_products_pagination_query(query_params)
        filter_errors, explicit_product_type, explicit_size, explicit_color = parse_catalog_filters_query(query_params)

        if pagination_errors or filter_errors or scope_errors:
            self.send_json(400, {"ok": False, "errors": pagination_errors + filter_errors + scope_errors})
            return

        if explicit_category and explicit_category not in PRODUCT_CATEGORIES:
            self.send_json(
                400,
                {"ok": False, "message": "Kategoria e kerkuar nuk eshte valide."},
            )
            return

        if explicit_category_group and explicit_category_group not in {"clothing", "cosmetics"}:
            self.send_json(
                400,
                {"ok": False, "message": "Grupi i kategorise nuk eshte valid."},
            )
            return

        interpreted_intent = interpret_search_query(raw_search_text) if raw_search_text else sanitize_search_intent({})
        category = explicit_category or scoped_category or interpreted_intent.get("category")
        category_group = explicit_category_group or scoped_category_group or interpreted_intent.get("categoryGroup")
        product_type = explicit_product_type or interpreted_intent.get("productType")
        size = explicit_size or interpreted_intent.get("size")
        color = explicit_color or interpreted_intent.get("color")
        business_name = str(interpreted_intent.get("businessName") or "").strip() or None
        search_text = str(interpreted_intent.get("searchText", "") or raw_search_text).strip()

        cache_key = build_runtime_public_cache_key(
            "products:search",
            {
                "q": raw_search_text,
                "category": category or "",
                "categoryGroup": category_group or "",
                "pageSection": scoped_page_section or "",
                "audience": scoped_audience or "",
                "productType": product_type or "",
                "size": size or "",
                "color": color or "",
                "businessName": business_name or "",
                "searchText": search_text,
                "limit": limit,
                "offset": offset,
                "includeFacets": bool(include_facets),
            },
        )

        if not raw_search_text and not any([category, category_group, product_type, size, color, business_name]):
            self.send_json(
                200,
                {
                    "ok": True,
                    "products": [],
                    "query": "",
                    "interpretedQuery": "",
                    "facets": {
                        "pageSections": [],
                        "categories": [],
                        "productTypes": [],
                        "sizes": [],
                        "colors": [],
                    },
                    "activeFilters": {
                        "pageSection": scoped_page_section or "",
                        "audience": scoped_audience or "",
                        "category": "",
                        "categoryGroup": scoped_category_group or "",
                        "productType": "",
                        "size": "",
                        "color": "",
                    },
                    "limit": limit,
                    "offset": offset,
                    "total": 0,
                    "hasMore": False,
                },
            )
            return

        cached_payload = read_runtime_public_cache(cache_key)
        if isinstance(cached_payload, dict):
            self.send_json(200, cached_payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)
            return

        product_rows, has_more = fetch_products_page(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
            business_name_search=business_name,
            search_text=search_text,
            limit=limit,
            offset=offset,
        )
        products = [
            serialize_product(row)
            for row in product_rows
        ]
        facets = None
        if include_facets:
            facets = build_product_catalog_facets(
                category,
                category_group=category_group,
                product_type=product_type,
                size=size,
                color=color,
                business_name_search=business_name,
                search_text=search_text,
            )
        payload = {
            "ok": True,
            "products": products,
            "query": raw_search_text,
            "interpretedQuery": search_text,
            "searchIntent": {
                "category": category,
                "categoryGroup": category_group,
                "productType": product_type,
                "size": size,
                "color": color,
                "businessName": business_name,
            },
            "facets": facets,
            "activeFilters": {
                "pageSection": scoped_page_section or derive_section_from_category(category) or category_group or "",
                "audience": scoped_audience or derive_audience_from_category(category) or "",
                "category": category or "",
                "categoryGroup": category_group or "",
                "productType": product_type or "",
                "size": size or "",
                "color": color or "",
            },
            "limit": limit,
            "offset": offset,
            "total": None,
            "hasMore": has_more,
        }
        write_runtime_public_cache(
            cache_key,
            payload,
            ttl_seconds=PUBLIC_PRODUCTS_ENDPOINT_CACHE_TTL_SECONDS,
        )
        self.send_json(200, payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)

    def handle_search_autocomplete(self, query_params: dict[str, list[str]]) -> None:
        raw_query = str(query_params.get("q", [""])[0] or "").strip()
        try:
            limit = int(str(query_params.get("limit", ["4"])[0] or "4").strip() or "4")
        except ValueError:
            limit = 4
        safe_limit = max(1, min(6, limit))

        if len(raw_query) < 2:
            self.send_json(
                200,
                {
                    "ok": True,
                    "query": raw_query,
                    "products": [],
                    "businesses": [],
                    "categories": [],
                },
                headers=PUBLIC_PRODUCTS_CACHE_HEADERS,
            )
            return

        cache_key = build_runtime_public_cache_key(
            "search:autocomplete",
            {
                "q": raw_query,
                "limit": safe_limit,
            },
        )
        cached_payload = read_runtime_public_cache(cache_key)
        if isinstance(cached_payload, dict):
            self.send_json(200, cached_payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)
            return

        interpreted_intent = interpret_search_query(raw_query)
        category = interpreted_intent.get("category")
        category_group = interpreted_intent.get("categoryGroup")
        product_type = interpreted_intent.get("productType")
        size = interpreted_intent.get("size")
        color = interpreted_intent.get("color")
        business_name = str(interpreted_intent.get("businessName") or "").strip() or None
        search_text = str(interpreted_intent.get("searchText", "") or raw_query).strip()

        product_rows, _has_more = fetch_products_page(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
            business_name_search=business_name,
            search_text=search_text,
            limit=safe_limit,
            offset=0,
        )
        businesses = [
            serialize_public_business_profile(row)
            for row in search_public_business_profiles(raw_query, limit=safe_limit)
        ]
        categories = build_catalog_autocomplete_matches(raw_query, limit=safe_limit)

        payload = {
            "ok": True,
            "query": raw_query,
            "products": [serialize_product(row) for row in product_rows],
            "businesses": businesses,
            "categories": categories,
        }
        write_runtime_public_cache(
            cache_key,
            payload,
            ttl_seconds=PUBLIC_PRODUCTS_ENDPOINT_CACHE_TTL_SECONDS,
        )
        self.send_json(200, payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)

    def handle_products_visual_search(self) -> None:
        if not PILLOW_AVAILABLE:
            self.send_json(
                503,
                {
                    "ok": False,
                    "message": (
                        "Kerkimi me foto nuk eshte aktiv ende ne server. "
                        "Instalo Pillow dhe provo perseri."
                    ),
                },
            )
            return

        try:
            message = self.read_multipart_message()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        image_parts = [
            part
            for part in message.iter_parts()
            if part.get_content_disposition() == "form-data"
            and part.get_param("name", header="content-disposition") == "image"
            and part.get_filename()
        ]

        if not image_parts:
            self.send_json(
                400,
                {"ok": False, "message": "Zgjidh ose fotografo nje imazh per kerkimin vizual."},
            )
            return

        image_part = image_parts[0]
        image_bytes = image_part.get_payload(decode=True) or b""
        if not image_bytes:
            self.send_json(400, {"ok": False, "message": "Imazhi i zgjedhur eshte bosh."})
            return

        if len(image_bytes) > MAX_UPLOAD_FILE_SIZE:
            self.send_json(
                400,
                {"ok": False, "message": "Imazhi nuk mund te jete me i madh se 8MB."},
            )
            return

        form_values = {}
        for part in message.iter_parts():
            if part.get_content_disposition() != "form-data":
                continue
            field_name = part.get_param("name", header="content-disposition")
            if not field_name or part.get_filename():
                continue
            form_values[field_name] = str(part.get_content() or "").strip()
        include_facets = str(form_values.get("includeFacets", "")).strip().lower() in {"1", "true", "yes", "on"}

        query_params = {
            key: [value]
            for key, value in {
                "pageSection": str(form_values.get("pageSection", "")).strip(),
                "audience": str(form_values.get("audience", "")).strip(),
                "productType": str(form_values.get("productType", "")).strip(),
                "size": str(form_values.get("size", "")).strip(),
                "color": str(form_values.get("color", "")).strip(),
            }.items()
            if value
        }
        scope_errors, scoped_page_section, scoped_audience, scoped_category, scoped_category_group = parse_catalog_scope_query(
            query_params
        )
        filter_errors, product_type, size, color = parse_catalog_filters_query(query_params)
        category = str(form_values.get("category", "")).strip().lower() or None
        category_group = str(form_values.get("categoryGroup", "")).strip().lower() or None
        category = category or scoped_category
        category_group = category_group or scoped_category_group
        raw_limit = str(form_values.get("limit", "")).strip()
        raw_offset = str(form_values.get("offset", "")).strip()

        if category and category not in PRODUCT_CATEGORIES:
            self.send_json(
                400,
                {"ok": False, "message": "Kategoria e kerkuar nuk eshte valide."},
            )
            return

        if category_group and category_group not in {"clothing", "cosmetics"}:
            self.send_json(
                400,
                {"ok": False, "message": "Grupi i kategorise nuk eshte valid."},
            )
            return

        if scope_errors or filter_errors:
            self.send_json(400, {"ok": False, "errors": scope_errors + filter_errors})
            return

        try:
            limit = int(raw_limit) if raw_limit else PRODUCTS_PAGE_DEFAULT_LIMIT
        except ValueError:
            limit = PRODUCTS_PAGE_DEFAULT_LIMIT

        try:
            offset = int(raw_offset) if raw_offset else 0
        except ValueError:
            offset = 0

        limit = max(1, min(PRODUCTS_PAGE_MAX_LIMIT, limit))
        offset = max(0, offset)

        query_fingerprint = compute_image_fingerprint(image_bytes)
        if not query_fingerprint:
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": (
                        "Imazhi nuk u lexua dot per kerkimin vizual. "
                        "Provo nje foto tjeter me produktin me te qarte."
                    ),
                },
            )
            return

        candidates = fetch_visual_search_candidates(
            category,
            category_group=category_group,
            product_type=product_type,
            size=size,
            color=color,
        )
        matched_products = score_products_by_visual_similarity(query_fingerprint, candidates)

        total_count = len(matched_products)
        visible_products = matched_products[offset : offset + limit]
        facets = None
        if include_facets:
            facets = build_product_catalog_facets(
                category,
                category_group=category_group,
                product_type=product_type,
                size=size,
                color=color,
            )

        self.send_json(
            200,
            {
                "ok": True,
                "mode": "visual",
                "products": [serialize_product(row) for row in visible_products],
                "facets": facets,
                "activeFilters": {
                    "pageSection": scoped_page_section or derive_section_from_category(category) or category_group or "",
                    "audience": scoped_audience or derive_audience_from_category(category) or "",
                    "category": category or "",
                    "categoryGroup": category_group or "",
                    "productType": product_type or "",
                    "size": size or "",
                    "color": color or "",
                },
                "limit": limit,
                "offset": offset,
                "total": total_count,
                "hasMore": offset + len(visible_products) < total_count,
                "message": (
                    "U gjeten produkte te ngjashme sipas fotos."
                    if visible_products
                    else "Nuk u gjet asnje produkt i ngjashem sipas fotos."
                ),
            },
            headers=PUBLIC_PRODUCTS_CACHE_HEADERS,
        )

    def handle_product_detail(self, query_params: dict[str, list[str]]) -> None:
        errors, product_id = parse_product_id_query(query_params)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        current_user = self.get_current_user()
        cache_key = build_runtime_public_cache_key(
            "product:detail",
            {"productId": product_id},
        )
        if not current_user:
            cached_payload = read_runtime_public_cache(cache_key)
            if isinstance(cached_payload, dict):
                self.send_json(200, cached_payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)
                return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        can_view_hidden = bool(
            current_user and can_manage_product(current_user, product)
        )
        if not bool(product["is_public"]) and not can_view_hidden:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        payload = {"ok": True, "product": serialize_product(product)}
        if bool(product["is_public"]):
            write_runtime_public_cache(
                cache_key,
                payload,
                ttl_seconds=PUBLIC_DETAIL_ENDPOINT_CACHE_TTL_SECONDS,
            )
        self.send_json(
            200,
            payload,
            headers=PUBLIC_PRODUCTS_CACHE_HEADERS if bool(product["is_public"]) else None,
        )

    def handle_product_reviews_list(self, query_params: dict[str, list[str]]) -> None:
        errors, product_id = parse_product_id_query(query_params)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        product = fetch_product_by_id(product_id)
        if not product or not bool(product["is_public"]):
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        current_user = self.get_current_user()
        cache_key = build_runtime_public_cache_key(
            "product:reviews",
            {"productId": product_id},
        )
        if not current_user:
            cached_payload = read_runtime_public_cache(cache_key)
            if isinstance(cached_payload, dict):
                self.send_json(200, cached_payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)
                return

        reviews = [serialize_product_review(row) for row in fetch_product_reviews(product_id)]
        can_submit_review = False
        if current_user:
            with get_db_connection() as connection:
                can_submit_review = bool(
                    find_reviewable_order_item(
                        connection=connection,
                        user_id=int(current_user["id"]),
                        product_id=product_id,
                    )
                )

        payload = {
            "ok": True,
            "reviews": reviews,
            "canSubmitReview": can_submit_review,
            "stats": {
                "averageRating": round(float(product["average_rating"] or 0), 2)
                if "average_rating" in product.keys()
                else 0,
                "reviewCount": max(0, int(product["review_count"] or 0))
                if "review_count" in product.keys()
                else len(reviews),
            },
        }
        if not current_user:
            write_runtime_public_cache(
                cache_key,
                payload,
                ttl_seconds=PUBLIC_DETAIL_ENDPOINT_CACHE_TTL_SECONDS,
            )
        self.send_json(
            200,
            payload,
            headers=PUBLIC_PRODUCTS_CACHE_HEADERS if not current_user else None,
        )

    def handle_admin_products_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i shohin keto produkte."},
            )
            return

        products = [
            serialize_product(row) for row in fetch_products(include_hidden=True)
        ]
        self.send_json(200, {"ok": True, "products": products})

    def handle_admin_users_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i shohin perdoruesit."},
            )
            return

        users = [serialize_user(row) for row in fetch_users_for_admin()]
        self.send_json(200, {"ok": True, "users": users})

    def handle_admin_businesses_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i shohe bizneset."},
            )
            return

        businesses = [
            serialize_admin_business_profile(row)
            for row in fetch_business_profiles_for_admin()
        ]
        self.send_json(200, {"ok": True, "businesses": businesses})

    def handle_default_address(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se t'i shohesh adresat."},
            )
            return

        address = fetch_default_address_for_user(user["id"])
        self.send_json(
            200,
            {
                "ok": True,
                "address": serialize_address(address) if address else None,
            },
        )

    def handle_public_businesses_list(self) -> None:
        cache_key = build_runtime_public_cache_key("businesses:list", {"scope": "public"})
        cached_payload = read_runtime_public_cache(cache_key)
        if isinstance(cached_payload, dict):
            self.send_json(200, cached_payload, headers=PUBLIC_BUSINESSES_CACHE_HEADERS)
            return

        businesses = [
            serialize_public_business_profile(row)
            for row in fetch_public_business_profiles()
        ]
        payload = {"ok": True, "businesses": businesses}
        write_runtime_public_cache(
            cache_key,
            payload,
            ttl_seconds=PUBLIC_BUSINESSES_ENDPOINT_CACHE_TTL_SECONDS,
        )
        self.send_json(200, payload, headers=PUBLIC_BUSINESSES_CACHE_HEADERS)

    def handle_public_business_detail(
        self,
        query_params: dict[str, list[str]],
    ) -> None:
        errors, business_id = parse_business_id_query(query_params)
        if errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        current_user = self.get_current_user()
        cache_key = build_runtime_public_cache_key(
            "business:detail",
            {"businessId": business_id},
        )
        if not current_user:
            cached_payload = read_runtime_public_cache(cache_key)
            if isinstance(cached_payload, dict):
                self.send_json(200, cached_payload, headers=PUBLIC_BUSINESSES_CACHE_HEADERS)
                return

        business_profile = fetch_public_business_profile_by_id(business_id)
        if not business_profile:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        is_followed = bool(
            current_user
            and is_business_followed_by_user(business_id, int(current_user["id"]))
        )
        payload = {
            "ok": True,
            "business": serialize_public_business_detail(
                business_profile,
                is_followed=is_followed,
            ),
        }
        if not current_user:
            write_runtime_public_cache(
                cache_key,
                payload,
                ttl_seconds=PUBLIC_BUSINESSES_ENDPOINT_CACHE_TTL_SECONDS,
            )
        self.send_json(
            200,
            payload,
            headers=PUBLIC_BUSINESSES_CACHE_HEADERS if not current_user else None,
        )

    def handle_public_business_products(
        self,
        query_params: dict[str, list[str]],
    ) -> None:
        errors, business_id = parse_business_id_query(query_params)
        pagination_errors, limit, offset = parse_products_pagination_query(query_params)
        if errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return
        if pagination_errors:
            self.send_json(400, {"ok": False, "errors": pagination_errors})
            return

        business_profile = fetch_public_business_profile_by_id(business_id)
        if not business_profile:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        cache_key = build_runtime_public_cache_key(
            "business:products",
            {
                "businessId": business_id,
                "limit": limit,
                "offset": offset,
            },
        )
        cached_payload = read_runtime_public_cache(cache_key)
        if isinstance(cached_payload, dict):
            self.send_json(200, cached_payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)
            return

        product_rows, has_more = fetch_public_products_page_for_business(
            business_id,
            limit=limit,
            offset=offset,
        )
        products = [
            serialize_product(row)
            for row in product_rows
        ]
        payload = {
            "ok": True,
            "products": products,
            "limit": limit,
            "offset": offset,
            "total": None,
            "hasMore": has_more,
        }
        write_runtime_public_cache(
            cache_key,
            payload,
            ttl_seconds=PUBLIC_PRODUCTS_ENDPOINT_CACHE_TTL_SECONDS,
        )
        self.send_json(200, payload, headers=PUBLIC_PRODUCTS_CACHE_HEADERS)

    def handle_business_profile(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se ta shohesh biznesin."},
            )
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset kane akses ne kete faqe."},
            )
            return

        business_profile = fetch_business_profile_for_user(user["id"])
        self.send_json(
            200,
            {
                "ok": True,
                "profile": (
                    serialize_business_profile(business_profile)
                    if business_profile
                    else None
                ),
            },
        )

    def handle_business_products_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se t'i shohesh artikujt."},
            )
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset kane akses ne kete faqe."},
            )
            return

        products = [
            serialize_product(row)
            for row in fetch_products(
                include_hidden=True,
                created_by_user_id=user["id"],
            )
        ]
        self.send_json(200, {"ok": True, "products": products})

    def handle_business_products_import_template(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh para se ta shkarkosh template-n."})
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset mund ta perdorin importin e artikujve."},
            )
            return

        payload = build_product_import_template_xlsx()
        self.send_bytes(
            200,
            payload,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": 'attachment; filename="trego-products-template.xlsx"',
                "Cache-Control": "no-store",
            },
        )

    def handle_business_products_import(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh para se te importosh artikuj."})
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset mund te importojne artikuj."},
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            message = self.read_multipart_message()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        file_parts = [
            part
            for part in message.iter_parts()
            if part.get_content_disposition() == "form-data"
            and part.get_param("name", header="content-disposition") == "file"
            and part.get_filename()
        ]

        if not file_parts:
            self.send_json(
                400,
                {"ok": False, "message": "Zgjidh nje skedar CSV per import."},
            )
            return

        import_part = file_parts[0]
        original_filename = str(import_part.get_filename() or "").strip()
        if not (
            original_filename.lower().endswith(".csv")
            or original_filename.lower().endswith(".xlsx")
        ):
            self.send_json(
                400,
                {"ok": False, "message": "Per momentin supportohen vetem formatet CSV dhe XLSX te Excel-it."},
            )
            return

        file_bytes = import_part.get_payload(decode=True) or b""
        if original_filename.lower().endswith(".xlsx"):
            errors, parsed_rows = parse_product_import_xlsx(file_bytes)
        else:
            errors, parsed_rows = parse_product_import_csv(file_bytes)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        created_products: list[dict[str, object]] = []
        with get_db_connection() as connection:
            for normalized_product in parsed_rows:
                product_id = insert_product_for_owner(
                    connection,
                    normalized_product=normalized_product,
                    owner_user_id=int(user["id"]),
                )
                product_row = connection.execute(
                    """
                    SELECT
                    """
                    + PRODUCT_SELECT_COLUMNS
                    + """
                    FROM products
                    """
                    + PRODUCT_SELECT_RELATION_JOINS
                    + """
                    WHERE products.id = ?
                    """,
                    (product_id,),
                ).fetchone()
                if product_row:
                    created_products.append(serialize_product(product_row))

        self.send_json(
            201,
            {
                "ok": True,
                "message": f"U importuan me sukses {len(created_products)} artikuj.",
                "products": created_products,
                "count": len(created_products),
            },
        )

    def handle_business_follow_toggle(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per ta ndjekur biznesin."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, business_id = parse_business_id(payload)
        if errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        business_profile = fetch_public_business_profile_by_id(business_id)
        if not business_profile:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        action = "followed"
        with get_db_connection() as connection:
            existing_row = connection.execute(
                """
                SELECT 1
                FROM business_followers
                WHERE business_id = ? AND user_id = ?
                LIMIT 1
                """,
                (business_id, user["id"]),
            ).fetchone()

            if existing_row:
                connection.execute(
                    """
                    DELETE FROM business_followers
                    WHERE business_id = ? AND user_id = ?
                    """,
                    (business_id, user["id"]),
                )
                action = "unfollowed"
            else:
                connection.execute(
                    """
                    INSERT INTO business_followers (business_id, user_id)
                    VALUES (?, ?)
                    """,
                    (business_id, user["id"]),
                )

        updated_business = fetch_public_business_profile_by_id(business_id)
        self.send_json(
            200,
            {
                "ok": True,
                "action": action,
                "message": (
                    "Biznesi u shtua te bizneset qe ndjek."
                    if action == "followed"
                    else "Biznesi u hoq nga lista qe ndjek."
                ),
                "business": (
                    serialize_public_business_detail(
                        updated_business,
                        is_followed=action == "followed",
                    )
                    if updated_business
                    else None
                ),
            },
        )

    def handle_chat_conversations(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per t'i hapur mesazhet."},
            )
            return

        if not can_use_chat(user):
            self.send_json(
                403,
                {"ok": False, "message": "Ky rol nuk ka inbox mesazhesh."},
            )
            return

        conversations = []
        for row in fetch_chat_conversations_for_user(int(user["id"])):
            serialized_conversation = serialize_chat_conversation(row, viewer_user_id=int(user["id"]))
            serialized_conversation["counterpartTyping"] = is_counterpart_typing(
                int(row["id"]),
                int(user["id"]),
            )
            conversations.append(serialized_conversation)
        unread_count = sum(max(0, int(item.get("unreadCount", 0) or 0)) for item in conversations)
        self.send_json(
            200,
            {
                "ok": True,
                "conversations": conversations,
                "total": len(conversations),
                "unreadCount": unread_count,
            },
        )

    def handle_chat_messages(
        self,
        query_params: dict[str, list[str]],
    ) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per ta hapur biseden."},
            )
            return

        if not can_use_chat(user):
            self.send_json(
                403,
                {"ok": False, "message": "Ky rol nuk ka qasje ne mesazhe."},
            )
            return

        errors, conversation_id = parse_conversation_id_query(query_params)
        if errors or conversation_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))
        if not conversation_row:
            self.send_json(404, {"ok": False, "message": "Biseda nuk u gjet."})
            return

        mark_chat_messages_as_read(conversation_id, int(user["id"]))
        updated_conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))
        message_rows = fetch_chat_messages_for_conversation(conversation_id)
        counterpart_typing = is_counterpart_typing(conversation_id, int(user["id"]))
        serialized_conversation = (
            serialize_chat_conversation(updated_conversation_row, viewer_user_id=int(user["id"]))
            if updated_conversation_row
            else None
        )
        if serialized_conversation is not None:
            serialized_conversation["counterpartTyping"] = counterpart_typing

        self.send_json(
            200,
            {
                "ok": True,
                "conversation": serialized_conversation,
                "messages": [
                    serialize_chat_message(row, viewer_user_id=int(user["id"]))
                    for row in message_rows
                ],
                "counterpartTyping": counterpart_typing,
            },
        )

    def handle_chat_unread_reminders(self) -> None:
        authorization_header = str(self.headers.get("Authorization", "")).strip()
        expected_authorization = f"Bearer {CRON_SECRET}" if CRON_SECRET else ""

        if CRON_SECRET and not secrets.compare_digest(authorization_header, expected_authorization):
            self.send_json(
                401,
                {"ok": False, "message": "Cron authorization failed."},
            )
            return

        order_confirmation_summary = {"expiredItems": 0, "refundedRequests": 0, "refreshedOrders": 0}
        with get_db_connection() as connection:
            order_confirmation_summary = process_expired_order_confirmations(connection)

        reminder_rows = fetch_pending_chat_unread_reminder_rows()
        if not reminder_rows:
            self.send_json(
                200,
                {
                    "ok": True,
                    "processed": 0,
                    "sent": 0,
                    "warnings": [],
                    "orderConfirmationSummary": order_confirmation_summary,
                },
            )
            return

        warnings: list[str] = []
        sent_count = 0
        public_app_origin = self.get_public_app_origin()

        for reminder_row in reminder_rows:
            reminder_message = build_chat_unread_reminder_message(
                reminder_row,
                public_app_origin=public_app_origin,
            )
            message_warnings = send_email_notifications([reminder_message])
            if message_warnings:
                reminder_id = int(reminder_row["id"])
                warnings.extend(
                    [f"Mesazhi #{reminder_id}: {warning}" for warning in message_warnings]
                )
                continue

            mark_chat_unread_reminder_sent(int(reminder_row["id"]))
            sent_count += 1

        self.send_json(
            200,
            {
                "ok": True,
                "processed": len(reminder_rows),
                "sent": sent_count,
                "warnings": warnings,
                "orderConfirmationSummary": order_confirmation_summary,
            },
        )

    def handle_chat_reply_suggestions(
        self,
        query_params: dict[str, list[str]],
    ) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per t'i marre sugjerimet e bisedes."},
            )
            return

        if not can_use_chat(user):
            self.send_json(
                403,
                {"ok": False, "message": "Ky rol nuk ka sugjerime te bisedes."},
            )
            return

        errors, conversation_id = parse_conversation_id_query(query_params)
        if errors or conversation_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))
        if not conversation_row:
            self.send_json(404, {"ok": False, "message": "Biseda nuk u gjet."})
            return

        message_rows = fetch_chat_messages_for_conversation(conversation_id)
        viewer_role = str(user["role"] or "").strip()
        suggestions = request_openai_chat_reply_suggestions(
            viewer_role=viewer_role,
            viewer_user_id=int(user["id"]),
            conversation=conversation_row,
            messages=message_rows,
        )
        if not suggestions:
            suggestions = heuristic_chat_reply_suggestions(
                viewer_role=viewer_role,
                viewer_user_id=int(user["id"]),
                conversation=conversation_row,
                messages=message_rows,
            )

        self.send_json(
            200,
            {
                "ok": True,
                "conversationId": conversation_id,
                "suggestions": suggestions[:3],
                "message": "Sugjerimet e bisedes u pergatiten.",
            },
        )

    def handle_chat_open(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per ta hapur biseden."},
            )
            return

        if not can_use_chat(user):
            self.send_json(
                403,
                {"ok": False, "message": "Ky rol nuk ka qasje ne chat."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        open_target = str(payload.get("target", "") or "").strip().lower()
        business_profile_id: int | None = None
        counterpart_user_id: int | None = None

        if open_target == "support":
            if str(user["role"] or "").strip() == "admin":
                self.send_json(
                    400,
                    {"ok": False, "message": "Admini eshte vete customer support."},
                )
                return

            support_user = fetch_support_admin_user(exclude_user_id=int(user["id"]))
            if not support_user:
                self.send_json(
                    404,
                    {"ok": False, "message": "Customer support nuk eshte i disponueshem per momentin."},
                )
                return

            counterpart_user_id = int(support_user["id"])
        else:
            errors, business_id = parse_business_id(payload)
            if errors or business_id is None:
                self.send_json(400, {"ok": False, "errors": errors})
                return

            business_profile = fetch_public_business_profile_by_id(business_id)
            if not business_profile:
                self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
                return

            if int(business_profile["user_id"]) == int(user["id"]):
                self.send_json(
                    400,
                    {"ok": False, "message": "Nuk mund ta hapesh biseden me profilin tend."},
                )
                return

            business_profile_id = int(business_profile["id"])
            counterpart_user_id = int(business_profile["user_id"])

        if counterpart_user_id is None or counterpart_user_id <= 0:
            self.send_json(400, {"ok": False, "message": "Pala e zgjedhur per bisede nuk eshte valide."})
            return

        if str(user["role"] or "").strip() == "business":
            own_business_profile = fetch_business_profile_for_user(int(user["id"]))
            if own_business_profile and not business_profile_id:
                business_profile_id = int(own_business_profile["id"])

        conversation_id = ensure_chat_conversation_between_users(
            int(user["id"]),
            counterpart_user_id,
            business_profile_id,
        )
        conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Biseda u hap me sukses.",
                "conversation": (
                    serialize_chat_conversation(conversation_row, viewer_user_id=int(user["id"]))
                    if conversation_row
                    else None
                ),
                "redirectTo": f"/mesazhet?conversationId={conversation_id}",
            },
        )

    def handle_chat_typing(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per typing state."},
            )
            return

        if not can_use_chat(user):
            self.send_json(
                403,
                {"ok": False, "message": "Ky rol nuk ka qasje ne chat."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        conversation_errors, conversation_id = parse_conversation_id(payload)
        if conversation_errors or conversation_id is None:
            self.send_json(400, {"ok": False, "errors": conversation_errors})
            return

        conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))
        if not conversation_row:
            self.send_json(404, {"ok": False, "message": "Biseda nuk u gjet."})
            return

        is_typing = parse_chat_typing_state(payload)
        set_chat_typing_state(conversation_id, int(user["id"]), is_typing=is_typing)
        self.send_json(200, {"ok": True, "isTyping": is_typing})

    def handle_chat_send_message(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per te derguar mesazh."},
            )
            return

        if not can_use_chat(user):
            self.send_json(
                403,
                {"ok": False, "message": "Vetem perdoruesit me qasje ne chat mund te dergojne mesazhe."},
            )
            return

        payload: dict[str, object] = {}
        attachment_payload: dict[str, object] | None = None
        is_multipart_request = "multipart/form-data" in str(self.headers.get("Content-Type", "")).lower()

        if is_multipart_request:
            try:
                message = self.read_multipart_message()
            except ValueError as error:
                self.send_json(400, {"ok": False, "message": str(error)})
                return

            for part in message.iter_parts():
                if part.get_content_disposition() != "form-data":
                    continue

                part_name = str(part.get_param("name", header="content-disposition") or "").strip()
                if not part_name:
                    continue

                if part_name == "attachment" and part.get_filename():
                    attachment_errors, next_attachment_payload = build_chat_attachment_payload_from_part(part)
                    if attachment_errors:
                        self.send_json(400, {"ok": False, "errors": attachment_errors})
                        return
                    attachment_payload = next_attachment_payload
                    continue

                payload[part_name] = str(part.get_payload(decode=True) or b"", "utf-8", errors="ignore")
        else:
            try:
                payload = self.read_json()
            except ValueError as error:
                self.send_json(400, {"ok": False, "message": str(error)})
                return

        conversation_errors, conversation_id = parse_conversation_id(payload)
        message_errors, message_body = parse_chat_message_body(payload)
        if attachment_payload and not message_body:
            message_errors = []
            message_body = ""
        if conversation_errors or message_errors or conversation_id is None:
            self.send_json(400, {"ok": False, "errors": conversation_errors + message_errors})
            return

        conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))
        if not conversation_row:
            self.send_json(404, {"ok": False, "message": "Biseda nuk u gjet."})
            return

        if int(conversation_row["client_user_id"]) == int(user["id"]):
            recipient_user_id = int(conversation_row["business_user_id"])
        else:
            recipient_user_id = int(conversation_row["client_user_id"])

        attachment_path = ""
        attachment_content_type = ""
        attachment_file_name = ""
        if attachment_payload:
            stored_name = f"{secrets.token_urlsafe(16)}{attachment_payload['extension']}"
            store_uploaded_asset(
                stored_name=stored_name,
                original_filename=str(attachment_payload["original_filename"]),
                content_type=str(attachment_payload["content_type"]),
                file_bytes=bytes(attachment_payload["file_bytes"]),
                created_by_user_id=int(user["id"]),
            )
            attachment_path = f"/uploads/{stored_name}"
            attachment_content_type = str(attachment_payload["content_type"])
            attachment_file_name = str(attachment_payload["original_filename"])

        message_id = insert_chat_message(
            conversation_id,
            int(user["id"]),
            recipient_user_id,
            message_body,
            attachment_path=attachment_path,
            attachment_content_type=attachment_content_type,
            attachment_file_name=attachment_file_name,
        )
        set_chat_typing_state(conversation_id, int(user["id"]), is_typing=False)
        message_row = fetch_chat_message_by_id(message_id)
        updated_conversation_row = fetch_chat_conversation_for_user(conversation_id, int(user["id"]))
        serialized_conversation = (
            serialize_chat_conversation(updated_conversation_row, viewer_user_id=int(user["id"]))
            if updated_conversation_row
            else None
        )
        if serialized_conversation is not None:
            serialized_conversation["counterpartTyping"] = False

        self.send_json(
            201,
            {
                "ok": True,
                "message": (
                    serialize_chat_message(message_row, viewer_user_id=int(user["id"]))
                    if message_row
                    else None
                ),
                "conversation": serialized_conversation,
            },
        )

    def handle_chat_update_message(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta ndryshuar mesazhin."})
            return

        if not can_use_chat(user):
            self.send_json(403, {"ok": False, "message": "Ky rol nuk ka qasje ne chat."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        message_errors, message_id = parse_chat_message_id(payload)
        body_errors, next_body = parse_chat_message_body(payload)
        if message_errors or body_errors or message_id is None:
            self.send_json(400, {"ok": False, "errors": message_errors + body_errors})
            return

        message_row = fetch_chat_message_by_id(message_id)
        if not message_row:
            self.send_json(404, {"ok": False, "message": "Mesazhi nuk u gjet."})
            return

        if int(message_row["sender_user_id"]) != int(user["id"]):
            self.send_json(403, {"ok": False, "message": "Mund te ndryshosh vetem mesazhet e tua."})
            return

        if str(message_row["deleted_at"] or "").strip():
            self.send_json(400, {"ok": False, "message": "Mesazhi i fshire nuk mund te ndryshohet."})
            return

        conversation_row = fetch_chat_conversation_for_user(int(message_row["conversation_id"]), int(user["id"]))
        if not conversation_row:
            self.send_json(404, {"ok": False, "message": "Biseda nuk u gjet."})
            return

        update_chat_message_content(message_id, next_body=next_body)
        updated_message_row = fetch_chat_message_by_id(message_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    serialize_chat_message(updated_message_row, viewer_user_id=int(user["id"]))
                    if updated_message_row
                    else None
                ),
            },
        )

    def handle_chat_delete_message(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta fshire mesazhin."})
            return

        if not can_use_chat(user):
            self.send_json(403, {"ok": False, "message": "Ky rol nuk ka qasje ne chat."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        message_errors, message_id = parse_chat_message_id(payload)
        if message_errors or message_id is None:
            self.send_json(400, {"ok": False, "errors": message_errors})
            return

        message_row = fetch_chat_message_by_id(message_id)
        if not message_row:
            self.send_json(404, {"ok": False, "message": "Mesazhi nuk u gjet."})
            return

        if int(message_row["sender_user_id"]) != int(user["id"]):
            self.send_json(403, {"ok": False, "message": "Mund te fshish vetem mesazhet e tua."})
            return

        if str(message_row["deleted_at"] or "").strip():
            self.send_json(200, {"ok": True, "message": "Mesazhi eshte i fshire tashme."})
            return

        conversation_row = fetch_chat_conversation_for_user(int(message_row["conversation_id"]), int(user["id"]))
        if not conversation_row:
            self.send_json(404, {"ok": False, "message": "Biseda nuk u gjet."})
            return

        delete_chat_message(message_id)
        updated_message_row = fetch_chat_message_by_id(message_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    serialize_chat_message(updated_message_row, viewer_user_id=int(user["id"]))
                    if updated_message_row
                    else None
                ),
            },
        )

    def handle_save_business_profile(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se ta regjistrosh biznesin."},
            )
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset mund ta ruajne kete profil."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, normalized = validate_business_profile_payload(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        try:
            with get_db_connection() as connection:
                existing_profile = connection.execute(
                    """
                    SELECT id, verification_status, profile_edit_access_status
                    FROM business_profiles
                    WHERE user_id = ?
                    """,
                    (user["id"],),
                ).fetchone()

                if existing_profile:
                    is_verified_profile = (
                        str(existing_profile["verification_status"] or "").strip().lower() == "verified"
                    )
                    is_edit_unlocked = (
                        str(existing_profile["profile_edit_access_status"] or "").strip().lower() == "approved"
                    )
                    if is_verified_profile and not is_edit_unlocked:
                        self.send_json(
                            403,
                            {
                                "ok": False,
                                "message": "Per biznes te verifikuar, editimi duhet te aprovohet fillimisht nga admini.",
                            },
                        )
                        return

                    connection.execute(
                        """
                        UPDATE business_profiles
                        SET
                            business_name = ?,
                            business_description = ?,
                            business_number = ?,
                            business_logo_path = ?,
                            phone_number = ?,
                            city = ?,
                            address_line = ?,
                            profile_edit_access_status = CASE
                                WHEN LOWER(TRIM(COALESCE(verification_status, ''))) = 'verified' THEN 'locked'
                                ELSE COALESCE(profile_edit_access_status, 'locked')
                            END,
                            profile_edit_requested_at = CASE
                                WHEN LOWER(TRIM(COALESCE(verification_status, ''))) = 'verified' THEN ''
                                ELSE COALESCE(profile_edit_requested_at, '')
                            END,
                            profile_edit_approved_at = CASE
                                WHEN LOWER(TRIM(COALESCE(verification_status, ''))) = 'verified' THEN ''
                                ELSE COALESCE(profile_edit_approved_at, '')
                            END,
                            profile_edit_notes = CASE
                                WHEN LOWER(TRIM(COALESCE(verification_status, ''))) = 'verified' THEN ''
                                ELSE COALESCE(profile_edit_notes, '')
                            END,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE user_id = ?
                        """,
                        (
                            normalized["business_name"],
                            normalized["business_description"],
                            normalized["business_number"],
                            normalized["business_logo_path"],
                            normalized["phone_number"],
                            normalized["city"],
                            normalized["address_line"],
                            user["id"],
                        ),
                    )
                else:
                    connection.execute(
                        """
                        INSERT INTO business_profiles (
                            user_id,
                            business_name,
                            business_description,
                            business_number,
                            business_logo_path,
                            shipping_settings,
                            phone_number,
                            city,
                            address_line
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            user["id"],
                            normalized["business_name"],
                            normalized["business_description"],
                            normalized["business_number"],
                            normalized["business_logo_path"],
                            serialize_business_shipping_settings_storage(DEFAULT_BUSINESS_SHIPPING_SETTINGS),
                            normalized["phone_number"],
                            normalized["city"],
                            normalized["address_line"],
                        ),
                    )

                saved_profile = connection.execute(
                    """
                    SELECT
                    """
                    + BUSINESS_PROFILE_SELECT_COLUMNS
                    + """
                    FROM business_profiles
                    WHERE user_id = ?
                    """,
                    (user["id"],),
                ).fetchone()
        except DB_INTEGRITY_ERRORS:
            self.send_json(
                409,
                {"ok": False, "message": "Ky numer biznesi ekziston tashme ne sistem."},
            )
            return

        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    "Biznesi u ruajt me sukses dhe editimi u mbyll."
                    if is_business_profile_verified(saved_profile)
                    else "Biznesi u ruajt me sukses."
                ),
                "profile": serialize_business_profile(saved_profile),
            },
        )

    def handle_save_business_shipping_settings(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se ta ruash transportin."},
            )
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset mund t'i ndryshojne rregullat e transportit."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, normalized_settings = validate_business_shipping_settings_payload(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            business_profile = connection.execute(
                """
                SELECT id, verification_status
                FROM business_profiles
                WHERE user_id = ?
                LIMIT 1
                """,
                (user["id"],),
            ).fetchone()

            if not business_profile:
                self.send_json(404, {"ok": False, "message": "Ruaje fillimisht profilin e biznesit."})
                return

            if str(business_profile["verification_status"] or "").strip().lower() != "verified":
                self.send_json(
                    403,
                    {
                        "ok": False,
                        "message": "Rregullat e transportit hapen sapo biznesi te verifikohet nga admini.",
                    },
                )
                return

            connection.execute(
                """
                UPDATE business_profiles
                SET
                    shipping_settings = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (
                    serialize_business_shipping_settings_storage(normalized_settings),
                    int(business_profile["id"]),
                ),
            )

        updated_profile = fetch_business_profile_for_user(int(user["id"]))
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Rregullat e transportit u ruajten me sukses.",
                "profile": serialize_business_profile(updated_profile) if updated_profile else None,
            },
        )

    def handle_admin_create_business_account(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund te krijoje biznese."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, cleaned_payload = validate_admin_business_account_payload(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        first_name, last_name = split_full_name(cleaned_payload["full_name"])

        try:
            with get_db_connection() as connection:
                existing_business_number = connection.execute(
                    """
                    SELECT id
                    FROM business_profiles
                    WHERE LOWER(TRIM(business_number)) = LOWER(?)
                    LIMIT 1
                    """,
                    (cleaned_payload["business_number"],),
                ).fetchone()

                if existing_business_number:
                    self.send_json(
                        409,
                        {
                            "ok": False,
                            "message": "Ky numer biznesi ekziston tashme ne sistem.",
                        },
                    )
                    return

                user_id = execute_insert_and_get_id(
                    connection,
                    """
                    INSERT INTO users (
                        full_name,
                        first_name,
                        last_name,
                        email,
                        password_hash,
                        birth_date,
                        gender,
                        role,
                        is_email_verified,
                        email_verified_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        cleaned_payload["full_name"],
                        first_name,
                        last_name,
                        cleaned_payload["email"],
                        hash_password(cleaned_payload["password"]),
                        "",
                        "",
                        "business",
                        1,
                        datetime_to_storage_text(utc_now()),
                    ),
                )

                connection.execute(
                    """
                    INSERT INTO business_profiles (
                        user_id,
                        business_name,
                        business_description,
                        business_number,
                        shipping_settings,
                        phone_number,
                        city,
                        address_line
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        user_id,
                        cleaned_payload["business_name"],
                        cleaned_payload["business_description"],
                        cleaned_payload["business_number"],
                        serialize_business_shipping_settings_storage(DEFAULT_BUSINESS_SHIPPING_SETTINGS),
                        cleaned_payload["phone_number"],
                        cleaned_payload["city"],
                        cleaned_payload["address_line"],
                    ),
                )

                created_user = connection.execute(
                    """
                    SELECT
                    """
                    + USER_SELECT_COLUMNS
                    + """
                    FROM users
                    WHERE id = ?
                    """,
                    (user_id,),
                ).fetchone()
                created_profile = connection.execute(
                    """
                    SELECT
                    """
                    + BUSINESS_PROFILE_SELECT_COLUMNS
                    + """
                    FROM business_profiles
                    WHERE user_id = ?
                    """,
                    (user_id,),
                ).fetchone()
        except DB_INTEGRITY_ERRORS:
            self.send_json(
                409,
                {"ok": False, "message": "Ky email ekziston tashme ne databaze."},
            )
            return

        self.send_json(
            201,
            {
                "ok": True,
                "message": "Llogaria e biznesit u krijua me sukses.",
                "user": serialize_user(created_user) if created_user else None,
                "profile": (
                    serialize_business_profile(created_profile)
                    if created_profile
                    else None
                ),
            },
        )

    def handle_admin_update_business_logo(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund te ndryshoje logot e bizneseve."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, business_id = parse_business_id(payload)
        business_logo_path = normalize_image_path(payload.get("businessLogoPath"))

        combined_errors = list(id_errors)
        if not business_logo_path:
            combined_errors.append("Zgjidh nje logo valide per biznesin.")

        if combined_errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        with get_db_connection() as connection:
            existing_business = connection.execute(
                """
                SELECT id
                FROM business_profiles
                WHERE id = ?
                LIMIT 1
                """,
                (business_id,),
            ).fetchone()

            if not existing_business:
                self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
                return

            connection.execute(
                """
                UPDATE business_profiles
                SET business_logo_path = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (business_logo_path, business_id),
            )

        updated_business = fetch_business_profile_for_admin_by_id(business_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Logoja e biznesit u ruajt me sukses.",
                "business": (
                    serialize_admin_business_profile(updated_business)
                    if updated_business
                    else None
                ),
            },
        )

    def handle_admin_update_business(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i editoje bizneset."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, business_id = parse_business_id(payload)
        business_errors, cleaned_payload = validate_business_profile_payload(payload)
        combined_errors = id_errors + business_errors
        if combined_errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        with get_db_connection() as connection:
            existing_business = connection.execute(
                """
                SELECT id, business_logo_path
                FROM business_profiles
                WHERE id = ?
                LIMIT 1
                """,
                (business_id,),
            ).fetchone()

            if not existing_business:
                self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
                return

            duplicate_business_number = connection.execute(
                """
                SELECT id
                FROM business_profiles
                WHERE LOWER(TRIM(business_number)) = LOWER(?)
                  AND id <> ?
                LIMIT 1
                """,
                (cleaned_payload["business_number"], business_id),
            ).fetchone()

            if duplicate_business_number:
                self.send_json(
                    409,
                    {
                        "ok": False,
                        "message": "Ky numer biznesi ekziston tashme ne sistem.",
                    },
                )
                return

            next_logo_path = (
                cleaned_payload["business_logo_path"]
                or normalize_image_path(existing_business["business_logo_path"])
            )

            connection.execute(
                """
                UPDATE business_profiles
                SET
                    business_name = ?,
                    business_description = ?,
                    business_number = ?,
                    business_logo_path = ?,
                    phone_number = ?,
                    city = ?,
                    address_line = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (
                    cleaned_payload["business_name"],
                    cleaned_payload["business_description"],
                    cleaned_payload["business_number"],
                    next_logo_path,
                    cleaned_payload["phone_number"],
                    cleaned_payload["city"],
                    cleaned_payload["address_line"],
                    business_id,
                ),
            )

        updated_business = fetch_business_profile_for_admin_by_id(business_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Biznesi u perditesua me sukses.",
                "business": (
                    serialize_admin_business_profile(updated_business)
                    if updated_business
                    else None
                ),
            },
        )

    def handle_image_uploads(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te ngarkuar foto."})
            return

        if not can_upload_product_assets(user):
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin ose biznes mund te ngarkoje foto."},
            )
            return

        try:
            message = self.read_multipart_message()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        image_parts = [
            part
            for part in message.iter_parts()
            if part.get_content_disposition() == "form-data"
            and part.get_param("name", header="content-disposition") == "images"
            and part.get_filename()
        ]

        if not image_parts:
            self.send_json(
                400,
                {"ok": False, "message": "Zgjidh te pakten nje foto per upload."},
            )
            return

        if len(image_parts) > MAX_UPLOAD_FILES:
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": f"Mund te ngarkosh deri ne {MAX_UPLOAD_FILES} foto njeheresh.",
                },
            )
            return

        saved_paths: list[str] = []
        saved_asset_names: list[str] = []
        errors: list[str] = []

        for part in image_parts:
            original_filename = str(part.get_filename() or "").strip()
            file_bytes = part.get_payload(decode=True) or b""

            if not file_bytes:
                continue

            if len(file_bytes) > MAX_UPLOAD_FILE_SIZE:
                errors.append(
                    f"Fotoja `{original_filename or 'pa emer'}` eshte me e madhe se 8MB."
                )
                continue

            extension = Path(original_filename).suffix.lower()
            if extension not in ALLOWED_IMAGE_EXTENSIONS:
                extension = IMAGE_CONTENT_TYPE_EXTENSIONS.get(part.get_content_type(), "")

            if extension not in ALLOWED_IMAGE_EXTENSIONS:
                errors.append(
                    f"Formati i fotos `{original_filename or 'pa emer'}` nuk mbeshtetet."
                )
                continue

            content_type = str(part.get_content_type() or "").strip().lower()
            file_bytes, extension, content_type = normalize_uploaded_image_payload(
                file_bytes,
                extension,
                content_type,
            )
            base_name = re.sub(r"[^a-zA-Z0-9]+", "-", Path(original_filename).stem)
            safe_name = base_name.strip("-").lower() or "product-photo"
            stored_name = f"{safe_name[:48]}-{secrets.token_hex(6)}{extension}"

            store_uploaded_asset(
                stored_name=stored_name,
                original_filename=original_filename,
                content_type=content_type,
                file_bytes=file_bytes,
                created_by_user_id=int(user["id"]),
            )
            saved_asset_names.append(stored_name)
            saved_paths.append(f"/uploads/{stored_name}")

        if errors or not saved_paths:
            for stored_name in saved_asset_names:
                delete_uploaded_asset_by_stored_name(stored_name)

            self.send_json(
                400,
                {
                    "ok": False,
                    "errors": errors or ["Fotot nuk u ngarkuan."],
                },
            )
            return

        self.send_json(
            201,
            {
                "ok": True,
                "message": "Fotot u ngarkuan me sukses.",
                "paths": saved_paths,
            },
        )

    def handle_profile_photo_upload(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per te ngarkuar foton e profilit."},
            )
            return

        try:
            message = self.read_multipart_message()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        image_parts = [
            part
            for part in message.iter_parts()
            if part.get_content_disposition() == "form-data"
            and part.get_param("name", header="content-disposition") == "image"
            and part.get_filename()
        ]

        if not image_parts:
            self.send_json(
                400,
                {"ok": False, "message": "Zgjidh nje foto per profilin."},
            )
            return

        image_part = image_parts[0]
        original_filename = str(image_part.get_filename() or "").strip()
        file_bytes = image_part.get_payload(decode=True) or b""

        if not file_bytes:
            self.send_json(
                400,
                {"ok": False, "message": "Fotoja e zgjedhur eshte bosh."},
            )
            return

        if len(file_bytes) > MAX_UPLOAD_FILE_SIZE:
            self.send_json(
                400,
                {"ok": False, "message": "Fotoja e profilit nuk mund te jete me e madhe se 8MB."},
            )
            return

        extension = Path(original_filename).suffix.lower()
        if extension not in ALLOWED_IMAGE_EXTENSIONS:
            extension = IMAGE_CONTENT_TYPE_EXTENSIONS.get(image_part.get_content_type(), "")

        if extension not in ALLOWED_IMAGE_EXTENSIONS:
            self.send_json(
                400,
                {"ok": False, "message": "Formati i fotos nuk mbeshtetet."},
            )
            return

        content_type = str(image_part.get_content_type() or "").strip().lower()
        file_bytes, extension, content_type = normalize_uploaded_image_payload(
            file_bytes,
            extension,
            content_type,
        )
        safe_name = re.sub(r"[^a-zA-Z0-9_-]+", "-", Path(original_filename).stem).strip("-") or "profile"
        stored_name = f"profile-{user['id']}-{safe_name[:36]}-{secrets.token_hex(6)}{extension}"

        store_uploaded_asset(
            stored_name=stored_name,
            original_filename=original_filename,
            content_type=content_type,
            file_bytes=file_bytes,
            created_by_user_id=int(user["id"]),
        )

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Fotoja e profilit u ngarkua me sukses.",
                "path": f"/uploads/{stored_name}",
            },
        )

    def handle_product_ai_draft(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te perdorur AI draft."})
            return

        if not can_create_products(user):
            self.send_json(
                403,
                {
                    "ok": False,
                    "message": "Vetem admin ose biznes mund ta perdorin AI draft per produkte.",
                },
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            message = self.read_multipart_message()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        form_values: dict[str, str] = {}
        uploaded_images: list[dict[str, object]] = []

        for part in message.iter_parts():
            if part.get_content_disposition() != "form-data":
                continue

            field_name = part.get_param("name", header="content-disposition")
            if not field_name:
                continue

            if part.get_filename():
                if field_name != "images":
                    continue

                file_bytes = part.get_payload(decode=True) or b""
                if not file_bytes:
                    continue

                if len(file_bytes) > MAX_UPLOAD_FILE_SIZE:
                    self.send_json(
                        400,
                        {"ok": False, "message": "Secila foto per AI draft duhet te jete nen 8MB."},
                    )
                    return

                content_type = str(part.get_content_type() or "").strip().lower() or "image/jpeg"
                if not content_type.startswith("image/"):
                    self.send_json(
                        400,
                        {"ok": False, "message": "Per AI draft lejohen vetem foto produktesh."},
                    )
                    return

                uploaded_images.append(
                    {
                        "file_bytes": file_bytes,
                        "content_type": content_type,
                    }
                )
                continue

            form_values[field_name] = str(part.get_content() or "").strip()

        title = str(form_values.get("title", "")).strip()
        description = str(form_values.get("description", "")).strip()
        page_section = str(form_values.get("pageSection", "")).strip().lower()
        audience = str(form_values.get("audience", "")).strip().lower()
        product_type = str(form_values.get("productType", "")).strip().lower()
        fallback_image_path = str(form_values.get("imagePath", "")).strip()
        image_gallery = normalize_image_gallery_value(
            form_values.get("imageGallery", ""),
            fallback_image_path=fallback_image_path,
        )

        image_urls = build_openai_input_image_urls_from_upload_payloads(uploaded_images)
        image_search_text = ""
        image_color_terms = ""

        if not image_urls and image_gallery:
            image_urls = build_openai_input_image_urls(
                image_gallery,
                fallback_image_path=fallback_image_path,
            )
            image_metadata = generate_product_image_search_metadata(
                title=title,
                description=description,
                category=build_category_from_section_selection(page_section, audience),
                product_type=product_type,
                color="",
                image_gallery=image_gallery,
                fallback_image_path=fallback_image_path,
            )
            image_search_text = str(image_metadata.get("searchText") or "").strip()
            image_color_terms = str(image_metadata.get("colorTerms") or "").strip()

        raw_draft = request_openai_product_draft_suggestion(
            title=title,
            description=description,
            page_section=page_section,
            audience=audience,
            product_type=product_type,
            image_urls=image_urls,
            image_search_text=image_search_text,
            image_color_terms=image_color_terms,
        )
        draft = sanitize_ai_product_draft_suggestion(
            raw_draft,
            current_title=title,
            current_description=description,
            current_page_section=page_section,
            current_audience=audience,
            current_product_type=product_type,
            image_search_text=image_search_text,
            image_color_terms=image_color_terms,
        )

        self.send_json(
            200,
            {
                "ok": True,
                "draft": draft,
                "message": (
                    "AI pergatiti nje draft te produktit."
                    if raw_draft
                    else "Drafti u pergatit me sugjerime automatike."
                ),
            },
        )

    def handle_create_product(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te shtuar artikuj."})
            return

        if not can_create_products(user):
            self.send_json(
                403,
                {
                    "ok": False,
                    "message": "Vetem admin ose biznes mund te shtoje artikuj.",
                },
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, normalized = validate_product_payload(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            product_id = insert_product_for_owner(
                connection,
                normalized_product=normalized,
                owner_user_id=int(user["id"]),
            )

            product_row = connection.execute(
                """
                SELECT
                """
                + PRODUCT_SELECT_COLUMNS
                + """
                FROM products
                """
                + PRODUCT_SELECT_RELATION_JOINS
                + """
                WHERE products.id = ?
                """,
                (product_id,),
            ).fetchone()

        self.send_json(
            201,
            {
                "ok": True,
                "message": "Artikulli u ruajt me sukses.",
                "product": serialize_product(product_row),
            },
        )

    def handle_update_product(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh per ta menaxhuar produktin."},
            )
            return

        if user["role"] not in {"admin", "business"}:
            self.send_json(
                403,
                {
                    "ok": False,
                    "message": "Vetem admin ose biznes mund ta editoje produktin.",
                },
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        product_id_errors, product_id = parse_product_id(payload)
        if product_id_errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": product_id_errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        if not can_manage_product(user, product):
            self.send_json(
                403,
                {"ok": False, "message": "Nuk ke akses ta menaxhosh kete produkt."},
            )
            return

        errors, normalized = validate_product_payload(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        image_fingerprint = compute_product_image_fingerprint(
            normalized["imageGallery"],
            fallback_image_path=normalized["imagePath"],
        )
        image_search_metadata = generate_product_image_search_metadata(
            title=normalized["title"],
            description=normalized["description"],
            category=normalized["category"],
            product_type=normalized["productType"],
            color=normalized["color"],
            image_gallery=normalized["imageGallery"],
            fallback_image_path=normalized["imagePath"],
            image_fingerprint=image_fingerprint,
            existing_metadata=(
                {
                    "searchText": product["ai_image_search_text"],
                    "colorTerms": product["ai_image_color_terms"],
                }
                if image_fingerprint and image_fingerprint == str(product["image_fingerprint"] or "").strip()
                else None
            ),
        )

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE products
                SET
                    article_number = ?,
                    title = ?,
                    description = ?,
                    price = ?,
                    image_path = ?,
                    image_gallery = ?,
                    image_fingerprint = ?,
                    ai_image_search_text = ?,
                    ai_image_color_terms = ?,
                    category = ?,
                    product_type = ?,
                    size = ?,
                    color = ?,
                    variant_inventory = ?,
                    package_amount_value = ?,
                    package_amount_unit = ?,
                    stock_quantity = ?
                WHERE id = ?
                """,
                (
                    normalized["articleNumber"],
                    normalized["title"],
                    normalized["description"],
                    normalized["price"],
                    normalized["imagePath"],
                    json.dumps(normalized["imageGallery"], ensure_ascii=False),
                    image_fingerprint,
                    image_search_metadata["searchText"],
                    image_search_metadata["colorTerms"],
                    normalized["category"],
                    normalized["productType"],
                    normalized["size"],
                    normalized["color"],
                    json.dumps(normalized["variantInventory"], ensure_ascii=False),
                    normalized["packageAmountValue"],
                    normalized["packageAmountUnit"],
                    normalized["stockQuantity"],
                    product_id,
                ),
            )

            product_row = connection.execute(
                """
                SELECT
                """
                + PRODUCT_SELECT_COLUMNS
                + """
                FROM products
                """
                + PRODUCT_SELECT_RELATION_JOINS
                + """
                WHERE products.id = ?
                """,
                (product_id,),
            ).fetchone()

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Artikulli u perditesua me sukses.",
                "product": serialize_product(product_row),
            },
        )

    def handle_wishlist(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Duhet te kyçesh ose te krijosh llogari per wishlist.",
                },
            )
            return

        items = [serialize_product(row) for row in fetch_wishlist_products(user["id"])]
        self.send_json(200, {"ok": True, "items": items})

    def handle_cart(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Duhet te kyçesh ose te krijosh llogari per shporten.",
                },
            )
            return

        items = [serialize_cart_item(row) for row in fetch_cart_items(user["id"])]
        self.send_json(200, {"ok": True, "items": items})

    def handle_create_stripe_checkout_session(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se te vazhdosh me pagesen online."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        cart_line_ids_errors, cart_line_ids = parse_cart_line_ids(payload)
        address_errors, cleaned_address = validate_address_payload(payload)
        promo_code_errors, promo_code = parse_promo_code(payload)
        delivery_method_errors, delivery_method = parse_delivery_method(payload)
        combined_errors = cart_line_ids_errors + address_errors + promo_code_errors + delivery_method_errors
        if combined_errors:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        try:
            with get_db_connection() as connection:
                checkout_items = load_checkout_items_for_order_or_raise(
                    connection,
                    user_id=int(user["id"]),
                    cart_line_ids=cart_line_ids,
                )
                pricing_summary = build_checkout_pricing_summary(
                    connection,
                    checkout_items=checkout_items,
                    promo_code=promo_code,
                    user_id=int(user["id"]),
                    delivery_method=delivery_method or "standard",
                    destination_city=str(cleaned_address.get("city") or "").strip(),
                )
                reserved_until = reserve_checkout_stock(
                    connection,
                    user_id=int(user["id"]),
                    cart_line_ids=cart_line_ids,
                    checkout_items=checkout_items,
                )
        except CheckoutProcessError as error:
            self.send_json(
                400,
                {
                    "ok": False,
                    "errors": error.errors,
                    "message": error.message or "Checkout-i nuk u validua.",
                },
            )
            return

        checkout_signature = build_checkout_signature(
            int(user["id"]),
            cleaned_address,
            checkout_items,
            promo_code,
            str(pricing_summary.get("deliveryMethod") or delivery_method or "standard"),
        )
        line_item_fields, fallback_total_amount = build_stripe_checkout_line_items(
            checkout_items,
            discount_amount=float(pricing_summary.get("discountAmount") or 0),
            shipping_amount=float(pricing_summary.get("shippingAmount") or 0),
            delivery_label=str(pricing_summary.get("deliveryLabel") or ""),
        )
        form_fields = list(line_item_fields)
        form_fields.extend(
            [
                ("mode", "payment"),
                ("payment_method_types[0]", "card"),
                (
                    "success_url",
                    self.build_public_url("/menyra-e-pageses?stripeStatus=success&session_id={CHECKOUT_SESSION_ID}"),
                ),
                (
                    "cancel_url",
                    self.build_public_url("/menyra-e-pageses?stripeStatus=cancelled"),
                ),
                ("client_reference_id", str(user["id"])),
                ("customer_email", str(user["email"] or "").strip()),
                ("locale", "auto"),
                ("metadata[trego_user_id]", str(user["id"])),
                ("metadata[trego_checkout_signature]", checkout_signature),
                ("metadata[trego_promo_code]", promo_code),
            ]
        )

        ok, stripe_payload = request_stripe_api(
            "/checkout/sessions",
            method="POST",
            form_fields=form_fields,
        )
        if not ok or not stripe_payload.get("id") or not stripe_payload.get("url"):
            self.send_json(
                502,
                {
                    "ok": False,
                    "message": resolve_stripe_error_message(
                        stripe_payload,
                        "Stripe test checkout nuk u hap.",
                    ),
                },
            )
            return

        with get_db_connection() as connection:
            persist_stripe_payment_session(
                connection,
                stripe_session_id=str(stripe_payload.get("id") or "").strip(),
                user_id=int(user["id"]),
                checkout_signature=checkout_signature,
                cart_line_ids=cart_line_ids,
                cleaned_address=cleaned_address,
                checkout_items=checkout_items,
                amount_total=int(stripe_payload.get("amount_total") or fallback_total_amount),
                discount_amount=int(round(float(pricing_summary.get("discountAmount") or 0) * 100)),
                shipping_amount=int(round(float(pricing_summary.get("shippingAmount") or 0) * 100)),
                promo_code=promo_code,
                delivery_method=str(pricing_summary.get("deliveryMethod") or delivery_method or "standard"),
                delivery_label=str(pricing_summary.get("deliveryLabel") or ""),
                estimated_delivery_text=str(pricing_summary.get("estimatedDeliveryText") or ""),
                currency=str(stripe_payload.get("currency") or STRIPE_CURRENCY).strip().lower(),
                payment_status=str(stripe_payload.get("payment_status") or "").strip().lower(),
                stripe_status=str(stripe_payload.get("status") or "").strip().lower(),
            )

        self.send_json(
            200,
            {
                "ok": True,
                "message": pricing_summary.get("message") or "Po hapet Stripe test checkout.",
                "sessionId": str(stripe_payload.get("id") or "").strip(),
                "checkoutUrl": str(stripe_payload.get("url") or "").strip(),
                "pricing": pricing_summary,
                "reservedUntil": reserved_until,
            },
        )

    def handle_confirm_stripe_checkout_session(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se te konfirmosh pagesen."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        session_errors, stripe_session_id = parse_stripe_session_id(payload)
        if session_errors or not stripe_session_id:
            self.send_json(400, {"ok": False, "errors": session_errors})
            return

        with get_db_connection() as connection:
            stored_session = fetch_stripe_payment_session(connection, stripe_session_id)

        if not stored_session:
            self.send_json(
                404,
                {"ok": False, "message": "Sesioni i pageses nuk u gjet ne sistem."},
            )
            return

        if int(stored_session["user_id"] or 0) != int(user["id"]):
            self.send_json(
                403,
                {"ok": False, "message": "Ky sesion i pageses nuk i perket llogarise tende."},
            )
            return

        ok, stripe_payload = request_stripe_api(
            f"/checkout/sessions/{quote(stripe_session_id)}",
            method="GET",
        )
        if not ok:
            self.send_json(
                502,
                {
                    "ok": False,
                    "message": resolve_stripe_error_message(
                        stripe_payload,
                        "Verifikimi i pageses me Stripe nuk funksionoi.",
                    ),
                },
            )
            return

        payment_status = str(stripe_payload.get("payment_status") or "").strip().lower()
        stripe_status = str(stripe_payload.get("status") or "").strip().lower()
        stripe_metadata = stripe_payload.get("metadata") if isinstance(stripe_payload.get("metadata"), dict) else {}
        metadata_user_id = str(stripe_metadata.get("trego_user_id") or "").strip()
        metadata_signature = str(stripe_metadata.get("trego_checkout_signature") or "").strip()
        expected_signature = str(stored_session["checkout_signature"] or "").strip()
        stored_amount_total = int(stored_session["amount_total"] or 0)
        stripe_amount_total = int(stripe_payload.get("amount_total") or 0)
        stripe_currency = str(stripe_payload.get("currency") or STRIPE_CURRENCY).strip().lower() or STRIPE_CURRENCY

        with get_db_connection() as connection:
            update_stripe_payment_session_state(
                connection,
                stripe_session_id,
                payment_status=payment_status,
                stripe_status=stripe_status,
            )

        if metadata_user_id != str(user["id"]) or metadata_signature != expected_signature:
            self.send_json(
                400,
                {"ok": False, "message": "Ky sesion Stripe nuk perputhet me checkout-in tend."},
            )
            return

        if stored_amount_total > 0 and stripe_amount_total > 0 and stored_amount_total != stripe_amount_total:
            self.send_json(
                400,
                {"ok": False, "message": "Shuma e pageses nuk perputhet me checkout-in e ruajtur."},
            )
            return

        if payment_status != "paid" or stripe_status != "complete":
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": "Pagesa nuk eshte konfirmuar ende nga Stripe.",
                    "paymentStatus": payment_status,
                    "stripeStatus": stripe_status,
                },
            )
            return

        existing_order_id = int(stored_session["order_id"] or 0)
        if existing_order_id > 0:
            with get_db_connection() as connection:
                saved_order = connection.execute(
                    """
                    SELECT
                    """
                    + ORDER_SELECT_COLUMNS
                    + """
                    FROM orders
                    WHERE id = ?
                    LIMIT 1
                    """,
                    (existing_order_id,),
                ).fetchone()
                saved_items = connection.execute(
                    """
                    SELECT
                    """
                    + ORDER_ITEM_SELECT_COLUMNS
                    + """
                    FROM order_items
                    WHERE order_id = ?
                    ORDER BY id DESC
                    """,
                    (existing_order_id,),
                ).fetchall()

            self.send_json(
                200,
                {
                    "ok": True,
                    "message": "Pagesa ishte konfirmuar tashme dhe porosia pret konfirmim nga biznesi.",
                    "order": (
                        serialize_order(
                            saved_order,
                            [serialize_order_item(item) for item in saved_items],
                        )
                        if saved_order
                        else None
                    ),
                    "redirectTo": "/porosite",
                },
            )
            return

        try:
            checkout_address = json.loads(str(stored_session["checkout_address"] or "{}"))
        except (TypeError, ValueError, json.JSONDecodeError):
            checkout_address = {}
        try:
            parsed_cart_line_ids = json.loads(str(stored_session["cart_line_ids"] or "[]"))
        except (TypeError, ValueError, json.JSONDecodeError):
            parsed_cart_line_ids = []
        cart_line_ids = [
            int(cart_line_id)
            for cart_line_id in parsed_cart_line_ids
            if str(cart_line_id).strip().isdigit() and int(cart_line_id) > 0
        ]
        checkout_items_snapshot = deserialize_checkout_items_snapshot(stored_session["checkout_items_snapshot"])

        if not checkout_items_snapshot:
            self.send_json(
                400,
                {"ok": False, "message": "Sesionit te pageses i mungon lista e produkteve."},
            )
            return

        try:
            with get_db_connection() as connection:
                order_id, saved_order, saved_items = create_order_from_checkout_items(
                    connection,
                    user=user,
                    payment_method="card-online",
                    cleaned_address={
                        "address_line": str(checkout_address.get("address_line") or "").strip(),
                        "city": str(checkout_address.get("city") or "").strip(),
                        "country": str(checkout_address.get("country") or "").strip(),
                        "zip_code": str(checkout_address.get("zip_code") or "").strip(),
                        "phone_number": str(checkout_address.get("phone_number") or "").strip(),
                    },
                    checkout_items=checkout_items_snapshot,
                    cart_line_ids=cart_line_ids,
                    pricing_summary={
                        "promoCode": str(stored_session["promo_code"] or "").strip().upper(),
                        "subtotal": round(
                            sum(
                                round(float(item.get("price") or 0), 2) * max(1, int(item.get("quantity") or 1))
                                for item in checkout_items_snapshot
                            ),
                            2,
                        ),
                        "discountAmount": round(float(int(stored_session["discount_amount"] or 0)) / 100, 2),
                        "shippingAmount": round(float(int(stored_session["shipping_amount"] or 0)) / 100, 2),
                        "total": round(float(stripe_amount_total or 0) / 100, 2),
                        "deliveryMethod": str(stored_session["delivery_method"] or "standard").strip().lower(),
                        "deliveryLabel": str(stored_session["delivery_label"] or "").strip(),
                        "estimatedDeliveryText": str(stored_session["estimated_delivery_text"] or "").strip(),
                    },
                )
                update_stripe_payment_session_state(
                    connection,
                    stripe_session_id,
                    payment_status=payment_status,
                    stripe_status=stripe_status,
                    order_id=order_id,
                )
                create_order_notifications(
                    connection,
                    order_row=saved_order,
                    saved_items=saved_items,
                )
        except CheckoutProcessError as error:
            self.send_json(
                409,
                {
                    "ok": False,
                    "errors": error.errors,
                    "message": error.message or "Porosia nuk u krijua pas pageses.",
                },
            )
            return

        notification_messages, notification_warnings = build_business_notification_messages(
            fetch_order_notification_rows(order_id)
        )
        notification_warnings.extend(send_email_notifications(notification_messages))

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Pagesa u konfirmua me sukses dhe porosia u dergua per konfirmim.",
                "order": (
                    serialize_order(
                        saved_order,
                        [serialize_order_item(item) for item in saved_items],
                    )
                    if saved_order
                    else None
                ),
                "notificationWarnings": notification_warnings,
                "paymentStatus": payment_status,
                "stripeStatus": stripe_status,
                "currency": stripe_currency,
                "redirectTo": "/porosite",
            },
        )

    def handle_orders_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se t'i shohesh porosite."},
            )
            return

        orders = fetch_orders_for_user(user["id"])
        order_ids = [int(order["id"]) for order in orders]
        payload = build_orders_payload(orders, fetch_order_items_for_orders(order_ids))
        self.send_json(200, {"ok": True, "orders": payload})

    def handle_order_invoice(self, query_params: dict[str, list[str]]) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta shkarkuar faturen."})
            return

        errors, order_id = parse_order_id_query(query_params)
        if errors or order_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            order_row = fetch_order_row_by_id(connection, order_id)
            if not order_row:
                self.send_json(404, {"ok": False, "message": "Porosia nuk u gjet."})
                return

            if not user_can_access_order_invoice(connection, user=user, order_row=order_row):
                self.send_json(403, {"ok": False, "message": "Nuk ke akses ne kete fature."})
                return

            order_items = fetch_order_items_for_order_id(connection, order_id)

        order_payload = serialize_order(
            order_row,
            [serialize_order_item(item) for item in order_items],
        )
        invoice_pdf = build_order_invoice_pdf(order_payload)
        self.send_bytes(
            200,
            invoice_pdf,
            content_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="trego-invoice-{order_id}.pdf"',
                "Cache-Control": "no-store",
            },
        )

    def handle_business_orders_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se t'i shohesh porosite e biznesit."},
            )
            return

        if user["role"] != "business":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem bizneset kane akses ne porosite e tyre."},
            )
            return

        orders = fetch_business_orders_for_user(user["id"])
        self.send_json(200, {"ok": True, "orders": orders})

    def handle_admin_orders_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if user["role"] != "admin":
            self.send_json(403, {"ok": False, "message": "Vetem admini mund t'i shohë te gjitha porosite."})
            return

        self.send_json(200, {"ok": True, "orders": fetch_all_orders_for_admin()})

    def handle_notifications_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per t'i pare njoftimet."})
            return

        notifications = [serialize_notification(row) for row in fetch_notifications_for_user(int(user["id"]))]
        unread_count = sum(1 for notification in notifications if not notification["isRead"])
        self.send_json(
            200,
            {"ok": True, "notifications": notifications, "unreadCount": unread_count},
        )

    def handle_notifications_count(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per t'i pare njoftimet."})
            return

        unread_count = fetch_unread_notifications_count(int(user["id"]))
        self.send_json(200, {"ok": True, "unreadCount": unread_count})

    def handle_mark_notifications_read(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per t'i perditesuar njoftimet."})
            return

        with get_db_connection() as connection:
            mark_notifications_as_read(connection, user_id=int(user["id"]))

        self.send_json(200, {"ok": True, "message": "Njoftimet u shenuan si te lexuara."})

    def handle_business_analytics(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si biznes."})
            return

        if user["role"] != "business":
            self.send_json(403, {"ok": False, "message": "Vetem bizneset kane analytics."})
            return

        self.send_json(200, {"ok": True, "analytics": fetch_business_analytics(int(user["id"]))})

    def handle_business_promotions_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per t'i pare promocionet."})
            return

        if user["role"] not in {"business", "admin"}:
            self.send_json(403, {"ok": False, "message": "Nuk ke akses ne promocione."})
            return

        promotions = [serialize_promo_code(row) for row in fetch_business_promotions(user)]
        self.send_json(200, {"ok": True, "promotions": promotions})

    def handle_admin_reports_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if user["role"] != "admin":
            self.send_json(403, {"ok": False, "message": "Vetem admin mund t'i shohë raportimet."})
            return

        reports = [serialize_report(row) for row in fetch_reports_for_admin()]
        self.send_json(200, {"ok": True, "reports": reports})

    def handle_checkout_reserve_stock(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh para checkout-it."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        cart_line_ids_errors, cart_line_ids = parse_cart_line_ids(payload)
        if cart_line_ids_errors:
            self.send_json(400, {"ok": False, "errors": cart_line_ids_errors})
            return

        try:
            with get_db_connection() as connection:
                checkout_items = load_checkout_items_for_order_or_raise(
                    connection,
                    user_id=int(user["id"]),
                    cart_line_ids=cart_line_ids,
                )
                reserved_until = reserve_checkout_stock(
                    connection,
                    user_id=int(user["id"]),
                    cart_line_ids=cart_line_ids,
                    checkout_items=checkout_items,
                )
        except CheckoutProcessError as error:
            self.send_json(
                409,
                {
                    "ok": False,
                    "errors": error.errors,
                    "message": error.message or "Stoku nuk u rezervua.",
                },
            )
            return

        self.send_json(
            200,
            {
                "ok": True,
                "message": f"Stoku u rezervua per {STOCK_RESERVATION_HOLD_MINUTES} minuta.",
                "reservedUntil": reserved_until,
            },
        )

    def handle_apply_promotion(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh para checkout-it."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        promo_code_errors, promo_code = parse_promo_code(payload)
        cart_line_ids_errors, cart_line_ids = parse_cart_line_ids(payload)
        delivery_method_errors, delivery_method = parse_delivery_method(payload)
        combined_errors = promo_code_errors + cart_line_ids_errors + delivery_method_errors
        if combined_errors:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        try:
            with get_db_connection() as connection:
                checkout_items = load_checkout_items_for_order_or_raise(
                    connection,
                    user_id=int(user["id"]),
                    cart_line_ids=cart_line_ids,
                )
                pricing = build_checkout_pricing_summary(
                    connection,
                    checkout_items=checkout_items,
                    promo_code=promo_code,
                    user_id=int(user["id"]),
                    delivery_method=delivery_method or "standard",
                    destination_city=str(payload.get("city", "") or "").strip(),
                )
        except CheckoutProcessError as error:
            self.send_json(
                400,
                {
                    "ok": False,
                    "errors": error.errors,
                    "message": error.message or "Kuponi nuk u aplikua.",
                },
            )
            return

        self.send_json(
            200,
            {
                "ok": True,
                "message": pricing.get("message") or "Kuponi u aplikua.",
                "pricing": pricing,
            },
        )

    def handle_save_business_promotion(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te ruajtur promocionin."})
            return

        if user["role"] not in {"business", "admin"}:
            self.send_json(403, {"ok": False, "message": "Vetem biznesi ose admini mund te ruaje promocione."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        delete_requested = str(payload.get("action", "")).strip().lower() == "delete" or bool(payload.get("deletePromotion"))
        if delete_requested:
            try:
                promotion_id = int(str(payload.get("promotionId", "")).strip() or 0)
            except ValueError:
                promotion_id = 0
            promo_code = str(payload.get("code", "")).strip().upper()

            if promotion_id <= 0 and not promo_code:
                self.send_json(400, {"ok": False, "message": "Promocioni per fshirje nuk eshte valid."})
                return

            with get_db_connection() as connection:
                promo_row = None
                if promotion_id > 0:
                    promo_row = connection.execute(
                        """
                        SELECT *
                        FROM promo_codes
                        WHERE id = ?
                        LIMIT 1
                        """,
                        (promotion_id,),
                    ).fetchone()
                if not promo_row and promo_code:
                    promo_row = fetch_promo_code_by_code(connection, promo_code)

                if not promo_row:
                    self.send_json(404, {"ok": False, "message": "Promocioni nuk u gjet."})
                    return

                if user["role"] == "business" and int(promo_row["business_user_id"] or 0) != int(user["id"]):
                    self.send_json(403, {"ok": False, "message": "Nuk ke leje te fshish kete promocion."})
                    return

                connection.execute(
                    """
                    DELETE FROM promo_codes
                    WHERE id = ?
                    """,
                    (int(promo_row["id"]),),
                )

            promotions = [serialize_promo_code(row) for row in fetch_business_promotions(user)]
            self.send_json(200, {"ok": True, "message": "Promocioni u fshi me sukses.", "promotions": promotions})
            return

        promo_code_errors, promo_code = parse_promo_code(payload, field_name="code")
        discount_type_errors, discount_type = parse_promo_code_type(payload)
        title = re.sub(r"\s+", " ", str(payload.get("title", "")).strip())[:120]
        description = re.sub(r"\s+", " ", str(payload.get("description", "")).strip())[:220]
        page_section = str(payload.get("pageSection", "")).strip().lower()
        category = str(payload.get("category", "")).strip().lower()
        starts_at = str(payload.get("startsAt", "")).strip()
        ends_at = str(payload.get("endsAt", "")).strip()
        is_active = 1 if str(payload.get("isActive", "1")).strip().lower() not in {"0", "false", "jo", "no"} else 0
        try:
            discount_value = round(float(str(payload.get("discountValue", "")).strip() or 0), 2)
            minimum_subtotal = round(float(str(payload.get("minimumSubtotal", "")).strip() or 0), 2)
            usage_limit = max(0, int(str(payload.get("usageLimit", "")).strip() or 0))
            per_user_limit = max(0, int(str(payload.get("perUserLimit", "")).strip() or PROMO_CODE_DEFAULT_PER_USER_LIMIT))
        except ValueError:
            self.send_json(400, {"ok": False, "message": "Vlerat e promocionit nuk jane valide."})
            return

        combined_errors = promo_code_errors + discount_type_errors
        if combined_errors:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        if discount_value <= 0:
            self.send_json(400, {"ok": False, "message": "Zbritja duhet te jete me e madhe se 0."})
            return

        if discount_type == "percent" and discount_value > 95:
            self.send_json(400, {"ok": False, "message": "Zbritja ne perqindje nuk mund te jete mbi 95%."})
            return

        if user["role"] == "business":
            normalized_business_user_id = int(user["id"])
        else:
            try:
                normalized_business_user_id = int(str(payload.get("businessUserId", "")).strip() or 0) or None
            except ValueError:
                self.send_json(400, {"ok": False, "message": "Biznesi i kuponit nuk eshte valid."})
                return

        with get_db_connection() as connection:
            existing_row = fetch_promo_code_by_code(connection, promo_code)
            if existing_row:
                if user["role"] == "business" and int(existing_row["business_user_id"] or 0) != int(user["id"]):
                    self.send_json(403, {"ok": False, "message": "Ky kupon i takon nje biznesi tjeter."})
                    return
                connection.execute(
                    """
                    UPDATE promo_codes
                    SET
                        title = ?,
                        description = ?,
                        discount_type = ?,
                        discount_value = ?,
                        minimum_subtotal = ?,
                        usage_limit = ?,
                        per_user_limit = ?,
                        is_active = ?,
                        page_section = ?,
                        category = ?,
                        starts_at = ?,
                        ends_at = ?,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (
                        title,
                        description,
                        discount_type,
                        discount_value,
                        minimum_subtotal,
                        usage_limit,
                        per_user_limit,
                        is_active,
                        page_section,
                        category,
                        starts_at,
                        ends_at,
                        int(existing_row["id"]),
                    ),
                )
            else:
                connection.execute(
                    """
                    INSERT INTO promo_codes (
                        code,
                        title,
                        description,
                        discount_type,
                        discount_value,
                        minimum_subtotal,
                        usage_limit,
                        per_user_limit,
                        is_active,
                        page_section,
                        category,
                        business_user_id,
                        created_by_user_id,
                        starts_at,
                        ends_at,
                        created_at,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """,
                    (
                        promo_code,
                        title,
                        description,
                        discount_type,
                        discount_value,
                        minimum_subtotal,
                        usage_limit,
                        per_user_limit,
                        is_active,
                        page_section,
                        category,
                        normalized_business_user_id,
                        int(user["id"]),
                        starts_at,
                        ends_at,
                    ),
                )

        promotions = [serialize_promo_code(row) for row in fetch_business_promotions(user)]
        self.send_json(200, {"ok": True, "message": "Promocioni u ruajt me sukses.", "promotions": promotions})

    def handle_create_report(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te raportuar."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        target_type_errors, target_type = parse_report_target_type(payload)
        reason = re.sub(r"\s+", " ", str(payload.get("reason", "")).strip())[:180]
        details = re.sub(r"\s+", " ", str(payload.get("details", "")).strip())[:900]
        try:
            target_id = int(str(payload.get("targetId", "")).strip() or 0)
        except ValueError:
            self.send_json(400, {"ok": False, "message": "Objekti i raportimit nuk eshte valid."})
            return
        target_label = re.sub(r"\s+", " ", str(payload.get("targetLabel", "")).strip())[:180]
        try:
            reported_user_id = int(str(payload.get("reportedUserId", "")).strip() or 0) or None
            business_user_id = int(str(payload.get("businessUserId", "")).strip() or 0) or None
        except ValueError:
            self.send_json(400, {"ok": False, "message": "Perdoruesi i raportuar nuk eshte valid."})
            return
        if target_type_errors:
            self.send_json(400, {"ok": False, "errors": target_type_errors})
            return

        if target_id <= 0:
            self.send_json(400, {"ok": False, "message": "Objekti i raportimit nuk eshte valid."})
            return

        if not reason:
            self.send_json(400, {"ok": False, "message": "Shkruaj arsyen e raportimit."})
            return

        with get_db_connection() as connection:
            existing_report = connection.execute(
                """
                SELECT id
                FROM reports
                WHERE reporter_user_id = ?
                  AND target_type = ?
                  AND target_id = ?
                  AND status IN ('open', 'reviewing')
                LIMIT 1
                """,
                (int(user["id"]), target_type, target_id),
            ).fetchone()
            if existing_report:
                self.send_json(409, {"ok": False, "message": "Per kete objekt ekziston tashme nje raportim aktiv."})
                return

            report_id = execute_insert_and_get_id(
                connection,
                """
                INSERT INTO reports (
                    reporter_user_id,
                    reported_user_id,
                    business_user_id,
                    target_type,
                    target_id,
                    target_label,
                    reason,
                    details,
                    status,
                    admin_notes,
                    created_at,
                    updated_at,
                    resolved_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, '')
                """,
                (
                    int(user["id"]),
                    reported_user_id,
                    business_user_id,
                    target_type,
                    target_id,
                    target_label,
                    reason,
                    details,
                ),
            )

            admin_rows = connection.execute(
                """
                SELECT id
                FROM users
                WHERE role = 'admin'
                """
            ).fetchall()
            for admin_row in admin_rows:
                create_notification(
                    connection,
                    user_id=int(admin_row["id"]),
                    notification_type="report",
                    title="Raportim i ri",
                    body=f"U raportua nje {target_type}: {target_label or reason}.",
                    href="/admin-products",
                    metadata={"reportId": report_id, "targetType": target_type, "targetId": target_id},
                )

        self.send_json(201, {"ok": True, "message": "Raportimi u dergua me sukses."})

    def handle_admin_update_report_status(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if user["role"] != "admin":
            self.send_json(403, {"ok": False, "message": "Vetem admin mund te menaxhoje raportimet."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        report_id_errors, report_id = parse_report_id(payload)
        report_status_errors, report_status = parse_report_status(payload)
        admin_notes = re.sub(r"\s+", " ", str(payload.get("adminNotes", "")).strip())[:500]
        combined_errors = report_id_errors + report_status_errors
        if combined_errors or report_id is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        with get_db_connection() as connection:
            report_row = connection.execute(
                """
                SELECT *
                FROM reports
                WHERE id = ?
                LIMIT 1
                """,
                (report_id,),
            ).fetchone()
            if not report_row:
                self.send_json(404, {"ok": False, "message": "Raportimi nuk u gjet."})
                return

            connection.execute(
                """
                UPDATE reports
                SET
                    status = ?,
                    admin_notes = ?,
                    updated_at = CURRENT_TIMESTAMP,
                    resolved_at = CASE
                        WHEN ? IN ('resolved', 'dismissed') THEN CURRENT_TIMESTAMP
                        ELSE COALESCE(resolved_at, '')
                    END,
                    resolved_by_user_id = ?
                WHERE id = ?
                """,
                (
                    report_status,
                    admin_notes,
                    report_status,
                    int(user["id"]),
                    report_id,
                ),
            )

            if int(report_row["reporter_user_id"] or 0) > 0:
                create_notification(
                    connection,
                    user_id=int(report_row["reporter_user_id"]),
                    notification_type="report",
                    title="Raportimi juaj u perditesua",
                    body=f"Raportimi per `{report_row['target_label']}` tani eshte `{report_status}`.",
                    href="/njoftimet",
                    metadata={"reportId": report_id},
                )

        self.send_json(200, {"ok": True, "message": "Raportimi u perditesua."})

    def handle_create_product_review(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te lene review."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        product_errors, product_id = parse_product_id(payload)
        rating_errors, rating = parse_review_rating(payload)
        review_title = re.sub(r"\s+", " ", str(payload.get("title", "")).strip())[:120]
        review_body = re.sub(r"\s+", " ", str(payload.get("body", "")).strip())[:900]
        combined_errors = product_errors + rating_errors
        if product_id is None or rating is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        if not review_title and not review_body:
            self.send_json(400, {"ok": False, "message": "Shkruaj pak tekst per pershtypjen tende."})
            return

        product = fetch_product_by_id(product_id)
        if not product or not bool(product["is_public"]):
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        with get_db_connection() as connection:
            reviewable_item = find_reviewable_order_item(
                connection=connection,
                user_id=int(user["id"]),
                product_id=product_id,
            )
            if not reviewable_item:
                self.send_json(
                    400,
                    {"ok": False, "message": "Mund te vleresosh vetem nje produkt qe e ke pranuar ne porosi."},
                )
                return

            execute_insert_and_get_id(
                connection,
                """
                INSERT INTO product_reviews (
                    product_id,
                    order_id,
                    order_item_id,
                    user_id,
                    business_user_id,
                    rating,
                    review_title,
                    review_body,
                    status,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """,
                (
                    product_id,
                    int(reviewable_item["order_id"]),
                    int(reviewable_item["id"]),
                    int(user["id"]),
                    int(reviewable_item["business_user_id"] or 0) or None,
                    rating,
                    review_title,
                    review_body,
                ),
            )

            business_user_id = int(reviewable_item["business_user_id"] or 0)
            if business_user_id > 0:
                create_notification(
                    connection,
                    user_id=business_user_id,
                    notification_type="review",
                    title="Keni review te ri",
                    body=f"Produkti `{product['title']}` mori {rating} yje nga nje bleres.",
                    href=f"/produkti?id={product_id}",
                    metadata={"productId": product_id},
                )

        self.send_json(201, {"ok": True, "message": "Review u ruajt me sukses."})

    def handle_create_return_request(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te hapur kerkese per kthim."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        item_errors, order_item_id = parse_order_item_id(payload)
        reason = re.sub(r"\s+", " ", str(payload.get("reason", "")).strip())[:160]
        details = re.sub(r"\s+", " ", str(payload.get("details", "")).strip())[:900]
        if item_errors or order_item_id is None:
            self.send_json(400, {"ok": False, "errors": item_errors})
            return

        if not reason:
            self.send_json(400, {"ok": False, "message": "Shkruaj arsyen e kthimit."})
            return

        order_item_row = fetch_order_item_by_id(order_item_id)
        if not order_item_row:
            self.send_json(404, {"ok": False, "message": "Artikulli i porosise nuk u gjet."})
            return

        if int(order_item_row["customer_user_id"] or 0) != int(user["id"]):
            self.send_json(403, {"ok": False, "message": "Mund te kerkosh kthim vetem per porosite e tua."})
            return

        if str(order_item_row["fulfillment_status"] or "").strip().lower() not in {"delivered", "returned"}:
            self.send_json(400, {"ok": False, "message": "Kthimi mund te kerkohet pasi produkti te jete dorezuar."})
            return

        with get_db_connection() as connection:
            existing_request = connection.execute(
                """
                SELECT id
                FROM return_requests
                WHERE user_id = ?
                  AND order_item_id = ?
                  AND status IN ('requested', 'approved', 'received')
                LIMIT 1
                """,
                (user["id"], order_item_id),
            ).fetchone()
            if existing_request:
                self.send_json(409, {"ok": False, "message": "Per kete artikull ekziston tashme nje kerkese aktive per kthim."})
                return

            return_request_id = execute_insert_and_get_id(
                connection,
                """
                INSERT INTO return_requests (
                    order_id,
                    order_item_id,
                    user_id,
                    business_user_id,
                    reason,
                    details,
                    status,
                    created_at,
                    updated_at,
                    resolved_at,
                    resolution_notes
                )
                VALUES (?, ?, ?, ?, ?, ?, 'requested', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, '', '')
                """,
                (
                    int(order_item_row["order_id"]),
                    order_item_id,
                    int(user["id"]),
                    int(order_item_row["business_user_id"] or 0) or None,
                    reason,
                    details,
                ),
            )

            business_user_id = int(order_item_row["business_user_id"] or 0)
            if business_user_id > 0:
                create_notification(
                    connection,
                    user_id=business_user_id,
                    notification_type="return",
                    title="Kerkese e re per kthim",
                    body=f"Klienti kerkon kthim per `{order_item_row['product_title']}`.",
                    href="/porosite-e-biznesit",
                    metadata={"returnRequestId": return_request_id, "orderItemId": order_item_id},
                )
            create_notification(
                connection,
                user_id=int(user["id"]),
                notification_type="return",
                title="Kerkesa per kthim u dergua",
                body=f"Kerkesa juaj per `{order_item_row['product_title']}` u regjistrua.",
                href="/refund-returne",
                metadata={"returnRequestId": return_request_id, "orderItemId": order_item_id},
            )

        self.send_json(201, {"ok": True, "message": "Kerkesa per kthim u dergua me sukses."})

    def handle_returns_list(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per t'i pare kerkesat e kthimit."})
            return

        requests_payload = [serialize_return_request(row) for row in fetch_return_requests_for_user(user)]
        self.send_json(200, {"ok": True, "requests": requests_payload})

    def handle_update_return_request_status(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te perditesuar kerkesen."})
            return

        if user["role"] not in {"business", "admin"}:
            self.send_json(403, {"ok": False, "message": "Nuk ke akses per te perditesuar kerkesat e kthimit."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, return_request_id = parse_return_request_id(payload)
        status_errors, next_status = parse_return_status(payload)
        resolution_notes = re.sub(r"\s+", " ", str(payload.get("resolutionNotes", "")).strip())[:500]
        combined_errors = id_errors + status_errors
        if combined_errors or return_request_id is None or next_status is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        return_request_row = fetch_return_request_by_id(return_request_id)
        if not return_request_row:
            self.send_json(404, {"ok": False, "message": "Kerkesa per kthim nuk u gjet."})
            return

        if user["role"] == "business" and int(return_request_row["business_user_id"] or 0) != int(user["id"]):
            self.send_json(403, {"ok": False, "message": "Nuk ke akses mbi kete kerkese."})
            return

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE return_requests
                SET
                    status = ?,
                    updated_at = CURRENT_TIMESTAMP,
                    resolved_at = CASE
                        WHEN ? IN ('rejected', 'refunded') THEN CURRENT_TIMESTAMP
                        ELSE COALESCE(resolved_at, '')
                    END,
                    resolution_notes = ?
                WHERE id = ?
                """,
                (next_status, next_status, resolution_notes, return_request_id),
            )

            if next_status == "refunded":
                current_fulfillment_status = str(return_request_row["fulfillment_status"] or "").strip().lower()
                next_fulfillment_status = (
                    "returned"
                    if current_fulfillment_status in {"delivered", "returned"}
                    else "cancelled"
                )
                update_order_item_fulfillment_state(
                    connection,
                    order_item_id=int(return_request_row["order_item_id"]),
                    fulfillment_status=next_fulfillment_status,
                )
                refresh_order_status_from_items(connection, int(return_request_row["order_id"]))

            create_notification(
                connection,
                user_id=int(return_request_row["user_id"]),
                notification_type="return",
                title="Kerkesa juaj u perditesua",
                body=f"Kerkesa per `{return_request_row['product_title']}` tani eshte `{next_status}`.",
                href="/refund-returne",
                metadata={"returnRequestId": return_request_id},
            )

        self.send_json(200, {"ok": True, "message": "Kerkesa e kthimit u perditesua."})

    def handle_update_order_status(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per te perditesuar porosite."})
            return

        if user["role"] not in {"business", "admin"}:
            self.send_json(403, {"ok": False, "message": "Nuk ke akses per te perditesuar porosite."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        item_errors, order_item_id = parse_order_item_id(payload)
        status_errors, next_status = parse_fulfillment_status(payload)
        tracking_code = re.sub(r"\s+", " ", str(payload.get("trackingCode", "")).strip())[:120]
        tracking_url = str(payload.get("trackingUrl", "")).strip()[:280]
        combined_errors = item_errors + status_errors
        if combined_errors or order_item_id is None or next_status is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        order_item_row = fetch_order_item_by_id(order_item_id)
        if not order_item_row:
            self.send_json(404, {"ok": False, "message": "Artikulli i porosise nuk u gjet."})
            return

        if user["role"] == "business" and int(order_item_row["business_user_id"] or 0) != int(user["id"]):
            self.send_json(403, {"ok": False, "message": "Nuk ke akses mbi kete porosi."})
            return

        current_status = str(order_item_row["fulfillment_status"] or "").strip().lower()
        if current_status == "pending_confirmation" and next_status not in {"confirmed", "cancelled"}:
            self.send_json(
                409,
                {
                    "ok": False,
                    "message": "Porosia duhet te konfirmohet fillimisht nga biznesi para se te vazhdoje ne statuset e tjera.",
                },
            )
            return

        with get_db_connection() as connection:
            update_order_item_fulfillment_state(
                connection,
                order_item_id=order_item_id,
                fulfillment_status=next_status,
                tracking_code=tracking_code,
                tracking_url=tracking_url,
            )
            refresh_order_status_from_items(connection, int(order_item_row["order_id"]))

            customer_user_id = int(order_item_row["customer_user_id"] or 0)
            if customer_user_id > 0:
                create_notification(
                    connection,
                    user_id=customer_user_id,
                    notification_type="order",
                    title="Porosia juaj u perditesua",
                    body=f"`{order_item_row['product_title']}` tani eshte `{next_status}`.",
                    href="/porosite",
                    metadata={"orderItemId": order_item_id, "orderId": int(order_item_row['order_id'])},
                )

        self.send_json(200, {"ok": True, "message": "Statusi i porosise u perditesua."})

    def handle_business_verification_request(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si biznes."})
            return

        if user["role"] != "business":
            self.send_json(403, {"ok": False, "message": "Vetem bizneset mund te kerkojne verifikim."})
            return

        with get_db_connection() as connection:
            business_profile = connection.execute(
                """
                SELECT id, verification_status
                FROM business_profiles
                WHERE user_id = ?
                LIMIT 1
                """,
                (user["id"],),
            ).fetchone()
            if not business_profile:
                self.send_json(404, {"ok": False, "message": "Ruaje fillimisht profilin e biznesit."})
                return

            if str(business_profile["verification_status"] or "").strip().lower() == "verified":
                self.send_json(200, {"ok": True, "message": "Biznesi eshte tashme i verifikuar."})
                return

            connection.execute(
                """
                UPDATE business_profiles
                SET
                    verification_status = 'pending',
                    verification_requested_at = CURRENT_TIMESTAMP,
                    verification_notes = ''
                WHERE id = ?
                """,
                (business_profile["id"],),
            )

            admin_rows = connection.execute(
                """
                SELECT id
                FROM users
                WHERE role = 'admin'
                """
            ).fetchall()
            for admin_row in admin_rows:
                create_notification(
                    connection,
                    user_id=int(admin_row["id"]),
                    notification_type="verification",
                    title="Biznes kerkon verifikim",
                    body="Nje biznes ka derguar kerkese per verifikim.",
                    href="/bizneset-e-regjistruara",
                    metadata={"businessId": int(business_profile["id"])},
                )

        updated_profile = fetch_business_profile_for_user(int(user["id"]))
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Kerkesa per verifikim u dergua.",
                "profile": serialize_business_profile(updated_profile) if updated_profile else None,
            },
        )

    def handle_business_profile_edit_request(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si biznes."})
            return

        if user["role"] != "business":
            self.send_json(403, {"ok": False, "message": "Vetem bizneset mund te kerkojne editim te profilit."})
            return

        with get_db_connection() as connection:
            business_profile = connection.execute(
                """
                SELECT
                    id,
                    verification_status,
                    profile_edit_access_status
                FROM business_profiles
                WHERE user_id = ?
                LIMIT 1
                """,
                (user["id"],),
            ).fetchone()
            if not business_profile:
                self.send_json(404, {"ok": False, "message": "Ruaje fillimisht profilin e biznesit."})
                return

            if str(business_profile["verification_status"] or "").strip().lower() != "verified":
                self.send_json(
                    403,
                    {"ok": False, "message": "Vetem biznesi i verifikuar mund te kerkoje editim te profilit."},
                )
                return

            current_edit_status = str(business_profile["profile_edit_access_status"] or "").strip().lower()
            if current_edit_status == "approved":
                updated_profile = fetch_business_profile_for_user(int(user["id"]))
                self.send_json(
                    200,
                    {
                        "ok": True,
                        "message": "Admini e ka lejuar tashme editimin e profilit.",
                        "profile": serialize_business_profile(updated_profile) if updated_profile else None,
                    },
                )
                return

            if current_edit_status == "pending":
                updated_profile = fetch_business_profile_for_user(int(user["id"]))
                self.send_json(
                    200,
                    {
                        "ok": True,
                        "message": "Kerkesa per editim eshte ne pritje te admini.",
                        "profile": serialize_business_profile(updated_profile) if updated_profile else None,
                    },
                )
                return

            connection.execute(
                """
                UPDATE business_profiles
                SET
                    profile_edit_access_status = 'pending',
                    profile_edit_requested_at = CURRENT_TIMESTAMP,
                    profile_edit_approved_at = '',
                    profile_edit_notes = '',
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (business_profile["id"],),
            )

            admin_rows = connection.execute(
                """
                SELECT id
                FROM users
                WHERE role = 'admin'
                """
            ).fetchall()
            for admin_row in admin_rows:
                create_notification(
                    connection,
                    user_id=int(admin_row["id"]),
                    notification_type="business-edit",
                    title="Biznesi kerkon editim te profilit",
                    body="Nje biznes i verifikuar ka kerkuar leje per editim te profilit.",
                    href="/bizneset-e-regjistruara",
                    metadata={"businessId": int(business_profile["id"])},
                )

        updated_profile = fetch_business_profile_for_user(int(user["id"]))
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Kerkesa per editim u dergua te admini.",
                "profile": serialize_business_profile(updated_profile) if updated_profile else None,
            },
        )

    def handle_admin_update_business_verification(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(403, {"ok": False, "message": "Vetem admin mund te ndryshoje verifikimin."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, business_id = parse_business_id(payload)
        status_errors, verification_status = parse_business_verification_status(payload)
        verification_notes = re.sub(r"\s+", " ", str(payload.get("verificationNotes", "")).strip())[:500]
        combined_errors = id_errors + status_errors
        if combined_errors or business_id is None or verification_status is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        business_row = fetch_business_profile_for_admin_by_id(business_id)
        if not business_row:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE business_profiles
                SET
                    verification_status = ?,
                    verification_verified_at = CASE
                        WHEN ? = 'verified' THEN CURRENT_TIMESTAMP
                        ELSE NULL
                    END,
                    profile_edit_access_status = 'locked',
                    profile_edit_requested_at = '',
                    profile_edit_approved_at = '',
                    profile_edit_notes = '',
                    verification_notes = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (
                    verification_status,
                    verification_status,
                    verification_notes,
                    business_id,
                ),
            )

            create_notification(
                connection,
                user_id=int(business_row["user_id"]),
                notification_type="verification",
                title="Statusi i verifikimit u perditesua",
                body=f"Biznesi juaj tani eshte `{verification_status}`.",
                href="/biznesi-juaj",
                metadata={"businessId": business_id},
            )

        updated_business = fetch_business_profile_for_admin_by_id(business_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Statusi i verifikimit u ruajt.",
                "business": serialize_admin_business_profile(updated_business) if updated_business else None,
            },
        )

    def handle_admin_update_business_edit_access(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(403, {"ok": False, "message": "Vetem admin mund te aprovoje editimin e biznesit."})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, business_id = parse_business_id(payload)
        status_errors, edit_access_status = parse_business_profile_edit_access_status(payload)
        edit_notes = re.sub(r"\s+", " ", str(payload.get("editAccessNotes", "")).strip())[:500]
        combined_errors = id_errors + status_errors
        if combined_errors or business_id is None or edit_access_status is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        if edit_access_status not in {"approved", "locked"}:
            self.send_json(400, {"ok": False, "message": "Admini mund ta lejoje ose ta mbylle editimin."})
            return

        business_row = fetch_business_profile_for_admin_by_id(business_id)
        if not business_row:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        if str(business_row["verification_status"] or "").strip().lower() != "verified":
            self.send_json(400, {"ok": False, "message": "Editimi mund te aprovohet vetem per biznes te verifikuar."})
            return

        now_text = datetime_to_storage_text(utc_now())
        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE business_profiles
                SET
                    profile_edit_access_status = ?,
                    profile_edit_requested_at = CASE
                        WHEN ? = 'approved' THEN COALESCE(NULLIF(TRIM(profile_edit_requested_at), ''), ?)
                        ELSE ''
                    END,
                    profile_edit_approved_at = CASE
                        WHEN ? = 'approved' THEN ?
                        ELSE ''
                    END,
                    profile_edit_notes = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (
                    edit_access_status,
                    edit_access_status,
                    now_text,
                    edit_access_status,
                    now_text,
                    edit_notes,
                    business_id,
                ),
            )

            create_notification(
                connection,
                user_id=int(business_row["user_id"]),
                notification_type="business-edit",
                title=(
                    "Admini e lejoi editimin e biznesit"
                    if edit_access_status == "approved"
                    else "Kerkesa per editim u mbyll"
                ),
                body=(
                    "Tani mund ta editosh profilin e biznesit."
                    if edit_access_status == "approved"
                    else "Editimi i profilit nuk eshte i hapur. Provo perseri me kerkese te re."
                ),
                href="/biznesi-juaj",
                metadata={"businessId": business_id},
            )

        updated_business = fetch_business_profile_for_admin_by_id(business_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    "Editimi i biznesit u aprovua."
                    if edit_access_status == "approved"
                    else "Editimi i biznesit u mbyll."
                ),
                "business": serialize_admin_business_profile(updated_business) if updated_business else None,
            },
        )

    def handle_toggle_wishlist(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Duhet te kyçesh ose te krijosh llogari per wishlist.",
                },
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        product = fetch_product_by_id(product_id)
        if not product or not bool(product["is_public"]):
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        action = "added"
        with get_db_connection() as connection:
            existing_row = connection.execute(
                """
                SELECT 1
                FROM wishlist_items
                WHERE user_id = ? AND product_id = ?
                """,
                (user["id"], product_id),
            ).fetchone()

            if existing_row:
                connection.execute(
                    """
                    DELETE FROM wishlist_items
                    WHERE user_id = ? AND product_id = ?
                    """,
                    (user["id"], product_id),
                )
                action = "removed"
            else:
                connection.execute(
                    """
                    INSERT INTO wishlist_items (user_id, product_id)
                    VALUES (?, ?)
                    """,
                    (user["id"], product_id),
                )

        items = [serialize_product(row) for row in fetch_wishlist_products(user["id"])]
        self.send_json(
            200,
            {
                "ok": True,
                "action": action,
                "message": (
                    "Produkti u shtua ne wishlist."
                    if action == "added"
                    else "Produkti u hoq nga wishlist."
                ),
                "items": items,
            },
        )

    def handle_add_to_cart(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Duhet te kyçesh ose te krijosh llogari per shporten.",
                },
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        product = fetch_product_by_id(product_id)
        if not product or not bool(product["is_public"]):
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        variant_errors, selected_variant = resolve_requested_product_variant(product, payload)
        quantity_errors, quantity = parse_optional_positive_quantity(payload, "quantity")
        combined_errors = variant_errors + quantity_errors
        if combined_errors or not selected_variant or quantity is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        updated_at_value = datetime_to_storage_text(utc_now())
        with get_db_connection() as connection:
            existing_row = connection.execute(
                """
                SELECT quantity
                FROM cart_lines
                WHERE user_id = ? AND product_id = ? AND variant_key = ?
                LIMIT 1
                """,
                (user["id"], product_id, selected_variant["key"]),
            ).fetchone()
            existing_quantity = max(0, int(existing_row["quantity"] or 0)) if existing_row else 0
            available_quantity = max(0, int(selected_variant.get("quantity") or 0))
            if existing_quantity + quantity > available_quantity:
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": f"Varianti `{selected_variant['label']}` nuk ka me shume stok te lire.",
                    },
                )
                return

            connection.execute(
                """
                INSERT INTO cart_lines (
                    user_id,
                    product_id,
                    variant_key,
                    variant_label,
                    selected_size,
                    selected_color,
                    quantity,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id, product_id, variant_key)
                DO UPDATE SET
                    quantity = cart_lines.quantity + EXCLUDED.quantity,
                    updated_at = ?
                """,
                (
                    user["id"],
                    product_id,
                    selected_variant["key"],
                    selected_variant["label"],
                    selected_variant["size"],
                    selected_variant["color"],
                    quantity,
                    updated_at_value,
                    updated_at_value,
                    updated_at_value,
                ),
            )

        items = [serialize_cart_item(row) for row in fetch_cart_items(user["id"])]
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Produkti u shtua ne shporte.",
                "items": items,
            },
        )

    def handle_remove_from_cart(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Duhet te kyçesh ose te krijosh llogari per shporten.",
                },
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, cart_line_id = parse_cart_line_id(payload)
        if errors or cart_line_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            connection.execute(
                """
                DELETE FROM cart_lines
                WHERE user_id = ? AND id = ?
                """,
                (user["id"], cart_line_id),
            )

        items = [serialize_cart_item(row) for row in fetch_cart_items(user["id"])]
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Produkti u hoq nga shporta.",
                "items": items,
            },
        )

    def handle_update_cart_quantity(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": "Duhet te kyçesh ose te krijosh llogari per shporten.",
                },
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, cart_line_id = parse_cart_line_id(payload)
        quantity_errors, quantity = parse_positive_quantity(payload, "quantity")
        combined_errors = errors + quantity_errors
        if combined_errors or cart_line_id is None or quantity is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        updated_at_value = datetime_to_storage_text(utc_now())
        with get_db_connection() as connection:
            existing_row = connection.execute(
                """
                SELECT
                    cl.id,
                    cl.product_id,
                    cl.variant_key,
                    p.variant_inventory,
                    p.category,
                    p.size,
                    p.color,
                    p.stock_quantity
                FROM cart_lines cl
                INNER JOIN products p ON p.id = cl.product_id
                WHERE cl.user_id = ? AND cl.id = ?
                LIMIT 1
                """,
                (user["id"], cart_line_id),
            ).fetchone()

            if not existing_row:
                self.send_json(
                    404,
                    {"ok": False, "message": "Produkti nuk u gjet ne shporte."},
                )
                return

            variant_inventory = deserialize_product_variant_inventory(
                existing_row["variant_inventory"],
                category=existing_row["category"],
                size=existing_row["size"],
                color=existing_row["color"],
                stock_quantity=existing_row["stock_quantity"],
            )
            selected_variant = next(
                (
                    entry
                    for entry in variant_inventory
                    if str(entry.get("key", "")).strip() == str(existing_row["variant_key"] or "").strip()
                ),
                None,
            )
            available_quantity = max(0, int(selected_variant.get("quantity") or 0)) if selected_variant else 0
            if quantity > available_quantity:
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": "Nuk ka stok te mjaftueshem per sasine e zgjedhur.",
                    },
                )
                return

            connection.execute(
                """
                UPDATE cart_lines
                SET quantity = ?, updated_at = ?
                WHERE user_id = ? AND id = ?
                """,
                (quantity, updated_at_value, user["id"], cart_line_id),
            )

        items = [serialize_cart_item(row) for row in fetch_cart_items(user["id"])]
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Sasia e produktit u perditesua.",
                "items": items,
            },
        )

    def handle_create_order(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se ta konfirmosh porosine."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        cart_line_ids_errors, cart_line_ids = parse_cart_line_ids(payload)
        payment_method_errors, payment_method = parse_payment_method(payload)
        address_errors, cleaned_address = validate_address_payload(payload)
        promo_code_errors, promo_code = parse_promo_code(payload)
        delivery_method_errors, delivery_method = parse_delivery_method(payload)
        combined_errors = (
            cart_line_ids_errors
            + payment_method_errors
            + address_errors
            + promo_code_errors
            + delivery_method_errors
        )

        if combined_errors or payment_method is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        if payment_method == "card-online":
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": "Per pagesen online vazhdo me Stripe test checkout.",
                },
            )
            return

        try:
            with get_db_connection() as connection:
                checkout_items = load_checkout_items_for_order_or_raise(
                    connection,
                    user_id=int(user["id"]),
                    cart_line_ids=cart_line_ids,
                )
                pricing_summary = build_checkout_pricing_summary(
                    connection,
                    checkout_items=checkout_items,
                    promo_code=promo_code,
                    user_id=int(user["id"]),
                    delivery_method=delivery_method or "standard",
                    destination_city=str(cleaned_address.get("city") or "").strip(),
                )
                order_id, saved_order, saved_items = create_order_from_checkout_items(
                    connection,
                    user=user,
                    payment_method=payment_method,
                    cleaned_address=cleaned_address,
                    checkout_items=checkout_items,
                    cart_line_ids=cart_line_ids,
                    pricing_summary=pricing_summary,
                )
                create_order_notifications(
                    connection,
                    order_row=saved_order,
                    saved_items=saved_items,
                )
        except CheckoutProcessError as error:
            self.send_json(
                400,
                {
                    "ok": False,
                    "errors": error.errors,
                    "message": error.message or "Porosia nuk u konfirmua.",
                },
            )
            return

        notification_messages, notification_warnings = build_business_notification_messages(
            fetch_order_notification_rows(order_id)
        )
        notification_warnings.extend(send_email_notifications(notification_messages))

        self.send_json(
            201,
            {
                "ok": True,
                "message": (pricing_summary.get("message") or "").strip() or "Porosia u dergua per konfirmim.",
                "order": (
                    serialize_order(
                        saved_order,
                        [serialize_order_item(item) for item in saved_items],
                    )
                    if saved_order
                    else None
                ),
                "notificationWarnings": notification_warnings,
            },
        )

    def handle_delete_product(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta menaxhuar produktin."})
            return

        if user["role"] not in {"admin", "business"}:
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin ose biznes mund t'i fshije produktet."},
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        if not can_manage_product(user, product):
            self.send_json(
                403,
                {"ok": False, "message": "Nuk ke akses ta menaxhosh kete produkt."},
            )
            return

        with get_db_connection() as connection:
            connection.execute("DELETE FROM products WHERE id = ?", (product_id,))

        self.send_json(
            200,
            {"ok": True, "message": "Produkti u fshi me sukses."},
        )

    def handle_product_public_visibility(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta menaxhuar produktin."})
            return

        if user["role"] not in {"admin", "business"}:
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin ose biznes mund ta ndryshoje dukshmerine."},
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        flag_errors, is_public = parse_boolean_flag(payload, "isPublic")
        if flag_errors or is_public is None:
            self.send_json(400, {"ok": False, "errors": flag_errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        if not can_manage_product(user, product):
            self.send_json(
                403,
                {"ok": False, "message": "Nuk ke akses ta menaxhosh kete produkt."},
            )
            return

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE products
                SET is_public = ?
                WHERE id = ?
                """,
                (1 if is_public else 0, product_id),
            )

        updated_product = fetch_product_by_id(product_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    "Produkti tani shfaqet per userat."
                    if is_public
                    else "Produkti u fsheh nga pamja publike."
                ),
                "product": serialize_product(updated_product),
            },
        )

    def handle_product_public_stock(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta menaxhuar produktin."})
            return

        if user["role"] not in {"admin", "business"}:
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin ose biznes mund ta ndryshoje stokun publik."},
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        flag_errors, show_stock_public = parse_boolean_flag(payload, "showStockPublic")
        if flag_errors or show_stock_public is None:
            self.send_json(400, {"ok": False, "errors": flag_errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        if not can_manage_product(user, product):
            self.send_json(
                403,
                {"ok": False, "message": "Nuk ke akses ta menaxhosh kete produkt."},
            )
            return

        if show_stock_public and int(product["stock_quantity"]) <= 0:
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": "Shto fillimisht stok para se ta shfaqesh si te disponueshem.",
                },
            )
            return

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE products
                SET show_stock_public = ?
                WHERE id = ?
                """,
                (1 if show_stock_public else 0, product_id),
            )

        updated_product = fetch_product_by_id(product_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    "Gjendja ne stok tani shfaqet publikisht."
                    if show_stock_public
                    else "Gjendja ne stok u fsheh nga pamja publike."
                ),
                "product": serialize_product(updated_product),
            },
        )

    def handle_restock_product(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta menaxhuar produktin."})
            return

        if user["role"] not in {"admin", "business"}:
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin ose biznes mund te shtoje stok."},
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        quantity_errors, quantity = parse_positive_quantity(payload, "quantity")
        combined_errors = errors + quantity_errors

        if combined_errors or product_id is None or quantity is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        if not can_manage_product(user, product):
            self.send_json(
                403,
                {"ok": False, "message": "Nuk ke akses ta menaxhosh kete produkt."},
            )
            return

        variant_inventory = deserialize_product_variant_inventory(
            product["variant_inventory"] if "variant_inventory" in product.keys() else [],
            category=product["category"],
            size=product["size"],
            color=product["color"],
            stock_quantity=product["stock_quantity"],
        )
        if len(variant_inventory) > 1 or any(
            str(entry.get("size", "")).strip() or str(entry.get("color", "")).strip()
            for entry in variant_inventory
        ):
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": "Per produktet me variante, perditeso stokun nga forma e editimit te produktit.",
                },
            )
            return

        with get_db_connection() as connection:
            next_inventory = variant_inventory or [
                {
                    "key": "default",
                    "size": "",
                    "color": "",
                    "quantity": 0,
                    "label": "Standard",
                }
            ]
            next_inventory[0]["quantity"] = max(0, int(next_inventory[0].get("quantity") or 0)) + quantity
            normalized_size, normalized_color, total_stock_quantity, serialized_inventory = summarize_variant_inventory_for_storage(
                next_inventory
            )
            connection.execute(
                """
                UPDATE products
                SET
                    variant_inventory = ?,
                    size = ?,
                    color = ?,
                    stock_quantity = ?
                WHERE id = ?
                """,
                (
                    serialized_inventory,
                    normalized_size,
                    normalized_color,
                    total_stock_quantity,
                    product_id,
                ),
            )

        updated_product = fetch_product_by_id(product_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": f"U shtuan {quantity} cope ne stok.",
                "product": serialize_product(updated_product),
            },
        )

    def handle_reduce_stock_product(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh per ta menaxhuar produktin."})
            return

        if user["role"] not in {"admin", "business"}:
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin ose biznes mund te heqe stok."},
            )
            return

        catalog_errors, _ = require_verified_business_catalog_profile(user)
        if catalog_errors:
            self.send_json(403, {"ok": False, "message": catalog_errors[0]})
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, product_id = parse_product_id(payload)
        quantity_errors, quantity = parse_positive_quantity(payload, "quantity")
        combined_errors = errors + quantity_errors

        if combined_errors or product_id is None or quantity is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        if not can_manage_product(user, product):
            self.send_json(
                403,
                {"ok": False, "message": "Nuk ke akses ta menaxhosh kete produkt."},
            )
            return

        variant_inventory = deserialize_product_variant_inventory(
            product["variant_inventory"] if "variant_inventory" in product.keys() else [],
            category=product["category"],
            size=product["size"],
            color=product["color"],
            stock_quantity=product["stock_quantity"],
        )
        if len(variant_inventory) > 1 or any(
            str(entry.get("size", "")).strip() or str(entry.get("color", "")).strip()
            for entry in variant_inventory
        ):
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": "Per produktet me variante, perditeso stokun nga forma e editimit te produktit.",
                },
            )
            return

        current_stock = max(0, int(product["stock_quantity"] or 0))
        if quantity > current_stock:
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": f"Nuk mund te largosh {quantity} cope. Stoku aktual eshte {current_stock}.",
                },
            )
            return

        with get_db_connection() as connection:
            next_inventory = variant_inventory or [
                {
                    "key": "default",
                    "size": "",
                    "color": "",
                    "quantity": 0,
                    "label": "Standard",
                }
            ]
            next_inventory[0]["quantity"] = max(0, int(next_inventory[0].get("quantity") or 0)) - quantity
            normalized_size, normalized_color, total_stock_quantity, serialized_inventory = summarize_variant_inventory_for_storage(
                next_inventory
            )
            connection.execute(
                """
                UPDATE products
                SET
                    variant_inventory = ?,
                    size = ?,
                    color = ?,
                    stock_quantity = ?,
                    show_stock_public = CASE
                        WHEN ? > 0 THEN show_stock_public
                        ELSE 0
                    END
                WHERE id = ?
                """,
                (
                    serialized_inventory,
                    normalized_size,
                    normalized_color,
                    total_stock_quantity,
                    total_stock_quantity,
                    product_id,
                ),
            )

        updated_product = fetch_product_by_id(product_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": f"U larguan {quantity} cope nga stoku.",
                "product": serialize_product(updated_product),
            },
        )

    def handle_forgot_password(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        email = str(payload.get("email", "")).strip().lower()
        if not EMAIL_RE.match(email):
            self.send_json(
                400,
                {"ok": False, "message": "Vendos nje email valid."},
            )
            return

        user = fetch_user_by_email(email)
        if not user:
            self.send_json(
                404,
                {"ok": False, "message": "Nuk ekziston nje llogari me kete email."},
            )
            return

        email_warnings: list[str] = []
        reset_code = generate_password_reset_code()
        with get_db_connection() as connection:
            save_password_reset_code(connection, user["id"], reset_code)
        email_warnings = send_password_reset_code(user, reset_code)

        if email_warnings:
            self.send_json(
                503,
                {
                    "ok": False,
                    "message": (
                        "Kodi u krijua, por email-i nuk u dergua. "
                        "Kontrollo SMTP-ne ose terminalin lokal te serverit."
                    ),
                    "warnings": email_warnings,
                },
            )
            return

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Kodi per ndryshim te fjalekalimit u dergua.",
                "redirectTo": build_password_reset_redirect(email),
            },
        )

    def handle_password_reset_confirm(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors = validate_password_reset(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        email = str(payload.get("email", "")).strip().lower()
        code = re.sub(r"\D", "", str(payload.get("code", "")))
        new_password = str(payload.get("newPassword", ""))

        with get_db_connection() as connection:
            user = connection.execute(
                """
                SELECT
                """
                + USER_AUTH_SELECT_COLUMNS
                + """
                FROM users
                WHERE email = ?
                LIMIT 1
                """,
                (email,),
            ).fetchone()

            if not user:
                self.send_json(
                    404,
                    {"ok": False, "message": "Llogaria me kete email nuk u gjet."},
                )
                return

            reset_row = fetch_password_reset_row(connection, user["id"])
            if not reset_row:
                self.send_json(
                    404,
                    {
                        "ok": False,
                        "message": "Nuk u gjet kod aktiv. Kerko dergim te ri te kodit.",
                    },
                )
                return

            if is_password_reset_expired(reset_row):
                delete_password_reset_code(connection, user["id"])
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": (
                            "Kodi ka skaduar pas 30 minutash. "
                            "Kerko nje kod te ri per ndryshimin e fjalekalimit."
                        ),
                    },
                )
                return

            attempts = int(reset_row["attempts"] or 0)
            if attempts >= PASSWORD_RESET_MAX_ATTEMPTS:
                self.send_json(
                    429,
                    {
                        "ok": False,
                        "message": (
                            "Ke kaluar numrin e tentativave. "
                            "Kerko nje kod te ri per ndryshimin e fjalekalimit."
                        ),
                    },
                )
                return

            if not verify_password(code, reset_row["code_hash"]):
                connection.execute(
                    """
                    UPDATE password_reset_codes
                    SET attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP
                    WHERE user_id = ?
                    """,
                    (user["id"],),
                )
                next_attempts = attempts + 1
                remaining_attempts = max(
                    0,
                    PASSWORD_RESET_MAX_ATTEMPTS - next_attempts,
                )
                message = "Kodi per ndryshim te fjalekalimit nuk eshte i sakte."
                if remaining_attempts > 0:
                    message += f" Te kane mbetur edhe {remaining_attempts} tentativa."
                else:
                    message += " Kerko nje kod te ri."

                self.send_json(400, {"ok": False, "message": message})
                return

            connection.execute(
                """
                UPDATE users
                SET password_hash = ?
                WHERE id = ?
                """,
                (hash_password(new_password), user["id"]),
            )
            delete_password_reset_code(connection, user["id"])

        delete_sessions_for_user(user["id"])
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Fjalekalimi u ndryshua me sukses. Tani mund te kyçesh.",
                "redirectTo": "/login",
            },
            headers={"Set-Cookie": build_expired_session_cookie()},
        )

    def handle_change_password(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se ta ndryshosh fjalekalimin."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors = validate_account_password_change(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        current_password = str(payload.get("currentPassword", ""))
        new_password = str(payload.get("newPassword", ""))

        fresh_user = fetch_user_by_id(user["id"])
        if not fresh_user or not verify_password(current_password, fresh_user["password_hash"]):
            self.send_json(
                401,
                {"ok": False, "message": "Fjalekalimi aktual nuk eshte i sakte."},
            )
            return

        new_password_hash = hash_password(new_password)

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE users
                SET password_hash = ?
                WHERE id = ?
                """,
                (new_password_hash, user["id"]),
            )
            delete_password_reset_code(connection, user["id"])

        delete_sessions_for_user(user["id"])
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Fjalekalimi u ndryshua me sukses. Te lutem kyçu perseri.",
                "redirectTo": "/login",
            },
            headers={"Set-Cookie": build_expired_session_cookie()},
        )

    def handle_profile_update(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se t'i ruash te dhenat."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, cleaned_payload = validate_profile_update(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        full_name = build_full_name(
            cleaned_payload["first_name"],
            cleaned_payload["last_name"],
        )
        next_profile_image_path = (
            cleaned_payload["profile_image_path"]
            or normalize_image_path(user["profile_image_path"])
        )

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE users
                SET
                    full_name = ?,
                    first_name = ?,
                    last_name = ?,
                    birth_date = ?,
                    gender = ?,
                    profile_image_path = ?
                WHERE id = ?
                """,
                (
                    full_name,
                    cleaned_payload["first_name"],
                    cleaned_payload["last_name"],
                    cleaned_payload["birth_date"],
                    cleaned_payload["gender"],
                    next_profile_image_path,
                    user["id"],
                ),
            )

        updated_user = fetch_user_by_id(user["id"])
        if not updated_user:
            self.send_json(
                404,
                {"ok": False, "message": "Perdoruesi nuk u gjet pas ruajtjes."},
            )
            return

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Te dhenat personale u ruajten me sukses.",
                "user": serialize_user(updated_user),
            },
        )

    def handle_save_default_address(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se t'i ruash adresat."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors, cleaned_payload = validate_address_payload(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            existing_default = connection.execute(
                """
                SELECT id
                FROM user_addresses
                WHERE user_id = ? AND is_default = 1
                ORDER BY updated_at DESC, id DESC
                LIMIT 1
                """,
                (user["id"],),
            ).fetchone()

            connection.execute(
                "UPDATE user_addresses SET is_default = 0 WHERE user_id = ?",
                (user["id"],),
            )

            if existing_default:
                address_id = existing_default["id"]
                connection.execute(
                    """
                    UPDATE user_addresses
                    SET
                        address_line = ?,
                        city = ?,
                        country = ?,
                        zip_code = ?,
                        phone_number = ?,
                        is_default = 1,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (
                        cleaned_payload["address_line"],
                        cleaned_payload["city"],
                        cleaned_payload["country"],
                        cleaned_payload["zip_code"],
                        cleaned_payload["phone_number"],
                        address_id,
                    ),
                )
            else:
                address_id = execute_insert_and_get_id(
                    connection,
                    """
                    INSERT INTO user_addresses (
                        user_id,
                        address_line,
                        city,
                        country,
                        zip_code,
                        phone_number,
                        is_default
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 1)
                    """,
                    (
                        user["id"],
                        cleaned_payload["address_line"],
                        cleaned_payload["city"],
                        cleaned_payload["country"],
                        cleaned_payload["zip_code"],
                        cleaned_payload["phone_number"],
                    ),
                )

            saved_address = connection.execute(
                """
                SELECT
                """
                + ADDRESS_SELECT_COLUMNS
                + """
                FROM user_addresses
                WHERE id = ?
                """,
                (address_id,),
            ).fetchone()

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Adresa default u ruajt me sukses.",
                "address": serialize_address(saved_address) if saved_address else None,
            },
        )

    def handle_reverse_geocode_address(self) -> None:
        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        try:
            latitude = float(payload.get("latitude"))
            longitude = float(payload.get("longitude"))
        except (TypeError, ValueError):
            self.send_json(400, {"ok": False, "message": "Lokacioni i telefonit nuk eshte valid."})
            return

        if not (-90.0 <= latitude <= 90.0 and -180.0 <= longitude <= 180.0):
            self.send_json(400, {"ok": False, "message": "Lokacioni i telefonit nuk eshte valid."})
            return

        geocode_url = (
            "https://nominatim.openstreetmap.org/reverse?"
            + urlencode(
                {
                    "format": "jsonv2",
                    "lat": f"{latitude:.8f}",
                    "lon": f"{longitude:.8f}",
                    "addressdetails": "1",
                    "zoom": "18",
                }
            )
        )
        request = Request(
            geocode_url,
            headers={
                "Accept": "application/json",
                "User-Agent": "TREGO/1.0 (checkout geolocation)",
            },
            method="GET",
        )

        try:
            with urlopen(request, timeout=20) as response:
                raw_response = response.read().decode("utf-8", errors="ignore")
            payload_data = json.loads(raw_response)
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
            self.send_json(
                502,
                {
                    "ok": False,
                    "message": "Lokacioni nuk u identifikua automatikisht. Plotëso adresën manualisht.",
                },
            )
            return

        address_details = payload_data.get("address") or {}
        address_line_parts = [
            str(address_details.get("house_number") or "").strip(),
            str(address_details.get("road") or "").strip(),
            str(address_details.get("suburb") or address_details.get("neighbourhood") or "").strip(),
        ]
        address_line = ", ".join(part for part in address_line_parts if part).strip()
        city = (
            str(address_details.get("city") or "").strip()
            or str(address_details.get("town") or "").strip()
            or str(address_details.get("village") or "").strip()
            or str(address_details.get("municipality") or "").strip()
            or str(address_details.get("county") or "").strip()
        )
        country = str(address_details.get("country") or "").strip()
        zip_code = str(address_details.get("postcode") or "").strip()
        display_name = str(payload_data.get("display_name") or "").strip()

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Lokacioni u plotësua nga telefoni.",
                "address": {
                    "addressLine": address_line or display_name or f"{latitude:.6f}, {longitude:.6f}",
                    "city": city,
                    "country": country,
                    "zipCode": zip_code,
                    "phoneNumber": "",
                    "latitude": latitude,
                    "longitude": longitude,
                    "displayName": display_name,
                },
            },
        )

    def handle_delete_own_account(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Duhet te kyçesh para se ta fshish llogarine."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        errors = validate_account_deletion(payload)
        if errors:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        fresh_user = fetch_user_by_id(user["id"])
        if not fresh_user:
            self.send_json(404, {"ok": False, "message": "Perdoruesi nuk u gjet."})
            return

        password = str(payload.get("password", ""))
        if not verify_password(password, fresh_user["password_hash"]):
            self.send_json(
                401,
                {"ok": False, "message": "Fjalekalimi nuk eshte i sakte."},
            )
            return

        with get_db_connection() as connection:
            if fresh_user["role"] == "admin" and count_admin_users(connection) <= 1:
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": "Nuk mund ta fshish adminin e fundit nga sistemi.",
                    },
                )
                return

            connection.execute(
                "DELETE FROM wishlist_items WHERE user_id = ?",
                (fresh_user["id"],),
            )
            connection.execute(
                "DELETE FROM cart_items WHERE user_id = ?",
                (fresh_user["id"],),
            )
            connection.execute(
                """
                UPDATE products
                SET created_by_user_id = NULL
                WHERE created_by_user_id = ?
                """,
                (fresh_user["id"],),
            )
            connection.execute(
                "DELETE FROM user_addresses WHERE user_id = ?",
                (fresh_user["id"],),
            )
            connection.execute(
                "DELETE FROM users WHERE id = ?",
                (fresh_user["id"],),
            )

        delete_sessions_for_user(fresh_user["id"])
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Llogaria u fshi me sukses.",
                "redirectTo": "/signup",
            },
            headers={"Set-Cookie": build_expired_session_cookie()},
        )

    def handle_logout(self) -> None:
        delete_session(self.get_session_token())
        self.send_json(
            200,
            {
                "ok": True,
                "message": "U ckyqe me sukses.",
                "redirectTo": "/login",
            },
            headers={"Set-Cookie": build_expired_session_cookie()},
        )

    def handle_admin_user_role(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i ndryshoje rolet."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, target_user_id = parse_user_id(payload)
        role_errors, role = parse_user_role(payload)
        combined_errors = id_errors + role_errors

        if combined_errors or target_user_id is None or role is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        with get_db_connection() as connection:
            target_user = connection.execute(
                """
                SELECT
                """
                + USER_SELECT_COLUMNS
                + """
                FROM users
                WHERE id = ?
                """,
                (target_user_id,),
            ).fetchone()

            if not target_user:
                self.send_json(404, {"ok": False, "message": "Perdoruesi nuk u gjet."})
                return

            if target_user["role"] == role:
                self.send_json(
                    200,
                    {
                        "ok": True,
                        "message": "Ky perdorues e ka tashme kete rol.",
                        "user": serialize_user(target_user),
                    },
                )
                return

            if target_user["role"] == "admin" and role != "admin":
                if count_admin_users(connection) <= 1:
                    self.send_json(
                        400,
                        {
                            "ok": False,
                            "message": "Nuk mund ta heqesh adminin e fundit nga sistemi.",
                        },
                    )
                    return

            connection.execute(
                """
                UPDATE users
                SET role = ?
                WHERE id = ?
                """,
                (role, target_user_id),
            )

            updated_user = connection.execute(
                """
                SELECT
                """
                + USER_SELECT_COLUMNS
                + """
                FROM users
                WHERE id = ?
                """,
                (target_user_id,),
            ).fetchone()

        self.send_json(
            200,
            {
                "ok": True,
                "message": {
                    "admin": "Perdoruesi u be admin me sukses.",
                    "business": "Perdoruesi u be biznes me sukses.",
                    "client": "Perdoruesi u kthye ne user normal.",
                }[role],
                "user": serialize_user(updated_user),
            },
        )

    def handle_admin_delete_user(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i fshije perdoruesit."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, target_user_id = parse_user_id(payload)
        if id_errors or target_user_id is None:
            self.send_json(400, {"ok": False, "errors": id_errors})
            return

        if target_user_id == current_user["id"]:
            self.send_json(
                400,
                {"ok": False, "message": "Nuk mund ta fshish llogarine tende nga kjo faqe."},
            )
            return

        with get_db_connection() as connection:
            target_user = connection.execute(
                """
                SELECT
                """
                + USER_SELECT_COLUMNS
                + """
                FROM users
                WHERE id = ?
                """,
                (target_user_id,),
            ).fetchone()

            if not target_user:
                self.send_json(404, {"ok": False, "message": "Perdoruesi nuk u gjet."})
                return

            if target_user["role"] == "admin" and count_admin_users(connection) <= 1:
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": "Nuk mund ta fshish adminin e fundit nga sistemi.",
                    },
                )
                return

            connection.execute(
                "DELETE FROM wishlist_items WHERE user_id = ?",
                (target_user_id,),
            )
            connection.execute(
                "DELETE FROM cart_items WHERE user_id = ?",
                (target_user_id,),
            )
            connection.execute(
                """
                UPDATE products
                SET created_by_user_id = NULL
                WHERE created_by_user_id = ?
                """,
                (target_user_id,),
            )
            connection.execute(
                "DELETE FROM users WHERE id = ?",
                (target_user_id,),
            )

        delete_sessions_for_user(target_user_id)
        self.send_json(
            200,
            {"ok": True, "message": "Perdoruesi u fshi me sukses."},
        )

    def handle_admin_set_user_password(self) -> None:
        current_user = self.get_current_user()
        if not current_user:
            self.send_json(401, {"ok": False, "message": "Duhet te kyçesh si admin."})
            return

        if current_user["role"] != "admin":
            self.send_json(
                403,
                {"ok": False, "message": "Vetem admin mund t'i ndryshoje fjalekalimet."},
            )
            return

        try:
            payload = self.read_json()
        except ValueError as error:
            self.send_json(400, {"ok": False, "message": str(error)})
            return

        id_errors, target_user_id = parse_user_id(payload)
        password_errors = validate_admin_password_reset(payload)
        combined_errors = id_errors + password_errors

        if combined_errors or target_user_id is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        target_user = fetch_user_by_id(target_user_id)
        if not target_user:
            self.send_json(404, {"ok": False, "message": "Perdoruesi nuk u gjet."})
            return

        new_password_hash = hash_password(str(payload.get("newPassword", "")))

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE users
                SET password_hash = ?
                WHERE id = ?
                """,
                (new_password_hash, target_user_id),
            )

        delete_sessions_for_user(target_user_id)
        self.send_json(
            200,
            {
                "ok": True,
                "message": "Fjalekalimi i perdoruesit u ndryshua me sukses.",
            },
        )

    def read_json(self) -> dict[str, object]:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            raise ValueError("Kerkesa nuk permban te dhena.")

        raw_body = self.rfile.read(content_length)

        try:
            data = json.loads(raw_body)
        except json.JSONDecodeError as error:
            raise ValueError("Formati JSON nuk eshte valid.") from error

        if not isinstance(data, dict):
            raise ValueError("Forma e te dhenave duhet te jete objekt.")

        return data

    def read_multipart_message(self):
        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type.lower():
            raise ValueError("Formati i upload-it nuk eshte valid.")

        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            raise ValueError("Kerkesa nuk permban te dhena.")

        if content_length > MAX_UPLOAD_REQUEST_SIZE:
            raise ValueError("Ngarkimi i fotove eshte shume i madh.")

        raw_body = self.rfile.read(content_length)
        message = BytesParser(policy=default).parsebytes(
            (
                f"Content-Type: {content_type}\r\n"
                "MIME-Version: 1.0\r\n\r\n"
            ).encode("utf-8")
            + raw_body
        )

        if not message.is_multipart():
            raise ValueError("Formati i upload-it nuk eshte valid.")

        return message

    def handle_uploaded_file(self, path: str) -> None:
        relative_path = path.removeprefix("/uploads/").strip("/")
        if not relative_path or ".." in relative_path.split("/"):
            self.send_error(404, "Skedari nuk u gjet.")
            return

        target_path = UPLOADS_DIR / relative_path
        payload: bytes | None = None
        content_type = self.guess_type(str(target_path)) or "application/octet-stream"

        if target_path.is_file():
            try:
                payload = target_path.read_bytes()
            except OSError:
                self.send_error(500, "Skedari nuk u lexua.")
                return
        else:
            uploaded_asset = fetch_uploaded_asset_by_stored_name(relative_path)
            if not uploaded_asset:
                self.send_error(404, "Skedari nuk u gjet.")
                return

            payload = bytes(uploaded_asset["file_bytes"] or b"")
            content_type = (
                str(uploaded_asset["content_type"] or "").strip()
                or content_type
            )

        if payload is None:
            self.send_error(404, "Skedari nuk u gjet.")
            return

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        self.end_headers()
        self.wfile.write(payload)

    def get_session_token(self) -> str | None:
        return parse_session_token(self.headers.get("Cookie"))

    def get_current_user(self):
        session_token = self.get_session_token()
        if not session_token:
            return None

        user_id = fetch_session_user_id(session_token)
        if not user_id:
            return None

        user = fetch_user_by_id(user_id)
        if not user:
            delete_session(session_token)
            return None

        touch_user_presence(int(user["id"]), user["last_seen_at"])

        return user

    def send_redirect(self, location: str) -> None:
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def get_public_app_origin(self) -> str:
        if STRIPE_PUBLIC_APP_URL:
            return STRIPE_PUBLIC_APP_URL

        forwarded_proto = str(self.headers.get("X-Forwarded-Proto", "")).split(",")[0].strip()
        forwarded_host = str(self.headers.get("X-Forwarded-Host", "")).split(",")[0].strip()
        host = forwarded_host or str(self.headers.get("Host", "")).strip() or "127.0.0.1:8000"
        protocol = forwarded_proto or ("https" if IS_VERCEL else "http")
        return f"{protocol}://{host}"

    def build_public_url(self, path: str) -> str:
        normalized_path = str(path or "/").strip() or "/"
        if normalized_path.startswith("http://") or normalized_path.startswith("https://"):
            return normalized_path
        if not normalized_path.startswith("/"):
            normalized_path = f"/{normalized_path}"
        return f"{self.get_public_app_origin()}{normalized_path}"

    def send_json(
        self,
        status_code: int,
        payload: dict[str, object],
        headers: dict[str, str] | None = None,
    ) -> None:
        response = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response)))
        if headers:
            for header_name, header_value in headers.items():
                self.send_header(header_name, header_value)
        self.end_headers()
        self.wfile.write(response)

    def send_bytes(
        self,
        status_code: int,
        payload: bytes,
        *,
        content_type: str,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        for header_name, header_value in (headers or {}).items():
            self.send_header(header_name, header_value)
        self.end_headers()
        self.wfile.write(payload)


class AppServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def run_server(host: str, port: int) -> None:
    initialize_database()
    server = AppServer((host, port), AppHandler)

    print(f"Serveri po punon ne http://{host}:{port}")
    print(f"Databaza ruhet ne: {DB_PATH}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServeri u ndal.")
    finally:
        server.server_close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Aplikacion i thjeshte per regjistrim perdoruesish me SQLite."
    )
    parser.add_argument("--host", default="127.0.0.1", help="Host-i i serverit.")
    parser.add_argument("--port", default=8000, type=int, help="Porta e serverit.")
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    run_server(arguments.host, arguments.port)
