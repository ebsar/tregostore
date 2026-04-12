# Catalog Import Migration Notes

## What changed

The old product importer treated each spreadsheet row as a final storefront product and hard-failed on many non-exact values. The new importer now stages every source into a canonical import pipeline before touching the `products` table.

New pipeline:

1. source ingestion
2. parsing
3. field mapping
4. normalization
5. category mapping
6. grouping / parent-variant detection
7. validation
8. preview
9. final import
10. optional sync for API feeds

## New backend module

- [`catalog_import.py`](/Users/ebsarhoxha/Documents/Playground/catalog_import.py)

This module now contains:

- source adapters for `csv`, `xlsx`, `json`, and `api-json`
- canonical intermediate records with `rawData`, `mappedData`, `normalizedData`, warnings, and errors
- layered validation instead of rigid enum-only validation
- normalization for color, size, storage, condition, volume, dimensions, and boolean-style values
- category alias mapping and title/description hints
- category-specific attribute sets
- parent + variant grouping and storefront payload generation
- AI suggestion schema contracts for structured enrichment

## Schema changes

Updated tables:

- `products`
  - `normalized_title`
  - `group_key`
  - `source_id`
  - `source_product_key`
  - `import_metadata`

New tables:

- `catalog_import_profiles`
- `catalog_import_sources`
- `catalog_import_jobs`
- `catalog_import_job_records`

These support:

- saved mapping profiles per business
- reusable API / JSON source connectors
- preview jobs and row-level staging
- commit/sync history

## New API endpoints

Configuration:

- `GET /api/business/catalog-import/config`

Preview / staging:

- `POST /api/business/catalog-import/preview`

Commit:

- `POST /api/business/catalog-import/commit`

Saved mapping profiles:

- `POST /api/business/catalog-import/profile`

Saved source connectors:

- `POST /api/business/catalog-import/source`

Source sync preview:

- `POST /api/business/catalog-import/sync`

## Compatibility notes

- The old quick-start template download remains available:
  - `GET /api/business/products/import-template`
- The new UI is intended to replace the rigid direct-import path for real business workflows.
- Existing storefront product rendering was kept compatible by importing grouped parent products into the existing `products` table with richer `variant_inventory`.

## Import behavior changes

Hard errors now only block rows that are truly unusable, such as:

- missing minimum product identity
- invalid price / stock types
- broken or incomplete parent/variant records

Warnings are now used for:

- unknown categories
- unknown colors / sizes / storage values
- ambiguous grouping
- non-standard but understandable business values

## AI layer

The importer now supports structured AI suggestions for:

- header mapping suggestions
- category suggestions
- normalized attributes
- grouping suggestions
- ambiguity warnings

Important rule:

- AI does not write directly to the database.
- AI suggestions only assist preview and review.

## Frontend changes

Updated business dashboard import flow:

- source type selector
- CSV/XLSX upload
- JSON payload preview
- API source connector form
- dynamic field mapping UI
- grouping preview
- row-level warnings/errors
- saved profiles
- saved source connectors
- staged commit

## Verification

Current verification added:

- `python3 -m py_compile app.py catalog_import.py tests/test_catalog_import.py`
- `python3 -m unittest tests.test_catalog_import`
- `npm run build`

## Fixture coverage

Added fixtures and tests for:

- boutique / fashion CSV
- mobile shop / electronics CSV
- thrift JSON catalog
