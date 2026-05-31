---
name: Vivid Kinetic
colors:
  surface: '#051424'
  surface-dim: '#051424'
  surface-bright: '#2c3a4c'
  surface-container-lowest: '#010f1f'
  surface-container-low: '#0d1c2d'
  surface-container: '#122131'
  surface-container-high: '#1c2b3c'
  surface-container-highest: '#273647'
  on-surface: '#d4e4fa'
  on-surface-variant: '#c6c6cb'
  inverse-surface: '#d4e4fa'
  inverse-on-surface: '#233143'
  outline: '#909095'
  outline-variant: '#45474b'
  surface-tint: '#c6c6cc'
  primary: '#c6c6cc'
  on-primary: '#2f3035'
  primary-container: '#0f1115'
  on-primary-container: '#7b7c82'
  inverse-primary: '#5d5e63'
  secondary: '#5de6ff'
  on-secondary: '#00363e'
  secondary-container: '#00cbe6'
  on-secondary-container: '#00515d'
  tertiary: '#ffb783'
  on-tertiary: '#4f2500'
  tertiary-container: '#200b00'
  on-tertiary-container: '#c06409'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e2e2e8'
  primary-fixed-dim: '#c6c6cc'
  on-primary-fixed: '#1a1c20'
  on-primary-fixed-variant: '#45474b'
  secondary-fixed: '#a2eeff'
  secondary-fixed-dim: '#2fd9f4'
  on-secondary-fixed: '#001f25'
  on-secondary-fixed-variant: '#004e5a'
  tertiary-fixed: '#ffdcc5'
  tertiary-fixed-dim: '#ffb783'
  on-tertiary-fixed: '#301400'
  on-tertiary-fixed-variant: '#713700'
  background: '#051424'
  on-background: '#d4e4fa'
  surface-variant: '#273647'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  title-md:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 20px
  container-padding-desktop: 40px
  stack-gap-sm: 12px
  stack-gap-md: 24px
  section-margin: 48px
---

## Brand & Style
The design system is engineered to evoke energy, precision, and motivation through a high-contrast, multi-sensory visual language. It rejects the sterility of monochrome minimalism in favor of a **Vibrant Modernism** style. 

The aesthetic centers on a "Deep Space" canvas—a sophisticated obsidian foundation that allows high-chroma category colors to pop with almost neon intensity. The target audience is the performance-oriented enthusiast who values data clarity and aesthetic inspiration. By combining large radii, subtle glassmorphism, and intentional color-coding, the UI feels both high-tech and approachable.

## Colors
The palette is rooted in a deep obsidian base (`#0F1115`) to provide maximum contrast for functional color coding. 

- **Protein (Coral/Orange):** Used for protein tracking and muscle-building content.
- **Carbs (Sunset Yellow):** Used for energy metrics and macro-balancing.
- **Fats (Rose/Pink):** Used for healthy fats and dietary lipids.
- **Workouts (Electric Cyan):** The primary action color for starting activities, timers, and rep tracking.
- **Health (Emerald):** Reserved for positive streaks, goal completion, and heart rate recovery.

Surface layers use a slightly lighter charcoal (`#1E293B`) to create depth without losing the "true black" OLED-friendly feel of the background.

## Typography
This design system utilizes **Hanken Grotesk** for all roles to maintain a cohesive, sharp, and contemporary feel. 

- **Display & Headlines:** Use ExtraBold (800) or Bold (700) weights with negative letter spacing for a dense, high-impact look suitable for workout summaries and heavy stats.
- **Body Text:** Regular weight (400) ensures readability against dark backgrounds.
- **Labels:** Uppercase bold labels are used for macro headers and category tags to ensure they stand out even at small sizes.

## Layout & Spacing
The layout follows a **Fluid Grid** model with generous internal safe areas. 

- **Mobile:** 4-column grid with 20px side margins and 16px gutters.
- **Desktop/Tablet:** 12-column centered grid with a maximum content width of 1200px.
- **Spacing Rhythm:** Based on an 8px scale. Use 24px (md) for spacing between related components and 48px (lg) for major section breaks to ensure the UI feels airy and premium.

## Elevation & Depth
This design system employs **Glassmorphism** and **Tonal Layering** instead of traditional drop shadows.

- **Background:** Base obsidian layer.
- **Surface (Level 1):** Dark charcoal cards with a 1px inner stroke (10% white) to define edges.
- **Floating Elements (Level 2):** Semi-transparent glass panels (15% white opacity) with a 20px backdrop blur. This is used for navigation bars and modal overlays.
- **Interactive Glow:** Active elements (like the current workout card) utilize a subtle outer glow matching the category color (e.g., a 15px Cyan blur at 20% opacity) to signify focus.

## Shapes
The design system adopts a **Pill-shaped** and large-radius philosophy to counter the "aggressive" dark theme with a friendly, organic feel. 

- **Cards/Containers:** Use a minimum radius of 24px.
- **Buttons:** Fully rounded (pill) for primary actions.
- **Inputs:** 16px radius for text fields to maintain consistency with the softer card aesthetic.
- **Imagery:** Photography should always be clipped with the container's radius (24px+) to prevent sharp corners from breaking the visual flow.

## Components
- **Primary Buttons:** Pill-shaped, high-chroma backgrounds (Electric Cyan) with black text for maximum legibility.
- **Macro Chips:** Categorized by color (e.g., Protein uses the Warm Orange hex) with a subtle 10% opacity background of the same color and a bold label.
- **Progress Rings:** Large, thick strokes (12px+) with rounded caps. Use gradients between the category color and its darker shade to create a 3D effect.
- **Data Cards:** Use a glassmorphic header for food names, overlaying appetizing, high-resolution photography.
- **Iconography:** Multi-color "Glass-style" icons. Use a primary color for the main glyph and a secondary, translucent shade for the background decorative element of the icon.
- **Workouts:** High-action photography with a dark-to-transparent gradient overlay at the bottom to ensure white typography remains readable.