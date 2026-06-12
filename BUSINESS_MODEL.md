# Zivo Subscription & Profitability Model

This document outlines the business economics, unit costs, and net margins for Zivo, targeting launch on the **Google Play Store**.

> **Last Updated**: June 2026 — Costs derived from actual codebase audit of Cloud Functions (`index.ts`), Firebase service usage, and current published Gemini 2.5 Flash-Lite API pricing.

---

## 1. Pricing Strategy
* **Monthly Subscription**: **₹249**
* **Yearly Subscription**: **₹1,499** (effectively ~₹125/month)

---

## 2. Google Play Store Commission (15% tier)
For developers earning under $1M annually, Google takes a **15% fee** on subscriptions:

* **Monthly Plan Net**: ₹249 - 15% = **₹211.65**
* **Yearly Plan Net**: ₹1,499 - 15% = **₹1,274.15** (approx. **₹106.18/month**)

---

## 3. Service Inventory — What Zivo Actually Pays For

| # | Service | What It Does | Free Tier? | Pricing Model |
|---|---------|-------------|-----------|---------------|
| 1 | **Firebase Auth** | Email, Google, Guest sign-in | ✅ Unlimited free | Free |
| 2 | **Cloud Firestore** | User profiles, daily metrics, workouts, food logs, vision scan cache | ✅ 50K reads + 20K writes/day | Per document read/write |
| 3 | **Cloud Functions (v2)** | Proxies to Gemini: `healthCheckAI`, `analyzeMeal`, `identifyProduct`, `analyzeVisionProduct` | ✅ ~2M invocations/month | Per invocation + compute |
| 4 | **Firebase Hosting** | Landing page / Web App | ✅ 10GB + 360MB/day transfer | Per GB |
| 5 | **Gemini 2.5 Flash-Lite** | AI brain — meal analysis, product ID, health scoring, ingredient decoding | ❌ No free tier | Per million tokens |
| 6 | **OpenFoodFacts API** | Barcode lookups, product search | ✅ 100% free | Free forever |
| 7 | **OpenBeautyFacts API** | Skincare barcode lookups | ✅ 100% free | Free forever |

> **Key Insight**: Firebase Auth, OpenFoodFacts, and OpenBeautyFacts are completely free. The only real costs are **Gemini AI tokens** (~95% of total) and **Firestore operations** (~5%).

---

## 4. Gemini 2.5 Flash-Lite — Per-Action Token Cost

### API Pricing (June 2026)
| Direction | Cost |
|-----------|------|
| **Input tokens** | $0.10 / 1 million tokens |
| **Output tokens** | $0.40 / 1 million tokens |

### Cost Per Cloud Function Call

| Cloud Function | Use Case | Est. Input Tokens | Est. Output Tokens | Cost (INR) |
|:---|:---|:-:|:-:|---:|
| `analyzeMeal` (text/voice) | "2 rotis with dal" → JSON | ~300 | ~100 | **₹0.006** |
| `analyzeMeal` (image) | Food photo → structured JSON | ~2,500 | ~100 | **₹0.024** |
| `analyzeMeal` (barcode_image) | Barcode photo → extract digits | ~2,500 | ~30 | **₹0.022** |
| `identifyProduct` | Product photo → name, brand, category | ~2,500 | ~150 | **₹0.026** |
| `analyzeVisionProduct` | Deep health analysis → score, insights, alternatives | ~3,000 | ~800 | **₹0.052** |

### Cost Per User Action

| User Action | Cloud Functions Called | Gemini Cost (INR) |
|:---|:---|---:|
| **Log food via text/voice** | 1× `analyzeMeal` | **₹0.006** |
| **Log food via photo** | 1× `analyzeMeal` (image) | **₹0.024** |
| **Barcode scan (found in OpenFoodFacts)** | 0 (free API lookup) | **₹0.00** |
| **Barcode scan (NOT found → AI fallback)** | 1× `analyzeMeal` (barcode_image) | **₹0.022** |
| **Vision Lens scan (any category)** | 1× `identifyProduct` + 1× `analyzeVisionProduct` | **₹0.03** |

---

## 5. Fair Usage Policy (FUP) Limits
To protect the backend from abuse while marketing the app as having "unlimited" scans, we enforce soft daily limits:
* **Food Logging (AI-based Voice/Text/Pic)**: Max **25 scans / day** (Barcodes remain local, offline, and completely unlimited).
* **Zivo Lens Analyzer (Food/Skincare/Supplements)**: Max **50 scans / day**.
* **Combined Daily Limit**: **75 AI scans / day**.

---

## 6. Profit Margin Analysis — Per User Scenario

### Scenario A: Light User (50% of users)
*Logs 1-2 meals/day via text + 1 barcode scan (free) + 0-1 Vision Lens scans/day.*

| Cost Component | Calculation | Monthly Cost |
|:---|:---|---:|
| Gemini (text meal logs) | 45 × ₹0.006 | ₹0.27 |
| Gemini (Vision Lens) | 15 × ₹0.03 | ₹0.45 |
| Firestore / Functions | Within free tier | ₹0.00 |
| **Total Cost** | | **₹0.72** |

* **Monthly Subscription (₹249)**: Net Revenue ₹211.65 → **Profit: +₹210.93 / month** (99.7% Margin)
* **Yearly Subscription (₹1,499)**: Net Revenue ₹106.18/mo → **Profit: +₹105.46 / month** (99.3% Margin)

### Scenario B: Regular User (35% of users)
*Logs 3 meals/day (2 text + 1 photo) + 1 barcode (free) + 1 Vision Lens scan/day.*

| Cost Component | Calculation | Monthly Cost |
|:---|:---|---:|
| Gemini (text logs) | 60 × ₹0.006 | ₹0.36 |
| Gemini (photo logs) | 30 × ₹0.024 | ₹0.72 |
| Gemini (Vision Lens) | 30 × ₹0.03 | ₹0.90 |
| Firestore / Functions | Within free tier | ₹0.00 |
| **Total Cost** | | **₹1.98** |

* **Monthly Subscription (₹249)**: Net Revenue ₹211.65 → **Profit: +₹209.67 / month** (99.1% Margin)
* **Yearly Subscription (₹1,499)**: Net Revenue ₹106.18/mo → **Profit: +₹104.20 / month** (98.1% Margin)

### Scenario C: Power User (12% of users)
*Logs 5 meals/day (3 text + 2 photo) + 2 barcodes (free) + 5 Vision Lens scans/day.*

| Cost Component | Calculation | Monthly Cost |
|:---|:---|---:|
| Gemini (text logs) | 90 × ₹0.006 | ₹0.54 |
| Gemini (photo logs) | 60 × ₹0.024 | ₹1.44 |
| Gemini (Vision Lens) | 150 × ₹0.03 | ₹4.50 |
| Firestore / Functions | Within free tier | ₹0.00 |
| **Total Cost** | | **₹6.48** |

* **Monthly Subscription (₹249)**: Net Revenue ₹211.65 → **Profit: +₹205.17 / month** (96.9% Margin)
* **Yearly Subscription (₹1,499)**: Net Revenue ₹106.18/mo → **Profit: +₹99.70 / month** (93.9% Margin)

### Scenario D: Extreme / Abuser (3% of users)
*Hits 30-50 AI scans/day. Heavy mix of photo meals + Vision Lens.*

| Cost Component | Calculation | Monthly Cost |
|:---|:---|---:|
| Gemini (text logs) | 150 × ₹0.006 | ₹0.90 |
| Gemini (photo logs) | 150 × ₹0.024 | ₹3.60 |
| Gemini (Vision Lens) | 900 × ₹0.03 | ₹27.00 |
| Firestore | May exceed free tier slightly | ~₹2.00 |
| **Total Cost** | | **₹33.50** |

* **Monthly Subscription (₹249)**: Net Revenue ₹211.65 → **Profit: +₹178.15 / month** (84.2% Margin)
* **Yearly Subscription (₹1,499)**: Net Revenue ₹106.18/mo → **Profit: +₹72.68 / month** (68.4% Margin)

### Scenario E: Maximum-Limit Abuser (Theoretical)
*Hits the absolute maximum daily limit (75 AI scans/day) every single day for a month. (2,250 scans/month)*
* *Note: This requires scanning something every 13 minutes for 16 hours straight, every day — virtually impossible for a human.*

| Cost Component | Calculation | Monthly Cost |
|:---|:---|---:|
| Gemini (worst-case blend) | 750 text × ₹0.006 + 750 photo × ₹0.024 + 750 Vision × ₹0.03 | ₹45.00 |
| Firestore | Exceeds free tier | ~₹5.00 |
| **Total Cost** | | **~₹50.00** |

* **Monthly Subscription (₹249)**: Net Revenue ₹211.65 → **Profit: +₹161.65 / month** (76.4% Margin) ✅
* **Yearly Subscription (₹1,499)**: Net Revenue ₹106.18/mo → **Profit: +₹56.18 / month** (52.9% Margin) ✅

> **⚠️ Critical Update**: Unlike the old estimates (₹0.10/scan flat), the real per-token cost of Gemini 2.5 Flash-Lite is so low that **even worst-case abusers are still profitable on both plans**. There is no loss scenario.

---

## 7. Business Takeaways & Safety Rules
1. **No Loss Scenario**: With accurate per-token pricing, even the absolute worst-case abuser generates positive margin. The old ₹0.10/scan flat estimate was 4-17× too high.
2. **Safety of Daily Caps**: The soft limit of 25 + 50 still prevents any hypothetical extreme abuse. Maximum monthly cost per user is capped at ~₹86.
3. **Cross-Subsidization**: 85% of users (Light + Regular) cost under ₹3.50/month, generating enormous surplus to cover the rare power user.
4. **Local Barcodes**: Barcode scans via OpenFoodFacts cost ₹0.00 — emphasizing barcode logging keeps engagement high while offloading AI costs completely.
5. **Vision Lens Caching**: Scanning the same product twice reads from Firestore cache (₹0.00 AI cost), not Gemini.

---

## 8. Firebase Backend Cost Matrix

| Firebase Service | Purpose in Zivo | Free Tier (Resets Daily) | Rate Beyond Free Tier | Real-world Estimate (1,000 Active Users) |
| :--- | :--- | :--- | :--- | :--- |
| **Firebase Auth** | Email, Google, and Guest sign-ins | **Unlimited Free** (Standard providers) | Free | **₹0.00 / month** |
| **Cloud Firestore** | User Profiles, Food Logs, Macros, Goals, Vision Scan Cache | **50,000 Reads** / day<br>**20,000 Writes** / day | Reads: $0.03 (₹2.50) / 100k<br>Writes: $0.09 (₹7.50) / 100k | **~₹0 to ₹300 / month** (Most patterns fit in Free Tier) |
| **Cloud Functions (v2)** | Proxying to Gemini API securely | **~2,000,000 runs** / month | Cloud Run-based pricing | **₹0.00 / month** (Within free tier for 1K users) |
| **Firebase Hosting** | Landing page or Web App | **10 GB Storage** total<br>**360 MB Transfer** / day | Storage: $0.026 (₹2.15) / GB<br>Transfer: $0.15 (₹12.50) / GB | **₹0.00 / month** |

### When Free Tiers Run Out

| Service | Free Tier Limit | Approx. Users to Exhaust | Monthly Cost After |
|:---|:---|:-:|:---|
| Firestore Reads | 50K/day | ~2,000 active | ~₹2.50 per 100K reads |
| Firestore Writes | 20K/day | ~3,000 active | ~₹7.50 per 100K writes |
| Firestore Storage | 1 GiB | ~5,000+ | ₹9.00/GiB/month |
| Cloud Functions | ~2M/month | ~5,000 active | ~₹0.002/invocation |
| Firebase Auth | Unlimited | Never | Always free |

---

## 9. Worst-Case Scenario (1,000 Users — All Abusers, All Yearly Plan)

Every single user on the **cheapest plan (Yearly ₹1,499)** hitting the **maximum daily AI limit (75 scans/day)** every day.

### Revenue (Worst Case)

| Metric | Calculation | Amount |
| :--- | :--- | :--- |
| Gross Revenue | 1,000 users × ₹1,499 / year | **₹14,99,000 / year** |
| Google Play Cut (15%) | ₹14,99,000 × 0.15 | -₹2,24,850 / year |
| **Net Revenue** | | **₹12,74,150 / year** (₹1,06,179 / month) |

### Expenses (Worst Case — Every User Maxing Out Daily)

| Expense | Calculation | Monthly Cost |
| :--- | :--- | :--- |
| **Gemini AI (text scans)** | 1,000 × 25 text/day × 30 days × ₹0.006 | **₹4,500** |
| **Gemini AI (photo scans)** | Not all 75 are photo — conservatively 25 photo × 30 × ₹0.024 | **₹18,000** |
| **Gemini AI (Vision Lens)** | 1,000 × 25 Vision/day × 30 days × ₹0.03 | **₹22,500** |
| **Firestore Writes** | ~2 writes/scan × 2.25M scans = 4.5M writes<br>Free: 600K → 3.9M billable × ₹7.50/100K | **₹293** |
| **Firestore Reads** | ~3 reads/scan × 2.25M scans = 6.75M reads<br>Free: 1.5M → 5.25M billable × ₹2.50/100K | **₹131** |
| **Cloud Functions** | 2.25M + 1.0M Vision 2nd calls = 3.25M invocations<br>Free: 2.0M → 1.25M billable (with compute) | **₹1,762** |
| **Total Monthly Expense** | | **₹47,186** |

### Worst-Case Profit / Loss Summary

| Metric | Monthly | Yearly |
| :--- | :--- | :--- |
| Net Revenue | ₹1,06,179 | ₹12,74,150 |
| Total Expenses | ₹47,186 | ₹5,66,232 |
| **Net Profit** | **+₹58,993 / month** | **+₹7,07,916 / year** |

> **✅ Even the worst case is highly profitable.** With actual token pricing of ₹0.03 per Vision Lens scan, even 1,000 max-abusers on the cheapest plan still generate ~₹56.8K/month profit.

---

## 10. Realistic Mix Scenario (1,000 Users)

A realistic distribution of 1,000 paying users:

| User Type | % of Users | Count | AI Scans/Day | Monthly AI Cost (per user) |
| :--- | :--- | :--- | :--- | :--- |
| Light Users | 50% | 500 | 1–2 | ₹0.72 |
| Regular Users | 35% | 350 | 3–5 | ₹1.98 |
| Power Users | 12% | 120 | 8–15 | ₹6.48 |
| Extreme Users | 3% | 30 | 30–50 | ₹33.50 |

### Realistic Monthly P&L

| Metric | Calculation | Amount |
| :--- | :--- | :--- |
| **Net Revenue** | 1,000 users × ₹106.18/month (yearly plan, after Play Store cut) | **₹1,06,179 / month** |
| AI Cost (Light) | 500 × ₹0.72 | ₹360 |
| AI Cost (Regular) | 350 × ₹1.98 | ₹693 |
| AI Cost (Power) | 120 × ₹6.48 | ₹778 |
| AI Cost (Extreme) | 30 × ₹33.50 | ₹1,005 |
| **Total AI Cost** | | **₹2,836** |
| Firebase Infra | Firestore + Functions (mostly free tier) | **~₹0** |
| **Total Expenses** | | **₹2,836 / month** |
| **Net Profit** | | **+₹103,343 / month** (₹12,40,116 / year) |
| **Profit Margin** | | **97.3%** |

---

## 11. Unit Economics Summary

| Metric | Value |
|:---|:---|
| **ARPU** (Avg Revenue Per User / Month, yearly plan) | ₹106.18 |
| **COGS** (Avg Cost of Goods Served / User / Month) | ₹2.84 |
| **Gross Margin** | 97.3% |
| **LTV** (Lifetime Value, 12-month retention) | ₹1,274.15 |
| **LTV-to-COGS Ratio** | 37:1 |
| **Breakeven** | Profitable from User #1 |
| **Everything Else** | ₹0 (Auth, Hosting, OpenFoodFacts all free) |
