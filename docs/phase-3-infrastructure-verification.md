# Phase 3 infrastructure verification

## Django upgrade first (2026-09-20)

Django was upgraded independently from 5.1.15 to **5.2.17**, the latest installable
stable 5.2 patch returned by the package registry at the time. 5.2.18 documentation
exists but that version was not published. Python 3.14 and PostgreSQL 16 are
supported by this release. The official [5.2 release notes](https://docs.djangoproject.com/en/5.2/releases/5.2/)
were reviewed, especially the PostgreSQL minimum (14), decimal adaptation,
constraint validation, and query expression ordering changes. No application
changes were necessary for the pre-existing test suite.

Before any job-feature implementation, all **84 existing tests passed on real
PostgreSQL** in 7.690 seconds, and the Django system check reported no issues.
This is a dedicated dependency change in the working tree; no commits or PRs were
created because existing uncommitted user work must not be swept into a commit.

## Storage and dependency verification (2026-09-21)

The official MinIO binary download returned HTTP 410 and Docker is unavailable
on this host. Following upstream's source-only release instructions, a temporary
Go 1.26.8 toolchain was downloaded from go.dev (archive SHA-256 verified against
the official download listing) and the official
`RELEASE.2025-10-15T17-29-55Z` MinIO source was built successfully. It was run on
loopback with disposable credentials and test data, outside the repository.

`apps.documents.tests.test_storage` passed **3/3 tests**, including a real MinIO
integration test: document and job-photo keys, SHA-256 and exact byte round-trips,
conditional creation preserving original bytes, anonymous read denied (403),
deletion, missing-object handling, local collision protection and normalized
provider errors. The random temporary test bucket was removed by test cleanup.

The pinned mc client also compiled successfully. The exact compose provisioning
operations (`alias set`, `mb --ignore-existing`, `anonymous set none`) passed
against this temporary server and created the private development bucket.

`pip-audit -r requirements.txt` returned **No known vulnerabilities found**.
New pins are boto3 1.43.98 and Pillow 12.3.0. This scan is a timestamped result,
not a guarantee against future disclosures.

The committed CI definition builds the same pinned MinIO source release and runs
the real-network smoke independently of the main PostgreSQL regression job.
Docker compose and the hosted CI job could not be executed locally because Docker
is absent; the native MinIO integration was executed and passed. Production R2
remains unverified without credentials. Named key custodians, production escrow,
and a recovery drill remain pending NGO/professor decisions as recorded in
[key custody](encryption-key-custody.md).
