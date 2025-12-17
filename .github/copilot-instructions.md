# Copilot / AI Agent Instructions for BebaMart Flutter app

This file gives concise, actionable guidance for AI coding agents working on the BebaMart Flutter repo.

**Quick context**
- **Project type:** Flutter mobile app (Android/iOS) in `lib/` with platform folders present.
- **State management:** `flutter_riverpod` (look for `ProviderScope` overrides in `lib/main.dart`).
- **Navigation:** `go_router` via `lib/app_router.dart` and `routerProvider`.
- **Networking & storage:** `dio`, `shared_preferences`, `flutter_secure_storage` (see `pubspec.yaml`).

**Primary files to read first**
- `lib/main.dart` — app bootstrap, `StorageService.init()` override, `ProviderScope` usage.
- `lib/app_router.dart` — routing rules, auth redirects, `ShellRoute` separation for buyer/vendor flows.
- `pubspec.yaml` — dependencies and assets (`assets/images/`, `assets/animations/`).
- `lib/core/services/storage_service.dart` — local storage initialization and provider override.

**Architecture & patterns (what to know and rely on)**
- The app separates features under `lib/features/` by domain (e.g., `buyer`, `vendor`, `auth`, `chat`). Use that structure for new features.
- Routing is centralized: use `routerProvider` for navigation changes; route guards are implemented via `authProvider` watched in `app_router.dart`.
- UI shells: `ShellRoute` is used to compose persistent bottom navigation / shell UI (see `BuyerShell` and `VendorShell`).
- State is Riverpod-first. Prefer `ConsumerWidget`, `ref.watch`, and provider overrides rather than global singletons.

**Build / test / debug commands**
- Install deps: `flutter pub get`
- Run on connected device: `flutter run -d <device-id>`
- Run Android emulator: `flutter emulators --launch <name>` then `flutter run`
- Release build: `flutter build apk --release`
- Tests: `flutter test` (no special test harness detected).

**Project-specific conventions**
- Use `ProviderScope` overrides for environment-specific singletons (main sets `storageServiceProvider`). When adding services, expose them as providers and allow overrides in `main.dart` for tests.
- Navigation must go through `routerProvider` — avoid direct `Navigator.push` except in localized widget contexts where `context.go()` / `context.push()` are unsuitable.
- Feature folder layout: follow `lib/features/<feature>/screens`, `providers`, `widgets`, `models` if present — mirror existing patterns.

**Integration points & external systems**
- Backend API routes are referenced via `laravel_api_routes.php` (project root). Assume a Laravel backend; concrete base URLs and endpoints will be defined in networking helpers (search for `dio` usages).
- Native integrations: Android/iOS platform code exists; for platform-specific issues inspect `android/` and `ios/Runner`.

**When modifying code**
- Preserve Riverpod provider patterns and avoid introducing global mutable state. If you add a new service, provide a provider and add an override in `main.dart` for initialization.
- Update `pubspec.yaml` only when adding packages; run `flutter pub get` and ensure no major version bumps without testing.

**Examples (where to make common changes)**
- Add a new top-level route: modify `lib/app_router.dart` and add screen under `lib/features/<feature>/screens`.
- Add persistent dependency: create `lib/core/services/<service>.dart` exposing a provider, initialize in `main.dart` and add to `ProviderScope.overrides`.

**What not to change without confirmation**
- Do not change `StorageService.init()` signature or the way it's overridden in `main.dart` without discussing; tests and many providers expect that pattern.
- Avoid reworking the routing guard logic in `app_router.dart` without end-to-end checks of auth flows (buyer vs vendor). The redirect logic encodes role-based initial routes.

If anything here is unclear or you want deeper examples (e.g., common provider patterns or sample PRs), say which part and I will expand or adapt this file.
