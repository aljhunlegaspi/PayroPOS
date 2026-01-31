# PayroPOS Color Palette

> Modern Teal & Lavender Theme - Professional, Fresh, Easy on the Eyes

---

## Color Preview

```
+----------------------------------------------------------------------------+
|                         PAYROPOS COLOR PALETTE                              |
+----------------------------------------------------------------------------+
|                                                                              |
|  PRIMARY COLORS - Dark Teal                                                  |
|  +---------------------------------------------------------------------+    |
|  |  ########  Primary       #1E454F  rgb(30, 69, 79)                   |    |
|  |  ########  Primary Light #2A5761  rgb(42, 87, 97)                   |    |
|  |  ########  Primary Dark  #173F49  rgb(23, 63, 73)                   |    |
|  |  ########  Primary Muted #87AC9E  rgb(135, 172, 158)                |    |
|  +---------------------------------------------------------------------+    |
|                                                                              |
|  SECONDARY COLORS - Blue Grey                                                |
|  +---------------------------------------------------------------------+    |
|  |  ########  Secondary       #5B7378  rgb(91, 115, 120)               |    |
|  |  ########  Secondary Light #7A9499  rgb(122, 148, 153)              |    |
|  |  ########  Secondary Dark  #4A5F63  rgb(74, 95, 99)                 |    |
|  +---------------------------------------------------------------------+    |
|                                                                              |
|  ACCENT COLORS                                                               |
|  +---------------------------------------------------------------------+    |
|  |  ########  Lavender Accent  #D3C2F8  rgb(211, 194, 248)             |    |
|  |  ########  Lime Accent      #C3F351  rgb(195, 243, 81)              |    |
|  +---------------------------------------------------------------------+    |
|                                                                              |
|  BACKGROUND COLORS                                                           |
|  +---------------------------------------------------------------------+    |
|  |  ########  Background       #CAD6DC  Cool light grey/blue           |    |
|  |  ########  Surface          #FFFFFF  Pure white (cards)             |    |
|  |  ########  Surface Variant  #F5F5F6  Off-white (soft UI)            |    |
|  |  ########  Surface Tint     #E3E4EE  Light lavender/grey            |    |
|  +---------------------------------------------------------------------+    |
|                                                                              |
|  SEMANTIC COLORS                                                             |
|  +---------------------------------------------------------------------+    |
|  |  ########  Success  #059669  For: Paid, Complete, Confirmed         |    |
|  |  ########  Warning  #D97706  For: Pending, Partial, Alert           |    |
|  |  ########  Error    #DC2626  For: Failed, Overdue, Danger           |    |
|  |  ########  Info     #0284C7  For: Information, Tips, Links          |    |
|  +---------------------------------------------------------------------+    |
|                                                                              |
+----------------------------------------------------------------------------+
```

---

## Quick Reference

### Primary Colors (Dark Teal)
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Primary | `#1E454F` | `rgb(30, 69, 79)` | Headers, buttons, primary actions |
| Primary Light | `#2A5761` | `rgb(42, 87, 97)` | Hover states |
| Primary Dark | `#173F49` | `rgb(23, 63, 73)` | Shadow, pressed states |
| Primary Muted | `#87AC9E` | `rgb(135, 172, 158)` | Icons, soft blocks |

### Secondary Colors (Blue Grey)
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Secondary | `#5B7378` | `rgb(91, 115, 120)` | Text, lines, secondary elements |
| Secondary Light | `#7A9499` | `rgb(122, 148, 153)` | Lighter variants |
| Secondary Dark | `#4A5F63` | `rgb(74, 95, 99)` | Darker variants |

### Accent Colors
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Lavender | `#D3C2F8` | `rgb(211, 194, 248)` | Highlights, special badges |
| Lime | `#C3F351` | `rgb(195, 243, 81)` | CTA underlines, important highlights |

### Background Colors
| Name | Hex | Usage |
|------|-----|-------|
| Background | `#CAD6DC` | Main app background (cool light grey/blue) |
| Surface | `#FFFFFF` | Cards, dialogs, text areas |
| Surface Variant | `#F5F5F6` | Off-white soft UI elements |
| Surface Tint | `#E3E4EE` | Light lavender/grey tint |

### Semantic Colors
| Name | Hex | Usage |
|------|-----|-------|
| Success | `#059669` | Payments received, completed sales, confirmations |
| Warning | `#D97706` | Pending payments, low stock, partial payments |
| Error | `#DC2626` | Failed transactions, overdue credits, errors |
| Info | `#0284C7` | Tips, information, links |

### Text Colors
| Name | Hex | Usage |
|------|-----|-------|
| Text Primary | `#1E454F` | Headings, body text |
| Text Secondary | `#5B7378` | Labels, captions |
| Text Tertiary | `#87AC9E` | Placeholders, hints |
| Text Light | `#FFFFFF` | Text on dark backgrounds |

### Role Colors
| Name | Hex | Usage |
|------|-----|-------|
| Role Owner | `#1E454F` | Store owner badge |
| Role Staff | `#87AC9E` | Staff member badge |
| Role Admin | `#D3C2F8` | Admin badge (lavender) |

---

## Usage Examples

### Buttons
```dart
// Primary Button
ElevatedButton -> Background: #1E454F, Text: #FFFFFF

// Secondary Button (Outlined)
OutlinedButton -> Border: #1E454F, Text: #1E454F

// Danger Button
ElevatedButton -> Background: #DC2626, Text: #FFFFFF
```

### Status Indicators
```dart
// Paid/Success
Container -> Background: #D1FAE5, Text: #059669

// Pending/Warning
Container -> Background: #FEF3C7, Text: #D97706

// Failed/Error
Container -> Background: #FEE2E2, Text: #DC2626
```

### Role Badges
```dart
// Store Owner
Container -> Background: #1E454F (10% opacity), Text: #1E454F

// Staff Member
Container -> Background: #87AC9E (20% opacity), Text: #5B7378
```

---

## Font

The app uses **Inter** font family (via Google Fonts):
- Modern, clean, highly readable
- Great for numbers (important for POS)
- Works well on all screen sizes

---

## Tailwind CSS Equivalents (for Web)

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1E454F',
          light: '#2A5761',
          dark: '#173F49',
          muted: '#87AC9E',
        },
        secondary: {
          DEFAULT: '#5B7378',
          light: '#7A9499',
          dark: '#4A5F63',
        },
        accent: {
          lavender: '#D3C2F8',
          lime: '#C3F351',
        },
        background: '#CAD6DC',
        surface: {
          DEFAULT: '#FFFFFF',
          variant: '#F5F5F6',
          tint: '#E3E4EE',
        },
      },
    },
  },
}
```

---

*Last updated: 2026-01-31*
