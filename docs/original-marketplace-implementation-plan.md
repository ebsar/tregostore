# Original Marketplace UI Implementation Plan

## What is already in progress

### 1. Global design system
- Central tokens live in `src/styles/design-system.css`
- Shared roles:
  - navigation / trust: `--color-navigation`
  - primary action: `--color-primary-action`
  - surface / cards / borders / spacing / radius / shadows
- Base layout utilities added:
  - `page-shell`
  - `page-main`
  - `page-main-home`
  - `market-button`
  - `market-pill`
  - `market-card`
  - `market-section-title`

### 2. Shared public shell
- `src/App.vue`
- New responsibilities:
  - stable app shell
  - floating toast pattern
  - refined footer container
  - consistent layout width and padding

### 3. Public discovery header
- `src/components/CommerceHeader.vue`
- Converted into a reusable command deck:
  - promo rail
  - meta rail
  - brand + search + actions
  - quick navigation rail
  - mobile sheet
  - overlay wrappers for account/cart/wishlist/track

### 4. Discovery component system
- `src/components/MarketSectionTitle.vue`
- `src/components/ProductCard.vue`
- `src/components/RecommendationSections.vue`

## Phase map

### Phase A: Discovery layer
Goal: make the public storefront feel original, product-first, and fast to scan.

Files:
- `src/views/HomePage.vue`
- `src/components/ProductCard.vue`
- `src/components/RecommendationSections.vue`

Sections:
- Hero stage
- Deal current
- Category stream
- Feature board
- Decision grid

### Phase B: Exploration layer
Goal: rebuild search/listing into a lens-based exploration interface.

Files to target next:
- `src/views/SearchPage.vue`
- filter/sidebar components connected to product search

Work:
- compact adaptive filter rail
- sticky exploration controls
- fast preview / compare affordances
- denser product grid and paging states

### Phase C: Product detail layer
Goal: create a focused product stage with trust signals and direct action zone.

Files to target next:
- `src/views/ProductDetailPage.vue`
- supporting gallery / recommendation widgets

Work:
- large media stage
- compact seller / shipping / trust block
- persistent CTA cluster
- lighter supporting content layout

### Phase D: Transaction layer
Goal: simplify cart + checkout into one clean decision flow.

Files to target next:
- `src/views/CartPage.vue`
- `src/views/CheckoutAddressPage.vue`
- `src/views/PaymentOptionsPage.vue`
- header cart overlays

Work:
- instant summary state
- one-page visual grouping
- strong CTA emphasis
- cleaner empty / loading / retry states

### Phase E: User workspace
Goal: convert account surfaces into a compact personal command deck.

Files to target next:
- `src/views/AccountDashboardPage.vue`
- `src/views/OrdersPage.vue`
- `src/views/WishlistPage.vue`
- `src/views/ProductComparePage.vue`
- `src/views/SettingsPage.vue`

Work:
- stable shared dashboard frame
- compact content panels
- denser list/table blocks
- common internal section header component

### Phase F: Vendor workspace
Goal: rebuild seller tools as a cleaner operations canvas.

Files to target next:
- `src/views/BusinessDashboardPage.vue`
- business subcomponents under `src/components/`

Work:
- product operations
- inventory panels
- order stream
- compact analytics summary cards

### Phase G: Admin control center
Goal: modular control grid instead of heavy dashboard chrome.

Files to target next:
- `src/views/AdminDashboardPage.vue`
- admin products / businesses / orders pages

Work:
- fast action panels
- moderation queues
- compact table surfaces
- reusable admin section shell

## Component rules

### Buttons
- Orange only for primary actions
- Blue/nav tone for trust and navigation
- Secondary buttons stay light and quiet

### Cards
- Product cards must always prioritize:
  1. image
  2. title
  3. price
  4. action

### Section titles
- Use `MarketSectionTitle.vue`
- Keep copy short
- Use action link only when it improves discovery

### Overlays
- Same rounded/glassy white panel language
- Keep max widths controlled
- No full-page visual clutter inside panels

## Technical rules for the next refactors
- Keep backend logic untouched unless performance requires otherwise
- Keep API/data flow in current stores and service helpers
- Prefer re-skinning and re-structuring existing components before creating duplicate variants
- Keep loading states local to each panel or section
- Preserve pagination and current product data flow while improving layout
