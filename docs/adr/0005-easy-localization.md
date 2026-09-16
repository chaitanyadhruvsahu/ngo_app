# ADR-0005: i18n — easy_localization with JSON translation files

**Status:** Accepted
**Date:** 2026-09-16

## Context

Copy will need to be reviewed and edited by non-technical NGO staff, not just engineers, and the
app must support at least English and Hindi.

## Decision

Use the `easy_localization` package with plain JSON translation files under
`/app/assets/translations/`. Namespaced translation keys (e.g. `auth.login_button`,
`common.loading`) are the agreed convention, documented before any real UI copy is written.

## Alternatives considered

- **Official `flutter_localizations` + `intl` + `gen-l10n` (ARB files + code generation):** more
  "blessed" long-term within the Flutter ecosystem, but ARB files and the codegen pipeline are
  heavier tooling than a non-technical contributor can safely edit.

## Consequences / trade-offs

- JSON files are trivial for any contributor to edit directly.
- One more third-party dependency to keep updated.
- All lookups go through a small wrapper (`lib/core/i18n/`) so the underlying library is
  swappable later without touching every call site.

## Reversibility

Medium — isolated behind the i18n wrapper.
