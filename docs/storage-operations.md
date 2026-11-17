# Private object storage operations

Documents and job photos share `apps.documents.services.storage`: write (SHA-256),
read stream, and rollback delete. Reads remain behind application RBAC and access
logs. Neither bucket URLs nor keys belong in client API responses.

## Local development with MinIO

From `backend`, run:

```sh
docker compose --profile storage up -d --build --wait minio
docker compose --profile storage run --rm minio-init
```

The initial build compiles pinned upstream MinIO and mc releases. The community
[latest security release](https://github.com/minio/minio/releases/tag/RELEASE.2025-10-15T17-29-55Z)
is source-only; the original project is archived and its binary download returned
HTTP 410 during implementation. Do not substitute the older, pre-security-fix
Docker image. MinIO here is a local/CI fixture, not the production recommendation.

Use the S3 values in `.env.example`, set `STORAGE_BACKEND=s3`, and restart Django.
The endpoint is `http://127.0.0.1:9000` for host-run Django or `http://minio:9000`
for the Docker web service. The console is on port 9001. Both published ports bind
only to loopback. `minio-init` creates `ngo-private` and disables anonymous access.
These fixed development credentials must never be used in production.

```sh
RUN_S3_INTEGRATION=1 python manage.py test apps.documents.tests.test_storage.S3IntegrationTests
```

This smoke test creates one random temporary bucket, writes document/photo keys,
checks exact bytes/checksums, rejects overwrites and anonymous reads, deletes the
objects and then removes only its own bucket. It requires bucket-creation rights
on the development endpoint. Normal regression runs skip the real-network test.
CI runs it in a separate job with actual MinIO, not an in-memory S3 imitation.

## Production S3 / R2

Provision a dedicated private bucket with public access disabled. Configure
`S3_BUCKET_NAME`, TLS `S3_ENDPOINT_URL` (R2 account endpoint; omit for AWS),
`S3_REGION_NAME` (`auto` for R2), and scoped service credentials through the hosting
secret manager. AWS IAM credentials can instead come from the standard boto3
credential provider chain. Grant the application only object get/put/delete in
its bucket; do not use root credentials or grant bucket-policy management.
The application never creates a production bucket or changes its policy.

Before cutover, copy existing local objects using their exact stored keys, compare
counts and SHA-256 checksums with database metadata, verify authenticated downloads
and anonymous denial, then switch the backend. Keep the original files until the
restore/cutover has been verified. Switching configuration alone does not migrate
existing bytes. Configure provider backup/versioning and retention with the NGO.

Uploads precede metadata creation. A caller rolling back a multi-photo submission
must call `delete_document` for every successfully written key; cleanup failures
must be logged for reconciliation. S3 conditional creation prevents accidental
overwrite of an existing key. Provider failures become `OSError`; missing reads
become `FileNotFoundError`. R2 deployment remains unverified until real credentials
and a bucket are supplied.
