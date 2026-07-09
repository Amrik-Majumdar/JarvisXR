# JVS Design Tokens

The native shell targets iPhone 6 portrait-first use at 375 by 667 points.

## Spacing

- Small: 8 points.
- Medium: 16 points.
- Large: 24 points.

## Typography Intent

- Status labels: compact, semibold, uppercase when useful.
- Body text: readable at 15 points.
- Avoid oversized hero text inside tool screens.

## Color Names

- Background: graphite black.
- Primary text: soft white.
- Accent: restrained cyan.
- Warning: amber.
- Refusal: muted red.
- Dock: controlled blue.
- Offline: neutral steel.

## Motion

- Fast transition: 0.16 seconds.
- Standard transition: 0.24 seconds.
- Avoid heavy blur and continuous effects on iPhone 6.

## Component Sizing

- Minimum touch target: 44 by 44 points.
- Fixed status rows should not resize from dynamic text.
- Camera preview owns the inspection screen, with controls anchored below or over safe dark bands.

## Layout Notes

Portrait is locked until landscape is proven useful. Use safe top and bottom margins even on older devices. Treat online, dock, and jailbreak indicators as state signals, not decoration.
