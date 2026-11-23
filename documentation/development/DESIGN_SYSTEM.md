# Shared Design System

## Brand palette

- Primary: `#101820`
- Secondary: `#D4AF37`
- Background: `#F5F6F8`
- Surface: `#FFFFFF`
- Primary text: `#20252B`
- Muted text: `#777F88`

Application accents may be tuned for audience needs, but these core brand values must remain recognizable.

## Typography

Use a clean system or hosted sans-serif font. Initial prototypes use DM Sans and Manrope. Shared type roles should cover page titles, section headings, card headings, body text and captions.

## Spacing

Use a small spacing scale such as 4, 8, 12, 16, 24, 32 and 48 pixels. Components must use shared CSS variables instead of isolated hard-coded values.

## Components

- Buttons: primary, secondary, text and destructive variants.
- Forms: labels, inputs, selects, textareas, validation and helper text.
- Navigation: sidebar, top bar and mobile navigation patterns.
- Cards: consistent surface, border, radius and shadow behavior.
- Modals and drawers: accessible focus handling and close actions.
- Tables: responsive layouts, sorting states and empty states.
- Notifications: success, warning, error and informational variants.
- Status indicators: active, pending, approved, declined and cancelled states.

## Responsive layout

Shared layouts should support desktop, tablet and mobile widths. Navigation and dense tables require deliberate mobile behavior rather than horizontal overflow.

Implementation belongs in `packages/shared-ui` after the current prototypes are safely separated into CSS and JavaScript modules.
