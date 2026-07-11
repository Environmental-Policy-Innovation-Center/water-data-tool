# Update S3 File Timestamps (to re-trigger the ETL)

> **Testing only.** Confirms the overnight ETL job picks up an existing file's updated timestamp — not a normal operational task.

Bump the `Last-Modified` timestamp on one or more S3 source files without changing their data, content-type, or permissions.

- The ETL detects changes via each file's `Last-Modified` (see [ETL.md](../ETL.md)).
- A bumped timestamp re-triggers an import even when the data is identical.
- All commands below run in your terminal (AWS CLI), not the Rails console.

> **No AWS credentials?** Ask an admin for temporary access keys and confirm your IAM permissions cover this bucket, before starting.

## 1. Set AWS credentials

```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_PAGER=""   # otherwise each aws call below opens its JSON output in a pager (`q` to exit, per call)

aws sts get-caller-identity   # errors with InvalidClientTokenId if expired
```

Any AWS CLI auth method works — env vars, SSO, a named profile. Use what you already have.

## 2. Bump the timestamp(s)

S3 objects are immutable, so this does a **self-copy** with `--metadata-directive REPLACE` — same bytes, new `Last-Modified`. `--content-type` and `--acl` must be re-supplied or they reset (see warning below).

Edit `KEYS` — the two lines below are just examples, not a fixed list.

```bash
BUCKET=tech-team-data
KEYS=(
  national-dw-tool/staging/epa_sabs.csv
  national-dw-tool/staging/ejscreen.csv
)

for KEY in "${KEYS[@]}"; do
  CT=$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --query ContentType --output text)
  ETAG_BEFORE=$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --query ETag --output text)

  ETAG_AFTER=$(aws s3api copy-object \
    --bucket "$BUCKET" --key "$KEY" \
    --copy-source "$BUCKET/$KEY" \
    --metadata-directive REPLACE \
    --acl public-read \
    --content-type "$CT" \
    --output text --query 'CopyObjectResult.ETag')

  echo "$KEY  ETag before=$ETAG_BEFORE after=$ETAG_AFTER"
done
```

`copy-object` returns the new `ETag` (captured above) but never `ContentType`, even though you just set it — that's normal, not a dropped value. `ContentType` and a fresh `LastModified` still need the `head-object` check in step 3.

## 3. Verify

```bash
for KEY in "${KEYS[@]}"; do
  aws s3api head-object --bucket "$BUCKET" --key "$KEY" \
    --query '{LastModified:LastModified, ContentType:ContentType}'
done
```

- **`LastModified`** should be ~now, in **UTC** (can look like "the future" vs. your local clock — expected, not a bug).
- **`ContentType`** should match the original (e.g. `text/csv`). `binary/octet-stream` means `--content-type` got dropped — see fix below.
- **`ETag`** (the before=/after= line from step 2) — S3's content fingerprint, an MD5 of the bytes for a plain (non-multipart) upload.
  - **Match** → expected; content untouched.
  - **Mismatch → stop.** Content changed between your read and the copy, most likely a concurrent writer (another script, teammate, live pipeline). Check the file's actual content and confirm with whoever else touches this bucket path before retrying.
  - **Exception:** a multipart-uploaded original can get a differently-formatted ETag (`<hash>-<part-count>`) on copy even with identical data — not a real mismatch.

Files should still be publicly readable (the ETL fetches them anonymously over HTTPS):

```bash
curl -sI "https://$BUCKET.s3.us-east-1.amazonaws.com/national-dw-tool/staging/epa_sabs.csv" | head -1
# expect HTTP/... 200 — a 403 means the ACL got dropped, see fix below
```

## ⚠️ Do not drop `--acl` or `--content-type`

`--metadata-directive REPLACE` resets anything you don't re-specify:

- No `--content-type` → resets to `binary/octet-stream`. Caught by the `ContentType` check in step 3.
- No `--acl public-read` → object becomes **private**, ETL's anonymous fetch fails with **403 Forbidden**. Caught by the `curl` check in step 3.

Fix a dropped ACL:

```bash
aws s3api put-object-acl --bucket "$BUCKET" --key "$KEY" --acl public-read
```

Fix a dropped content-type: re-run the `copy-object` command from step 2 with the correct `--content-type`.

## Notes

- URL-encode keys with special characters (spaces, `+`) in `--copy-source`. The example keys are clean.
- Run the ETL after bumping to pick up the change — e.g. `bin/rails "etl:import[epa_sabs]"` (see [ETL.md](../ETL.md)).
- Browse objects in the console at `s3://tech-team-data/national-dw-tool/staging/` — requires AWS console access and read permission on this bucket.
