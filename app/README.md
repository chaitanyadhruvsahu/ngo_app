# Flutter client (`/app`)

Single Flutter codebase targeting Web and Android (ADR-0001). State management is Riverpod
(ADR-0004), i18n is `easy_localization` with JSON files (ADR-0005).

## Getting started

```bash
flutter pub get
flutter run -d chrome                       # web
flutter run                                  # connected Android device/emulator
flutter analyze
flutter test
flutter test integration_test                # requires a connected device/emulator
```

Point the client at a non-default backend with:

```bash
flutter run --dart-define=API_BASE_URL=https://staging.example.com/api/v1
```

> **Note on this scaffold:** this project was generated in an environment without a local
> Flutter SDK, so `lib/`, `assets/`, `test/`, and `integration_test/` were hand-authored and
> could not be run through `flutter analyze` / `flutter test` locally before being committed.
> The `android/` and `web/` platform folders were hand-authored to match the current standard
> Flutter templates (Gradle Kotlin embedding v2, `flutter_bootstrap.js` web entry point). As a
> first step, run `flutter create --platforms=android,web .` from `/app` to let your installed
> Flutter version regenerate/reconcile the platform folders, then diff before committing —
> platform boilerplate is version-sensitive in ways that are hard to get right blind. CI
> (`.github/workflows/flutter-ci.yml`) will catch anything broken on the next push either way.

## Folder structure

```
lib/
  core/        theme, i18n wrapper, api client, shared config/providers
  features/    one folder per feature (auth, health, onboarding, admin, ...)
```

Every later phase's feature should follow the same `data/` (API calls) / `application/`
(Riverpod controllers, state) / `presentation/` (widgets/screens) split used by
`lib/features/auth/`.

## Auth token storage (Phase 1 / ADR-0003)

JWTs are never stored in `SharedPreferences` or any other plain-text location. Storage goes
through `lib/core/api/token_storage.dart`:

- `SecureTokenStorage` (production) wraps `flutter_secure_storage` — Keychain on iOS/macOS,
  Keystore-backed `EncryptedSharedPreferences` on Android, encrypted storage on web.
- `TokenStorage` is an abstract interface so tests can substitute `InMemoryTokenStorage`
  instead of exercising a real platform channel (the secure storage plugin needs one, which
  isn't available in widget/unit tests).
- The access token, refresh token, and role are always written/cleared together as one
  "session" (`saveSession` / `clear`), so there's never a window where one is stale relative to
  the others.

`lib/core/api/api_client.dart` is the single authenticated HTTP client every feature should use:
it attaches the stored access token to outgoing requests and, on a 401, transparently calls
`/auth/refresh` (coalescing concurrent 401s into one refresh call) before retrying the original
request once. If the refresh itself fails, it clears the stored session and calls
`onSessionExpired`, which `AuthController` wires up to force a logout — the router's `redirect`
then sends the user back to `/login`.

**Do not** create a second `Dio` instance or read tokens directly from storage in a new feature
— go through `apiClientProvider` (`lib/core/providers.dart`) so refresh/auth-header behavior
stays centralized.

## i18n convention

Translation keys are namespaced (`auth.login_button`, `common.loading`, ...) and live in
`assets/translations/{en,hi}.json`. All lookups in Dart code go through `t()` in
`lib/core/i18n/translator.dart` rather than calling `easy_localization`'s `.tr()` directly, so
the underlying package stays swappable (ADR-0005).
