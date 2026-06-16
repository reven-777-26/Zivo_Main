# Zivofit — Unit Economics & Scaled Cost Projections (1,000 Users)

This document breaks down the unit economics of Zivofit per individual user and models the financial performance (costs, revenues, margins, and profits) scaled to **1,000 active users**.

---

## 1. Core Pricing & Net Revenue (After 15% Play Store Fee)

Before looking at backend costs, here is the net revenue the app retains after Google Play's 15% developer commission.

| Subscription Plan | Gross Price | Play Store Fee (15%) | Monthly Gross Revenue | Monthly Net Revenue |
| :--- | :--- | :--- | :--- | :--- |
| **Monthly Subscription** | ₹249 / month | ₹37.35 | ₹249.00 | **₹211.65** |
| **Yearly Subscription** | ₹1,499 / year | ₹224.85 | ₹124.92 | **₹106.18** |

---

## 2. Unit Economics: Cost & Margin Per User Segment

User costs are driven by their backend usage (Gemini 2.5 Flash-Lite API calls and Firestore transactions). 

Below is the monthly cost and net margin per user across the five recognized user profiles, calculated for both the **Monthly** and **Yearly** plans.

### Monthly Cost and Margin Breakdown

| User Profile | % of Users | Avg. AI Scans / Day | Monthly Cost (INR) | Monthly Net Margin (Monthly Plan) | Monthly Net Margin (Yearly Plan) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Light User** | 50% | 1–2 scans | **₹0.72** | **99.7%** (₹210.93 profit) | **99.3%** (₹105.46 profit) |
| **Regular User** | 35% | 3–5 scans | **₹1.98** | **99.1%** (₹209.67 profit) | **98.1%** (₹104.20 profit) |
| **Power User** | 12% | 8–15 scans | **₹6.48** | **96.9%** (₹205.17 profit) | **93.9%** (₹99.70 profit) |
| **Extreme User** | 3% | 30–50 scans | **₹33.50** | **84.2%** (₹178.15 profit) | **68.4%** (₹72.68 profit) |
| **Worst-Case Abuser** | 0% | 75 scans (Cap) | **₹47.19** | **77.7%** (₹164.46 profit) | **55.6%** (₹58.99 profit) |

> **Note**: **Worst-Case Abuser** represents a theoretical user hitting the absolute daily Fair Usage Policy (FUP) cap of 75 AI scans (25 text + 25 photo + 25 Vision Lens) every day of the month, which triggers billing for Firebase Cloud Functions and Firestore read/write operations beyond the free tier.

---

## 3. Scaled Projections: Per 1,000 Users (Realistic Mix)

This model shows the realistic performance of 1,000 paying users, based on the audit-derived distribution: **500 Light, 350 Regular, 120 Power, and 30 Extreme users**.

### Cost and Volume per Month (Realistic Mix)

* **Light Users (500)**: 500 × ₹0.72 = **₹360.00**
* **Regular Users (350)**: 350 × ₹1.98 = **₹693.00**
* **Power Users (120)**: 120 × ₹6.48 = **₹777.60**
* **Extreme Users (30)**: 30 × ₹33.50 = **₹1,005.00**
* **Firebase Infra (Firestore/Functions)**: **₹0.00** *(Fully covered by Firebase Daily Free Tiers)*
* **Total Cost / Month**: **₹2,835.60** (approx. **₹2,836**)

### P&L Summary (1,000 Users — Realistic Mix)

| Metric | Monthly Subscription Plan (₹249/mo) | Yearly Subscription Plan (₹1,499/yr) |
| :--- | :--- | :--- |
| **Total Gross Revenue** | ₹2,49,000 | ₹1,24,917 *(₹14,99,000 / yr)* |
| **Total Net Revenue** (after Play Store 15%) | **₹2,11,650** | **₹106,179** *(₹12,74,150 / yr)* |
| **Total Expenses** (COGS) | **₹2,836** | **₹2,836** |
| **Net Profit / Month** | **+₹208,814** | **+₹103,343** |
| **Net Profit / Year** | **+₹25,05,768** | **+₹12,40,116** |
| **Gross Profit Margin** | **98.7%** | **97.3%** |

---

## 4. Scaled Projections: Per 1,000 Users (Worst-Case Scenario)

This model shows the absolute worst-case scenario: **every single one of the 1,000 users is a worst-case abuser** hitting the daily limit of 75 AI scans every day of the month.

### Cost and Volume per Month (Worst-Case)

* **Gemini AI API (Text Meal Logs)**: 1,000 × 25 scans × 30 days × ₹0.006 = **₹4,500.00**
* **Gemini AI API (Photo Meal Logs)**: 1,000 × 25 scans × 30 days × ₹0.024 = **₹18,000.00**
* **Gemini AI API (Vision Lens Scans)**: 1,000 × 25 scans × 30 days × ₹0.030 = **₹22,500.00**
* **Firestore Writes**: (4.5M writes - 600K free tier) × ₹7.50 / 100K = **₹292.50**
* **Firestore Reads**: (6.75M reads - 1.5M free tier) × ₹2.50 / 100K = **₹131.25**
* **Cloud Functions (v2)**: (3.25M runs - 2M free tier) = 1.25M billable runs = **₹1,762.25** *(includes compute surcharge)*
* **Total Cost / Month**: **₹47,186.00**

### P&L Summary (1,000 Users — Worst-Case Scenario)

| Metric | Monthly Subscription Plan (₹249/mo) | Yearly Subscription Plan (₹1,499/yr) |
| :--- | :--- | :--- |
| **Total Gross Revenue** | ₹2,49,000 | ₹1,24,917 *(₹14,99,000 / yr)* |
| **Total Net Revenue** (after Play Store 15%) | **₹2,11,650** | **₹106,179** *(₹12,74,150 / yr)* |
| **Total Expenses** (COGS) | **₹47,186** | **₹47,186** |
| **Net Profit / Month** | **+₹164,464** | **+₹58,993** |
| **Net Profit / Year** | **+₹19,73,568** | **+₹7,07,916** |
| **Gross Profit Margin** | **77.7%** | **55.6%** |

> **Tip**: Even if 100% of your users are bad actors trying to max out the system on the cheapest yearly subscription, the business remains **solidly profitable** (+₹58.9K profit/month per 1,000 users) due to the low per-token cost of Gemini 2.5 Flash-Lite and FUP soft-capping.

---

## 5. Summary of Key Financial Indicators (Realistic Mix)

| Metric | Value | Meaning |
| :--- | :--- | :--- |
| **ARPU** (Average Revenue Per User) | **₹106.18 / month** | Net monthly income per user on the yearly plan (conservative baseline). |
| **COGS** (Cost of Goods Sold) | **₹2.84 / month** | Average monthly infrastructure & API cost per active user. |
| **Contribution Margin** | **₹103.34 / month** | Profit per user before customer acquisition costs (CAC). |
| **Gross Margin %** | **97.3%** | Percentage of revenue remaining after hosting, database, and AI cost. |
| **LTV** (Lifetime Value - 12m retention) | **₹1,274.15** | Projected total net revenue generated per user. |
| **LTV-to-COGS Ratio** | **37 : 1** | Scale metric showing that revenue easily outpaces backend costs. |
| **Breakeven Threshold** | **User #1** | Profitable from the first user due to zero fixed server maintenance fees. |
