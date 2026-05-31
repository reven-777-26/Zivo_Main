# Aura Health App Design System

This document outlines the design tokens, visual aesthetics, and UI rules for the **Aura Health** application. It serves as an instruction guide for Google Stitch or other AI design agents to generate unified, matching screens.

---

## 🎨 Color Tokens

Aura utilizes an ultra-premium, low-light, high-contrast digital cockpit palette. 

### 1. Brand Theme Backgrounds
* **Base Scaffold Background**: `#070B16` (Deep Obsidian Velvet Midnight)
* **Glass Container Background**: `#121626` (Premium Dark Space Sapphire)
* **Glass Container Border**: `#1F243B` (Subtle Frost-Slate Ice Border)
* **Ambient Page Gradient**: Linear Gradient from `#070B16` (top) to `#0C1021` (bottom)

### 2. Accent Accents & Neon Highlights
* **Ice Cyan (Primary Accent)**: `#00E5FF` (Luminous sky-blue glow - used for main metrics, hydration, and primary buttons)
* **Electric Purple (Secondary Accent)**: `#8C52FF` (Luminous royal purple - used for workout categories and buttons)
* **Jade Green (Success Accent)**: `#00E676` (Glowing emerald - used for positive metrics, calorie completion, and consistency charts)
* **Rose Crimson (Warning/Danger)**: `#FFFF3B6F` (Vibrant rose - used for calorie overages, deletes, and alerts)
* **Amber Gold (Alert/Trend)**: `#FFFF9100` (Glowing warm gold - used for warning thresholds, focus muscle zones, and streaks)

### 3. Typography Hierarchy Colors
* **Primary Text**: `#F1F5F9` (Clear Slate-White)
* **Secondary Text**: `#8F9BB3` (Cool Silver-Grey)
* **Tertiary Text**: `#3B4867` (Deep Muted Dark Slate)

---

## 📐 Layout & Geometry

* **Corner Radius (Cards)**: `22px` (Soft rounded squares for Bento grids)
* **Corner Radius (Pills/Badges)**: `10px` to `14px` (Capsules for macro splits and switches)
* **Paddings & Spacing**: 
  * Core Page Margins: `20px` (Generous gutter padding for breathing room)
  * Bento Card Margins: `12px` spacing between tiles.
  * Internal Card Padding: `14px` (Uncluttered internal alignment)
* **Visual Hierarchy (Uncluttered)**: Single-tap card triggers instead of double buttons. Micro-interactive pin elements inside containers to customize layouts.

---

## ✍️ Typography Guidelines

* **Primary Font**: `Outfit` or `Inter` (Sleek modern geometric sans-serif)
* **Screen Headers**: `26px`, Heavy Bold (`FontWeight.w900`), `-0.5` letter spacing.
* **Bento Section Titles**: `18px`, Extra Bold (`FontWeight.w900`), `-0.5` letter spacing.
* **Card Titles**: `14px`, Extra Bold (`FontWeight.w900`), `-0.3` letter spacing.
* **Support Labels & Captions**: `10px` to `12px` (`FontWeight.bold` or `FontWeight.normal`).

---

## 📲 Interaction & Aesthetics

* **Glassmorphism**: Soft background blurs behind floating elements (like the glass navigation bar).
* **Card States**:
  * **Default state**: Deep Space Card background (`#121626`) with Frost-Slate Ice Border (`#1F243B`).
  * **Active/Pinned state**: Subtle glow overlay (accent color with `0.04` opacity) and custom glowing border (`accentColor` with `0.4` opacity).
