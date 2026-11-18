---
name: El Piolín POS
colors:
  surface: '#fef9ec'
  surface-dim: '#dedacd'
  surface-bright: '#fef9ec'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f8f3e6'
  surface-container: '#f2eee1'
  surface-container-high: '#ede8db'
  surface-container-highest: '#e7e2d6'
  on-surface: '#1d1c14'
  on-surface-variant: '#494552'
  inverse-surface: '#323128'
  inverse-on-surface: '#f5f0e4'
  outline: '#7a7584'
  outline-variant: '#cbc4d4'
  surface-tint: '#684ab9'
  primary: '#340685'
  on-primary: '#ffffff'
  primary-container: '#4b2a9b'
  on-primary-container: '#b9a1ff'
  inverse-primary: '#cebdff'
  secondary: '#b81212'
  on-secondary: '#ffffff'
  secondary-container: '#dc3128'
  on-secondary-container: '#fffbff'
  tertiary: '#6f5d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#c8a900'
  on-tertiary-container: '#4b3f00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e8ddff'
  primary-fixed-dim: '#cebdff'
  on-primary-fixed: '#21005d'
  on-primary-fixed-variant: '#4f2f9f'
  secondary-fixed: '#ffdad5'
  secondary-fixed-dim: '#ffb4aa'
  on-secondary-fixed: '#410001'
  on-secondary-fixed-variant: '#930006'
  tertiary-fixed: '#ffe167'
  tertiary-fixed-dim: '#e7c400'
  on-tertiary-fixed: '#221b00'
  on-tertiary-fixed-variant: '#544600'
  background: '#fef9ec'
  on-background: '#1d1c14'
  surface-variant: '#e7e2d6'
typography:
  display-lg:
    fontFamily: Domine
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
  display-lg-mobile:
    fontFamily: Domine
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
  headline-lg:
    fontFamily: Domine
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
  headline-md:
    fontFamily: Domine
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  section-header:
    fontFamily: Domine
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 18px
    letterSpacing: 0.08em
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 22px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  button-text:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  price-lg:
    fontFamily: Domine
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 28px
  price-sm:
    fontFamily: Domine
    fontSize: 15px
    fontWeight: '700'
    lineHeight: 18px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  gutter-desktop: 1rem
  margin: 1rem
  margin-mobile: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system serves a bustling, multi-generational taquería and abarrotes grocer situated in Veracruz, Mexico. It balances operational speed, extreme tactile legibility under varied ambient glare (kitchen steam, afternoon sun, dim night shifts), and cultural authenticity. 

The aesthetic is **Tactile Modernist Bodega**—rooted in Mexican commercial vernacular (hand-lettered price tags, painted canvas tarps, vinyl booths) while providing modern handheld efficiency. The visual tone is grounded, warm, unapologetically vivid, yet strictly disciplined: high-frequency primary sales actions cut through busy environments with authoritative clarity.

## Colors

The palette establishes an immediate hierarchy tailored for active, continuous touch manipulation on Android POS hardware:

- **Brand Anchor & Shell**: `Morado Lona` (`#4B2A9B`) defines the system frame, active states, and structural top app bars. Pressed variations drop into `Morado Profundo` (`#33196F`). `Morado Suave` (`#E4DCF7`) is reserved for selected category chips and softly tinted summary backgrounds.
- **Action Driver**: `Red Etiqueta` (`#D42B23`) functions exclusively as an operational trigger: `+ Nuevo Pedido`, `Cobrar`, quantity badges, and urgent inventory alerts. It must never be diluted for decorative use.
- **Accents & Signals**:
  - `Canary Yellow` (`#F6D21E`): Status tags (e.g., mesa `Abierta`) and energetic brand highlights.
  - `Orange Paw` (`#EF8A17`): Operational indicators and warning dots.
  - `Green` (`#2F9E5B`): Order discounts, paid balances, and healthy stock levels.
  - `Blue Chair` (`#2F6FD6`): System info, external links, and fiscal receipts.
- **Foundational Surfaces**:
  - Main Canvas: `Crema` (`#FBF6E9`) avoids harsh display glare in indoor environments.
  - Cards & Floating Panels: `Pure White` (`#FFFFFF`).
  - Text: `Tinta` (`#1E1530`) for maximum legibility; `Gris Banca` (`#6B6478`) for subtext and metadata.
  - Structural Lines: `#E6DEC9` for all borders, dividers, and card outlines.

## Typography

The type system blends authoritative, tabular-friendly slab-serif forms with an ultra-readable geometric sans-serif:

- **Domine** delivers the sturdy, traditional feel of rotulistas and printed receipts. It is deployed across structural titles, POS numeric entries, order totals, and monetary values. All price representations must enforce tabular numerical rendering (`font-variant-numeric: tabular-nums`).
- **Section Headers** enforce `Domine 700`, uppercase formatting, 14px size, and `+0.08em` tracking to clearly demarcate inventory and ticket partitions.
- **Hanken Grotesk** serves as the utilitarian workhorse across interactive buttons, item modifiers, tables, and settings labels. Weights 600 and 700 guarantee zero degradation on lower-resolution terminal displays.

## Layout & Spacing

Designed primarily for portrait mobile and compact tablet Android POS terminals:

- **Layout Philosophy**: A dense fluid grid built to minimize vertical scrolling during order-entry rushes. Phone devices use a 4-column layout with 12px gutters; counter tablets step up to an 8-column layout with 16px gutters, splitting active carts (sticky 3 columns) from catalog browsing (5 columns).
- **Rhythm**: Spacing follows an interior 4px/8px micro-grid. Component boundaries enforce generous touch bounds (minimum 48x48px target size) while keeping layout margins compact (`margin-mobile`: 12px) to maximize real-estate.

## Elevation & Depth

To avoid optical clutter under harsh lights, depth relies on **structural outlining and subtle surface layering** rather than blurred ambient drop shadows:

- **Level 0 (Floor)**: Canvas background `#FBF6E9`.
- **Level 1 (Card & Containers)**: Solid `#FFFFFF` with a crisp `1px solid #E6DEC9` outline. Zero drop-shadow in rest state.
- **Level 2 (Active/Pressed Overlays)**: Surface translation of -1px with an ultra-tight, crisp contact shadow: `0px 2px 0px #C9BFAC`.
- **Level 3 (Modals, Sliders, Bottom Sheets)**: `#FFFFFF` elevation container with `0px -4px 16px rgba(30, 21, 48, 0.12)` and a top boundary of `1px solid #E6DEC9`.
- **App Bar**: Clean solid `#4B2A9B` edge terminating directly at the canvas with no under-shadow.

## Shapes

The interface embraces a structured, friendly geometric profile. All cards, input containers, modals, and major touch targets adopt an exact **12px border-radius**.

- **Interactive Nodes**: Buttons, item cards, and dropdown triggers uniformly share the 12px profile.
- **Status Pills & Micro-Badges**: Badges (e.g., `Mesa 4`, `Abierta`, stock counts) enforce full pill radii (`9999px`) to create clear differentiation against rectilinear product and cart cards.

## Components

### Top App Bar
- Background: `#4B2A9B`. Height: 64px.
- Text: Station title in `Domine 700` (White), with branch or turn shift subtext in `Hanken Grotesk 400` (`#E4DCF7`).
- Includes dynamic operational status pills (e.g., `Abierta` in `#F6D21E` with `#1E1530` text).

### Buttons
- **Primary CTA**: `#D42B23` background, `#FFFFFF` text (`button-text`), height: 48px min, 12px corner radius. Pressed: `#B5201A`.
- **Secondary Action**: `#4B2A9B` background, `#FFFFFF` text. Pressed: `#33196F`.
- **Ghost/Tertiary**: Transparent fill, 1px `#E6DEC9` border, `Tinta` (`#1E1530`) text.
- Full width on modal footers and cart checkout triggers.

### Cards & Ticket Lists
- Interior padding: 12px. Border: 1px `#E6DEC9`. Surface: `#FFFFFF`. Corner radius: 12px.
- Menu Item Card: Displays item name (`Hanken Grotesk 700`), price (`Domine 700`), and quick-add tap state turning card border to `Morado Lona` (`#4B2A9B`) for 150ms.
- Order List Item: Dense line-height, split alignment with product quantity modifier (+ / -) docked on the right.

### Chips & Category Filters
- Height: 36px. Border radius: 9999px.
- **Resting**: Surface `#FFFFFF`, border 1px `#E6DEC9`, text `Gris Banca` (`#6B6478`).
- **Selected**: Surface `Morado Suave` (`#E4DCF7`), border 1px `#4B2A9B`, text `Morado Lona` (`#4B2A9B`, font-weight 700).

### Inputs & Quantity Pickers
- Border: 1px `#E6DEC9` (resting), 2px `#4B2A9B` (focus). Background: `#FFFFFF`.
- Numerical keypad input displays use `Domine 700` 24px in `Tinta` (`#1E1530`).
- Checkboxes/Radios: `#4B2A9B` active fill, custom 4px radius for checkboxes, standard circular for radios.

### Bottom Navigation Bar
- 4 fixed tabs: `Cuentas`, `Menú`, `Inventario`, `Reportes`.
- Height: 60px. Background: `#FFFFFF`. Top border: 1px `#E6DEC9`.
- Active state: `#4B2A9B` icon and label with an integrated 3px upper marker bar. Inactive: `#6B6478`.

### Offline Banner
- Surface: Pale Yellow `#FFF3C4`.
- Border-bottom: 1px `#F6D21E`.
- Indicator: 8px pulsing dot in `Orange Paw` (`#EF8A17`).
- Text: 13px `Hanken Grotesk 600` (`#1E1530`).