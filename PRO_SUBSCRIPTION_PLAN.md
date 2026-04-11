# Dun Bun Finance — Pro Subscription & Role System Plan

## Overview

Transform the current 2-tier role system (user/admin) into a 3-tier system (user/pro/admin) with a subscription-based Pro tier, 7-day free trial with limited features, and payment processing via RevenueCat (wraps Google Play Billing, Apple StoreKit, and Stripe for web).

---

## 1. Role Tiers

| Feature                           |   Free (user)   | Pro (pro) |       Admin (admin)        |
| --------------------------------- | :-------------: | :-------: | :------------------------: |
| CRUD Expenses & Pots              |       Yes       |    Yes    |            Yes             |
| Monthly Income Input              |       Yes       |    Yes    |            Yes             |
| Total Section                     |       Yes       |    Yes    |            Yes             |
| Theme Toggle                      |       Yes       |    Yes    |            Yes             |
| How it Works                      |       Yes       |    Yes    |            Yes             |
| Refresh / Logout                  |       Yes       |    Yes    |            Yes             |
| **Spending History**              |       No        |    Yes    |            Yes             |
| **Maintenance Reminders**         |       No        |    Yes    |            Yes             |
| **Debt Payoff Planner**           |       No        |    Yes    |            Yes             |
| **Analyze Statement (Gemini AI)** | 1x during trial | Unlimited |         Unlimited          |
| **Export Data**                   |       No        |    Yes    |            Yes             |
| **Future Pro features**           |       No        |    Yes    |            Yes             |
| Manual role override              |       No        |    No     | Yes (via Firebase Console) |

### Admin Behaviour

- Admin bypasses ALL gates — no subscription check, no trial check
- Admin role is set manually in Firebase Console (`users/{uid}.role = 'admin'`)
- Admin sees everything Pro sees, plus any admin-only debugging tools added in future

---

## 2. Free Trial (7 Days)

### How It Works

- Every new user gets a 7-day trial starting from their **registration date** (already stored as `createdAt` in their Firestore profile)
- During the trial, users have access to all Pro features **except**:
  - Analyze Statement is limited to **1 use** during the entire trial period
- After 7 days, if they haven't subscribed:
  - Pro features become locked
  - A gentle "Your trial has ended" banner appears with an upgrade CTA
  - They keep full Free tier functionality
- Trial status is derived from `createdAt` — no extra field needed
- Analysis usage during trial tracked via a `trialAnalysisUsed: bool` field in Firestore profile

### Trial State Logic (computed client-side)

```
trialActive = (now - createdAt) <= 7 days
trialExpired = (now - createdAt) > 7 days
trialDaysRemaining = max(0, 7 - daysSinceRegistration)
```

---

## 3. Subscription Model

### Pricing

| Plan    | Price                                | Stripe Price ID             |
| ------- | ------------------------------------ | --------------------------- |
| Monthly | £2.99/month                          | Set in RevenueCat dashboard |
| Yearly  | £24.99/year (~£2.08/mo, 30% savings) | Set in RevenueCat dashboard |

### Subscription States

- `active` — currently paying, full Pro access
- `expired` — subscription lapsed, reverts to Free
- `grace_period` — payment failed but within retry window (still has access)

---

## 4. Payment Architecture — RevenueCat

### Why RevenueCat

- Single Flutter SDK (`purchases_flutter`) handles all 3 platforms
- Google Play Billing for Android (required by Google Play Store policy)
- Apple StoreKit for iOS (required by Apple App Store policy)
- Stripe for Web (RevenueCat's web SDK / Stripe Checkout)
- Webhook → Firebase Extension syncs subscription status to Firestore
- Free tier: up to $2,500/month in tracked revenue
- Handles receipt validation, subscription lifecycle, grace periods, refunds

### Flow: User Subscribes

```
1. User taps "Upgrade to Pro" in app
2. App calls RevenueCat SDK → shows native purchase sheet
   - Android: Google Play purchase dialog
   - iOS: Apple payment sheet
   - Web: Stripe Checkout page
3. User completes payment
4. RevenueCat validates the receipt
5. RevenueCat webhook fires → Cloud Function receives it
6. Cloud Function writes to Firestore:
   users/{uid}/subscriptions/{subId}: {
     status: 'active',
     plan: 'monthly' | 'yearly',
     platform: 'android' | 'ios' | 'web',
     expiresAt: timestamp,
     startedAt: timestamp,
   }
   AND updates users/{uid}.role = 'pro'
7. App detects role change → unlocks Pro features
```

### Flow: Subscription Expires / Cancelled

```
1. RevenueCat detects expiry or cancellation
2. Webhook fires → Cloud Function
3. Cloud Function updates:
   users/{uid}/subscriptions/{subId}.status = 'expired'
   users/{uid}.role = 'user'  (only if not admin)
4. App detects role change → locks Pro features
```

### Flow: Admin Override

- Admin role is never changed by subscription logic
- Cloud Function checks: if current role is 'admin', skip role update

---

## 5. Firestore Data Structure Changes

### Updated User Profile

```
users/{uid}: {
  displayName: string,
  role: 'user' | 'pro' | 'admin',         // Updated by Cloud Function or manual
  createdAt: timestamp,                     // Already exists — used for trial calc
  trialAnalysisUsed: bool,                  // NEW — tracks if free analysis used during trial
}
```

### New Subscriptions Subcollection

```
users/{uid}/subscriptions/{subId}: {
  status: 'active' | 'expired' | 'grace_period',
  plan: 'monthly' | 'yearly',
  platform: 'android' | 'ios' | 'web',
  productId: string,                        // RevenueCat product ID
  startedAt: timestamp,
  expiresAt: timestamp,
  cancelledAt: timestamp | null,
  revenueCatId: string,                     // RevenueCat customer ID
}
```

---

## 6. Implementation — Phase 1 (Client-Side, No Payments Yet)

This phase can be built NOW without any external accounts. It prepares the app for payments by implementing the full role system and feature gating.

### 6.1 Create a Role/Entitlement Service

**New file:** `lib/services/entitlement_service.dart`

Centralised place to check what the current user can do:

```dart
class EntitlementService {
  static String _role = 'user';
  static DateTime? _createdAt;
  static bool _trialAnalysisUsed = false;

  // Called once on app start
  static Future<void> init() async { ... fetch role, createdAt, trialAnalysisUsed ... }

  static bool get isAdmin => _role == 'admin';
  static bool get isPro => _role == 'pro' || isAdmin;

  static bool get isTrialActive {
    if (_createdAt == null) return false;
    return DateTime.now().difference(_createdAt!).inDays <= 7;
  }

  static int get trialDaysRemaining {
    if (_createdAt == null) return 0;
    return max(0, 7 - DateTime.now().difference(_createdAt!).inDays);
  }

  // Can the user access Pro features right now?
  static bool get hasProAccess => isPro || isTrialActive;

  // Can the user use Analyze Statement?
  static bool get canAnalyze {
    if (isAdmin || isPro) return true;
    if (isTrialActive && !_trialAnalysisUsed) return true;
    return false;
  }

  static Future<void> markTrialAnalysisUsed() async { ... }
}
```

### 6.2 Update Firestore Service

- Add `trialAnalysisUsed` field to `createUserProfile()` (default: false)
- Add `getTrialAnalysisUsed()` method
- Add `markTrialAnalysisUsed()` method
- Update `getUserRole()` to also return `createdAt` (or make EntitlementService fetch both)

### 6.3 Update Home Screen Role Checks

**File:** `lib/home_screen/home_screen.dart`

Replace all `_userRole == 'admin'` checks with `EntitlementService` calls:

**Current (line 942):**

```dart
if (_userRole == 'admin') ...[
  // analyze, debt_plan, export
]
```

**New structure — menu items grouped by access level:**

```dart
// Pro features (visible to pro, trial, and admin)
if (EntitlementService.hasProAccess) ...[
  'Analyze Statement',    // extra check: EntitlementService.canAnalyze
  'Debt Payoff Plan',
  'Export Data',
  'Spending History',     // move from always-visible to Pro
  'Maintenance',          // move from always-visible to Pro
  PopupMenuDivider,
],
// If trial active but not pro, show trial badge
// If trial expired and not pro, show "Upgrade to Pro" menu item
if (!EntitlementService.isPro && !EntitlementService.isAdmin) ...[
  'Upgrade to Pro',       // NEW — opens paywall/upgrade screen
],
```

**Analysis gating:**

- When user taps "Analyze Statement":
  - If `EntitlementService.canAnalyze` → proceed
  - If trial active but already used → show dialog: "You've used your free analysis. Upgrade to Pro for unlimited."
  - If trial expired → show upgrade prompt
- After successful analysis during trial → call `EntitlementService.markTrialAnalysisUsed()`

### 6.4 AppBar Role Badge Update

Currently shows "Admin" or "User". Update to show:

- "Admin" (amber) — for admin
- "Pro" (cyan/primary) — for pro subscribers
- "Trial · X days left" (green) — during trial
- "Free" (grey) — after trial expires, no subscription

### 6.5 Upgrade Screen / Paywall

**New file:** `lib/subscription/upgrade_screen.dart`

A screen showing:

- Feature comparison (Free vs Pro)
- Pricing cards (£2.99/mo, £24.99/yr with "Save 30%" badge)
- "Start Free Trial" button (if never trialled) OR "Subscribe" buttons
- "Restore Purchase" button (for platform switches)
- For Phase 1: buttons show a "Coming soon" message or placeholder
- For Phase 2: buttons trigger RevenueCat purchase flow

### 6.6 Trial Expired Banner

When trial ends and user hasn't subscribed, show a dismissible banner on HomeScreen (similar to the negotiation/loan banners):

```
"Your Pro trial has ended. Upgrade to keep access to Spending History,
 Maintenance, Debt Planner, and more."
 [Upgrade Now]  [Dismiss]
```

---

## 7. Implementation — Phase 2 (Payments via RevenueCat)

Requires external account setup. Cannot be coded until accounts exist.

### 7.1 External Setup Required

1. **RevenueCat account** — https://app.revenuecat.com
   - Create project "Dun Bun Finance"
   - Configure API keys for Android, iOS, Web
2. **Google Play Console** — Create subscription products:
   - `dun_bun_pro_monthly` — £2.99/month
   - `dun_bun_pro_yearly` — £24.99/year
3. **Apple Developer Account** — Create subscription products (same IDs)
4. **Stripe account** — For web payments, connected via RevenueCat
5. **Firebase Cloud Function** — Receives RevenueCat webhooks, updates Firestore role

### 7.2 Flutter Integration

**Package:** `purchases_flutter` (RevenueCat's official Flutter SDK)

**Initialization (in main.dart):**

```dart
await Purchases.configure(
  PurchasesConfiguration('<revenuecat_api_key>')
    ..appUserID = FirebaseAuth.instance.currentUser?.uid
);
```

**Purchase Flow (in upgrade_screen.dart):**

```dart
// Fetch available packages
final offerings = await Purchases.getOfferings();
final monthly = offerings.current?.monthly;
final annual = offerings.current?.annual;

// Trigger purchase
final result = await Purchases.purchasePackage(selectedPackage);

// RevenueCat handles receipt validation
// Webhook → Cloud Function → Firestore role update
// App picks up new role on next _refreshData() or listener
```

**Restore Purchases:**

```dart
final info = await Purchases.restorePurchases();
// Check if active entitlements exist
```

### 7.3 Cloud Function (Webhook Handler)

**File:** `functions/src/index.ts` (Firebase Cloud Functions)

```
RevenueCat webhook → HTTPS endpoint →
  1. Validate webhook signature
  2. Extract customer ID (= Firebase UID) and event type
  3. On 'INITIAL_PURCHASE' or 'RENEWAL':
     - Write subscription doc to users/{uid}/subscriptions/
     - Set users/{uid}.role = 'pro' (unless admin)
  4. On 'EXPIRATION' or 'CANCELLATION':
     - Update subscription doc status
     - Set users/{uid}.role = 'user' (unless admin)
```

### 7.4 Real-Time Role Updates

- After purchase completes, force a role refresh
- Optionally listen to `users/{uid}` document with a Firestore snapshot listener for real-time role updates (webhook may take a few seconds)

---

## 8. Security Considerations

### Firestore Rules Update

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Subscriptions subcollection — read-only for the user
    // Only Cloud Functions (admin SDK) can write subscription status
    match /users/{userId}/subscriptions/{subId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false;  // Only server-side via admin SDK
    }
  }
}
```

### Client-Side Gating Is Not Security

- Feature gating in Flutter is UX only — a determined user could bypass it
- For Gemini API calls (Analyze Statement), the API key is already in the app
- For true security, API calls should go through a Cloud Function that checks role server-side
- Acceptable for Phase 1; harden in Phase 2 with Cloud Functions

---

## 9. Migration Plan

### Existing Users

- All existing users with `role: 'user'` stay as `'user'` (Free tier)
- All existing users with `role: 'admin'` stay as `'admin'` (unchanged)
- `trialAnalysisUsed` defaults to `false` for existing users
- Trial period: existing users' trial starts from their original `createdAt` date
  - If they registered more than 7 days ago, trial is already expired → they get Free tier
  - This is fair — they've had access to everything until now

### Future Registrations

- New users get `role: 'user'`, `trialAnalysisUsed: false`
- 7-day trial countdown starts from registration

---

## 10. File Summary

### Phase 1 — New Files

| File                                    | Purpose                          |
| --------------------------------------- | -------------------------------- |
| `lib/services/entitlement_service.dart` | Central role/trial/access checks |
| `lib/subscription/upgrade_screen.dart`  | Paywall UI with pricing cards    |

### Phase 1 — Modified Files

| File                                  | Changes                                                                                |
| ------------------------------------- | -------------------------------------------------------------------------------------- |
| `lib/services/firestore_service.dart` | Add `trialAnalysisUsed` field + methods                                                |
| `lib/home_screen/home_screen.dart`    | Replace `_userRole == 'admin'` with EntitlementService, add trial banner, update badge |
| `lib/main.dart`                       | Add `/upgrade` route, init EntitlementService                                          |
| `lib/models/`                         | No model changes needed — roles stay as strings                                        |

### Phase 2 — New Files (Later)

| File                        | Purpose                                |
| --------------------------- | -------------------------------------- |
| `functions/src/index.ts`    | Cloud Function for RevenueCat webhooks |
| RevenueCat dashboard config | Product IDs, entitlements, webhook URL |
| Google Play Console config  | Subscription products                  |
| Apple Developer config      | Subscription products                  |

---

## 11. Recommended Build Order (Phase 1)

1. Create `EntitlementService` with role/trial/analysis logic
2. Update `FirestoreService` with `trialAnalysisUsed` field
3. Update `HomeScreen` — replace all role checks with EntitlementService
4. Update AppBar badge (Admin/Pro/Trial/Free)
5. Build `UpgradeScreen` with feature comparison + pricing placeholder
6. Add trial expired banner to HomeScreen
7. Gate Analyze Statement behind `canAnalyze` with trial limit
8. Add `/upgrade` route
9. Test all role states: admin, pro (manual override for testing), trial active, trial expired, free

AFTER ALL THAT UPGRADE THE CLAUDE.MD to reflect with all of the app content
