# Update S3 File Timestamps (to re-trigger the ETL)

Bump the `Last-Modified` timestamp on one or more S3 source files **without changing their data, content-type, or permissions**.

The ETL detects changes by comparing each file's S3 `Last-Modified` against the last import (see [ETL.md](../ETL.md)). Touching the timestamp makes the next ETL run re-import that file, even when the data is identical — useful for testing the pipeline.

## 1. Set AWS credentials

Export your temporary credentials (all three — the session token is required), then confirm they're valid:

```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...

aws sts get-caller-identity   # errors with InvalidClientTokenId if expired


# <authenticate another way if you have it set up>
```

## 2. Bump the timestamp(s)

S3 objects are immutable, so the trick is a **self-copy** with `--metadata-directive REPLACE`. Same bytes (same ETag), new `Last-Modified`. Re-supply `--content-type` and `--acl` so those are preserved (see the warning below):

```bash
BUCKET=tech-team-data
KEYS=(
  national-dw-tool/test-staged/epa_sabs.csv
  national-dw-tool/test-staged/ejscreen.csv
)

# <Is this valid copy and pastable>
for KEY in "${KEYS[@]}"; do
  CT=$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --query ContentType --output text)
  aws s3api copy-object \
    --bucket "$BUCKET" --key "$KEY" \
    --copy-source "$BUCKET/$KEY" \
    --metadata-directive REPLACE \
    --acl public-read \
    --content-type "$CT"
done
```

## 3. Verify

`LastModified` should move; `ETag` should be unchanged (proof the data is untouched):

```bash
for KEY in "${KEYS[@]}"; do
  aws s3api head-object --bucket "$BUCKET" --key "$KEY" \
    --query '{LastModified:LastModified, ETag:ETag, ContentType:ContentType}'
done
```

Confirm the files are still publicly readable (the ETL fetches them anonymously over HTTPS):

```bash
curl -sI "https://$BUCKET.s3.us-east-1.amazonaws.com/national-dw-tool/test-staged/epa_sabs.csv" | head -1
# expect HTTP/... 200
```

## ⚠️ Do not drop `--acl` or `--content-type`

`--metadata-directive REPLACE` **rewrites the object's metadata**, resetting anything you don't re-specify to defaults:

- Omit `--content-type` → it resets to `binary/octet-stream`.
- Omit `--acl public-read` → the object becomes **private**, and the ETL's anonymous fetch fails with **403 Forbidden**.

If that happens, restore public read with:

```bash
aws s3api put-object-acl --bucket "$BUCKET" --key "$KEY" --acl public-read
```

## Notes

- Keys with special characters (spaces, `+`) must be URL-encoded in `--copy-source`. The example keys are clean.
- After bumping, run the ETL to pick up the change — e.g. `bin/rails "etl:import[epa_sabs]"` (see [ETL.md](../ETL.md)).
