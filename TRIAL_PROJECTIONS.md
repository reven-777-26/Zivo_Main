# Zivofit — 7-Day Free Trial Cost Projections (25,000 Installs)

This document estimates the backend operational costs (Gemini API tokens, Firestore, and Cloud Functions) if you run ads and get **25,000 installs in a single week** with a **7-day free, unlimited trial** (capped by the 50 AI scans/day FUP).

---

## 1. Summary of Projections

| Scenario | Active Users (DAU/WAU) | Cost per User (7 days) | Total Cost for the Week | Analysis |
| :--- | :-: | :-: | ---: | :--- |
| **Realistic Funnel (50% Activation)** | 12,500 | ₹0.66 | **₹8,250** | Standard industry conversion. 50% of installers onboard and log data. |
| **High Engagement (100% Activation)** | 25,000 | ₹0.67 | **₹16,684** | Every single downloader logs meals and uses Zivo Lens. |
| **Absolute Worst-Case (100% Max Abusers)** | 25,000 | ₹7.62 | **₹1,90,442** | Every installer hits the Fair Usage Limit (50 scans/day) every day. |

---

## 2. Cost Breakdown (Standard Activated Trial Mix)

Assuming all 25,000 users are active and exhibit Zivofit's typical user distribution (50% Light, 35% Regular, 12% Power, 3% Extreme):

### A. Gemini AI Token Costs (June 2026 Prices)
* **Light Users** (12,500): 12,500 × ₹0.72/mo × (7/30 days) = **₹2,100**
* **Regular Users** (8,750): 8,750 × ₹1.98/mo × (7/30 days) = **₹4,043**
* **Power Users** (3,000): 3,000 × ₹6.48/mo × (7/30 days) = **₹4,536**
* **Extreme Users** (750): 750 × ₹30.26/mo × (7/30 days) = **₹5,296**
* **Total Gemini Token Cost**: **₹15,975**

### B. Firestore Database Costs (Beyond Free Tier)
With 25,000 concurrent active users in one week, you will exceed the daily free tier limits:
* **Total Reads**: ~3.31 Million reads. 
  * Free tier covers 350K reads (50K/day × 7).
  * Billable: 2.96 Million reads × ₹2.50 / 100K = **₹74**
* **Total Writes**: ~1.05 Million writes.
  * Free tier covers 140K writes (20K/day × 7).
  * Billable: 918K writes × ₹7.50 / 100K = **₹69**
* **Total Firestore Cost**: **₹143**

### C. Cloud Functions (v2) Compute Costs
* **Total Invocations**: ~1.25 Million invocations.
* **Monthly Free Tier**: 2 Million invocations.
* Since 1.25M is under your 2.0M monthly limit, Cloud Functions are **100% free** (₹0.00).

### 💎 Total Cost (Standard Mix): ₹16,118

---

## 3. The "Onboarding Funnel" Reality Check

In consumer mobile apps, **not everyone who installs the app actually uses it**. 
* **Download-to-Signup**: Typically 60-70%.
* **Signup-to-Action (Logging a meal/scanning)**: Typically 70%.
* This results in an **Activation Rate of ~40% to 50%**.

If you get 25,000 installs, you will likely have **12,500 active trial users** logging data. Under this realistic funnel:
* **Gemini AI & Sync**: ₹8,250
* **Firestore**: ₹0 (Fits entirely inside the daily free tier with 12.5k users!)
* **Cloud Functions**: ₹0
* **Total Cost**: **₹8,250** (or roughly $100 USD).

---

## 4. Risks & Mitigations

### ⚠️ Risk: Referral loops or bot networks abusing the unlimited trial
If competitors or script-kiddies automate installs to spam your backend:
* **Solution**: Ensure your **Fair Usage Policy (50 scans/day combined limit)** is active and compiled in your Firestore security rules or Cloud Functions. This limits your absolute maximum exposure to ₹7.62 per installer for the entire 7-day period.
* **Solution**: Implement basic rate-limiting on the Firebase Auth sign-up endpoint or use **Firebase App Check** to prevent automated bot scripts from making accounts.

---

## 5. Strategic Takeaway

A trial week of 25,000 installs will cost you between **₹8,250 and ₹16,684** in infrastructure. If even **1.5% to 2%** of those users convert to the ₹1,249 yearly subscription at the end of the trial:
* **Conversions**: 375 to 500 users
* **Net Revenue (After 15% Play Store cut)**: **₹3,98,119 to ₹5,30,825**
* **ROI**: ~24x to 32x on backend cost (excluding advertising spend). 
* Operational costs are a tiny fraction of your revenue. The trial is **extremely safe** to run.
