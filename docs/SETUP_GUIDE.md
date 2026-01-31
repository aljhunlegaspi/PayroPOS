# PayroPOS - Setup Guide

> Step-by-step guide to set up your development environment

---

## Prerequisites

Before starting, ensure you have the following installed:

### Required Software

| Software | Version | Download |
|----------|---------|----------|
| Flutter SDK | 3.x | https://docs.flutter.dev/get-started/install |
| Dart | 3.x | (Included with Flutter) |
| Node.js | 18+ | https://nodejs.org/ |
| Git | Latest | https://git-scm.com/ |
| Android Studio | Latest | https://developer.android.com/studio |
| VS Code | Latest | https://code.visualstudio.com/ |

### Recommended VS Code Extensions

**For Flutter:**
- Flutter
- Dart
- Awesome Flutter Snippets
- Flutter Riverpod Snippets

**For Next.js:**
- ESLint
- Prettier
- Tailwind CSS IntelliSense
- ES7+ React/Redux/React-Native snippets

---

## Step 1: Firebase Project Setup

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `payropos` (or your preferred name)
4. Disable Google Analytics (optional for now)
5. Click "Create project"

### 1.2 Enable Firebase Services

In your Firebase project, enable:

**Authentication:**
1. Go to Build > Authentication
2. Click "Get started"
3. Enable "Email/Password" provider

**Firestore Database:**
1. Go to Build > Firestore Database
2. Click "Create database"
3. Select "Start in test mode" (for development)
4. Choose a region close to you

**Storage:**
1. Go to Build > Storage
2. Click "Get started"
3. Select "Start in test mode"

### 1.3 Register Android App

1. In Firebase Console, click the gear icon > Project settings
2. Click "Add app" and select Android
3. Android package name: `com.payropos.app` (or your preferred)
4. App nickname: `PayroPOS`
5. Download `google-services.json`
6. Save it (you'll need it later)

### 1.4 Register Web App

1. In Project settings, click "Add app" and select Web
2. App nickname: `PayroPOS Web`
3. Check "Also set up Firebase Hosting"
4. Copy the Firebase config object
5. Save it (you'll need it later)

---

## Step 2: Flutter Project Setup

### 2.1 Create Flutter Project

```bash
# Navigate to apps folder (create if needed)
cd PayroPOS
mkdir -p apps
cd apps

# Create Flutter project
flutter create --org com.payropos mobile

cd mobile
```

### 2.2 Add Dependencies

Replace `pubspec.yaml` with:

```yaml
name: payropos
description: Point of Sale system with credit tracking
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0

  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # Navigation
  go_router: ^13.0.0

  # UI Components
  flutter_screenutil: ^5.9.0
  google_fonts: ^6.1.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  flutter_svg: ^2.0.9

  # Barcode/QR
  mobile_scanner: ^4.0.0
  qr_flutter: ^4.1.0

  # PDF & Printing
  pdf: ^3.10.7
  printing: ^5.11.1

  # Forms & Validation
  flutter_form_builder: ^9.1.1
  form_builder_validators: ^9.1.0

  # Utils
  intl: ^0.18.1
  uuid: ^4.2.2
  shared_preferences: ^2.2.2
  url_launcher: ^6.2.2

  # Icons
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.8

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/

  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fonts/Poppins-Regular.ttf
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 500
        - asset: assets/fonts/Poppins-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Poppins-Bold.ttf
          weight: 700
```

### 2.3 Install Dependencies

```bash
flutter pub get
```

### 2.4 Add Firebase Configuration

1. Copy `google-services.json` to `android/app/`
2. Update `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

3. Update `android/app/build.gradle`:

```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'com.google.gms:google-services'
}

android {
    defaultConfig {
        minSdkVersion 21  // Required for Firebase
        multiDexEnabled true
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
}
```

### 2.5 Create Folder Structure

```bash
# In apps/mobile/lib
mkdir -p core/constants
mkdir -p core/theme
mkdir -p core/utils
mkdir -p core/extensions
mkdir -p features/auth/data
mkdir -p features/auth/domain
mkdir -p features/auth/presentation
mkdir -p features/store
mkdir -p features/products
mkdir -p features/pos
mkdir -p features/customers
mkdir -p features/staff
mkdir -p features/reports
mkdir -p shared/widgets
mkdir -p shared/services
mkdir -p shared/providers
```

### 2.6 Create Asset Folders

```bash
# In apps/mobile
mkdir -p assets/images
mkdir -p assets/icons
mkdir -p assets/fonts
```

---

## Step 3: Next.js Project Setup

### 3.1 Create Next.js Project

```bash
# Navigate to apps folder
cd PayroPOS/apps

# Create Next.js project
npx create-next-app@latest web --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

cd web
```

### 3.2 Install Dependencies

```bash
npm install firebase
npm install @hookform/resolvers react-hook-form zod
npm install recharts
npm install date-fns
npm install lucide-react
npm install clsx tailwind-merge
npm install class-variance-authority
```

### 3.3 Add shadcn/ui

```bash
npx shadcn@latest init
```

Choose:
- TypeScript: Yes
- Style: Default
- Base color: Slate
- CSS variables: Yes

Install components:

```bash
npx shadcn@latest add button card input label form table dialog dropdown-menu toast tabs avatar badge separator sheet
```

### 3.4 Firebase Configuration

Create `src/lib/firebase/config.ts`:

```typescript
import { initializeApp, getApps } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

// Initialize Firebase
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);

export { app, auth, db, storage };
```

### 3.5 Environment Variables

Create `.env.local`:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your_project_id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your_project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

### 3.6 Update .gitignore

Add to `.gitignore`:

```
# Environment
.env.local
.env*.local

# Firebase
**/google-services.json
**/GoogleService-Info.plist
```

---

## Step 4: Firebase Security Rules

### 4.1 Firestore Rules

In Firebase Console > Firestore > Rules, add:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Development rules - UPDATE BEFORE PRODUCTION

    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    match /stores/{storeId} {
      allow read, write: if request.auth != null;

      match /{subcollection}/{docId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

### 4.2 Storage Rules

In Firebase Console > Storage > Rules, add:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /stores/{storeId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## Step 5: Verify Setup

### 5.1 Test Flutter

```bash
cd PayroPOS/apps/mobile
flutter doctor
flutter run
```

### 5.2 Test Next.js

```bash
cd PayroPOS/apps/web
npm run dev
```

Open http://localhost:3000

---

## Troubleshooting

### Flutter Issues

**Error: SDK not found**
```bash
flutter doctor -v
```
Follow the instructions to fix any issues.

**Error: Gradle build failed**
- Check that `google-services.json` is in `android/app/`
- Ensure minSdkVersion is 21+
- Run `flutter clean && flutter pub get`

### Next.js Issues

**Error: Module not found**
```bash
rm -rf node_modules
npm install
```

**Error: Firebase not initialized**
- Check `.env.local` has correct values
- Ensure no typos in environment variable names

### Firebase Issues

**Error: Permission denied**
- Check Firestore rules allow access
- Ensure user is authenticated
- Check Firebase project is correct

---

## Next Steps

After setup is complete:

1. Open [Progress Tracker](./PROGRESS_TRACKER.md)
2. Start with Phase 1.1 tasks
3. Mark tasks complete as you go
4. Verify checkpoints before moving to next phase

---

*Setup guide last updated: 2025-01-29*
