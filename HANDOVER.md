# 🚀 Video Platform - Project Handover Document

> **Last Updated**: 2026-08-02  
> **Last Commit**: `fix: add missing AuthService.getUserId and signupCandidate static methods`  
> **Branch**: `main`

---

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
   - Database: **Neon Cloud PostgreSQL (Serverless PostgreSQL)**
   - Reverse Proxy: **Nginx 1.24**
3. **Infrastructure**:
   - Server: **Hostinger VPS** (`195.35.21.139` / `elevateiq-softtech.com`)
   - HTTPS API Endpoint: `https://elevateiq-softtech.com/video-platform-api`

---

## 🔑 Key Working Features & Configs
- **Android Build Fixes**: Root `android/build.gradle` defines `ext.compileSdkVersion = 34` so legacy plugins (like `speech_to_text`) evaluate cleanly.
- **CI/CD (`.github/workflows/build-apk.yml`)**: Automatically compiles debug/release APKs on push to `main` and publishes releases to GitHub Releases.
- **API Constants**: `ApiConstants.baseUrl` points to `https://elevateiq-softtech.com/video-platform-api` for real physical devices, with instant demo fallback.
- **Web vs Android isolation**: Web-only APIs (`dart:html`, `dart:ui_web`, `SpeechRecognition`) are hidden behind conditional exports (`html_stub.dart`, `web_camera_view_stub.dart`) so the Android kernel snapshot compiles cleanly.

---

## 🧩 AuthService API Reference
> File: `mobile-app/lib/services/auth_service.dart`

All methods are **static**. Import: `import '../../services/auth_service.dart';`

| Method | Signature | Description |
|--------|-----------|-------------|
| `login` | `Future<Map<String,dynamic>> login(String identifier, String password)` | Authenticates user; falls back to demo mode if server unreachable. |
| `signupCandidate` | `Future<Map<String,dynamic>> signupCandidate({required email, required password, required vendorCode, String? fullName, String? phone})` | Registers a new candidate via `POST /auth/register`; saves session on success; demo-mode fallback. |
| `saveSession` | `Future<void> saveSession({token, refreshToken, role, name, email, userId, vendorId})` | Persists session data to `SharedPreferences`. |
| `restoreSession` | `Future<Map<String,String>?> restoreSession()` | Returns stored session map or `null` if not logged in. |
| `getAuthHeaders` | `Future<Map<String,String>> getAuthHeaders()` | Returns `{Content-Type, Authorization: Bearer <token>}` headers. |
| `getUserId` | `Future<String> getUserId()` | Returns the stored `user_id` string (empty string if not set). |
| `logout` | `Future<void> logout()` | Clears all session keys from `SharedPreferences`. |
| `baseUrl` | `static String get baseUrl` | `ApiConstants.baseUrl + ApiConstants.apiVersion` |

### Session Keys (SharedPreferences)
```
jwt_access_token, jwt_refresh_token, user_role, user_name, user_email, user_id, vendor_id
```

---

## 🐛 Bug Fix History

| Date | Commit | Fix |
|------|--------|-----|
| 2026-08-02 | `71da9ed` | **Added `AuthService.getUserId()` and `AuthService.signupCandidate()`** — kernel snapshot failed because `profile_screen.dart:58` called `getUserId()` and `candidate_signup_screen.dart:41` called `signupCandidate()`, neither of which existed in `auth_service.dart`. Both methods now implemented with demo-mode fallback. |
| 2026-08-02 | `e489785` | Fixed orphaned code block in `auth_service.dart` that broke class parsing (missing `_getPrefs`, `restoreSession`, `getAuthHeaders`, `logout`). |
| 2026-08-02 | `–` | Isolated `dart:html` / `dart:ui_web` symbols behind `html_stub.dart` and `web_camera_view_stub.dart` conditional exports so Android build compiles cleanly. |
| 2026-08-02 | `–` | Converted all deprecated `.withValues(alpha:)` calls to `.withOpacity()` across all `.dart` screens. |
| 2026-08-02 | `–` | Updated `ApiConstants.baseUrl` and `AuthService.baseUrl` to `https://elevateiq-softtech.com/video-platform-api` for real device networking. |

---

## 🏗️ VPS Deployment Notes
- **Docker**: `docker compose up -d` in `/root/video-platform-backend/`
- **Containers**: `videoplatform_db` (PostgreSQL:5432) & `videoplatform_backend` (Node.js:5002)
- **Nginx**: `/etc/nginx/sites-enabled/default` — location `/video-platform-api/` proxies to `http://127.0.0.1:5002/`
- **Company website safety**: Do NOT modify the root Nginx `server { listen 80; }` block — it serves `elevateiq-softtech.com` company website.

---

## 🎯 Next Tasks for New Agent
1. Continue adding features to candidate recording flow & vendor dashboards.
2. Maintain GitHub Actions APK build workflow.
3. Manage VPS deployment (`docker compose up -d`).
4. If any new screen calls an `AuthService` method not in the table above, add it as a `static` method in `auth_service.dart` following the same demo-fallback pattern.
