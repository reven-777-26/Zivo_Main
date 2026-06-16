---
name: ZivoFit
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1b1b1b'
  surface-container: '#1f1f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353535'
  on-surface: '#e2e2e2'
  on-surface-variant: '#c5c9ac'
  inverse-surface: '#e2e2e2'
  inverse-on-surface: '#303030'
  outline: '#8f9378'
  outline-variant: '#454932'
  surface-tint: '#b4d400'
  primary: '#ffffff'
  on-primary: '#2b3400'
  primary-container: '#D9FF00'
  on-primary-container: '#5a6b00'
  inverse-primary: '#556500'
  secondary: '#c8c6c8'
  on-secondary: '#303032'
  secondary-container: '#474649'
  on-secondary-container: '#b6b4b7'
  tertiary: '#ffffff'
  on-tertiary: '#303032'
  tertiary-container: '#e4e2e4'
  on-tertiary-container: '#656466'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#D9FF00'
  primary-fixed-dim: '#b4d400'
  on-primary-fixed: '#181e00'
  on-primary-fixed-variant: '#3f4c00'
  secondary-fixed: '#e4e2e4'
  secondary-fixed-dim: '#c8c6c8'
  on-secondary-fixed: '#1b1b1d'
  on-secondary-fixed-variant: '#474649'
  tertiary-fixed: '#e4e2e4'
  tertiary-fixed-dim: '#c8c6c8'
  on-tertiary-fixed: '#1b1b1d'
  on-tertiary-fixed-variant: '#474649'
  background: '#131313'
  on-background: '#e2e2e2'
  surface-variant: '#353535'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  container-padding: 20px
  stack-gap-lg: 24px
  stack-gap-md: 16px
  stack-gap-sm: 8px
  grid-gutter: 12px
---

## Brand & Style

This design system is built for a premium, high-performance health and fitness experience. It utilizes an **Ultra-Dark AMOLED** aesthetic that prioritizes visual focus and energy conservation on OLED displays. The brand personality is disciplined, modern, and energetic, aiming to evoke a sense of focused athletic performance and high-tech precision.

The style is characterized by high contrast between a pure black foundation and vibrant neon accents. It blends **Minimalism** with **Modern SaaS** sensibilities—using significant negative space, extreme corner radii for a tactile "object" feel, and a rigorous typographic hierarchy to manage dense biometric data without overwhelming the user.

## Colors

The palette is engineered for maximum legibility in low-light environments and high-impact data visualization.

- **Primary (Neon Lime):** Used exclusively for progress indicators, primary actions, and key status highlights. It represents energy and completion.
- **Surface (Deep Charcoal):** Layers of grey differentiate content zones from the pure black background.
    - `Level 1 (Secondary)`: #1C1C1E for primary card containers.
    - `Level 2 (Tertiary)`: #2C2C2E for interactive elements within cards (e.g., buttons, input fields).
- **Background (Pure Black):** #000000 is used for the base canvas to create an infinite depth effect and maximize contrast.
- **Functional Colors:** Success, Warning, and Error states should maintain high saturation to cut through the dark interface, though the primary Lime serves as the default "Success" state.

## Typography

The system utilizes **Inter** for its neutral, highly legible character, especially at small sizes where biometric data and units are displayed.

- **Scale:** A tight scale is used to maintain a professional, data-driven look. 
- **Hierarchy:** Contrast is achieved through weight and color rather than just size. Primary data (e.g., calorie counts) uses Bold weights, while secondary metadata (e.g., timestamps or units) uses Medium weights with a 60% opacity.
- **Case:** Labels and "View All" actions often utilize uppercase styling with increased letter spacing to provide a distinct structural rhythm between content blocks.

## Layout & Spacing

The layout follows a **Fluid Grid** approach within a fixed max-width for mobile-first consumption. 

- **Outer Margins:** A consistent 20px padding is maintained at the screen edges.
- **Rhythm:** An 8px linear scale governs all spacing. Vertical stacks of cards use 16px or 24px gaps to define content relationships.
- **Internal Padding:** Cards utilize generous internal padding (typically 20px) to maintain the "spacious" feel despite the high density of information.
- **Responsive Behavior:** On larger screens, the single-column dashboard reflows into a 12-column grid, allowing cards to span multiple columns (e.g., a 2-column layout for small metric widgets and a full-width span for the main daily goal).

## Elevation & Depth

In an AMOLED-focused system, elevation is conveyed through **Tonal Layering** rather than traditional shadows.

- **Base Layer:** #000000 (The floor).
- **Card Layer:** #1C1C1E (Raised once).
- **Interactive Layer:** #2C2C2E (Raised twice; used for buttons or nested elements inside cards).
- **Overlays:** Modals and bottom sheets should use a subtle 1px border (#3A3A3C) to define edges against the pure black background, as shadows are invisible on #000000.
- **Glassmorphism:** Navigation bars may use a background blur with 80% opacity of the secondary color to maintain context during scrolls.

## Shapes

The design system uses a signature **Extra-Large Roundedness** to create a friendly, premium, and modern aesthetic that feels organic.

- **Primary Cards:** 24px to 32px corner radius.
- **Buttons & Chips:** Fully pill-shaped or 16px radius depending on height.
- **Icons:** Enclosed in circular or highly rounded containers to match the overall soft geometry.
- **Consistency:** The extreme curves are a core brand identifier; avoid mixing sharp corners with this system.

## Components

- **Cards:** The primary container. Must use the secondary color (#1C1C1E) and a minimum of 24px corner radius. Headlines inside cards should be tucked into the top-left with 20px padding.
- **Buttons:**
    - *Primary:* Pill-shaped, Neon Lime background, black text.
    - *Secondary:* Dark Grey background (#2C2C2E), Lime or White text/icons.
- **Progress Indicators:** Circular rings or thick horizontal bars. Use Neon Lime for the progress fill and a low-opacity version (20%) of the same color for the track.
- **Navigation Bar:** Persistent bottom bar with a blurred background. Active states are indicated by a Neon Lime pill-shaped background behind the icon or text.
- **Metric Widgets:** Small-format cards (2-column grid) used for quick-glance stats like Protein, Carbs, and Fats. These should use distinctive icon colors (Teal, Green, Coral) but keep the Lime as the primary brand thread.
- **Inputs:** Dark, high-radius fields with subtle borders that glow Neon Lime when focused.