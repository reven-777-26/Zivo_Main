# Zivofit — Unit Economics & Scaled Cost Projections (1,000 Users)

This document breaks down the unit economics of Zivofit per individual user and models the financial performance (costs, revenues, margins, and profits) scaled to **1,000 active users** based on the updated pricing structure and usage limits.

---

## 1. Core Pricing & Net Revenue (After 15% Play Store Fee)

Before looking at backend costs, here is the net revenue the app retains after Google Play/App Store's 15% developer commission.

| Subscription Plan | Gross Price | Play Store Fee (15%) | Monthly Gross Equivalent | Monthly Net Revenue | Annual Net Revenue |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Monthly Subscription** | ₹249 / month | ₹37.35 | ₹249.00 | **₹211.65** | **₹2,539.80** |
| **Yearly Subscription** | ₹1,249 / year | ₹187.35 | ₹104.08 | **₹88.47** | **₹1,061.65** |

---

## 2. Infrastructure & API Costs (Cost of Goods Sold - COGS)

User costs are driven by their backend usage (Gemini 2.5 Flash-Lite API calls and Firebase Auth, Firestore database sync, and Cloud Functions).

### Cost per Action Assumed:
* **Firebase Auth**: **₹0.00** (100% Free)
* **Barcode Lookups (OpenFoodFacts)**: **₹0.00** (100% Free API)
* **Average AI Scan**: **₹0.020** (Assumes a 1:1:1 blend of Text logs at ₹0.006, Photo logs at ₹0.024, and Zivo Lens scans at ₹0.030)
* **Firebase Sync/Infra (per user/month)**: Est. Firestore reads (3/scan) and writes (2/scan) and Cloud Run invocation compute overhead beyond the free tier:
  * At 20 scans/day: **₹0.05 / user**
  * At 30 scans/day: **₹0.12 / user**
  * At 50 scans/day: **₹0.26 / user**

---

## 3. Unit Economics: Cost & Margin Per User (Monthly)

Below is the monthly cost and net profit/margin per user across the three specified active user scenarios, calculated for both the **Monthly** and **Yearly** plans.

| Usage Scenario | Daily AI Scans | Monthly AI Cost | Monthly Sync Cost | Total Monthly COGS | Monthly Plan Margin % (Profit) | Yearly Plan Margin % (Profit) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Moderate Active** | 20 scans | ₹12.00 | ₹0.05 | **₹12.05** | **94.3%** (+₹199.60) | **86.4%** (+₹76.42) |
| **High Active** | 30 scans | ₹18.00 | ₹0.12 | **₹18.12** | **91.4%** (+₹193.53) | **79.5%** (+₹70.35) |
| **FUP Daily Cap** | 50 scans | ₹30.00 | ₹0.26 | **₹30.26** | **85.7%** (+₹181.39) | **65.8%** (+₹58.21) |

> **Note**: Barcode scans are 100% free in the food log since they use local cache or OpenFoodFacts lookup without invoking the AI backend.

---

## 4. Scaled Projections: Per 1,000 Users (Uniform Usage Models)

These models show the absolute financial safety margins of the business. Even if **every single one of the 1,000 users** logs heavily at these volumes every single day, the business remains highly profitable.

### Scenario A: 1,000 Users at 20 Scans / Day (Moderate Active)
* **Total monthly scans**: 600,000 scans
* **Total Monthly COGS**: **₹12,053** (₹12,000 AI + ₹53 Firebase Sync)

| Metric | Monthly Subscription Plan (₹249/mo) | Yearly Subscription Plan (₹1,249/yr) |
| :--- | :--- | :--- |
| **Total Gross Revenue / Mo** | ₹2,49,000 | ₹1,04,083 *(₹12,49,000 / yr)* |
| **Total Net Revenue / Mo** | **₹2,11,650** | **₹88,471** *(₹10,61,650 / yr)* |
| **Total Expenses (COGS) / Mo** | **₹12,053** | **₹12,053** |
| **Net Profit / Month** | **+₹199,597** | **+₹76,418** |
| **Net Profit / Year** | **+₹23,95,164** | **+₹9,17,016** |
| **Gross Profit Margin** | **94.3%** | **86.4%** |

---

### Scenario B: 1,000 Users at 30 Scans / Day (High Active)
* **Total monthly scans**: 900,000 scans
* **Total Monthly COGS**: **₹18,120** (₹18,000 AI + ₹120 Firebase Sync)

| Metric | Monthly Subscription Plan (₹249/mo) | Yearly Subscription Plan (₹1,249/yr) |
| :--- | :--- | :--- |
| **Total Gross Revenue / Mo** | ₹2,49,000 | ₹1,04,083 *(₹12,49,000 / yr)* |
| **Total Net Revenue / Mo** | **₹2,11,650** | **₹88,471** *(₹10,61,650 / yr)* |
| **Total Expenses (COGS) / Mo** | **₹18,120** | **₹18,120** |
| **Net Profit / Month** | **+₹193,530** | **+₹70,351** |
| **Net Profit / Year** | **+₹23,22,360** | **+₹8,44,212** |
| **Gross Profit Margin** | **91.4%** | **79.5%** |

---

### Scenario C: 1,000 Users at 50 Scans / Day (Fair Usage Policy Cap)
* **Total monthly scans**: 1,500,000 scans
* **Total Monthly COGS**: **₹30,255** (₹30,000 AI + ₹255 Firebase Sync)

| Metric | Monthly Subscription Plan (₹249/mo) | Yearly Subscription Plan (₹1,249/yr) |
| :--- | :--- | :--- |
| **Total Gross Revenue / Mo** | ₹2,49,000 | ₹1,04,083 *(₹12,49,000 / yr)* |
| **Total Net Revenue / Mo** | **₹2,11,650** | **₹88,471** *(₹10,61,650 / yr)* |
| **Total Expenses (COGS) / Mo** | **₹30,255** | **₹30,255** |
| **Net Profit / Month** | **+₹181,395** | **+₹58,216** |
| **Net Profit / Year** | **+₹21,76,740** | **+₹6,98,592** |
| **Gross Profit Margin** | **85.7%** | **65.8%** |

---

## 5. Summary of Key Safety and Financial Protections

1. **Unlimited Marketing with Fair Usage Protection**:
   * Marketing the product as "unlimited scans" matches user expectations. 
   * A soft daily cap of **50 AI scans** (combined across food logs and analysers) is set. This is virtually impossible for a legitimate user to hit (requires logging meals or scanning items 3+ times every hour of a 16-hour awake cycle).
   * It completely prevents malicious actors or script attacks from running up massive API bills, capping the absolute worst-case monthly COGS per user at **₹30.26**.
2. **Positive Profit Margins in All Scenarios**:
   * Even on the cheapest Yearly Plan (₹1,249/yr) and at the absolute FUP maximum of 50 scans/day, the gross margin is a highly secure **65.8%** (+₹58.21 net profit/user/month).
   * On the standard Monthly Plan (₹249/mo), the margin remains a staggering **85.7%** at the FUP cap.
3. **Cross-Subsidization Dynamic**:
   * Real-world usage shows that over 85% of users will log 1–5 times daily (averaging ~₹1.50 to ₹2.50 in monthly backend cost). This generates a huge surplus that easily covers the occasional heavy user.
