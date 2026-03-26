import argparse
from collections import defaultdict
from datetime import date, datetime, timedelta
from email.message import EmailMessage
from email.parser import BytesParser
from email.policy import default
import hashlib
import json
import os
import re
import secrets
import sqlite3
import smtplib
from http.cookies import CookieError, SimpleCookie
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse


BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
IS_VERCEL = bool(str(os.environ.get("VERCEL", "")).strip())
RUNTIME_ROOT_DIR = Path("/tmp/trego-runtime") if IS_VERCEL else BASE_DIR
UPLOADS_DIR = RUNTIME_ROOT_DIR / "uploads" if IS_VERCEL else STATIC_DIR / "uploads"
DATA_DIR = RUNTIME_ROOT_DIR / "data" if IS_VERCEL else BASE_DIR / "data"
DB_PATH = DATA_DIR / "accounts.db"
SCHEMA_PATH = BASE_DIR / "schema.sql"
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
SESSION_COOKIE_NAME = "session_token"
PAGE_ROUTES = {
    "/": "/index.html",
    "/about": "/about.html",
    "/kerko": "/search.html",
    "/profili-biznesit": "/business-profile-public.html",
    "/login": "/login.html",
    "/forgot-password": "/forgot-password.html",
    "/signup": "/signup.html",
    "/verifiko-email": "/verify-email.html",
    "/biznesi-juaj": "/business-dashboard.html",
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
    "/admin-products": "/admin-products.html",
    "/bizneset-e-regjistruara": "/registered-businesses.html",
}
LEGACY_PRODUCT_CATEGORIES = {"pets", "agriculture", "medicine", "home"}
SHOP_SECTION_PRODUCT_TYPES = {
    "clothing-men": {
        "tshirt",
        "undershirt",
        "pants",
        "hoodie",
        "turtleneck",
        "jacket",
        "underwear",
        "pajamas",
    },
    "clothing-women": {
        "tshirt",
        "undershirt",
        "pants",
        "hoodie",
        "turtleneck",
        "jacket",
        "underwear",
        "pajamas",
    },
    "clothing-kids": {
        "tshirt",
        "undershirt",
        "pants",
        "hoodie",
        "turtleneck",
        "jacket",
        "underwear",
        "pajamas",
    },
    "cosmetics-men": {"perfumes", "hygiene", "creams"},
    "cosmetics-women": {
        "perfumes",
        "hygiene",
        "creams",
        "makeup",
        "nails",
        "hair-colors",
    },
    "cosmetics-kids": {"hygiene", "creams", "kids-care"},
    "home": {"room-decor", "bathroom-items", "bedroom-items", "kids-room-items"},
    "sport": {"sports-equipment", "sportswear", "sports-accessories"},
    "technology": {
        "phone-cases",
        "headphones",
        "phone-parts",
        "phone-accessories",
    },
}
LEGACY_PRODUCT_TYPES = {"clothing", "cream", "food", "tools", "other"}
PRODUCT_CATEGORIES = LEGACY_PRODUCT_CATEGORIES | set(SHOP_SECTION_PRODUCT_TYPES.keys())
PRODUCT_TYPES = LEGACY_PRODUCT_TYPES | {
    product_type
    for product_types in SHOP_SECTION_PRODUCT_TYPES.values()
    for product_type in product_types
}
CLOTHING_SIZES = {"XS", "S", "M", "L", "XL"}
PRODUCT_COLORS = {
    "bardhe",
    "zeze",
    "gri",
    "beige",
    "kafe",
    "kuqe",
    "roze",
    "vjollce",
    "blu",
    "gjelber",
    "verdhe",
    "portokalli",
    "shume-ngjyra",
}
USER_ROLES = {"client", "admin", "business"}
GENDER_OPTIONS = {"mashkull", "femer"}
PAYMENT_METHODS = {"cash", "card-online"}
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"}
IMAGE_CONTENT_TYPE_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "image/avif": ".avif",
}
MAX_UPLOAD_FILES = 8
MAX_UPLOAD_FILE_SIZE = 8 * 1024 * 1024
MAX_UPLOAD_REQUEST_SIZE = MAX_UPLOAD_FILES * MAX_UPLOAD_FILE_SIZE + (1024 * 1024)
EMAIL_VERIFICATION_CODE_LENGTH = 6
EMAIL_VERIFICATION_TTL_MINUTES = 30
EMAIL_VERIFICATION_MAX_ATTEMPTS = 5
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
    "created_at"
)
USER_AUTH_SELECT_COLUMNS = USER_SELECT_COLUMNS + ", password_hash"
PRODUCT_SELECT_COLUMNS = """
    id,
    title,
    description,
    price,
    image_path,
    image_gallery,
    category,
    product_type,
    size,
    color,
    stock_quantity,
    is_public,
    show_stock_public,
    created_by_user_id,
    created_at
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
    unit_price,
    quantity,
    created_at
"""
SESSIONS: dict[str, int] = {}


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


def get_smtp_settings() -> dict[str, object]:
    host = str(os.environ.get("TREGO_SMTP_HOST", "")).strip()
    username = str(os.environ.get("TREGO_SMTP_USERNAME", "")).strip()
    password = str(os.environ.get("TREGO_SMTP_PASSWORD", ""))
    from_email = str(os.environ.get("TREGO_SMTP_FROM", username or "")).strip()
    port_text = str(os.environ.get("TREGO_SMTP_PORT", "587")).strip()

    try:
        port = int(port_text)
    except ValueError:
        port = 587

    return {
        "host": host,
        "port": port,
        "username": username,
        "password": password,
        "from_email": from_email,
        "use_tls": read_bool_env("TREGO_SMTP_USE_TLS", True),
    }


def is_smtp_configured(settings: dict[str, object]) -> bool:
    return all(
        str(settings.get(key, "")).strip()
        for key in ("host", "username", "password", "from_email")
    )


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


def get_db_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON;")
    return connection


def initialize_database() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

    with get_db_connection() as connection:
        connection.execute("PRAGMA foreign_keys = ON;")
        connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        migrate_database(connection)


def migrate_database(connection: sqlite3.Connection) -> None:
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

    connection.execute(
        """
        UPDATE business_profiles
        SET
            business_number = COALESCE(NULLIF(TRIM(business_number), ''), ''),
            business_logo_path = COALESCE(NULLIF(TRIM(business_logo_path), ''), '')
        """
    )

    business_profiles = connection.execute(
        """
        SELECT id, business_logo_path
        FROM business_profiles
        """
    ).fetchall()
    for business_profile in business_profiles:
        normalized_logo_path = normalize_image_path(business_profile["business_logo_path"])
        if normalized_logo_path != str(business_profile["business_logo_path"] or "").strip():
            connection.execute(
                """
                UPDATE business_profiles
                SET business_logo_path = ?
                WHERE id = ?
                """,
                (normalized_logo_path, business_profile["id"]),
            )

    connection.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_business_profiles_business_number
        ON business_profiles(business_number)
        WHERE TRIM(business_number) <> ''
        """
    )

    if not column_exists(connection, "products", "product_type"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN product_type TEXT NOT NULL DEFAULT 'other'"
        )

    if not column_exists(connection, "products", "size"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN size TEXT NOT NULL DEFAULT ''"
        )

    if not column_exists(connection, "products", "color"):
        connection.execute(
            "ALTER TABLE products ADD COLUMN color TEXT NOT NULL DEFAULT ''"
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

    connection.execute(
        """
        UPDATE products
        SET
            product_type = COALESCE(NULLIF(TRIM(product_type), ''), 'other'),
            size = COALESCE(size, ''),
            color = COALESCE(NULLIF(TRIM(color), ''), ''),
            stock_quantity = COALESCE(stock_quantity, 0),
            is_public = CASE WHEN COALESCE(is_public, 1) = 0 THEN 0 ELSE 1 END,
            show_stock_public = CASE
                WHEN COALESCE(show_stock_public, 0) = 1 THEN 1
                ELSE 0
            END
        """
    )

    product_rows = connection.execute(
        """
        SELECT id, image_path, image_gallery
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


def column_exists(
    connection: sqlite3.Connection,
    table_name: str,
    column_name: str,
) -> bool:
    rows = connection.execute(f"PRAGMA table_info({table_name})").fetchall()
    return any(row["name"] == column_name for row in rows)


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
    return value.replace(microsecond=0).isoformat(sep=" ")


def parse_storage_datetime(value: object) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None

    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def generate_email_verification_code() -> str:
    return "".join(
        secrets.choice("0123456789")
        for _ in range(EMAIL_VERIFICATION_CODE_LENGTH)
    )


def build_email_verification_redirect(email: str) -> str:
    clean_email = str(email or "").strip().lower()
    if not clean_email:
        return "/verifiko-email"
    return f"/verifiko-email?email={quote(clean_email)}"


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

    if len(password) < 8:
        errors.append("Fjalekalimi duhet te kete te pakten 8 karaktere.")

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


def validate_password_reset(data: dict[str, str]) -> list[str]:
    errors: list[str] = []
    email = data.get("email", "").strip().lower()
    new_password = data.get("newPassword", "")
    confirm_password = data.get("confirmPassword", "")

    if not EMAIL_RE.match(email):
        errors.append("Vendos nje email valid.")

    if len(new_password) < 8:
        errors.append("Fjalekalimi i ri duhet te kete te pakten 8 karaktere.")

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

    if len(new_password) < 8:
        errors.append("Fjalekalimi i ri duhet te kete te pakten 8 karaktere.")

    if new_password != confirm_password:
        errors.append("Konfirmimi i fjalekalimit nuk perputhet.")

    if current_password and current_password == new_password:
        errors.append("Fjalekalimi i ri duhet te jete ndryshe nga ai aktual.")

    return errors


def validate_admin_password_reset(data: dict[str, object]) -> list[str]:
    errors: list[str] = []
    new_password = str(data.get("newPassword", ""))

    if len(new_password) < 8:
        errors.append("Fjalekalimi i ri duhet te kete te pakten 8 karaktere.")

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

    if len(password) < 8:
        errors.append("Fjalekalimi duhet te kete te pakten 8 karaktere.")

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


def validate_product_payload(data: dict[str, object]) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    title = str(data.get("title", "")).strip()
    description = str(data.get("description", "")).strip()
    category = str(data.get("category", "")).strip().lower()
    product_type = str(data.get("productType", "")).strip().lower()
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

    if color and color not in PRODUCT_COLORS:
        errors.append("Zgjidh nje ngjyre valide te produktit.")

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

    requires_size = category.startswith("clothing-") or product_type == "clothing"

    if requires_size:
        if size not in CLOTHING_SIZES:
            errors.append("Per veshje zgjidh nje madhesi nga XS deri ne XL.")
    else:
        size = ""

    return errors, {
        "title": title,
        "description": description,
        "category": category,
        "productType": product_type,
        "size": size,
        "color": color,
        "imagePath": image_path,
        "imageGallery": image_gallery,
        "price": price,
        "stockQuantity": stock_quantity,
    }


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
    return {
        "id": row["id"],
        "userId": row["user_id"],
        "businessName": row["business_name"],
        "businessDescription": row["business_description"],
        "businessNumber": row["business_number"],
        "logoPath": normalize_image_path(row["business_logo_path"]),
        "phoneNumber": row["phone_number"],
        "city": row["city"],
        "addressLine": row["address_line"],
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


def serialize_public_business_profile(row: sqlite3.Row) -> dict[str, object]:
    return {
        "id": row["id"],
        "businessName": row["business_name"],
        "businessDescription": row["business_description"],
        "logoPath": normalize_image_path(row["business_logo_path"]),
        "city": row["city"],
        "phoneNumber": row["phone_number"],
        "addressLine": row["address_line"],
        "followersCount": row["followers_count"],
        "productsCount": row["products_count"],
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
        "city": row["city"],
        "addressLine": row["address_line"],
        "phoneNumber": row["phone_number"],
        "ownerName": row["owner_full_name"],
        "ownerEmail": row["owner_email"],
        "productsCount": row["products_count"],
        "ordersCount": row["orders_count"],
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


def serialize_product(row: sqlite3.Row) -> dict[str, object]:
    image_gallery = normalize_image_gallery_value(
        row["image_gallery"],
        fallback_image_path=row["image_path"],
    )
    image_path = image_gallery[0] if image_gallery else normalize_image_path(row["image_path"])

    return {
        "id": row["id"],
        "title": row["title"],
        "description": row["description"],
        "price": row["price"],
        "imagePath": image_path,
        "imageGallery": image_gallery,
        "category": row["category"],
        "productType": row["product_type"],
        "size": row["size"],
        "color": row["color"],
        "stockQuantity": row["stock_quantity"],
        "isPublic": bool(row["is_public"]),
        "showStockPublic": bool(row["show_stock_public"]),
        "createdByUserId": row["created_by_user_id"],
        "createdAt": row["created_at"],
    }


def serialize_cart_item(row: sqlite3.Row) -> dict[str, object]:
    payload = serialize_product(row)
    payload["quantity"] = row["quantity"]
    return payload


def serialize_order_item(row: sqlite3.Row) -> dict[str, object]:
    quantity = max(1, int(row["quantity"] or 1))
    unit_price = round(float(row["unit_price"] or 0), 2)

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
        "unitPrice": unit_price,
        "quantity": quantity,
        "totalPrice": round(unit_price * quantity, 2),
        "createdAt": row["created_at"],
    }


def serialize_order(
    row: sqlite3.Row,
    items: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    normalized_items = list(items or [])
    total_items = sum(max(0, int(item.get("quantity", 0) or 0)) for item in normalized_items)
    total_price = round(
        sum(float(item.get("totalPrice", 0) or 0) for item in normalized_items),
        2,
    )

    return {
        "id": row["id"],
        "userId": row["user_id"],
        "customerName": row["customer_full_name"],
        "customerEmail": row["customer_email"],
        "paymentMethod": row["payment_method"],
        "status": row["status"],
        "addressLine": row["address_line"],
        "city": row["city"],
        "country": row["country"],
        "zipCode": row["zip_code"],
        "phoneNumber": row["phone_number"],
        "createdAt": row["created_at"],
        "totalItems": total_items,
        "totalPrice": total_price,
        "items": normalized_items,
    }


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


def send_email_messages(messages: list[dict[str, str]]) -> list[str]:
    if not messages:
        return []

    smtp_settings = get_smtp_settings()
    if not is_smtp_configured(smtp_settings):
        return [
            "SMTP nuk eshte konfiguruar ende. Vendos kredencialet e email-it qe njoftimet te dergohen automatikisht."
        ]

    warnings: list[str] = []
    try:
        with smtplib.SMTP(
            str(smtp_settings["host"]),
            int(smtp_settings["port"]),
            timeout=20,
        ) as server:
            server.ehlo()
            if bool(smtp_settings["use_tls"]):
                server.starttls()
                server.ehlo()
            server.login(
                str(smtp_settings["username"]),
                str(smtp_settings["password"]),
            )

            for message_payload in messages:
                email_message = EmailMessage()
                email_message["Subject"] = message_payload["subject"]
                email_message["From"] = str(smtp_settings["from_email"])
                email_message["To"] = message_payload["to_email"]
                email_message.set_content(message_payload["body"])
                server.send_message(email_message)
    except Exception as error:
        warnings.append(
            f"Njoftimi me email nuk u dergua: {error}"
        )

    return warnings


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
            """
            + BUSINESS_PROFILE_SELECT_COLUMNS
            + """
            FROM business_profiles
            WHERE user_id = ?
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
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.full_name AS owner_full_name,
                u.email AS owner_email,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(order_totals.total_orders, 0) AS orders_count
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
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.full_name AS owner_full_name,
                u.email AS owner_email,
                COALESCE(product_totals.total_products, 0) AS products_count,
                COALESCE(order_totals.total_orders, 0) AS orders_count
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
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                COALESCE(follower_totals.total_followers, 0) AS followers_count,
                COALESCE(product_totals.total_products, 0) AS products_count
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
            WHERE TRIM(business_name) <> ''
            ORDER BY updated_at DESC, id DESC
            """
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
                bp.phone_number,
                bp.city,
                bp.address_line,
                bp.created_at,
                bp.updated_at,
                u.email AS owner_email,
                COALESCE(follower_totals.total_followers, 0) AS followers_count,
                COALESCE(product_totals.total_products, 0) AS products_count
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
            WHERE bp.id = ?
            LIMIT 1
            """,
            (business_id,),
        ).fetchone()


def fetch_public_products_for_business(business_id: int) -> list[sqlite3.Row]:
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
                p.stock_quantity,
                p.is_public,
                p.show_stock_public,
                p.created_by_user_id,
                p.created_at
            FROM products p
            INNER JOIN business_profiles bp ON bp.user_id = p.created_by_user_id
            WHERE bp.id = ?
              AND p.is_public = 1
            ORDER BY p.id DESC
            """,
            (business_id,),
        ).fetchall()


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
    include_hidden: bool = False,
    created_by_user_id: int | None = None,
    search_text: str | None = None,
) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
        conditions: list[str] = []
        parameters: list[object] = []

        if category:
            conditions.append("category = ?")
            parameters.append(category)

        if created_by_user_id is not None:
            conditions.append("created_by_user_id = ?")
            parameters.append(created_by_user_id)

        if search_text:
            conditions.append("(LOWER(title) LIKE ? OR LOWER(description) LIKE ?)")
            search_pattern = f"%{search_text.lower()}%"
            parameters.extend([search_pattern, search_pattern])

        if not include_hidden:
            conditions.append("is_public = 1")

        where_clause = ""
        if conditions:
            where_clause = "WHERE " + " AND ".join(conditions)

        return connection.execute(
            """
            SELECT
            """
            + PRODUCT_SELECT_COLUMNS
            + """
            FROM products
            """
            + where_clause
            + """
            ORDER BY id DESC
            """,
            parameters,
        ).fetchall()


def fetch_product_by_id(product_id: int) -> sqlite3.Row | None:
    with get_db_connection() as connection:
        return connection.execute(
            """
            SELECT
            """
            + PRODUCT_SELECT_COLUMNS
            + """
            FROM products
            WHERE id = ?
            """,
            (product_id,),
        ).fetchone()


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
                p.stock_quantity,
                p.is_public,
                p.show_stock_public,
                p.created_by_user_id,
                wi.created_at
            FROM wishlist_items wi
            INNER JOIN products p ON p.id = wi.product_id
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
                p.stock_quantity,
                p.is_public,
                p.show_stock_public,
                p.created_by_user_id,
                ci.created_at,
                ci.quantity
            FROM cart_items ci
            INNER JOIN products p ON p.id = ci.product_id
            WHERE ci.user_id = ?
              AND p.is_public = 1
            ORDER BY ci.updated_at DESC
            """,
            (user_id,),
        ).fetchall()


def fetch_cart_items_for_checkout(
    connection: sqlite3.Connection,
    user_id: int,
    product_ids: list[int],
) -> list[sqlite3.Row]:
    if not product_ids:
        return []

    placeholders = ", ".join("?" for _ in product_ids)
    parameters: list[object] = [user_id, *product_ids]

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
            p.stock_quantity,
            p.is_public,
            p.show_stock_public,
            p.created_by_user_id,
            ci.created_at,
            ci.quantity,
            COALESCE(bp.business_name, '') AS business_name
        FROM cart_items ci
        INNER JOIN products p ON p.id = ci.product_id
        LEFT JOIN business_profiles bp ON bp.user_id = p.created_by_user_id
        WHERE ci.user_id = ?
          AND p.id IN ("""
        + placeholders
        + """)
          AND p.is_public = 1
        ORDER BY ci.updated_at DESC, p.id DESC
        """,
        parameters,
    ).fetchall()


def fetch_orders_for_user(user_id: int) -> list[sqlite3.Row]:
    with get_db_connection() as connection:
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


def fetch_business_orders_for_user(business_user_id: int) -> list[dict[str, object]]:
    with get_db_connection() as connection:
        order_rows = connection.execute(
            """
            SELECT
                o.id,
                o.user_id,
                o.customer_full_name,
                o.customer_email,
                o.payment_method,
                o.status,
                o.address_line,
                o.city,
                o.country,
                o.zip_code,
                o.phone_number,
                o.created_at
            FROM orders o
            INNER JOIN order_items oi ON oi.order_id = o.id
            WHERE oi.business_user_id = ?
            GROUP BY o.id
            ORDER BY o.id DESC
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
            f"U krijua nje porosi e re ne TREGO.\n\n"
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


def can_manage_product(user: sqlite3.Row, product: sqlite3.Row) -> bool:
    if user["role"] == "admin":
        return True

    if user["role"] == "business":
        return product["created_by_user_id"] == user["id"]

    return False


def create_session(user_id: int) -> str:
    session_token = secrets.token_urlsafe(32)
    SESSIONS[session_token] = user_id
    return session_token


def delete_session(session_token: str | None) -> None:
    if session_token:
        SESSIONS.pop(session_token, None)


def delete_sessions_for_user(user_id: int) -> None:
    expired_tokens = [
        session_token
        for session_token, session_user_id in SESSIONS.items()
        if session_user_id == user_id
    ]

    for session_token in expired_tokens:
        delete_session(session_token)


def build_session_cookie(session_token: str) -> str:
    return (
        f"{SESSION_COOKIE_NAME}={session_token}; "
        "HttpOnly; Path=/; SameSite=Lax; Max-Age=86400"
    )


def build_expired_session_cookie() -> str:
    return (
        f"{SESSION_COOKIE_NAME}=; "
        "HttpOnly; Path=/; SameSite=Lax; Max-Age=0"
    )


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
        if path == "/api/address":
            self.handle_default_address()
            return
        if path == "/api/business-profile":
            self.handle_business_profile()
            return
        if path == "/api/business/products":
            self.handle_business_products_list()
            return
        if path == "/api/business/public":
            self.handle_public_business_detail(query_params)
            return
        if path == "/api/business/public-products":
            self.handle_public_business_products(query_params)
            return
        if path == "/api/products/search":
            self.handle_products_search(query_params)
            return
        if path == "/api/product":
            self.handle_product_detail(query_params)
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
        if path == "/api/business/orders":
            self.handle_business_orders_list()
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

        if path in {
            "/llogaria",
            "/te-dhenat-personale",
            "/adresat",
            "/adresa-e-porosise",
            "/menyra-e-pageses",
            "/porosite",
            "/ndrysho-fjalekalimin",
        }:
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
        if path == "/api/business-profile":
            self.handle_save_business_profile()
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
        if path == "/api/admin/businesses/logo":
            self.handle_admin_update_business_logo()
            return
        if path == "/api/uploads":
            self.handle_image_uploads()
            return
        if path == "/api/products":
            self.handle_create_product()
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
        if path == "/api/business/follow-toggle":
            self.handle_business_follow_toggle()
            return
        if path == "/api/orders/create":
            self.handle_create_order()
            return

        self.send_json(404, {"ok": False, "message": "Rruga nuk u gjet."})

    def handle_stats(self) -> None:
        self.send_json(200, {"ok": True, "data": fetch_stats()})

    def handle_me(self) -> None:
        user = self.get_current_user()
        if not user:
            self.send_json(
                401,
                {"ok": False, "message": "Nuk ka perdorues te kyqur."},
            )
            return

        self.send_json(200, {"ok": True, "user": serialize_user(user)})

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
                cursor = connection.execute(
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
                user_id = cursor.lastrowid
                save_email_verification_code(connection, user_id, verification_code)
        except sqlite3.IntegrityError:
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

        if not user or not verify_password(password, user["password_hash"]):
            self.send_json(
                401,
                {
                    "ok": False,
                    "message": (
                        "Kerkojme falje, por llogaria nuk ekziston "
                        "ose te dhenat nuk jane te sakta."
                    ),
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
                "redirectTo": (
                    "/admin-products"
                    if user["role"] == "admin"
                    else "/biznesi-juaj"
                    if user["role"] == "business"
                    else "/"
                ),
                "user": serialize_user(user),
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
        category = query_params.get("category", [""])[0].strip().lower() or None

        if category and category not in PRODUCT_CATEGORIES:
            self.send_json(
                400,
                {"ok": False, "message": "Kategoria e kerkuar nuk eshte valide."},
            )
            return

        products = [serialize_product(row) for row in fetch_products(category)]
        self.send_json(200, {"ok": True, "products": products})

    def handle_products_search(self, query_params: dict[str, list[str]]) -> None:
        search_text = query_params.get("q", [""])[0].strip()

        if not search_text:
            self.send_json(200, {"ok": True, "products": [], "query": ""})
            return

        products = [
            serialize_product(row)
            for row in fetch_products(search_text=search_text)
        ]
        self.send_json(
            200,
            {"ok": True, "products": products, "query": search_text},
        )

    def handle_product_detail(self, query_params: dict[str, list[str]]) -> None:
        errors, product_id = parse_product_id_query(query_params)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        product = fetch_product_by_id(product_id)
        if not product:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        current_user = self.get_current_user()
        can_view_hidden = bool(
            current_user and can_manage_product(current_user, product)
        )
        if not bool(product["is_public"]) and not can_view_hidden:
            self.send_json(404, {"ok": False, "message": "Produkti nuk u gjet."})
            return

        self.send_json(200, {"ok": True, "product": serialize_product(product)})

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
        businesses = [
            serialize_public_business_profile(row)
            for row in fetch_public_business_profiles()
        ]
        self.send_json(200, {"ok": True, "businesses": businesses})

    def handle_public_business_detail(
        self,
        query_params: dict[str, list[str]],
    ) -> None:
        errors, business_id = parse_business_id_query(query_params)
        if errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        business_profile = fetch_public_business_profile_by_id(business_id)
        if not business_profile:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        current_user = self.get_current_user()
        is_followed = bool(
            current_user
            and is_business_followed_by_user(business_id, int(current_user["id"]))
        )
        self.send_json(
            200,
            {
                "ok": True,
                "business": serialize_public_business_detail(
                    business_profile,
                    is_followed=is_followed,
                ),
            },
        )

    def handle_public_business_products(
        self,
        query_params: dict[str, list[str]],
    ) -> None:
        errors, business_id = parse_business_id_query(query_params)
        if errors or business_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        business_profile = fetch_public_business_profile_by_id(business_id)
        if not business_profile:
            self.send_json(404, {"ok": False, "message": "Biznesi nuk u gjet."})
            return

        products = [
            serialize_product(row)
            for row in fetch_public_products_for_business(business_id)
        ]
        self.send_json(200, {"ok": True, "products": products})

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
                    SELECT id
                    FROM business_profiles
                    WHERE user_id = ?
                    """,
                    (user["id"],),
                ).fetchone()

                if existing_profile:
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
                            phone_number,
                            city,
                            address_line
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            user["id"],
                            normalized["business_name"],
                            normalized["business_description"],
                            normalized["business_number"],
                            normalized["business_logo_path"],
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
        except sqlite3.IntegrityError:
            self.send_json(
                409,
                {"ok": False, "message": "Ky numer biznesi ekziston tashme ne sistem."},
            )
            return

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Biznesi u ruajt me sukses.",
                "profile": serialize_business_profile(saved_profile),
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

                user_cursor = connection.execute(
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
                user_id = user_cursor.lastrowid

                connection.execute(
                    """
                    INSERT INTO business_profiles (
                        user_id,
                        business_name,
                        business_description,
                        business_number,
                        phone_number,
                        city,
                        address_line
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        user_id,
                        cleaned_payload["business_name"],
                        cleaned_payload["business_description"],
                        cleaned_payload["business_number"],
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
        except sqlite3.IntegrityError:
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

            base_name = re.sub(r"[^a-zA-Z0-9]+", "-", Path(original_filename).stem)
            safe_name = base_name.strip("-").lower() or "product-photo"
            stored_name = f"{safe_name[:48]}-{secrets.token_hex(6)}{extension}"
            target_path = UPLOADS_DIR / stored_name
            target_path.write_bytes(file_bytes)
            saved_paths.append(f"/uploads/{stored_name}")

        if errors or not saved_paths:
            for saved_path in saved_paths:
                uploaded_file = STATIC_DIR / saved_path.lstrip("/")
                uploaded_file.unlink(missing_ok=True)

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

        safe_name = re.sub(r"[^a-zA-Z0-9_-]+", "-", Path(original_filename).stem).strip("-") or "profile"
        stored_name = f"profile-{user['id']}-{safe_name[:36]}-{secrets.token_hex(6)}{extension}"
        target_path = UPLOADS_DIR / stored_name
        target_path.write_bytes(file_bytes)

        self.send_json(
            200,
            {
                "ok": True,
                "message": "Fotoja e profilit u ngarkua me sukses.",
                "path": f"/uploads/{stored_name}",
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

        if user["role"] == "business" and not fetch_business_profile_for_user(user["id"]):
            self.send_json(
                400,
                {
                    "ok": False,
                    "message": "Regjistroje fillimisht biznesin para se te shtosh artikuj.",
                },
            )
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
            cursor = connection.execute(
                """
                INSERT INTO products (
                    title,
                    description,
                    price,
                    image_path,
                    image_gallery,
                    category,
                    product_type,
                    size,
                    color,
                    stock_quantity,
                    created_by_user_id
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    normalized["title"],
                    normalized["description"],
                    normalized["price"],
                    normalized["imagePath"],
                    json.dumps(normalized["imageGallery"], ensure_ascii=False),
                    normalized["category"],
                    normalized["productType"],
                    normalized["size"],
                    normalized["color"],
                    normalized["stockQuantity"],
                    user["id"],
                ),
            )
            product_id = cursor.lastrowid

            product_row = connection.execute(
                """
                SELECT
                """
                + PRODUCT_SELECT_COLUMNS
                + """
                FROM products
                WHERE id = ?
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

        with get_db_connection() as connection:
            connection.execute(
                """
                INSERT INTO cart_items (user_id, product_id, quantity)
                VALUES (?, ?, 1)
                ON CONFLICT(user_id, product_id)
                DO UPDATE SET
                    quantity = quantity + 1,
                    updated_at = CURRENT_TIMESTAMP
                """,
                (user["id"], product_id),
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

        errors, product_id = parse_product_id(payload)
        if errors or product_id is None:
            self.send_json(400, {"ok": False, "errors": errors})
            return

        with get_db_connection() as connection:
            connection.execute(
                """
                DELETE FROM cart_items
                WHERE user_id = ? AND product_id = ?
                """,
                (user["id"], product_id),
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

        errors, product_id = parse_product_id(payload)
        quantity_errors, quantity = parse_positive_quantity(payload, "quantity")
        combined_errors = errors + quantity_errors
        if combined_errors or product_id is None or quantity is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        with get_db_connection() as connection:
            existing_row = connection.execute(
                """
                SELECT 1
                FROM cart_items
                WHERE user_id = ? AND product_id = ?
                """,
                (user["id"], product_id),
            ).fetchone()

            if not existing_row:
                self.send_json(
                    404,
                    {"ok": False, "message": "Produkti nuk u gjet ne shporte."},
                )
                return

            connection.execute(
                """
                UPDATE cart_items
                SET quantity = ?, updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND product_id = ?
                """,
                (quantity, user["id"], product_id),
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

        product_ids_errors, product_ids = parse_product_ids(payload)
        payment_method_errors, payment_method = parse_payment_method(payload)
        address_errors, cleaned_address = validate_address_payload(payload)
        combined_errors = product_ids_errors + payment_method_errors + address_errors

        if combined_errors or payment_method is None:
            self.send_json(400, {"ok": False, "errors": combined_errors})
            return

        with get_db_connection() as connection:
            checkout_items = fetch_cart_items_for_checkout(connection, user["id"], product_ids)
            if not checkout_items:
                self.send_json(
                    404,
                    {"ok": False, "message": "Produktet e zgjedhura nuk u gjeten ne shporte."},
                )
                return

            available_product_ids = {int(item["id"]) for item in checkout_items}
            missing_product_ids = [product_id for product_id in product_ids if product_id not in available_product_ids]
            if missing_product_ids:
                self.send_json(
                    400,
                    {
                        "ok": False,
                        "message": "Disa produkte nuk jane me te disponueshme per kete porosi.",
                    },
                )
                return

            stock_errors: list[str] = []
            for item in checkout_items:
                stock_quantity = max(0, int(item["stock_quantity"] or 0))
                quantity = max(1, int(item["quantity"] or 1))
                if stock_quantity < quantity:
                    stock_errors.append(
                        f"Produkti `{item['title']}` nuk ka stok te mjaftueshem per kete porosi."
                    )

            if stock_errors:
                self.send_json(400, {"ok": False, "errors": stock_errors})
                return

            customer_full_name = (str(user["full_name"] or "").strip() or build_full_name(
                str(user["first_name"] or ""),
                str(user["last_name"] or ""),
            ) or str(user["email"] or "").strip())

            order_cursor = connection.execute(
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
                    phone_number
                )
                VALUES (?, ?, ?, ?, 'confirmed', ?, ?, ?, ?, ?)
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
                ),
            )
            order_id = int(order_cursor.lastrowid)

            for item in checkout_items:
                quantity = max(1, int(item["quantity"] or 1))
                business_user_id = item["created_by_user_id"]
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
                        unit_price,
                        quantity
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        order_id,
                        item["id"],
                        business_user_id,
                        str(item["business_name"] or "").strip(),
                        str(item["title"] or "").strip(),
                        str(item["description"] or "").strip(),
                        normalize_image_path(item["image_path"]),
                        str(item["category"] or "").strip(),
                        str(item["product_type"] or "").strip(),
                        str(item["size"] or "").strip(),
                        str(item["color"] or "").strip(),
                        round(float(item["price"] or 0), 2),
                        quantity,
                    ),
                )
                connection.execute(
                    """
                    UPDATE products
                    SET stock_quantity = CASE
                        WHEN stock_quantity - ? < 0 THEN 0
                        ELSE stock_quantity - ?
                    END
                    WHERE id = ?
                    """,
                    (quantity, quantity, item["id"]),
                )

            placeholders = ", ".join("?" for _ in product_ids)
            connection.execute(
                """
                DELETE FROM cart_items
                WHERE user_id = ?
                  AND product_id IN ("""
                + placeholders
                + """)
                """,
                [user["id"], *product_ids],
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

        notification_messages, notification_warnings = build_business_notification_messages(
            fetch_order_notification_rows(order_id)
        )
        notification_warnings.extend(send_email_notifications(notification_messages))

        self.send_json(
            201,
            {
                "ok": True,
                "message": "Porosia u konfirmua me sukses.",
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

        with get_db_connection() as connection:
            connection.execute(
                """
                UPDATE products
                SET stock_quantity = stock_quantity + ?
                WHERE id = ?
                """,
                (quantity, product_id),
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

        fetch_user_by_email(email)
        self.send_json(
            200,
            {
                "ok": True,
                "message": (
                    "Kerkesa per kod u pranua. Ne kete version, dergimi real me email "
                    "mund te lidhet me vone."
                ),
            },
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
                cursor = connection.execute(
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
                address_id = cursor.lastrowid

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
        if not target_path.is_file():
            self.send_error(404, "Skedari nuk u gjet.")
            return

        try:
            payload = target_path.read_bytes()
        except OSError:
            self.send_error(500, "Skedari nuk u lexua.")
            return

        content_type = self.guess_type(str(target_path)) or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def get_session_token(self) -> str | None:
        return parse_session_token(self.headers.get("Cookie"))

    def get_current_user(self) -> sqlite3.Row | None:
        session_token = self.get_session_token()
        if not session_token:
            return None

        user_id = SESSIONS.get(session_token)
        if not user_id:
            return None

        user = fetch_user_by_id(user_id)
        if not user:
            delete_session(session_token)
            return None

        return user

    def send_redirect(self, location: str) -> None:
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()

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
