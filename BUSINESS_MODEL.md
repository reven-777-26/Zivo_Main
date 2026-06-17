# Zivo Subscription & Profitability Model

This document outlines the business economics, unit costs, and net margins for Zivo, targeting launch on the **Google Play Store**.

> **Last Updated**: June 2026 — Costs derived from actual codebase audit of Cloud Functions (`index.ts`), Firebase service usage, and current published Gemini 2.5 Flash-Lite API pricing.

---

## 1. Pricing Strategy
* **Monthly Subscription**: **₹249**
* **Yearly Subscription**: **₹1,249** (effectively ~₹104/month)

---

## 2. Google Play Store Commission (15% tier)
For developers earning under $1M annually, Google takes a **15% fee** on subscriptions:

* **Monthly Plan Net**: ₹249 - 15% = **₹211.65**
* **Yearly Plan Net**: ₹1,249 - 15% = **₹1,061.65** (approx. **₹88.47/month** equivalent)

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
* **Combined Daily Limit**: Max **50 AI scans / day** across food logging (AI text/voice/pic) and Zivo Lens Analyzer.
* **Barcode Logging**: 100% offline, local, and completely free/unlimited.

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
* **Yearly Subscription (₹1,249)**: Net Revenue ₹88.47/mo → **Profit: +₹87.75 / month** (99.2% Margin)

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
* **Yearly Subscription (₹1,249)**: Net Revenue ₹88.47/mo → **Profit: +₹86.49 / month** (97.8% Margin)

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
* **Yearly Subscription (₹1,249)**: Net Revenue ₹88.47/mo → **Profit: +₹81.99 / month** (92.7% Margin)

### Scenario D: Maximum-Limit Abuser / Extreme User (3% of users)
*Hits the absolute maximum daily limit (50 AI scans/day) every single day for a month. (1,500 scans/month)*
* *Note: Marketed as unlimited; capped at 50 scans to protect infrastructure.*

| Cost Component | Calculation | Monthly Cost |
|:---|:---|---:|
| Gemini (worst-case blend) | 500 text × ₹0.006 + 500 photo × ₹0.024 + 500 Vision × ₹0.03 | ₹30.00 |
| Firestore | Exceeds free tier (reads & writes sync) | ~₹0.26 |
| **Total Cost** | | **~₹30.26** |

* **Monthly Subscription (₹249)**: Net Revenue ₹211.65 → **Profit: +₹181.39 / month** (85.7% Margin) ✅
* **Yearly Subscription (₹1,249)**: Net Revenue ₹88.47/mo → **Profit: +₹58.21 / month** (65.8% Margin) ✅

> **⚠️ Critical Takeaway**: With the FUP limit capped at 50 AI scans per day, there is absolutely zero risk of loss. Even a user maxing out their daily cap on the cheapest Yearly plan remains highly profitable.

---

## 7. Business Takeaways & Safety Rules
1. **No Loss Scenario**: With accurate per-token pricing and the 50-scan cap, even the absolute worst-case abuser generates positive margin.
2. **Safety of Daily Caps**: The soft limit of 50 scans protects the system from automated scraping or loop abuse.
3. **Cross-Subsidization**: Over 85% of users (Light + Regular) cost under ₹2.00/month, generating massive surplus.
4. **Local Barcodes**: Barcode scans via OpenFoodFacts cost ₹0.00, keeping engagement high while offloading AI costs.
5. **Vision Lens Caching**: Duplicate vision scans read from Firestore cache (₹0.00 AI cost).

---

## 8. Firebase Backend Cost Matrix

| Firebase Service | Purpose in Zivo | Free Tier (Resets Daily) | Rate Beyond Free Tier | Real-world Estimate (1,000 Active Users) |
| :--- | :--- | :--- | :--- | :--- |
| **Firebase Auth** | Email, Google, and Guest sign-ins | **Unlimited Free** (Standard providers) | Free | **₹0.00 / month** |
| **Cloud Firestore** | User Profiles, Food Logs, Macros, Goals, Vision Cache | **50,000 Reads** / day<br>**20,000 Writes** / day | Reads: $0.03 (₹2.50) / 100k<br>Writes: $0.09 (₹7.50) / 100k | **~₹0 to ₹255 / month** (depending on scan rates) |
| **Cloud Functions (v2)** | Proxying to Gemini API securely | **~2,000,000 runs** / month | Cloud Run-based pricing | **₹0.00 / month** (Within free tier for 1K users up to 50 scans/day) |
| **Firebase Hosting** | Landing page or Web App | **10 GB Storage** total<br>**360 MB Transfer** / day | Storage: $0.026 (₹2.15) / GB<br>Transfer: $0.15 (₹12.50) / GB | **₹0.00 / month** |

---

## 9. Extreme FUP-Limit Scenario (1,000 Users — All Abusers, All Yearly Plan)

Every single user on the **cheapest plan (Yearly ₹1,249)** hitting the **maximum daily AI limit (50 scans/day)** every day.

### Revenue (Worst Case)

| Metric | Calculation | Amount |
| :--- | :--- | :--- |
| Gross Revenue | 1,000 users × ₹1,249 / year | **₹12,49,000 / year** |
| Google Play Cut (15%) | ₹12,49,000 × 0.15 | -₹1,87,350 / year |
| **Net Revenue** | | **₹10,61,650 / year** (₹88,471 / month) |

### Expenses (Worst Case — 100% of Users Maxing Out FUP Daily)

| Expense | Calculation | Monthly Cost |
| :--- | :--- | :--- |
| **Gemini AI (text scans)** | 1,000 × 16.67 text/day × 30 days × ₹0.006 | **₹3,000** |
| **Gemini AI (photo scans)** | 1,000 × 16.67 photo/day × 30 days × ₹0.024 | **₹12,000** |
| **Gemini AI (Vision Lens)** | 1,000 × 16.67 Vision/day × 30 days × ₹0.03 | **₹15,000** |
| **Firestore Writes** | ~2 writes/scan × 1.5M scans = 3.0M writes<br>Free: 600K → 2.4M billable × ₹7.50/100K | **₹180** |
| **Firestore Reads** | ~3 reads/scan × 1.5M scans = 4.5M reads<br>Free: 1.5M → 3.0M billable × ₹2.50/100K | **₹75** |
| **Cloud Functions** | 1.5M + 0.5M Vision 2nd calls = 2.0M invocations<br>Free: 2.0M → 0 billable | **₹0** |
| **Total Monthly Expense** | | **₹30,255** |

### Worst-Case Profit / Loss Summary

| Metric | Monthly | Yearly |
| :--- | :--- | :--- |
| Net Revenue | ₹88,471 | ₹10,61,650 |
| Total Expenses | ₹30,255 | ₹3,63,060 |
| **Net Profit** | **+₹58,216 / month** | **+₹6,98,590 / year** |

---

## 10. Realistic Mix Scenario (1,000 Users)

A realistic distribution of 1,000 paying users (50% Light, 35% Regular, 12% Power, 3% Extreme):

### Realistic Monthly P&L

| Metric | Calculation | Amount |
| :--- | :--- | :--- |
| **Net Revenue** | 1,000 users × ₹88.47/month (yearly plan, after Play Store cut) | **₹88,471 / month** |
| AI Cost (Light) | 500 × ₹0.72 | ₹360 |
| AI Cost (Regular) | 350 × ₹1.98 | ₹693 |
| AI Cost (Power) | 120 × ₹6.48 | ₹778 |
| AI Cost (Extreme) | 30 × ₹30.26 | ₹908 |
| **Total AI & Sync Cost** | | **₹2,739 / month** |
| **Net Profit** | | **+₹85,732 / month** (₹10,28,784 / year) |
| **Profit Margin** | | **96.9%** |

---

## 11. Unit Economics Summary (Yearly Plan Baseline)

| Metric | Value |
|:---|:---|
| **ARPU** (Avg Revenue Per User / Month, yearly plan) | ₹88.47 |
| **COGS** (Avg Cost of Goods Sold / User / Month) | ₹2.74 |
| **Gross Margin** | 96.9% |
| **LTV** (Lifetime Value, 12-month retention) | ₹1,061.65 |
| **LTV-to-COGS Ratio** | 32:1 |
| **Breakeven** | Profitable from User #1 |
| **Everything Else** | ₹0 (Auth, Hosting, OpenFoodFacts all free) |
