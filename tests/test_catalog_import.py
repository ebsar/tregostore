import json
import unittest
from pathlib import Path

import catalog_import


FIXTURES_DIR = Path(__file__).parent / "fixtures" / "catalog_import"


def read_bytes(name: str) -> bytes:
    return (FIXTURES_DIR / name).read_bytes()


def read_json(name: str):
    return json.loads((FIXTURES_DIR / name).read_text(encoding="utf-8"))


class CatalogImportPipelineTests(unittest.TestCase):
    def test_boutique_csv_groups_parent_and_variants(self):
      parsed_source = catalog_import.parse_catalog_source("csv", read_bytes("boutique.csv"))
      self.assertEqual(parsed_source["errors"], [])

      preview = catalog_import.build_import_preview(
          source_type=parsed_source["sourceType"],
          headers=parsed_source["headers"],
          rows=parsed_source["rows"],
      )

      self.assertEqual(preview["summary"]["validRows"], 2)
      self.assertEqual(preview["summary"]["parentProducts"], 1)
      self.assertEqual(len(preview["groups"]), 1)
      self.assertEqual(preview["groups"][0]["parent"]["canonicalCategory"], "clothing.tshirts")
      self.assertEqual(len(preview["groups"][0]["variants"]), 2)
      self.assertEqual(len(preview["storefrontPayloads"][0]["variantInventory"]), 2)

    def test_mobile_csv_normalizes_storage_and_phone_category(self):
      parsed_source = catalog_import.parse_catalog_source("csv", read_bytes("mobile_shop.csv"))
      self.assertEqual(parsed_source["errors"], [])

      preview = catalog_import.build_import_preview(
          source_type=parsed_source["sourceType"],
          headers=parsed_source["headers"],
          rows=parsed_source["rows"],
      )

      self.assertEqual(preview["summary"]["validRows"], 2)
      self.assertEqual(preview["summary"]["parentProducts"], 1)
      self.assertEqual(preview["groups"][0]["parent"]["canonicalCategory"], "electronics.phones")
      storage_values = {
          variant["attributes"].get("storage")
          for variant in preview["groups"][0]["variants"]
      }
      self.assertEqual(storage_values, {"128GB", "512GB"})

    def test_thrift_json_keeps_category_specific_attributes(self):
      parsed_source = catalog_import.parse_catalog_source("json", read_json("thrift.json"))
      self.assertEqual(parsed_source["errors"], [])

      preview = catalog_import.build_import_preview(
          source_type=parsed_source["sourceType"],
          headers=parsed_source["headers"],
          rows=parsed_source["rows"],
      )

      self.assertEqual(preview["summary"]["validRows"], 2)
      self.assertEqual(preview["summary"]["parentProducts"], 1)
      self.assertEqual(preview["groups"][0]["parent"]["canonicalCategory"], "thrift.apparel")
      first_variant_attributes = preview["groups"][0]["variants"][0]["attributes"]
      self.assertEqual(first_variant_attributes.get("condition"), "Very Good")
      self.assertEqual(str(first_variant_attributes.get("era", "")).lower(), "90s")
      self.assertEqual(first_variant_attributes.get("material"), "Denim")


if __name__ == "__main__":
    unittest.main()
