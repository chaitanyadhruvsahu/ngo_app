# ADR-0008: Application-level encryption for Aadhaar/bank fields

**Status:** Accepted
**Date:** 2026-09-16

## Context

The Phase 2 mandate (§F Decision 2) requires encrypting the structured Aadhaar/bank columns on
`FellowProfile` (`aadhaar_number`, `bank_account_number`, `bank_ifsc`) at the application layer,
not just relying on Postgres disk encryption — the realistic threat for a small team's app is a
leaked DB credential or an overly broad query, not disk theft.

`django-cryptography` was the mandate's implicit assumption (the obvious first choice for this in
the Django ecosystem) but turned out to be **incompatible with Django 5.1**: it imports
`django.utils.baseconv`, which Django removed in 4.0. The package hasn't been updated since.

## Decision

Implement a small custom Django model field, `apps.core.encrypted_fields.EncryptedCharField`,
wrapping the `cryptography` package's `Fernet` symmetric encryption directly — one well-audited
primitive (AES-128-CBC + HMAC, authenticated encryption) from a package that *is* actively
maintained and already a transitive dependency of this project (pulled in by `psycopg`/`PyJWT`),
rather than depending on an abandoned wrapper.

The encryption key comes from a dedicated `FIELD_ENCRYPTION_KEY` env var — deliberately separate
from `DJANGO_SECRET_KEY`, so the two can be rotated independently and a leaked `SECRET_KEY`
doesn't also compromise encrypted data. A Django system check
(`apps.core.checks.field_encryption_key_configured`) fails deploys/`manage.py` invocations at
startup with a clear message if it's unset or malformed, rather than surfacing as a confusing
`ImproperlyConfigured` the first time a request touches an encrypted field.

`aadhaar_number`, `bank_account_number`, and `bank_ifsc` use this field.
`bank_account_holder_name` deliberately does not — a name alone isn't the sensitive part; the
account number/IFSC pairing is (Phase 2 mandate, Data Architecture).

## Alternatives considered

- **`django-cryptography`:** rejected — incompatible with Django 5.1 (see Context).
- **`django-fernet-fields` or similar wrappers:** not evaluated in depth; given the actual
  encryption logic needed is ~15 lines on top of `cryptography.fernet.Fernet`, a small in-house
  field avoids taking on another possibly-unmaintained wrapper dependency for something this
  thin.
- **Rely solely on Postgres disk/volume encryption:** rejected per the mandate — doesn't cover
  the credential-leak/over-broad-query threat model that's the actual realistic risk here.
- **pgcrypto (`django-pgcrypto-fields` or raw `pgcrypto` functions):** would push the crypto
  operation into Postgres itself. Not chosen — keeping the key and the encrypt/decrypt operation
  entirely in application code (never sent to or stored by the database layer) is a smaller trust
  boundary, and doesn't tie this to a Postgres-specific extension when the local dev fallback
  intentionally also runs against SQLite (see ADR-0009 sibling discussion — decoupling the field
  encryption from the specific DB engine keeps that fallback simple).

## Consequences / trade-offs

- Encrypted columns aren't queryable/filterable by value (`WHERE aadhaar_number = ...` doesn't
  work — Fernet ciphertext is non-deterministic, same plaintext encrypts differently each time).
  Accepted: nothing in the spec requires searching by these values.
- `FIELD_ENCRYPTION_KEY` becomes a genuine secret whose loss is a data-loss event for these three
  columns specifically (not the whole DB) — back it up like a credential, not like config. No
  backup/escrow procedure exists yet beyond "don't lose the .env" — flagged as a real gap in
  [phase-2-mandate-execution-log.md](../phase-2-mandate-execution-log.md), not solved by this ADR.
- A stale/rotated key makes existing encrypted rows permanently unreadable (`InvalidToken` on
  decrypt) — `EncryptedCharField.from_db_value` raises `ImproperlyConfigured` loudly in that case
  rather than silently returning ciphertext, so a key mismatch fails fast and visibly instead of
  corrupting data silently.
- List/summary API responses (`FellowProfileListSerializer`, used by `GET /admin/fellows`)
  deliberately exclude these fields entirely — decrypting and serializing them into every row of
  a paginated list is both unnecessary I/O and expands the field's real exposure surface for no
  reason. Only the two single-record detail views (`GET /profile/me`, `GET /admin/fellows/{id}`)
  include them.

## Reversibility

Medium — migrating encrypted↔plaintext, or swapping the encryption scheme, touches every existing
row. This is why it was implemented now, in Phase 2, before real Aadhaar/bank data exists, rather
than deferred.
