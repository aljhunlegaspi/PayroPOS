# PayroPOS

> **Built for modern stores**

A comprehensive Point of Sale (POS) system with integrated customer credit tracking.

---

## Overview

PayroPOS is designed for small to medium retail stores that need:
- Quick and easy sales processing
- Barcode/QR code scanning
- Customer credit (utang) tracking
- Multi-staff support
- Real-time reporting

## Tech Stack

| Component | Technology |
|-----------|------------|
| Mobile App | Flutter (Android) |
| Web Admin | Next.js 14 + TypeScript |
| Database | Firebase Firestore |
| Auth | Firebase Authentication |
| Storage | Firebase Storage |
| Backend | Firebase Functions |

## Features

- **POS Operations** - Scan products, process sales, generate receipts
- **Product Management** - Categories, products, barcode/QR support
- **Customer Credit** - Track customer debts and payments
- **Staff Management** - Multi-user with role-based permissions
- **Reporting** - Sales reports, analytics, data export

## Documentation

- [Project Documentation](./docs/PROJECT_DOCUMENTATION.md) - Complete system design and specs
- [Progress Tracker](./docs/PROGRESS_TRACKER.md) - Implementation progress and checkpoints

## Project Structure

```
PayroPOS/
├── docs/                    # Documentation
├── apps/
│   ├── mobile/             # Flutter app
│   └── web/                # Next.js admin
├── firebase/               # Firebase config & functions
└── README.md
```

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Node.js 18+
- Firebase CLI
- Android Studio / VS Code

### Setup

1. Clone the repository
2. Create a Firebase project
3. Follow Phase 1 in the [Progress Tracker](./docs/PROGRESS_TRACKER.md)

## User Roles

| Role | Access | Capabilities |
|------|--------|--------------|
| Super Admin | Web | Platform management |
| Store Owner | Web + Mobile | Full store control |
| Store Staff | Mobile | POS operations |
| Customer | Mobile (optional) | View credit balance |

## License

Private project - All rights reserved

---

*PayroPOS - Built for modern stores*
