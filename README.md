# Senyas - Flutter Frontend Implementation

A pixel-perfect Flutter frontend implementation of the **Senyas** mobile application, converted from 8 Figma designs:
*"An offline two-way communication assistant for Deaf, Hard of Hearing and everyone."*

---

## 📱 Figma Designs & Architecture Mapping

| # | Screen / Component | Figma Node ID | Figma URL | Flutter Source File |
|---|-------------------|---------------|-----------|---------------------|
| 1 | **Status Bar** | `32:412` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=32-412&m=dev) | [`lib/widgets/senyas_status_bar.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/widgets/senyas_status_bar.dart) |
| 2 | **Introduction Screen** | `57:1254` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=57-1254&m=dev) | [`lib/screens/introduction_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/introduction_screen.dart) |
| 3 | **Front Page / Home** | `2:67` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=2-67&m=dev) | [`lib/screens/home_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/home_screen.dart) |
| 4 | **History Page** | `32:288` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=32-288&m=dev) | [`lib/screens/history_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/history_screen.dart) |
| 5 | **Profile Page** | `37:917` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=37-917&m=dev) | [`lib/screens/profile_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/profile_screen.dart) |
| 6 | **Settings Page** | `36:705` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=36-705&m=dev) | [`lib/screens/settings_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/settings_screen.dart) |
| 7 | **Speech Translation** | `32:471` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=32-471&m=dev) | [`lib/screens/speech_translation_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/speech_translation_screen.dart) |
| 8 | **Sign Translation** | `37:1111` | [View Design](https://www.figma.com/design/aIVz9pli871Iiua4myPIUd/Senyas?node-id=37-1111&m=dev) | [`lib/screens/sign_translation_screen.dart`](file:///c:/Users/Windows%2010/Documents/Coding%20Projects/Senyas/lib/screens/sign_translation_screen.dart) |

---

## 🎨 Design System & Tokens

### Colors (`lib/constants/app_colors.dart`)
- **Primary:** `#084131` (Dark forest green)
- **Accent Mint:** `#32D8B4` (Main CTA button and active status)
- **Accent Mint Dark:** `#50B09B` (Icon badge circle, camera action)
- **Accent Mint Soft:** `#B4F5E7` (Pill background, recognized card)
- **Accent Blue:** `#318DEF` (Brand tagline)
- **Accent Blue Dark:** `#143150` (Deep navy typography)
- **Accent Blue Light:** `#79A8DB` (Speech mic icon badge circle)
- **Accent Blue Soft:** `#C5E0FD` (FSL pill background, result card)
- **Sign Card Bg:** `rgba(50, 216, 180, 0.32)`
- **Speech Card Bg:** `rgba(64, 146, 233, 0.42)`
- **Background:** `#FFFFFF` (Screens) / `#F4F8F9` (Introduction)
- **Borders & Dividers:** `#E2E4E7` / `#CDE3EB`

### Typography (`lib/constants/app_text_styles.dart`)
- **Font Family:** `Inter` (via GoogleFonts)
- **H1:** Bold 28px, Line Height 36px
- **H2:** Semi-Bold 22px, Line Height 28px
- **H3:** Semi-Bold 18px, Line Height 24px
- **Body / Caption:** Regular 14px, Line Height 20px
- **Label:** Semi-Bold 12px, Line Height 16px

---

## 📁 Project Directory Structure

```text
Senyas/
├── assets/
│   ├── images/
│   │   ├── senyas_logo.png           # Senyas Brand Logo
│   │   └── sign_communication.png    # Featured banner illustration
│   └── icons/                        # 38 extracted SVG icons matching Figma
├── lib/
│   ├── main.dart                     # App entry point with routing
│   ├── constants/
│   │   ├── app_colors.dart           # Figma color tokens
│   │   ├── app_text_styles.dart      # Inter font styles
│   │   └── app_assets.dart           # Asset paths map
│   ├── models/
│   │   └── translation_history.dart  # Translation data model & mock list
│   ├── widgets/
│   │   ├── senyas_status_bar.dart    # Node 32:412 Status Bar
│   │   ├── senyas_header.dart        # Main & sub headers
│   │   ├── senyas_bottom_nav.dart    # 3-tab Bottom Navigation
│   │   ├── senyas_home_indicator.dart# iOS home indicator
│   │   └── custom_toggle_switch.dart # Figma settings switch
│   └── screens/
│       ├── introduction_screen.dart  # Node 57:1254 Introduction
│       ├── home_screen.dart          # Node 2:67 Front Page
│       ├── history_screen.dart       # Node 32:288 History
│       ├── profile_screen.dart       # Node 37:917 Profile
│       ├── settings_screen.dart      # Node 36:705 Settings
│       ├── speech_translation_screen.dart # Node 32:471 Speech
│       ├── sign_translation_screen.dart   # Node 37:1111 Sign
│       └── main_tab_scaffold.dart    # Coordinated tab scaffold
├── web_preview/                      # Interactive browser preview
│   ├── index.html
│   ├── index.css
│   └── app.js
├── pubspec.yaml                      # Flutter dependencies and assets
└── server.js                         # Local preview server
```

---

## 🚀 Running the Project

### 1. Flutter Mobile / Desktop / Web App
To run using Flutter:
```bash
flutter pub get
flutter run
```

### 2. Interactive Browser Showcase
A live companion web preview is running locally at:
👉 **[http://127.0.0.1:3000/](http://127.0.0.1:3000/)**

The preview includes:
- Exact 390x844 mobile device frame.
- Top switcher bar for all 8 designs.
- Interactive bottom navigation (Home ⇄ History ⇄ Profile).
- Working "Get Started" onboarding flow.
- Interactive Concentric Microphone with live listening ripple animation.
- Simulated Camera Viewfinder with hand tracking, landmarks, pulsing status ring, and speech synthesizer.
- Settings toggle switches with animated transitions.
