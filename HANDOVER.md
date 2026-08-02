# 🚀 Video Platform - Project Handover Document

## 📌 Project Overview
- **Name**: Video Platform (Data Collection & Vendor Management Platform)
- **Repository**: `https://github.com/rohith1246/video-platform.git`
- **Current Version**: `1.0.0`
- **Target OS**: Mobile (Android APK / Flutter) & Web (React / Vue / Flutter Web) & Backend Node.js Express + PostgreSQL.

---

## 🛠️ Architecture & Tech Stack
1. **Mobile App (`/mobile-app`)**:
   - Framework: **Flutter 3.22.2**
   - State Management: **Provider**
   - Gradle / AGP: **AGP 8.2.1**, **Kotlin 1.9.22**, **Gradle 8.5**
   - Min SDK: `21`, Target/Compile SDK: `34`
2. **Backend API (`/backend`)**:
   - Runtime: **Node.js 18 (Express)**
   - Database: **PostgreSQL (Dockerized)**
   - Reverse Proxy: **Nginx 1.24**
3. **Infrastructure**:
   - Server: **Hostinger VPS** (`195.35.21.139` / `elevateiq-softtech.com`)
   - HTTPS API Endpoint: `https://elevateiq-softtech.com/video-platform-api`

---

## 🔑 Key Working Features & Configs
- **Android Build Fixes**: Root `android/build.gradle` defines `ext.compileSdkVersion = 34` so legacy plugins (like `speech_to_text`) evaluate cleanly.
- **CI/CD (`.github/workflows/build-apk.yml`)**: Automatically compiles debug/release APKs on push to `main` and publishes releases to GitHub Releases.
- **API Constants**: `ApiConstants.baseUrl` points to `https://elevateiq-softtech.com/video-platform-api` for real physical devices, with instant demo fallback.

---

## 🎯 Next Tasks for New Agent
1. Continue adding features to candidate recording flow & vendor dashboards.
2. Maintain GitHub Actions APK build workflow.
3. Manage VPS deployment (`docker compose up -d`).
