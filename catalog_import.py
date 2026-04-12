import csv
import json
import re
import unicodedata
import zipfile
from collections import Counter, defaultdict
from io import BytesIO, StringIO
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET


MAX_IMPORT_ROWS = 1000
PLACEHOLDER_IMAGE_PATH = "/bujqesia.webp"
OOXML_SPREADSHEET_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

SOURCE_TYPES = {"csv", "xlsx", "json", "api-json"}
STRUCTURED_IMPORT_FIELDS = [
    "sourceProductKey",
    "sourceVariantKey",
    "groupId",
    "parentSku",
    "styleCode",
    "modelCode",
    "title",
    "description",
    "brand",
    "category",
    "productType",
    "audience",
    "pageSection",
    "sku",
    "barcode",
    "price",
    "compareAtPrice",
    "stock",
    "image",
    "images",
    "color",
    "size",
    "material",
    "fit",
    "storage",
    "condition",
    "carrier",
    "simType",
    "connectivity",
    "model",
    "volume",
    "skinType",
    "scent",
    "finish",
    "dimensions",
    "assemblyRequired",
    "era",
]
GROUPING_FIELD_PRIORITY = ["groupId", "parentSku", "styleCode", "modelCode", "sourceProductKey"]
AI_SUGGESTION_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "detectedFieldMappings": {
            "type": "object",
            "additionalProperties": {"type": "string"},
        },
        "rowSuggestions": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "sourceRowId": {"type": "string"},
                    "suggestedCategory": {"type": "string"},
                    "normalizedAttributes": {
                        "type": "object",
                        "additionalProperties": {"type": "string"},
                    },
                    "groupSuggestion": {
                        "type": "object",
                        "additionalProperties": False,
                        "properties": {
                            "groupKey": {"type": "string"},
                            "confidence": {"type": "number"},
                        },
                        "required": ["groupKey", "confidence"],
                    },
                    "confidence": {"type": "number"},
                    "warnings": {
                        "type": "array",
                        "items": {"type": "string"},
                    },
                },
                "required": [
                    "sourceRowId",
                    "suggestedCategory",
                    "normalizedAttributes",
                    "groupSuggestion",
                    "confidence",
                    "warnings",
                ],
            },
        },
    },
    "required": ["detectedFieldMappings", "rowSuggestions"],
}
FIELD_PATTERNS = {
    "sourceProductKey": ["productid", "product_id", "itemid", "item_id", "id", "artikullid"],
    "sourceVariantKey": ["variantid", "variant_id", "optionid", "option_id", "subsku"],
    "groupId": ["groupid", "group_id", "parentid", "parent_id"],
    "parentSku": ["parentsku", "parent_sku"],
    "styleCode": ["stylecode", "style_code"],
    "modelCode": ["modelcode", "model_code", "modelnumber", "model_no"],
    "title": ["title", "name", "productname", "product_name", "artikulli", "articulli", "emri"],
    "description": ["description", "desc", "pershkrim", "details", "body"],
    "brand": ["brand", "maker", "manufacturer", "brendi"],
    "category": ["category", "kategori", "department", "collection", "group", "typegroup"],
    "productType": ["producttype", "product_type", "subcategory", "subtype", "type"],
    "audience": ["audience", "gender", "target", "targetgender"],
    "pageSection": ["section", "departmenttype", "page_section"],
    "sku": ["sku", "articlenumber", "article_number", "productcode", "product_code", "kod"],
    "barcode": ["barcode", "gtin", "ean", "upc"],
    "price": ["price", "cmim", "qmimi", "retailprice", "saleprice", "unitprice"],
    "compareAtPrice": ["compareatprice", "compare_at_price", "oldprice", "listprice", "msrp"],
    "stock": ["stock", "qty", "quantity", "sasia", "inventory", "onhand", "quantityonhand"],
    "image": ["image", "imageurl", "image_url", "imagepath", "image_path", "photo", "foto", "thumbnail"],
    "images": ["images", "gallery", "imagegallery", "image_gallery", "photos"],
    "color": ["color", "colour", "ngjyra", "shade"],
    "size": ["size", "madhesia", "dimension_size"],
    "material": ["material", "fabric", "perberja"],
    "fit": ["fit"],
    "storage": ["storage", "capacity", "memory", "mem", "gb"],
    "condition": ["condition", "grade", "gjendja"],
    "carrier": ["carrier", "network"],
    "simType": ["sim", "simtype", "sim_type"],
    "connectivity": ["connectivity", "connection", "wireless"],
    "model": ["model", "modelname"],
    "volume": ["volume", "ml", "oz", "liter", "litersize"],
    "skinType": ["skintype", "skin_type"],
    "scent": ["scent", "fragrance", "aroma"],
    "finish": ["finish"],
    "dimensions": ["dimensions", "dimension", "sizecm", "measurements"],
    "assemblyRequired": ["assemblyrequired", "assembly_required", "assembly"],
    "era": ["era", "vintageera"],
}
COLOR_ALIASES = {
    "bardh": "White",
    "bardhe": "White",
    "e bardhe": "White",
    "white": "White",
    "off white": "White",
    "ivory": "Cream",
    "cream": "Cream",
    "krem": "Cream",
    "zi": "Black",
    "zeze": "Black",
    "zezë": "Black",
    "black": "Black",
    "gray": "Gray",
    "grey": "Gray",
    "gri": "Gray",
    "silver": "Silver",
    "argjend": "Silver",
    "blue": "Blue",
    "kalter": "Blue",
    "kaltër": "Blue",
    "blu": "Blue",
    "navy": "Navy",
    "red": "Red",
    "kuqe": "Red",
    "green": "Green",
    "gjelber": "Green",
    "gjelbër": "Green",
    "pink": "Pink",
    "roze": "Pink",
    "rozë": "Pink",
    "purple": "Purple",
    "vjollce": "Purple",
    "vjollcë": "Purple",
    "orange": "Orange",
    "portokalli": "Orange",
    "yellow": "Yellow",
    "verdhe": "Yellow",
    "verdhë": "Yellow",
    "brown": "Brown",
    "kafe": "Brown",
    "beige": "Beige",
    "gold": "Gold",
    "ari": "Gold",
    "multicolor": "Multicolor",
    "multi color": "Multicolor",
    "shume ngjyra": "Multicolor",
    "shume-ngjyra": "Multicolor",
}
COLOR_TO_STOREFRONT = {
    "White": "bardhe",
    "Black": "zeze",
    "Gray": "gri",
    "Silver": "argjend",
    "Blue": "blu",
    "Navy": "blu",
    "Red": "kuqe",
    "Green": "gjelber",
    "Pink": "roze",
    "Purple": "vjollce",
    "Orange": "portokalli",
    "Yellow": "verdhe",
    "Brown": "kafe",
    "Beige": "beige",
    "Gold": "ari",
    "Cream": "krem",
    "Multicolor": "shume-ngjyra",
}
SIZE_ALIASES = {
    "xs": "XS",
    "extra small": "XS",
    "s": "S",
    "small": "S",
    "m": "M",
    "medium": "M",
    "l": "L",
    "large": "L",
    "xl": "XL",
    "extra large": "XL",
    "xxl": "XXL",
    "2xl": "XXL",
    "xxxl": "XXXL",
    "3xl": "XXXL",
    "onesize": "One Size",
    "one size": "One Size",
}
CONDITION_ALIASES = {
    "new": "New",
    "brand new": "New",
    "i ri": "New",
    "new with tags": "New With Tags",
    "nwt": "New With Tags",
    "used": "Used",
    "second hand": "Used",
    "thrifted": "Used",
    "pre owned": "Pre-owned",
    "pre-owned": "Pre-owned",
    "excellent": "Excellent",
    "very good": "Very Good",
    "good": "Good",
    "fair": "Fair",
    "refurbished": "Refurbished",
    "renewed": "Refurbished",
}
CATEGORY_ALIASES = {
    "t-shirts": "clothing.tshirts",
    "t shirt": "clothing.tshirts",
    "tee": "clothing.tshirts",
    "tee shirt": "clothing.tshirts",
    "maica": "clothing.tshirts",
    "maice": "clothing.tshirts",
    "men tops": "clothing.tops",
    "tops": "clothing.tops",
    "phones": "electronics.phones",
    "mobile phones": "electronics.phones",
    "mobiles": "electronics.phones",
    "smartphones": "electronics.phones",
    "phone accessories": "electronics.accessories",
    "headphones": "electronics.headphones",
    "earphones": "electronics.headphones",
    "earbuds": "electronics.headphones",
    "cream": "beauty.creams",
    "face cream": "beauty.creams",
    "hand cream": "beauty.creams",
    "furniture": "furniture.general",
    "table": "home.tables",
    "tables": "home.tables",
    "dining table": "home.tables",
    "chair": "home.chairs",
    "chairs": "home.chairs",
    "cosmetics": "beauty.general",
    "beauty": "beauty.general",
    "thrift": "thrift.general",
    "second hand clothing": "thrift.apparel",
    "boutique": "clothing.general",
    "general retail": "retail.general",
}
TITLE_CATEGORY_HINTS = {
    "electronics.phones": ["iphone", "samsung", "galaxy", "phone", "smartphone", "mobile"],
    "electronics.headphones": ["headphone", "headphones", "earbud", "earbuds", "airpods", "speaker"],
    "electronics.laptops": ["laptop", "macbook", "notebook"],
    "clothing.tshirts": ["tshirt", "t-shirt", "tee", "maice", "maica"],
    "clothing.outerwear": ["hoodie", "jacket", "coat", "blazer"],
    "beauty.creams": ["cream", "krem", "serum", "lotion"],
    "home.tables": ["table", "tavoline", "desk"],
    "home.chairs": ["chair", "karrige", "stool"],
}
CATEGORY_ATTRIBUTE_SETS = {
    "clothing": ["color", "size", "material", "fit"],
    "electronics.phones": ["color", "storage", "condition", "carrier", "simType"],
    "electronics.headphones": ["color", "connectivity", "model", "condition"],
    "electronics.laptops": ["color", "storage", "memory", "condition"],
    "beauty.creams": ["volume", "skinType", "scent", "finish"],
    "furniture": ["material", "dimensions", "color", "assemblyRequired"],
    "thrift": ["size", "color", "condition", "era", "material"],
    "retail": ["color", "size", "material"],
}
STOREFRONT_CATEGORY_MAP = {
    "clothing.tshirts": {"pageSection": "clothing", "audience": "men", "category": "clothing-men", "productType": "tshirt"},
    "clothing.tops": {"pageSection": "clothing", "audience": "women", "category": "clothing-women", "productType": "blouse"},
    "clothing.bottoms": {"pageSection": "clothing", "audience": "men", "category": "clothing-men", "productType": "pants"},
    "clothing.outerwear": {"pageSection": "clothing", "audience": "men", "category": "clothing-men", "productType": "jacket"},
    "clothing.general": {"pageSection": "clothing", "audience": "men", "category": "clothing-men", "productType": "tshirt"},
    "electronics.phones": {"pageSection": "technology", "audience": "", "category": "technology", "productType": "phone"},
    "electronics.headphones": {"pageSection": "technology", "audience": "", "category": "technology", "productType": "headphones"},
    "electronics.laptops": {"pageSection": "technology", "audience": "", "category": "technology", "productType": "laptop"},
    "electronics.accessories": {"pageSection": "technology", "audience": "", "category": "technology", "productType": "charger"},
    "beauty.creams": {"pageSection": "cosmetics", "audience": "women", "category": "cosmetics-women", "productType": "face-cream"},
    "beauty.general": {"pageSection": "cosmetics", "audience": "women", "category": "cosmetics-women", "productType": "face-cream"},
    "home.tables": {"pageSection": "home", "audience": "", "category": "home", "productType": "table"},
    "home.chairs": {"pageSection": "home", "audience": "", "category": "home", "productType": "chair"},
    "home.sofas": {"pageSection": "home", "audience": "", "category": "home", "productType": "sofa"},
    "home.storage": {"pageSection": "home", "audience": "", "category": "home", "productType": "shelf"},
    "furniture.general": {"pageSection": "home", "audience": "", "category": "home", "productType": "table"},
    "thrift.apparel": {"pageSection": "clothing", "audience": "women", "category": "clothing-women", "productType": "tshirt"},
    "thrift.general": {"pageSection": "clothing", "audience": "women", "category": "clothing-women", "productType": "tshirt"},
    "retail.general": {"pageSection": "home", "audience": "", "category": "home", "productType": "table"},
}
ATTRIBUTE_ORDER = [
    "color",
    "size",
    "storage",
    "condition",
    "material",
    "fit",
    "carrier",
    "simType",
    "connectivity",
    "model",
    "volume",
    "skinType",
    "scent",
    "finish",
    "dimensions",
    "assemblyRequired",
    "era",
]


def strip_accents(value: object) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    return "".join(
        character
        for character in unicodedata.normalize("NFKD", text)
        if not unicodedata.combining(character)
    )


def normalize_header_key(value: object) -> str:
    text = strip_accents(value).lower()
    return re.sub(r"[^a-z0-9]+", "", text)


def slugify(value: object) -> str:
    text = strip_accents(value).lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def humanize_slug(value: object) -> str:
    text = str(value or "").strip().replace("-", " ").replace("_", " ")
    if not text:
        return ""
    return " ".join(part.capitalize() for part in text.split())


def normalize_whitespace(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def parse_number(value: object) -> float | None:
    raw_value = normalize_whitespace(value).replace(",", ".")
    if not raw_value:
        return None
    raw_value = re.sub(r"[^0-9.+-]", "", raw_value)
    if not raw_value:
        return None
    try:
        return round(float(raw_value), 2)
    except ValueError:
        return None


def parse_int(value: object) -> int | None:
    numeric_value = parse_number(value)
    if numeric_value is None:
        return None
    return int(round(numeric_value))


def normalize_boolean(value: object) -> bool | None:
    normalized = slugify(value)
    if normalized in {"1", "yes", "true", "po", "active"}:
        return True
    if normalized in {"0", "no", "false", "jo", "inactive"}:
        return False
    return None


def normalize_color_value(value: object) -> tuple[str, str]:
    normalized = normalize_whitespace(value)
    if not normalized:
        return "", ""
    alias_key = slugify(normalized).replace("-", " ")
    display_value = COLOR_ALIASES.get(alias_key) or COLOR_ALIASES.get(alias_key.replace(" ", "-")) or normalized.title()
    storefront_value = COLOR_TO_STOREFRONT.get(display_value) or slugify(display_value)
    return display_value, storefront_value


def normalize_size_value(value: object) -> str:
    normalized = normalize_whitespace(value)
    if not normalized:
        return ""
    alias_key = slugify(normalized).replace("-", " ")
    if alias_key in SIZE_ALIASES:
        return SIZE_ALIASES[alias_key]
    compact = re.sub(r"\s+", "", normalized).upper()
    if compact in {"XS", "S", "M", "L", "XL", "XXL", "XXXL"}:
        return compact
    if re.fullmatch(r"[0-9]{2,3}", compact):
        return compact
    return normalized.title()


def normalize_storage_value(value: object) -> str:
    normalized = normalize_whitespace(value)
    if not normalized:
        return ""
    matched = re.search(r"(\d+(?:\.\d+)?)\s*(tb|gb|mb)", normalized, re.IGNORECASE)
    if matched:
        amount = matched.group(1)
        unit = matched.group(2).upper()
        if amount.endswith(".0"):
            amount = amount[:-2]
        return f"{amount}{unit}"
    return normalized.upper().replace(" ", "")


def normalize_condition_value(value: object) -> str:
    normalized = normalize_whitespace(value)
    if not normalized:
        return ""
    alias_key = slugify(normalized).replace("-", " ")
    return CONDITION_ALIASES.get(alias_key) or normalized.title()


def normalize_volume_value(value: object) -> str:
    normalized = normalize_whitespace(value)
    if not normalized:
        return ""
    matched = re.search(r"(\d+(?:\.\d+)?)\s*(ml|l|oz)", normalized, re.IGNORECASE)
    if matched:
        amount = matched.group(1)
        unit = matched.group(2).lower()
        if amount.endswith(".0"):
            amount = amount[:-2]
        return f"{amount}{unit}"
    return normalized


def normalize_dimensions_value(value: object) -> str:
    normalized = normalize_whitespace(value)
    if not normalized:
        return ""
    return normalized.lower().replace(" x ", " x ").replace("×", " x ")


def normalize_attribute_value(attribute_key: str, value: object) -> str:
    normalized = normalize_whitespace(value)
    if not normalized:
        return ""
    key = str(attribute_key or "").strip()
    if key == "color":
        display_value, _ = normalize_color_value(normalized)
        return display_value
    if key == "size":
        return normalize_size_value(normalized)
    if key == "storage":
        return normalize_storage_value(normalized)
    if key == "condition":
        return normalize_condition_value(normalized)
    if key == "volume":
        return normalize_volume_value(normalized)
    if key == "dimensions":
        return normalize_dimensions_value(normalized)
    if key == "assemblyRequired":
        boolean_value = normalize_boolean(normalized)
        if boolean_value is None:
            return normalized.title()
        return "Yes" if boolean_value else "No"
    if key == "simType":
        return normalized.upper().replace(" ", "")
    return normalized.title() if normalized.islower() else normalized


def normalize_images_value(primary_image: object, gallery_value: object) -> list[str]:
    images: list[str] = []

    def append_image(candidate: object) -> None:
        raw_value = normalize_whitespace(candidate)
        if not raw_value or raw_value in images:
            return
        images.append(raw_value)

    append_image(primary_image)
    if isinstance(gallery_value, list):
        for item in gallery_value:
            append_image(item)
    else:
        for part in re.split(r"[;\n\r|,]+", str(gallery_value or "")):
            append_image(part)
    return images


def normalize_title_for_grouping(title: object, attributes: dict[str, str] | None = None) -> str:
    normalized = normalize_whitespace(title)
    if not normalized:
        return ""
    normalized_lower = strip_accents(normalized).lower()
    attribute_values = [
        strip_accents(value).lower()
        for value in (attributes or {}).values()
        if normalize_whitespace(value)
    ]
    for attribute_value in attribute_values:
        if not attribute_value:
            continue
        normalized_lower = re.sub(rf"\b{re.escape(attribute_value)}\b", " ", normalized_lower, flags=re.IGNORECASE)
    normalized_lower = re.sub(r"\b\d+\s*(gb|tb|ml|oz)\b", " ", normalized_lower, flags=re.IGNORECASE)
    normalized_lower = re.sub(r"\b(xs|s|m|l|xl|xxl|xxxl|small|medium|large)\b", " ", normalized_lower, flags=re.IGNORECASE)
    normalized_lower = re.sub(r"\s+", " ", normalized_lower).strip()
    return humanize_slug(slugify(normalized_lower))


def build_variant_key(*, size: str = "", color: str = "", attributes: dict[str, str] | None = None) -> str:
    parts: list[str] = []
    normalized_color = normalize_whitespace(color)
    normalized_size = normalize_whitespace(size)
    if normalized_color:
        parts.append(f"color:{slugify(normalized_color)}")
    if normalized_size:
        parts.append(f"size:{slugify(normalized_size)}")
    for attribute_key in ATTRIBUTE_ORDER:
        if attribute_key in {"color", "size"}:
            continue
        attribute_value = normalize_whitespace((attributes or {}).get(attribute_key, ""))
        if attribute_value:
            parts.append(f"{attribute_key}:{slugify(attribute_value)}")
    for attribute_key in sorted((attributes or {}).keys()):
        if attribute_key in ATTRIBUTE_ORDER or attribute_key in {"color", "size"}:
            continue
        attribute_value = normalize_whitespace((attributes or {}).get(attribute_key, ""))
        if attribute_value:
            parts.append(f"{slugify(attribute_key)}:{slugify(attribute_value)}")
    return "|".join(parts) or "default"


def build_variant_label(*, size: str = "", color_label: str = "", attributes: dict[str, str] | None = None) -> str:
    parts: list[str] = []
    if normalize_whitespace(color_label):
        parts.append(normalize_whitespace(color_label))
    if normalize_whitespace(size):
        parts.append(normalize_whitespace(size))
    for attribute_key in ATTRIBUTE_ORDER:
        if attribute_key in {"color", "size"}:
            continue
        attribute_value = normalize_whitespace((attributes or {}).get(attribute_key, ""))
        if attribute_value:
            parts.append(attribute_value)
    for attribute_key in sorted((attributes or {}).keys()):
        if attribute_key in ATTRIBUTE_ORDER or attribute_key in {"color", "size"}:
            continue
        attribute_value = normalize_whitespace((attributes or {}).get(attribute_key, ""))
        if attribute_value:
            parts.append(attribute_value)
    return " / ".join(parts) or "Standard"


def choose_attribute_set(category_slug: str) -> list[str]:
    normalized = str(category_slug or "").strip().lower()
    if normalized in CATEGORY_ATTRIBUTE_SETS:
        return list(CATEGORY_ATTRIBUTE_SETS[normalized])
    family = normalized.split(".", 1)[0]
    return list(CATEGORY_ATTRIBUTE_SETS.get(family, CATEGORY_ATTRIBUTE_SETS["retail"]))


def infer_category_from_text(category_value: object, title: object, description: object) -> tuple[str, float, list[str]]:
    warnings: list[str] = []
    normalized_category = normalize_whitespace(category_value)
    alias_key = slugify(normalized_category).replace("-", " ")
    if alias_key and alias_key in CATEGORY_ALIASES:
        return CATEGORY_ALIASES[alias_key], 0.96, warnings

    searchable = " ".join(
        filter(
            None,
            [
                strip_accents(title).lower(),
                strip_accents(description).lower(),
                strip_accents(category_value).lower(),
            ],
        )
    )
    for category_slug, hints in TITLE_CATEGORY_HINTS.items():
        if any(hint in searchable for hint in hints):
            if normalized_category:
                warnings.append(f"External category `{normalized_category}` was mapped to `{category_slug}`.")
            return category_slug, 0.74 if normalized_category else 0.66, warnings

    if normalized_category:
        warnings.append(f"Unknown external category `{normalized_category}` mapped to `retail.general`.")
    return "retail.general", 0.2, warnings


def map_category_to_storefront(
    category_slug: str,
    *,
    audience_hint: object = "",
    product_type_hint: object = "",
    title: object = "",
) -> dict[str, str]:
    normalized_category = str(category_slug or "").strip().lower() or "retail.general"
    storefront = dict(STOREFRONT_CATEGORY_MAP.get(normalized_category) or STOREFRONT_CATEGORY_MAP["retail.general"])
    normalized_audience = slugify(audience_hint).replace("-", "")
    if storefront["pageSection"] == "clothing":
        if normalized_audience in {"women", "female", "lady"}:
            storefront["audience"] = "women"
            storefront["category"] = "clothing-women"
        elif normalized_audience in {"kids", "kid", "children"}:
            storefront["audience"] = "kids"
            storefront["category"] = "clothing-kids"
        elif normalized_audience in {"baby", "babies"}:
            storefront["audience"] = "babies"
            storefront["category"] = "clothing-babies"
    if storefront["pageSection"] == "cosmetics":
        if normalized_audience in {"men", "male"}:
            storefront["audience"] = "men"
            storefront["category"] = "cosmetics-men"
    product_type = slugify(product_type_hint)
    if product_type:
        storefront["productType"] = product_type
    elif normalized_category == "beauty.creams":
        lowered_title = strip_accents(title).lower()
        if "hand" in lowered_title or "duar" in lowered_title:
            storefront["productType"] = "hand-cream"
        elif "body" in lowered_title or "trup" in lowered_title:
            storefront["productType"] = "body-cream"
        else:
            storefront["productType"] = "face-cream"
    return storefront


def build_default_field_mapping() -> dict[str, str]:
    return {field: "" for field in STRUCTURED_IMPORT_FIELDS}


def suggest_field_mappings(headers: list[str], sample_rows: list[dict[str, Any]] | None = None) -> dict[str, str]:
    suggestions = build_default_field_mapping()
    normalized_headers = [
        {
            "original": header,
            "normalized": normalize_header_key(header),
        }
        for header in headers
        if normalize_whitespace(header)
    ]
    for field_name, patterns in FIELD_PATTERNS.items():
        for header in normalized_headers:
            if any(pattern in header["normalized"] for pattern in patterns):
                suggestions[field_name] = header["original"]
                break
    if sample_rows:
        header_usage = Counter()
        for row in sample_rows[:8]:
            for header, raw_value in row.items():
                if normalize_whitespace(raw_value):
                    header_usage[header] += 1
        if not suggestions["title"] and header_usage:
            suggestions["title"] = max(header_usage.items(), key=lambda item: item[1])[0]
    return suggestions


def merge_field_mappings(base_mapping: dict[str, str] | None, overrides: dict[str, str] | None) -> dict[str, str]:
    merged = build_default_field_mapping()
    for source in [base_mapping or {}, overrides or {}]:
        for field_name in STRUCTURED_IMPORT_FIELDS:
            mapped_value = normalize_whitespace(source.get(field_name, ""))
            if mapped_value:
                merged[field_name] = mapped_value
    return merged


def parse_row_value(row: dict[str, Any], header_name: str) -> Any:
    if not header_name:
        return ""
    return row.get(header_name, "")


def attribute_fields_for_record(category_slug: str) -> list[str]:
    attribute_set = choose_attribute_set(category_slug)
    extras = ["material", "color", "size"]
    for extra in extras:
        if extra not in attribute_set:
            attribute_set.append(extra)
    return attribute_set


def extract_attributes_from_title(title: str, attribute_keys: list[str]) -> dict[str, str]:
    lowered_title = strip_accents(title).lower()
    attributes: dict[str, str] = {}
    if "color" in attribute_keys:
        for alias_value, normalized_color in COLOR_ALIASES.items():
            if alias_value in lowered_title:
                attributes["color"] = normalized_color
                break
    if "size" in attribute_keys:
        for alias_value, normalized_size in SIZE_ALIASES.items():
            if alias_value in lowered_title:
                attributes["size"] = normalized_size
                break
    if "storage" in attribute_keys:
        matched_storage = re.search(r"(\d+(?:\.\d+)?)\s*(tb|gb|mb)", lowered_title, re.IGNORECASE)
        if matched_storage:
            attributes["storage"] = normalize_storage_value(matched_storage.group(0))
    if "condition" in attribute_keys:
        for alias_value, normalized_condition in CONDITION_ALIASES.items():
            if alias_value in lowered_title:
                attributes["condition"] = normalized_condition
                break
    return attributes


def build_group_key(
    mapped_data: dict[str, Any],
    normalized_title: str,
    brand: str,
    category_slug: str,
) -> tuple[str, float, str]:
    for field_name in GROUPING_FIELD_PRIORITY:
        explicit_value = normalize_whitespace(mapped_data.get(field_name, ""))
        if explicit_value:
            return slugify(explicit_value), 0.99, f"explicit:{field_name}"

    parts = [
        slugify(brand) if brand else "",
        slugify(category_slug),
        slugify(normalized_title),
    ]
    group_key = "-".join(part for part in parts if part)
    return group_key or "ungrouped", 0.62, "heuristic:title-brand-category"


def build_intermediate_record(
    *,
    source_row_id: str,
    row_index: int,
    raw_row: dict[str, Any],
    field_mapping: dict[str, str],
    category_mapping_rules: dict[str, str] | None = None,
    ai_row_suggestion: dict[str, Any] | None = None,
) -> dict[str, Any]:
    mapped_data = {
        field_name: parse_row_value(raw_row, header_name)
        for field_name, header_name in field_mapping.items()
        if normalize_whitespace(header_name)
    }
    warnings: list[str] = []
    errors: list[str] = []
    normalized_title = normalize_whitespace(mapped_data.get("title", ""))
    if not normalized_title:
        errors.append("Missing product title.")
    normalized_description = normalize_whitespace(mapped_data.get("description", "")) or normalized_title or "Imported catalog item."
    price_value = parse_number(mapped_data.get("price", ""))
    if price_value is None or price_value <= 0:
        errors.append("Missing or invalid price.")
        price_value = 0.0
    compare_at_price = parse_number(mapped_data.get("compareAtPrice", "")) or 0.0
    stock_value = parse_int(mapped_data.get("stock", ""))
    if stock_value is None:
        if normalize_whitespace(mapped_data.get("stock", "")):
            errors.append("Stock must be numeric.")
        stock_value = 0
    stock_value = max(0, stock_value)

    brand = normalize_whitespace(mapped_data.get("brand", ""))
    images = normalize_images_value(mapped_data.get("image", ""), mapped_data.get("images", ""))
    if not images:
        warnings.append("Missing product images. Placeholder image will be used.")
        images = [PLACEHOLDER_IMAGE_PATH]

    requested_category = normalize_whitespace(mapped_data.get("category", ""))
    category_rule_key = slugify(requested_category).replace("-", " ")
    category_slug = normalize_whitespace((category_mapping_rules or {}).get(category_rule_key, "")).lower()
    category_confidence = 0.98 if category_slug else 0.0
    category_warnings: list[str] = []
    if not category_slug:
        category_slug, category_confidence, category_warnings = infer_category_from_text(
            requested_category,
            normalized_title,
            normalized_description,
        )
    warnings.extend(category_warnings)

    attribute_keys = attribute_fields_for_record(category_slug)
    extracted_title_attributes = extract_attributes_from_title(normalized_title, attribute_keys)
    normalized_attributes: dict[str, str] = {}
    attribute_warnings: list[str] = []
    for attribute_key in attribute_keys:
        raw_attribute_value = mapped_data.get(attribute_key, "")
        normalized_value = normalize_attribute_value(attribute_key, raw_attribute_value)
        if not normalized_value:
            normalized_value = normalize_attribute_value(attribute_key, extracted_title_attributes.get(attribute_key, ""))
        if normalized_value:
            normalized_attributes[attribute_key] = normalized_value
        elif normalize_whitespace(raw_attribute_value):
            attribute_warnings.append(f"Non-standard {attribute_key} value `{normalize_whitespace(raw_attribute_value)}` kept for review.")

    if ai_row_suggestion:
        suggested_category = normalize_whitespace(ai_row_suggestion.get("suggestedCategory", "")).lower()
        if suggested_category and category_slug == "retail.general":
            category_slug = suggested_category
            warnings.append("AI suggested a more specific category mapping.")
        for attribute_key, attribute_value in (ai_row_suggestion.get("normalizedAttributes") or {}).items():
            if attribute_key not in normalized_attributes and normalize_whitespace(attribute_value):
                normalized_attributes[attribute_key] = normalize_attribute_value(attribute_key, attribute_value)

    warnings.extend(attribute_warnings)

    color_label = normalized_attributes.get("color", "")
    _, storefront_color = normalize_color_value(color_label)
    normalized_size = normalized_attributes.get("size", "")
    if normalized_size:
        normalized_size = normalize_size_value(normalized_size)

    normalized_product_title = normalize_title_for_grouping(
        normalized_title,
        normalized_attributes,
    ) or normalized_title
    brand_from_title = brand or (normalize_whitespace(normalized_title).split(" ", 1)[0] if normalized_title else "")
    group_key, group_confidence, group_strategy = build_group_key(
        mapped_data,
        normalized_product_title,
        brand_from_title,
        category_slug,
    )
    if group_confidence < 0.7:
        warnings.append("Grouping is heuristic and should be reviewed.")

    storefront_mapping = map_category_to_storefront(
        category_slug,
        audience_hint=mapped_data.get("audience", ""),
        product_type_hint=mapped_data.get("productType", ""),
        title=normalized_title,
    )
    if category_slug == "retail.general":
        warnings.append("Category fallbacked to retail.general and should be reviewed before import.")

    variant_data = {
        "sku": normalize_whitespace(mapped_data.get("sku", "")),
        "barcode": normalize_whitespace(mapped_data.get("barcode", "")),
        "price": price_value,
        "compareAtPrice": compare_at_price if compare_at_price > price_value else 0.0,
        "stock": stock_value,
        "attributes": normalized_attributes,
        "image": images[0],
        "sourceVariantKey": normalize_whitespace(mapped_data.get("sourceVariantKey", "")) or source_row_id,
        "size": normalized_size,
        "color": storefront_color,
        "colorLabel": color_label,
    }
    variant_data["key"] = build_variant_key(
        size=normalized_size,
        color=storefront_color,
        attributes=normalized_attributes,
    )
    variant_data["label"] = build_variant_label(
        size=normalized_size,
        color_label=color_label,
        attributes=normalized_attributes,
    )

    parent_data = {
        "sourceProductKey": normalize_whitespace(mapped_data.get("sourceProductKey", "")),
        "groupKey": group_key,
        "title": normalized_product_title or normalized_title,
        "normalizedTitle": slugify(normalized_product_title or normalized_title),
        "brand": brand_from_title,
        "canonicalCategory": category_slug,
        "description": normalized_description,
        "images": images,
        "metadata": {
            "groupStrategy": group_strategy,
            "groupConfidence": group_confidence,
            "requestedCategory": requested_category,
            "storefront": storefront_mapping,
        },
    }

    normalized_data = {
        "sourceRowId": source_row_id,
        "rowIndex": row_index,
        "title": normalized_title,
        "normalizedTitle": normalized_product_title or normalized_title,
        "description": normalized_description,
        "brand": brand_from_title,
        "category": category_slug,
        "storefront": storefront_mapping,
        "price": price_value,
        "compareAtPrice": compare_at_price if compare_at_price > price_value else 0.0,
        "stock": stock_value,
        "images": images,
        "attributes": normalized_attributes,
        "groupKey": group_key,
        "groupConfidence": group_confidence,
        "groupStrategy": group_strategy,
        "sourceProductKey": parent_data["sourceProductKey"],
        "sourceVariantKey": variant_data["sourceVariantKey"],
    }

    return {
        "sourceRowId": source_row_id,
        "rawData": raw_row,
        "mappedData": mapped_data,
        "normalizedData": normalized_data,
        "parentData": parent_data,
        "variantData": variant_data,
        "warnings": warnings,
        "errors": errors,
    }


def summarize_groups(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        group_key = normalize_whitespace(record.get("parentData", {}).get("groupKey", "")) or "ungrouped"
        grouped[group_key].append(record)

    groups: list[dict[str, Any]] = []
    for group_key, items in grouped.items():
        parent_data = dict(items[0].get("parentData") or {})
        variants = [dict(item.get("variantData") or {}) for item in items]
        group_warnings = []
        group_errors = []
        group_confidences = [float(item.get("normalizedData", {}).get("groupConfidence") or 0) for item in items]
        if any(confidence < 0.7 for confidence in group_confidences):
            group_warnings.append("Grouping confidence is low and should be approved manually.")
        duplicate_keys = [key for key, count in Counter(variant["key"] for variant in variants).items() if count > 1]
        if duplicate_keys:
            group_errors.append("Duplicate variants detected inside the same parent group.")

        price_candidates = [float(variant.get("price") or 0) for variant in variants if float(variant.get("price") or 0) > 0]
        compare_candidates = [
            float(variant.get("compareAtPrice") or 0)
            for variant in variants
            if float(variant.get("compareAtPrice") or 0) > float(variant.get("price") or 0)
        ]
        total_stock = sum(max(0, int(variant.get("stock") or 0)) for variant in variants)
        groups.append(
            {
                "groupKey": group_key,
                "parent": {
                    **parent_data,
                    "variantCount": len(variants),
                    "stock": total_stock,
                    "priceRange": {
                        "min": min(price_candidates) if price_candidates else 0,
                        "max": max(price_candidates) if price_candidates else 0,
                    },
                    "compareAtPriceMax": max(compare_candidates) if compare_candidates else 0,
                },
                "variants": variants,
                "warnings": group_warnings,
                "errors": group_errors,
            }
        )

    groups.sort(key=lambda item: item["parent"]["title"].lower())
    return groups


def build_storefront_payloads(groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    storefront_payloads: list[dict[str, Any]] = []
    for group in groups:
        parent = dict(group.get("parent") or {})
        storefront = dict(parent.get("metadata", {}).get("storefront") or {})
        variants = [dict(variant) for variant in list(group.get("variants") or [])]
        total_stock = sum(max(0, int(variant.get("stock") or 0)) for variant in variants)
        price_candidates = [float(variant.get("price") or 0) for variant in variants if float(variant.get("price") or 0) > 0]
        compare_candidates = [
            float(variant.get("compareAtPrice") or 0)
            for variant in variants
            if float(variant.get("compareAtPrice") or 0) > float(variant.get("price") or 0)
        ]
        unique_sizes = sorted(
            {
                normalize_whitespace(variant.get("size", ""))
                for variant in variants
                if normalize_whitespace(variant.get("size", ""))
            }
        )
        unique_colors = sorted(
            {
                normalize_whitespace(variant.get("color", ""))
                for variant in variants
                if normalize_whitespace(variant.get("color", ""))
            }
        )

        variant_inventory = [
            {
                "key": variant["key"],
                "size": normalize_whitespace(variant.get("size", "")),
                "color": normalize_whitespace(variant.get("color", "")),
                "quantity": max(0, int(variant.get("stock") or 0)),
                "label": normalize_whitespace(variant.get("label", "")) or "Standard",
                "price": round(float(variant.get("price") or 0), 2),
                "compareAtPrice": round(float(variant.get("compareAtPrice") or 0), 2),
                "imagePath": normalize_whitespace(variant.get("image", "")) or PLACEHOLDER_IMAGE_PATH,
                "sku": normalize_whitespace(variant.get("sku", "")),
                "barcode": normalize_whitespace(variant.get("barcode", "")),
                "sourceVariantKey": normalize_whitespace(variant.get("sourceVariantKey", "")),
                "attributes": dict(variant.get("attributes") or {}),
                "colorLabel": normalize_whitespace(variant.get("colorLabel", "")),
            }
            for variant in variants
        ]

        storefront_payloads.append(
            {
                "articleNumber": normalize_whitespace(parent.get("sourceProductKey", "")) or normalize_whitespace(variant_inventory[0].get("sku", "")),
                "title": normalize_whitespace(parent.get("title", "")) or "Imported product",
                "description": normalize_whitespace(parent.get("description", "")) or normalize_whitespace(parent.get("title", "")) or "Imported catalog item.",
                "brand": normalize_whitespace(parent.get("brand", "")),
                "gtin": "",
                "mpn": "",
                "material": normalize_whitespace(variant_inventory[0]["attributes"].get("material", "")),
                "weightValue": 0.0,
                "weightUnit": "",
                "metaTitle": normalize_whitespace(parent.get("title", ""))[:120],
                "metaDescription": normalize_whitespace(parent.get("description", ""))[:320],
                "pageSection": storefront.get("pageSection", ""),
                "audience": storefront.get("audience", ""),
                "category": storefront.get("category", ""),
                "productType": storefront.get("productType", ""),
                "size": unique_sizes[0] if len(unique_sizes) == 1 else "",
                "color": unique_colors[0] if len(unique_colors) == 1 else ("shume-ngjyra" if len(unique_colors) > 1 else ""),
                "variantInventory": variant_inventory,
                "imagePath": normalize_whitespace(parent.get("images", [""])[0] if isinstance(parent.get("images"), list) and parent.get("images") else "") or PLACEHOLDER_IMAGE_PATH,
                "imageGallery": list(parent.get("images") or [PLACEHOLDER_IMAGE_PATH]),
                "price": min(price_candidates) if price_candidates else 0.0,
                "compareAtPrice": max(compare_candidates) if compare_candidates else 0.0,
                "saleEndsAt": "",
                "packageAmountValue": 0.0,
                "packageAmountUnit": "",
                "stockQuantity": total_stock,
                "normalizedTitle": normalize_whitespace(parent.get("normalizedTitle", "")),
                "groupKey": normalize_whitespace(parent.get("groupKey", "")),
                "sourceProductKey": normalize_whitespace(parent.get("sourceProductKey", "")),
                "canonicalCategory": normalize_whitespace(parent.get("canonicalCategory", "")),
                "importMetadata": {
                    **dict(parent.get("metadata") or {}),
                    "canonicalCategory": normalize_whitespace(parent.get("canonicalCategory", "")),
                    "groupKey": normalize_whitespace(parent.get("groupKey", "")),
                    "variantCount": len(variant_inventory),
                },
            }
        )
    return storefront_payloads


def build_import_preview(
    *,
    source_type: str,
    headers: list[str],
    rows: list[dict[str, Any]],
    field_mapping: dict[str, str] | None = None,
    category_mapping_rules: dict[str, str] | None = None,
    ai_suggestions: dict[str, Any] | None = None,
) -> dict[str, Any]:
    normalized_source_type = str(source_type or "").strip().lower()
    if normalized_source_type not in SOURCE_TYPES:
        raise ValueError("Unsupported source type.")

    auto_mapping = suggest_field_mappings(headers, rows)
    final_mapping = merge_field_mappings(auto_mapping, field_mapping)
    row_suggestions_by_id = {
        str(item.get("sourceRowId", "")).strip(): item
        for item in list((ai_suggestions or {}).get("rowSuggestions") or [])
        if str(item.get("sourceRowId", "")).strip()
    }

    intermediate_records = [
        build_intermediate_record(
            source_row_id=str(row.get("__sourceRowId", row_index)),
            row_index=row_index,
            raw_row=row,
            field_mapping=final_mapping,
            category_mapping_rules=category_mapping_rules,
            ai_row_suggestion=row_suggestions_by_id.get(str(row.get("__sourceRowId", row_index))),
        )
        for row_index, row in enumerate(rows[:MAX_IMPORT_ROWS], start=2)
    ]
    valid_records = [record for record in intermediate_records if not record["errors"]]
    groups = summarize_groups(valid_records)
    storefront_payloads = build_storefront_payloads(groups)
    hard_error_count = sum(1 for record in intermediate_records if record["errors"])
    warning_count = sum(len(record["warnings"]) for record in intermediate_records) + sum(len(group["warnings"]) for group in groups)
    valid_record_count = sum(1 for record in intermediate_records if not record["errors"])
    invalid_record_count = len(intermediate_records) - valid_record_count

    return {
        "sourceType": normalized_source_type,
        "headers": headers,
        "autoMapping": auto_mapping,
        "fieldMapping": final_mapping,
        "summary": {
            "totalRows": len(intermediate_records),
            "validRows": valid_record_count,
            "invalidRows": invalid_record_count,
            "parentProducts": len(groups),
            "warningsCount": warning_count,
            "hardErrorsCount": hard_error_count,
        },
        "records": intermediate_records,
        "groups": groups,
        "storefrontPayloads": storefront_payloads,
        "categoryAttributeSets": CATEGORY_ATTRIBUTE_SETS,
        "aiSuggestions": ai_suggestions or {
            "detectedFieldMappings": {},
            "rowSuggestions": [],
        },
    }


def update_preview_mapping(
    rows: list[dict[str, Any]],
    headers: list[str],
    *,
    source_type: str,
    field_mapping: dict[str, str],
    category_mapping_rules: dict[str, str] | None = None,
    ai_suggestions: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return build_import_preview(
        source_type=source_type,
        headers=headers,
        rows=rows,
        field_mapping=field_mapping,
        category_mapping_rules=category_mapping_rules,
        ai_suggestions=ai_suggestions,
    )


def resolve_record_path(payload: Any, record_path: str = "") -> list[dict[str, Any]]:
    target = payload
    for segment in [part for part in str(record_path or "").split(".") if part]:
        if isinstance(target, dict):
            target = target.get(segment)
        else:
            target = None
            break
    if isinstance(target, list):
        return [item for item in target if isinstance(item, dict)]
    if isinstance(target, dict):
        candidate_lists = [value for value in target.values() if isinstance(value, list)]
        if len(candidate_lists) == 1 and all(isinstance(item, dict) for item in candidate_lists[0]):
            return list(candidate_lists[0])
    return []


def build_json_rows(payload: Any, record_path: str = "") -> tuple[list[str], list[dict[str, Any]]]:
    records = resolve_record_path(payload, record_path=record_path)
    if not records:
        if isinstance(payload, list) and all(isinstance(item, dict) for item in payload):
            records = list(payload)
        elif isinstance(payload, dict):
            records = [payload]
    headers: list[str] = []
    header_seen: set[str] = set()
    normalized_rows: list[dict[str, Any]] = []
    for index, record in enumerate(records, start=1):
        normalized_row = {"__sourceRowId": str(record.get("id") or record.get("sku") or index)}
        for key, value in record.items():
            normalized_row[str(key)] = value
            if str(key) not in header_seen:
                header_seen.add(str(key))
                headers.append(str(key))
        normalized_rows.append(normalized_row)
    return headers, normalized_rows


def _read_csv_rows(file_bytes: bytes) -> tuple[list[str], list[dict[str, Any]], list[str]]:
    errors: list[str] = []
    if not file_bytes:
        return [], [], ["Import source file is empty."]
    try:
        raw_text = file_bytes.decode("utf-8-sig")
    except UnicodeDecodeError:
        return [], [], ["CSV file must be UTF-8 encoded."]
    if not raw_text.strip():
        return [], [], ["Import source file is empty."]

    reader = csv.DictReader(StringIO(raw_text))
    headers = [str(header or "").strip() for header in list(reader.fieldnames or []) if str(header or "").strip()]
    if not headers:
        return [], [], ["CSV file does not contain headers."]

    rows = []
    for index, row in enumerate(reader, start=1):
        normalized_row = {"__sourceRowId": str(index)}
        normalized_row.update({header: row.get(header, "") for header in headers})
        rows.append(normalized_row)
    return headers, rows, errors


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
    return str(value_node.text).strip() if value_node is not None and value_node.text is not None else ""


def _read_xlsx_rows(file_bytes: bytes) -> tuple[list[str], list[dict[str, Any]], list[str]]:
    if not file_bytes:
        return [], [], ["Import source file is empty."]
    try:
        workbook_archive = zipfile.ZipFile(BytesIO(file_bytes))
    except zipfile.BadZipFile:
        return [], [], ["XLSX file could not be read."]

    with workbook_archive:
        try:
            worksheet_xml = workbook_archive.read("xl/worksheets/sheet1.xml")
        except KeyError:
            return [], [], ["XLSX file does not contain a readable first worksheet."]

        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in workbook_archive.namelist():
            shared_root = ET.fromstring(workbook_archive.read("xl/sharedStrings.xml"))
            for node in shared_root.findall(f".//{{{OOXML_SPREADSHEET_NS}}}si"):
                shared_strings.append("".join(text for text in node.itertext()).strip())

    worksheet_root = ET.fromstring(worksheet_xml)
    row_nodes = worksheet_root.findall(f".//{{{OOXML_SPREADSHEET_NS}}}sheetData/{{{OOXML_SPREADSHEET_NS}}}row")
    if not row_nodes:
        return [], [], ["XLSX file is empty."]

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
        return [], [], ["XLSX file is empty."]
    headers = [normalize_whitespace(value) for value in extracted_rows[0] if normalize_whitespace(value)]
    if not headers:
        return [], [], ["XLSX file does not contain headers."]

    rows: list[dict[str, Any]] = []
    for index, row_values in enumerate(extracted_rows[1:], start=1):
        normalized_row = {"__sourceRowId": str(index)}
        for header_index, header in enumerate(headers):
            normalized_row[header] = row_values[header_index] if header_index < len(row_values) else ""
        rows.append(normalized_row)
    return headers, rows, []


class BaseCatalogSourceAdapter:
    source_type = ""

    def parse(self, payload: Any, **kwargs) -> dict[str, Any]:
        raise NotImplementedError


class CsvCatalogSourceAdapter(BaseCatalogSourceAdapter):
    source_type = "csv"

    def parse(self, payload: Any, **kwargs) -> dict[str, Any]:
        headers, rows, errors = _read_csv_rows(bytes(payload or b""))
        return {"sourceType": self.source_type, "headers": headers, "rows": rows, "errors": errors}


class XlsxCatalogSourceAdapter(BaseCatalogSourceAdapter):
    source_type = "xlsx"

    def parse(self, payload: Any, **kwargs) -> dict[str, Any]:
        headers, rows, errors = _read_xlsx_rows(bytes(payload or b""))
        return {"sourceType": self.source_type, "headers": headers, "rows": rows, "errors": errors}


class JsonCatalogSourceAdapter(BaseCatalogSourceAdapter):
    source_type = "json"

    def parse(self, payload: Any, **kwargs) -> dict[str, Any]:
        record_path = str(kwargs.get("record_path", "") or "").strip()
        headers, rows = build_json_rows(payload, record_path=record_path)
        errors = [] if rows else ["JSON source does not contain usable product records."]
        return {"sourceType": self.source_type, "headers": headers, "rows": rows, "errors": errors}


class ApiJsonCatalogSourceAdapter(BaseCatalogSourceAdapter):
    source_type = "api-json"

    def parse(self, payload: Any, **kwargs) -> dict[str, Any]:
        api_config = dict(payload or {})
        source_url = normalize_whitespace(api_config.get("url", ""))
        if not source_url.startswith("http://") and not source_url.startswith("https://"):
            return {"sourceType": self.source_type, "headers": [], "rows": [], "errors": ["API source URL is not valid."]}

        request_headers = {
            str(header_name): str(header_value)
            for header_name, header_value in dict(api_config.get("headers") or {}).items()
            if normalize_whitespace(header_name)
        }
        request_payload = api_config.get("body")
        request_method = normalize_whitespace(api_config.get("method", "GET")).upper() or "GET"
        data = None
        if request_payload is not None:
            data = json.dumps(request_payload).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
        request = Request(source_url, data=data, headers=request_headers, method=request_method)
        try:
            with urlopen(request, timeout=12) as response:
                response_payload = json.loads(response.read().decode("utf-8"))
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as error:
            return {
                "sourceType": self.source_type,
                "headers": [],
                "rows": [],
                "errors": [f"API source could not be fetched: {error}"],
            }

        record_path = str(api_config.get("recordPath", "") or "").strip()
        headers, rows = build_json_rows(response_payload, record_path=record_path)
        errors = [] if rows else ["API response does not contain usable product records."]
        return {
            "sourceType": self.source_type,
            "headers": headers,
            "rows": rows,
            "errors": errors,
        }


SOURCE_ADAPTERS = {
    "csv": CsvCatalogSourceAdapter(),
    "xlsx": XlsxCatalogSourceAdapter(),
    "json": JsonCatalogSourceAdapter(),
    "api-json": ApiJsonCatalogSourceAdapter(),
}


def parse_catalog_source(
    source_type: str,
    payload: Any,
    *,
    record_path: str = "",
) -> dict[str, Any]:
    normalized_source_type = str(source_type or "").strip().lower()
    adapter = SOURCE_ADAPTERS.get(normalized_source_type)
    if adapter is None:
        return {"sourceType": normalized_source_type, "headers": [], "rows": [], "errors": ["Unsupported source type."]}
    return adapter.parse(payload, record_path=record_path)
