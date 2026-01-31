# PayroPOS - Progress Tracker

> Use this file to track your implementation progress. Update checkboxes as you complete tasks.

---

## Quick Status

| Phase | Progress | Status |
|-------|----------|:------:|
| Phase 1: Foundation | 39/42 | 🔄 In Progress |
| Phase 2: Product Management | 31/34 | 🔄 In Progress |
| Phase 3: Core POS | 27/30 | 🔄 In Progress |
| Phase 4: Customer & Credit | 0/25 | ⬜ Not Started |
| Phase 5: Staff Management | 10/17 | 🔄 In Progress |
| Phase 6: Reporting | 0/19 | ⬜ Not Started |
| Phase 7: Polish | 5/20 | 🔄 In Progress |
| **TOTAL** | **112/187** | **~60%** |

**Legend:**
- ⬜ Not Started
- 🔄 In Progress
- ✅ Completed
- ⏸️ On Hold

---

## Phase 1: Foundation

**Status:** 🔄 In Progress
**Started:** 2025-01-29
**Completed:** -

### 1.1 Project Setup

- [x] 1.1.1 Create Flutter project with recommended structure
- [x] 1.1.2 Create Next.js project with App Router
- [ ] 1.1.3 Setup Firebase project (Firestore, Auth, Storage) ⚠️ *Manual step required*
- [ ] 1.1.4 Configure Firebase for Flutter (google-services.json) ⚠️ *Manual step required*
- [x] 1.1.5 Configure Firebase for Next.js (environment variables)
- [x] 1.1.6 Setup Git repository with proper .gitignore
- [x] 1.1.7 Create shared constants and theme configuration

### 1.2 Authentication

- [x] 1.2.1 Implement email/password signup (Flutter)
- [x] 1.2.2 Implement email/password login (Flutter)
- [x] 1.2.3 Implement email verification flow
- [x] 1.2.4 Implement password reset
- [x] 1.2.5 Create user document in Firestore on signup
- [x] 1.2.6 Implement role-based navigation
- [x] 1.2.7 Protected routes and auth state management
- [x] 1.2.8 Refresh user data method (for post-setup updates)
- [ ] 1.2.9 Implement auth for Next.js (Web Admin)

### 1.3 Store Onboarding

- [x] 1.3.1 Design store setup wizard UI
- [x] 1.3.2 Store/Brand name and business type form
- [x] 1.3.3 Single/Multiple location selection
- [x] 1.3.4 Location name input (for multi-location)
- [x] 1.3.5 Location address and phone form
- [ ] 1.3.6 Store logo upload to Firebase Storage
- [x] 1.3.7 Auto-set business settings (currency, tax rate)
- [x] 1.3.8 Save store document to Firestore
- [x] 1.3.9 Create first location document
- [x] 1.3.10 Update user document with storeId & locationId
- [x] 1.3.11 Redirect to dashboard after setup

### 1.4 Store Settings (Post-Onboarding)

- [x] 1.4.1 Store settings screen
- [x] 1.4.2 Edit business details (name, type)
- [x] 1.4.3 View locations list
- [x] 1.4.4 Enable multiple locations (upgrade from single)
- [x] 1.4.5 Add new location screen
- [x] 1.4.6 Edit location screen
- [x] 1.4.7 Set default location
- [x] 1.4.8 Store provider with state management
- [x] 1.4.9 Business settings (tax rate editing)
- [x] 1.4.10 Currency selection (15+ currencies supported)
- [x] 1.4.11 Receipt footer customization
- [x] 1.4.12 POS settings (require quantity input toggle)

### 1.5 Home Screen / Dashboard

- [x] 1.5.1 User profile card (avatar, first name, role badge)
- [x] 1.5.2 Current store/location indicator card
- [x] 1.5.3 Quick link to store settings from store card (long press)
- [x] 1.5.4 Warning prompt if no store setup
- [x] 1.5.5 Navigation to store setup from home
- [x] 1.5.6 Back/home navigation on store setup screen
- [x] 1.5.7 Location switcher (tap store card for multi-location stores)

### Phase 1 Checkpoint

**Before moving to Phase 2, verify:**

- [ ] User can sign up with email/password
- [ ] User receives verification email
- [ ] User can log in after verification
- [ ] User can reset password
- [ ] Store owner can complete store setup wizard
- [ ] Store owner can choose single or multiple locations
- [ ] First location created with store
- [ ] Store and location data persisted to Firestore
- [ ] Store settings accessible from home screen
- [ ] Can edit business details after setup
- [ ] Can upgrade from single to multiple locations
- [ ] Can add new locations
- [ ] Basic navigation structure working

**Notes:**
```
(Add any notes, blockers, or decisions made during this phase)


```

---

## Phase 2: Product Management

**Status:** 🔄 In Progress
**Started:** 2026-01-29
**Completed:** -

### 2.1 Category Management

- [x] 2.1.1 Category list screen
- [x] 2.1.2 Create category form/dialog
- [x] 2.1.3 Edit category
- [x] 2.1.4 Delete category (with confirmation)
- [x] 2.1.5 Drag-to-reorder categories
- [x] 2.1.6 Category CRUD in Firestore
- [x] 2.1.7 Subcategories support (for brands under categories)
- [x] 2.1.8 Add subcategory dialog
- [x] 2.1.9 Expandable category tiles showing subcategories
- [x] 2.1.10 Delete category cascades to subcategories
- [x] 2.1.11 Product model updated with subcategoryId field
- [x] 2.1.12 Separate category/subcategory dropdowns in product forms
- [x] 2.1.13 Separate category/subcategory filter chips in products & POS screens

### 2.2 Product Management

- [x] 2.2.1 Product list screen with search
- [x] 2.2.2 Filter products by category (filter chips)
- [x] 2.2.3 Create product form
- [x] 2.2.4 Product image upload (Cloudinary)
- [x] 2.2.5 Edit product
- [x] 2.2.6 Delete product (soft delete - isActive)
- [x] 2.2.7 Product CRUD in Firestore
- [x] 2.2.8 Implement product grid and list view toggle
- [x] 2.2.9 Category dropdown in add/edit product forms

### 2.3 Barcode Integration

- [x] 2.3.1 Integrate mobile_scanner package
- [x] 2.3.2 Camera permission handling
- [x] 2.3.3 Barcode scan screen
- [x] 2.3.4 Scan barcode and auto-fill product form
- [ ] 2.3.5 Generate QR code for each product
- [ ] 2.3.6 Display QR code on product detail
- [ ] 2.3.7 Print product label (QR + name + price)

### 2.4 Location-Based Inventory

- [x] 2.4.1 Stock quantity field per location in product form
- [x] 2.4.2 Display stock for current location on product list
- [x] 2.4.3 Low stock indicator (configurable threshold per product)
- [x] 2.4.4 Low stock alert/badge (in products list header)
- [x] 2.4.5 Location switcher on home screen (tap store card)
- [ ] 2.4.6 Stock transfer between locations

### 2.5 Restocking Feature

- [x] 2.5.1 Disable direct stock editing in edit product screen
- [x] 2.5.2 Restock screen with product info and location selector
- [x] 2.5.3 Quantity input with quick buttons (+10, +25, +50, +100)
- [x] 2.5.4 Notes field for restock reason/supplier info
- [x] 2.5.5 Stock history tracking with timestamps
- [x] 2.5.6 User attribution for restock entries
- [x] 2.5.7 Stock history display on restock screen

### Phase 2 Checkpoint

**Before moving to Phase 3, verify:**

- [x] Categories can be created, edited, deleted, reordered
- [x] Products can be created with all fields
- [x] Product images upload and display correctly
- [x] Barcode scanning works to add products
- [ ] QR codes generated for products
- [x] Stock tracking with low stock alerts (per location)
- [x] Filter products by category
- [x] Location-based inventory tracking

**Notes:**
```
2026-01-29: Implemented core product management with barcode scanning.
Features completed:
- Product CRUD (Create, Read, Update, Delete)
- Product list with grid/list view toggle
- Search functionality
- Barcode/QR scanning via mobile camera (mobile_scanner package)
- Manual barcode input option
- Product image upload to Cloudinary
- Stock quantity tracking
- Low stock threshold (configurable per product in edit screen)
- Low stock alert badge in products header
- Navigation from home screen to products

2026-01-29: Added category management and location-based inventory.
New features:
- Full category CRUD (create, edit, delete, reorder)
- Filter products by category (filter chips in products screen)
- Category dropdown in add/edit product forms
- Location-based inventory tracking:
  * Product model changed from single 'stock' to 'stockByLocation' map
  * Each location tracks its own inventory independently
  * Products shared across all locations in a store
  * Stock displayed for current location
  * Low stock alerts per location
- Location switcher on home screen (tap store card)

Still pending:
- QR code generation for products
- Print product labels
- Stock transfer between locations
```

---

## Phase 3: Core POS Functionality

**Status:** 🔄 In Progress
**Started:** 2026-01-29
**Completed:** -

### 3.1 POS Screen

- [x] 3.1.1 POS screen layout (product grid + cart)
- [x] 3.1.2 Product grid by category tabs
- [x] 3.1.3 Product search in POS
- [x] 3.1.4 Tap product to add to cart
- [x] 3.1.5 Integrate barcode scanning in POS
- [x] 3.1.6 Scan to add product to cart
- [x] 3.1.7 Haptic feedback on product tap

### 3.2 Shopping Cart

- [x] 3.2.1 Cart state management (CartNotifier with Riverpod)
- [x] 3.2.2 Display cart items with quantities
- [x] 3.2.3 Increase/decrease item quantity
- [x] 3.2.4 Remove item from cart (swipe to delete)
- [x] 3.2.5 Auto-calculate subtotal
- [x] 3.2.6 Auto-calculate tax (12% default)
- [x] 3.2.7 Display total
- [x] 3.2.8 Clear cart button
- [x] 3.2.9 Tap quantity to edit directly
- [x] 3.2.10 Quantity input dialog after barcode scan (configurable via store settings)
- [x] 3.2.11 Out of stock alert when adding products with zero stock
- [x] 3.2.12 Cart modal (replaced buggy draggable sheet with proper modal)
- [ ] 3.2.13 Cart persistence (survive app close)

### 3.3 Checkout (Cash Only)

- [x] 3.3.1 Checkout screen
- [x] 3.3.2 Amount received input with numpad
- [x] 3.3.3 Quick amount buttons (Exact, 200, 500, 1000)
- [x] 3.3.4 Calculate and display change
- [x] 3.3.5 Validate sufficient payment
- [x] 3.3.6 Complete transaction
- [x] 3.3.7 Save transaction to Firestore
- [x] 3.3.8 Decrease product stock on sale
- [x] 3.3.9 Generate receipt number (INV-YYYY-NNNN)

### 3.4 Receipt Generation

- [x] 3.4.1 Receipt screen with transaction details
- [ ] 3.4.2 PDF receipt generation
- [x] 3.4.3 Share receipt (native share text)
- [ ] 3.4.4 Receipt QR code (links to digital receipt)
- [ ] 3.4.5 Transaction history list
- [ ] 3.4.6 View past receipt

### Phase 3 Checkpoint

**Before moving to Phase 4, verify:**

- [x] Full POS screen with product grid and cart
- [x] Barcode/QR scanning adds products to cart
- [x] Cart calculations work correctly
- [x] Cash checkout flow complete
- [x] Transactions saved to database
- [x] Stock decremented on sale
- [ ] PDF receipts can be generated and shared

**Notes:**
```
2026-01-29: Implemented core POS functionality (MVP).

Files created:
- lib/shared/providers/cart_provider.dart - Cart state management
- lib/shared/providers/transaction_provider.dart - Transaction operations
- lib/features/pos/presentation/screens/pos_screen.dart - Main POS screen
- lib/features/pos/presentation/screens/checkout_screen.dart - Checkout flow
- lib/features/pos/presentation/screens/receipt_screen.dart - Receipt display

Features implemented:
- POS screen with product grid and category filters
- Product search in POS
- Barcode scanning to add products
- Draggable cart panel at bottom
- Cart with quantity controls, subtotal, tax, total
- Swipe-to-delete cart items
- Checkout screen with numpad input
- Quick amount buttons (Exact, 200, 500, 1000)
- Change calculation
- Transaction saved to Firestore
- Stock automatically decreased per location
- Receipt screen with share functionality
- Home screen "New Sale" buttons now connected
- Today's Summary shows real transaction data

2026-01-29: Enhanced cart and settings features.
New features:
- Tax rate editing in store settings
- Improved cart item layout (image+name left, quantity controls right)
- Tap quantity to show edit dialog (directly input quantity)
- Quantity input dialog after barcode scan (enter qty before adding)
- Fixed tax rate storage (stored as decimal 0.12, not 12.0)
- Fixed tax rate display in settings (show as 12% not 1200%)

Pending:
- PDF receipt generation
- Receipt QR code
- Transaction history screen
- Cart persistence across app restarts
- Currency and receipt footer settings

2026-01-31: POS improvements and Restocking feature.
New features:
- Cart modal: Replaced buggy DraggableScrollableSheet with proper modal dialog
  * Fixed swipe-up issues on some devices
  * Cart summary bar at bottom with "View Cart" button
  * Full modal shows cart items, totals, and checkout button

- Require Quantity Input setting:
  * Toggle in Store Settings > POS Settings
  * When enabled: Shows quantity dialog on every product tap/scan
  * When disabled: Products added directly to cart (qty 1)

- Out of Stock Alert:
  * Shows dialog when trying to add out-of-stock products
  * Prevents adding zero-stock items to cart
  * Works for both product tap and barcode scan

- Restocking Feature (multi-location aware):
  * Disabled direct stock editing in edit product screen
  * New restock screen with product info and location selector
  * Shows current stock for selected location
  * Quantity input with quick buttons (+10, +25, +50, +100)
  * Optional notes field for tracking reason/supplier
  * Stock history tracking with:
    - Timestamp of each restock
    - Previous and new stock values
    - Location where restocked
    - User who performed the restock
    - Notes/reason
  * History displayed on restock screen

Files created:
- lib/shared/providers/stock_provider.dart - Stock history model & provider
- lib/features/products/presentation/screens/restock_screen.dart - Restock UI

Files modified:
- lib/features/pos/presentation/screens/pos_screen.dart - Cart modal, out of stock alert, quantity setting check
- lib/features/store/presentation/screens/store_settings_screen.dart - POS settings toggle
- lib/shared/providers/store_provider.dart - requireQuantityInputProvider
- lib/features/products/presentation/screens/edit_product_screen.dart - Disabled stock editing, added restock button
- lib/core/router/app_router.dart - Added restock route

2026-01-31: Currency, Receipt Footer, and Subcategories.
New features:

1. Currency Selection:
   - Currency dialog in Store Settings > Business Settings
   - 15 currencies supported: PHP, USD, EUR, GBP, JPY, CNY, KRW, SGD, MYR, THB, VND, IDR, INR, AUD, CAD
   - Saves currency code and symbol to store settings

2. Receipt Footer:
   - Editable receipt footer message in Store Settings
   - Max 200 characters
   - Quick suggestion chips for common messages
   - Saved to store settings

3. Subcategories (Brands):
   - Categories now support subcategories (parentId field)
   - Use case: Category "Milk" -> Subcategories "Alaska", "Bear Brand", "Nestle"
   - Category model updated with parentId, isTopLevel, isSubcategory
   - Product model updated with subcategoryId field
   - Categories screen updated:
     * Expandable tiles show subcategories
     * Add subcategory button on each category
     * Folder icon for categories with subcategories
     * Label icon for subcategories
     * Delete category cascades to delete subcategories
   - New providers: topLevelCategoriesProvider, subcategoriesProvider, allSubcategoriesProvider

4. Separate Category/Subcategory Dropdowns in Product Forms:
   - Category dropdown now only shows top-level categories (not subcategories)
   - Subcategory dropdown appears below category dropdown when:
     * A category is selected AND
     * That category has subcategories
   - Changing category clears the selected subcategory
   - Product model stores both categoryId and subcategoryId
   - addProduct method updated to accept subcategoryId parameter
   - Fixed name collision between Flutter's Category annotation and our Category model
   - Edit product screen handles legacy data where categoryId might point to a subcategory

5. Category/Subcategory Filter Chips in Products & POS Screens:
   - Filter chips now only show top-level categories
   - Subcategory filter row appears below when a category is selected
   - Subcategories use secondary color to visually distinguish from parent categories
   - Changing category clears subcategory selection
   - Filter logic updated to handle both category and subcategory filtering

Files modified:
- lib/features/store/presentation/screens/store_settings_screen.dart - Currency & receipt footer dialogs
- lib/shared/providers/product_provider.dart - Category & Product models, subcategory support, addProduct subcategoryId
- lib/features/products/presentation/screens/categories_screen.dart - Subcategory UI
- lib/features/products/presentation/screens/add_product_screen.dart - Separate category/subcategory dropdowns
- lib/features/products/presentation/screens/edit_product_screen.dart - Separate category/subcategory dropdowns, legacy data handling
- lib/features/products/presentation/screens/products_screen.dart - Separate category/subcategory filter chips
- lib/features/pos/presentation/screens/pos_screen.dart - Separate category/subcategory filter chips
```

---

## Phase 4: Customer & Credit System

**Status:** ⬜ Not Started
**Started:** -
**Completed:** -

### 4.1 Customer Management

- [ ] 4.1.1 Customer list screen
- [ ] 4.1.2 Customer search (by name, phone)
- [ ] 4.1.3 Add customer form
- [ ] 4.1.4 Edit customer
- [ ] 4.1.5 Delete customer (with balance check)
- [ ] 4.1.6 Customer profile/detail screen
- [ ] 4.1.7 Customer CRUD in Firestore

### 4.2 Credit System

- [ ] 4.2.1 Credit limit field in customer form
- [ ] 4.2.2 Display credit balance on customer profile
- [ ] 4.2.3 Customer selection at checkout
- [ ] 4.2.4 "Credit" payment method option
- [ ] 4.2.5 Validate credit limit before approval
- [ ] 4.2.6 Update customer creditBalance on credit sale
- [ ] 4.2.7 Show available credit during checkout
- [ ] 4.2.8 Deny credit if over limit

### 4.3 Credit Management

- [ ] 4.3.1 Credit transaction history per customer
- [ ] 4.3.2 Record payment screen/dialog
- [ ] 4.3.3 Full payment option
- [ ] 4.3.4 Partial payment option
- [ ] 4.3.5 Update creditBalance on payment
- [ ] 4.3.6 Save creditPayment to Firestore
- [ ] 4.3.7 List customers with outstanding balance
- [ ] 4.3.8 Sort by balance amount

### 4.4 Notifications

- [ ] 4.4.1 SMS reminder link (opens SMS app)
- [ ] 4.4.2 WhatsApp reminder link
- [ ] 4.4.3 Credit limit warning during sale

### Phase 4 Checkpoint

**Before moving to Phase 5, verify:**

- [ ] Customer database with full CRUD
- [ ] Credit limits per customer
- [ ] Credit payment option at checkout
- [ ] Credit limit validation
- [ ] Payment recording
- [ ] Outstanding balance tracking
- [ ] Payment reminder links

**Notes:**
```
(Add any notes, blockers, or decisions made during this phase)


```

---

## Phase 5: Staff Management

**Status:** 🔄 In Progress
**Started:** 2026-01-31
**Completed:** -

### 5.1 Staff Management

- [x] 5.1.1 Staff list screen (store owner only)
- [x] 5.1.2 Invite staff form (email)
- [ ] 5.1.3 Send invitation email (Firebase Function)
- [x] 5.1.4 Staff accepts invitation flow (auto-join if user exists)
- [x] 5.1.5 Set staff PIN for quick login
- [x] 5.1.6 Staff permissions settings (location assignment)
- [x] 5.1.7 Remove staff from store (deactivate)
- [x] 5.1.8 Staff CRUD in Firestore

### 5.2 Staff Operations

- [ ] 5.2.1 Staff login screen (email or PIN)
- [ ] 5.2.2 PIN numpad interface
- [x] 5.2.3 Link transactions to current staff
- [ ] 5.2.4 Staff can only view own transactions
- [x] 5.2.5 Staff limited dashboard (POS-only access)

### 5.3 Clock In/Out (Optional)

- [ ] 5.3.1 Clock in button
- [ ] 5.3.2 Clock out button
- [ ] 5.3.3 Track working hours
- [ ] 5.3.4 Timesheet report

### Phase 5 Checkpoint

**Before moving to Phase 6, verify:**

- [x] Staff invitation and onboarding
- [ ] Staff PIN login
- [x] Staff permissions working
- [x] Transactions attributed to staff
- [ ] Staff can only see own transactions

**Notes:**
```
2026-01-31: Implemented core staff management.

Files created:
- lib/shared/providers/staff_provider.dart - Staff model, provider, CRUD operations
- lib/features/staff/presentation/screens/staff_list_screen.dart - Staff list with tabs (active/inactive/pending)
- lib/features/staff/presentation/screens/add_staff_screen.dart - Add/invite staff form

Features implemented:
1. Staff Management UI:
   - Staff list screen (owner only) with tabs for Active, Inactive, and Pending
   - Add staff screen with email and location assignment
   - Staff details bottom sheet
   - Edit assigned locations dialog
   - Set staff PIN dialog
   - Deactivate/reactivate staff

2. Staff Model:
   - StaffMember model with id, storeId, uid, email, fullName, phone, assignedLocationIds, isActive, pin
   - StaffInvitation model for pending invitations
   - Stored as subcollection under stores/{storeId}/staff

3. Role-Based Access:
   - Owners: Full access to all features (products, staff, settings, reports)
   - Staff: Limited to POS/sales only
   - Home screen shows different quick actions based on role
   - Bottom navigation bar changes based on role
   - App bar menu hides settings for staff

4. Location Assignment:
   - Staff can be assigned to specific locations
   - Multi-select location picker when adding staff
   - Edit locations after staff is added

5. Auto-Join Feature:
   - If invited email already exists as user, they're added as staff immediately
   - If email doesn't exist, invitation is created (pending)
   - When user signs up with invited email, they can accept invitation

Pending features:
- PIN login for staff
- Staff viewing own transactions only
- Send invitation email via Firebase Function
- Clock in/out functionality
```

---

## Phase 6: Reporting & Dashboard

**Status:** ⬜ Not Started
**Started:** -
**Completed:** -

### 6.1 Sales Reports

- [ ] 6.1.1 Daily sales summary
- [ ] 6.1.2 Weekly sales summary
- [ ] 6.1.3 Monthly sales summary
- [ ] 6.1.4 Date range picker
- [ ] 6.1.5 Sales by product report
- [ ] 6.1.6 Sales by category report
- [ ] 6.1.7 Sales by staff report
- [ ] 6.1.8 Sales by payment method

### 6.2 Dashboard (Web Admin)

- [ ] 6.2.1 Today's sales card
- [ ] 6.2.2 Sales trend chart (line/bar)
- [ ] 6.2.3 Top selling products widget
- [ ] 6.2.4 Low stock alerts widget
- [ ] 6.2.5 Outstanding credits summary
- [ ] 6.2.6 Recent transactions list
- [ ] 6.2.7 Quick stats (total products, customers, etc.)

### 6.3 Export

- [ ] 6.3.1 Export sales to CSV
- [ ] 6.3.2 Export customer list to CSV
- [ ] 6.3.3 Export credit report to CSV
- [ ] 6.3.4 Export inventory to CSV

### Phase 6 Checkpoint

**Before moving to Phase 7, verify:**

- [ ] Comprehensive sales reports
- [ ] Admin dashboard with charts
- [ ] Data export functionality
- [ ] Business insights visible

**Notes:**
```
(Add any notes, blockers, or decisions made during this phase)


```

---

## Phase 7: Super Admin & Polish

**Status:** ⬜ Not Started
**Started:** -
**Completed:** -

### 7.1 Super Admin Panel

- [ ] 7.1.1 Super admin login
- [ ] 7.1.2 List all stores
- [ ] 7.1.3 View store details
- [ ] 7.1.4 Approve/suspend store
- [ ] 7.1.5 Platform-wide analytics
- [ ] 7.1.6 User management

### 7.2 Polish & UX

- [ ] 7.2.1 Offline mode (cache with sync)
- [ ] 7.2.2 Sync indicator
- [ ] 7.2.3 Dark mode
- [ ] 7.2.4 Sound effects (scan beep)
- [ ] 7.2.5 Loading states (shimmer)
- [ ] 7.2.6 Error handling with user feedback
- [ ] 7.2.7 Empty states
- [ ] 7.2.8 Onboarding/tutorial screens
- [ ] 7.2.9 App icon and splash screen

### 7.3 Thermal Printer Support

- [ ] 7.3.1 Bluetooth printer discovery
- [ ] 7.3.2 Connect to printer
- [ ] 7.3.3 Print receipt to thermal printer
- [ ] 7.3.4 Printer settings
- [ ] 7.3.5 Cash drawer kick command

### Phase 7 Checkpoint

**Final verification before release:**

- [ ] Super admin platform management
- [ ] Offline mode working
- [ ] Dark mode
- [ ] Polished UX
- [ ] Thermal printer support
- [ ] Production-ready app

**Notes:**
```
(Add any notes, blockers, or decisions made during this phase)


```

---

## Milestones

| Milestone | Description | Target Date | Actual Date | Status |
|-----------|-------------|:-----------:|:-----------:|:------:|
| M1 | Auth & Store Setup Complete | - | - | ⬜ |
| M2 | Product Catalog Ready | - | - | ⬜ |
| M3 | First Sale Made (MVP) | - | - | ⬜ |
| M4 | Credit System Working | - | - | ⬜ |
| M5 | Multi-Staff Operations | - | - | ⬜ |
| M6 | Reports & Analytics | - | - | ⬜ |
| M7 | Production Ready | - | - | ⬜ |

---

## Blockers & Issues

| # | Issue | Phase | Status | Resolution |
|---|-------|:-----:|:------:|------------|
| 1 | - | - | - | - |

---

## Decisions Log

| Date | Decision | Reason |
|------|----------|--------|
| 2025-01-29 | Use Firebase Firestore | User preference, real-time sync |
| 2025-01-29 | Use Flutter for mobile | User preference, cross-platform |
| 2025-01-29 | Use Next.js for web admin | Modern React framework |
| 2025-01-29 | Add multi-location support | Business scalability - allows store owners with multiple branches |
| 2025-01-29 | Locations as subcollection | Better data organization, easier queries per location |
| 2025-01-29 | Use Inter font (not Poppins) | Better number readability for POS, matches color palette docs |
| 2026-01-29 | Show first name only on home | Cleaner UI, more personal greeting |
| 2026-01-29 | Role badge on user profile | Clear indication of user permissions |
| 2026-01-29 | Store/location card on home | Quick context and access to settings |
| 2026-01-29 | Use set() with merge for user doc | Handles cases where user doc doesn't exist |
| 2026-01-29 | Products as subcollection under stores | Better data organization, location-based filtering |
| 2026-01-29 | Use Cloudinary for product images | Reliable CDN, image transformations, no Firebase Storage needed |
| 2026-01-29 | Use mobile_scanner for barcode | Reliable, well-maintained, supports QR and barcodes |
| 2026-01-29 | Manual barcode input option | Fallback when camera scanning fails or not available |
| 2026-01-29 | Location-based inventory (stockByLocation map) | Allows multi-location stores to track inventory separately per branch while sharing product catalog |
| 2026-01-29 | Category management with drag-to-reorder | Better UX for organizing product categories |
| 2026-01-29 | Filter chips for category filtering | Quick visual filtering on products screen |
| 2026-01-29 | Tax rate as decimal (0.12 not 12) | Consistent with mathematical calculations, multiply by 100 for display |
| 2026-01-29 | Quantity input after barcode scan | Better UX for bulk adding items from scan |
| 2026-01-31 | Cart modal instead of draggable sheet | More reliable on mobile devices, avoids swipe issues |
| 2026-01-31 | Configurable quantity input setting | Different POS workflows - some prefer quick tap, others need quantity entry |
| 2026-01-31 | Separate restocking feature with history | Audit trail for inventory changes, track restock dates for accounting/reporting |
| 2026-01-31 | Stock history per store (not per product) | Easier querying for store-wide reports while still filterable by product/location |
| 2026-01-31 | Subcategories via parentId (not nested) | Simpler queries, reuse existing Category model, supports drag-reorder |
| 2026-01-31 | 15 predefined currencies | Covers major currencies for Southeast Asia, East Asia, Americas, Europe |
| 2026-01-31 | Receipt footer stored in store settings | Per-store customization, easily editable from settings |
| 2026-01-31 | Separate category and subcategory dropdowns | Better UX - category for main classification, subcategory only when needed |

---

## Resources & Links

- **Firebase Console:** https://console.firebase.google.com/
- **Flutter Docs:** https://docs.flutter.dev/
- **Next.js Docs:** https://nextjs.org/docs
- **Firestore Docs:** https://firebase.google.com/docs/firestore
- **mobile_scanner Package:** https://pub.dev/packages/mobile_scanner
- **shadcn/ui:** https://ui.shadcn.com/

---

*Last updated: 2026-01-31* (Currency settings, Receipt footer, Subcategories/Brands support, Separate category/subcategory dropdowns in product forms)
