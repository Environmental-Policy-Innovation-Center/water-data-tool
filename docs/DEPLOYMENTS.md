# Deployments

This document covers how the app is deployed, what environments exist, how to trigger deploys, and how to inspect what's currently running.

For the infrastructure setup and one-time provisioning steps, see the separate AWS infra handoff package.

---

## Environments

There are three environments. Pushing to `main` does **not** trigger a deploy — `main` is the stable canonical branch.

| | Production | Staging | Per-PR (ephemeral) |
|---|---|---|---|
| **Trigger** | GitHub Actions → **Promote Staging to Production** | GitHub Actions → **Deploy to Staging** | PR opened/updated against `main` |
| **Teardown** | Manual | Manual | Automatic on PR close |
| **ECS service** | `ep_app__water_data_tool__dev_us-east-1` | `ep_app__water_data_tool_staging__dev_us-east-1` | `ep_app__water_data_tool_pr_<N>__dev_us-east-1` |
| **URL** | `water-data-tool.policyinnovation.info` | `water-data-tool-staging.policyinnovation.info` | `water-data-tool-pr-<N>.policyinnovation.info` |
| **Database** | `water_data_tool_production` | `water_data_tool_staging` | `water_data_tool_preview` (shared across all PRs) |
| **ECR image tags** | `prod-promoted-<digest>`, `prod-latest` | `staging-<sha>`, `staging-latest` | `pr-<N>-<sha>`, `pr-<N>-latest` |
| **IAM role** | `ep_gha__water_data_tool` | `ep_gha__water_data_tool` | `ep_gha__water_data_tool_pr` |

All environments run on the same ECS cluster (`ep_core__dev_us-east-1`) and pull images from the same ECR repository (`ep_app_service_water_data_tool`).

---

## How deploys work

All workflows are gated on a repo variable `AWS_DEPLOY_ENABLED=true` — if that variable is absent or false, all jobs silently skip. This protects forks from accidentally trying to deploy.

Authentication to AWS uses OIDC — no static IAM access keys are stored anywhere. GitHub issues a short-lived signed token per job run; AWS is configured to trust it and exchange it for temporary credentials scoped to the appropriate IAM role.

### Deploy to staging (`deploy-to-staging.yml`)

Triggered manually via **Actions → Deploy to Staging → Run workflow**. Select a branch to deploy (defaults to `main`).

1. Docker image is built and pushed to ECR with two tags: an immutable `staging-<sha>` tag and a moving `staging-latest` tag.
2. `aws ecs update-service --force-new-deployment` is called — ECS cycles in containers running the new image.
3. The workflow waits up to 15 minutes for the service to stabilize before reporting success.

### Promote staging to production (`promote-to-production.yml`)

Triggered manually via **Actions → Promote Staging to Production → Run workflow**. Requires typing `promote` in the confirmation field.

1. The existing `staging-latest` ECR image is re-tagged as `prod-latest` and `prod-promoted-<digest>` — no rebuild.
2. `aws ecs update-service --force-new-deployment` is called against the production service.
3. The workflow waits up to 15 minutes for the service to stabilize.

Because promotion re-tags an existing image, production always runs the exact artifact that was tested on staging.

The ECS task definition references the moving tag (`prod-latest` / `staging-latest`). Terraform is not involved in normal deploys — only the image and the ECS service update cycle.

### Per-PR environments

When a PR is opened or updated against `main`:

1. The image is built and pushed with `pr-<N>-<sha>` and `pr-<N>-latest` tags.
2. Secrets Manager ARNs are looked up (`rails_master_key`, `mapbox_access_token`, `mapbox_style_url`, `database_url`).
3. `service_builder` runs with `EP_ACTION=apply` — this provisions a full ECS service, ALB, Route53 DNS record, and ACM certificate unique to that PR. First provision takes ~5–10 minutes (ACM cert validation).
4. The workflow waits in two phases before posting the PR comment:
   - **Phase 1** — polls ECS every 15 seconds (up to 15 min) until a running task is confirmed to be using the exact new image SHA. This ensures we are not checking the old container.
   - **Phase 2** — polls the preview URL's `/up` health check every 15 seconds (up to 5 min) until it returns HTTP 200.
5. Once both phases pass, the PR comment with the preview URL is posted and GitHub registers the deployment as active.
6. GitHub registers a deployment against the shared `pr-previews` environment. The PR timeline shows a **View deployment** button linked to the preview URL. Clicking into `pr-previews` from the repository Deployments sidebar shows all PR deployments with individual URLs and statuses. When a PR is closed, `pr-teardowns` marks that specific deployment inactive.

> **Why the workflow takes a few minutes after `service_builder` finishes:** The workflow first confirms the new image is running in ECS (up to 15 min), then confirms the URL is returning HTTP 200 (up to 5 min), and only then posts the PR comment. If the job is still running, it is polling — not hung. First-time PR deploys can take 5–10 minutes due to ACM cert validation; subsequent pushes to the same PR typically resolve in 1–3 minutes. If Phase 1 times out, the ECS task failed to start — check CloudWatch logs. If Phase 2 times out, the container started but isn't passing its health check.

When the PR is closed, `service_builder` runs with `EP_ACTION=destroy` and tears down all provisioned resources.

> **Stale environments:** Teardown only fires on PR close. If teardown fails, the environment persists. Terraform state is preserved in S3 at `tf/water_data_tool_pr_<N>/water_data_tool_pr_<N>_pr-<N>.tfstate`. Use the **Teardown PR Environments** workflow to clean up manually, or run `terraform destroy` locally using that state file.

---

## Triggering a deploy

### Deploy to staging

1. Go to **Actions → Deploy to Staging → Run workflow**
2. Select the branch to deploy (default: `main`)
3. Click **Run workflow**

### Promote staging to production

1. Go to **Actions → Promote Staging to Production → Run workflow**
2. Type `promote` in the confirmation field
3. Click **Run workflow**

Watch progress in the **Actions** tab. Both workflows write a summary table (image digest, URL, who triggered it) to the job summary on completion.

### Tear down a specific PR environment manually

Use **Actions → Teardown PR Environment → Run workflow** to destroy a single PR environment on demand. Requires `pr-teardowns` environment approval.

1. Enter the PR number
2. Type `teardown` in the confirmation field
3. Click **Run workflow**

The workflow tears down the AWS infrastructure, then closes the PR and leaves a comment.

### Refresh cartographic boundaries

Use **Actions → Refresh Cartographic Boundaries → Run workflow** to reload the `cartographic_states`, `cartographic_counties`, and `cartographic_places` tables from the TIGER source data and bust the tile cache. Supports staging, production, and preview.

**Inputs:**

| Input | Description |
|---|---|
| `target_environment` | `staging`, `production`, or `preview` |
| `scale_service_down` | Scale the staging web service to zero while the task runs. Required for preview (the constrained instances don't have enough free memory otherwise); optional for staging/production. |
| `confirm` | Type `refresh-<env>-boundaries` exactly. Append `-with-downtime` if `scale_service_down` is true (e.g. `refresh-preview-boundaries-with-downtime`). |

**How it works:**

1. Resolves the ECS task definition from the staging or production service (preview borrows staging's task definition).
2. For preview: looks up the `ep/wdt/dev/database_url` secret ARN and injects it as a `DATABASE_URL` override, pointing the task at the shared preview database instead of staging's.
3. Runs a one-off ECS task with `CartographicBoundaries.load` and tile cache busting.
4. Runs a second verification task to confirm row counts and tile byte sizes are non-zero.
5. Optionally restores the service's desired count if it was scaled down.

The job summary shows the task ARNs, environment, and the row counts from the verification step.

This workflow does not backfill PWS generalized geometries. Those columns live on `service_area_geometries` and are derived from EPA SABS service-area polygons, not from TIGER cartographic boundaries.

### PWS generalized geometries

Production backfills missing `service_area_geometries.geom_z0_4`, `geom_z5`, `geom_z6`, and `geom_z7` during the scheduled nightly ETL. This runs even when all source files are unchanged, because the ETL post-import step checks for missing generalized geometry columns before returning from a no-op import.

Page requests do not populate these columns. Normal geometry imports keep them current after the initial deploy, and a forced `epa_sabs_geoms` import also repopulates them, but neither is required just to complete the rollout. The `etl:geometries:generalize` rake task exists for local development or an explicit manual fallback.

### Sweep stale PR environments

Use **Actions → Teardown Stale PR Environments → Run workflow** to bulk-destroy all PR environments whose last commit is older than a threshold. Requires `pr-teardowns` environment approval.

1. Optionally set **Days old** (default: 14)
2. Type `teardown` in the confirmation field
3. Click **Run workflow**

The sweep checks each PR's last commit date via the GitHub API and destroys any environment that hasn't been updated within the threshold. PRs that are already closed or not found are also torn down. Each torn-down PR is closed and receives a comment.

### List PR preview environments (AWS + ECR)

Use **Actions → List PR Environments → Run workflow** for a read-only inventory sourced from ECS and ECR (no teardown). The job summary table includes:

- PR number
- Preview URL
- **Last image push** — `pr-<N>-latest` tag in ECR (`imagePushedAt`)
- **ECS rollout** — most recent deployment on the ECS service
- Running vs desired task count
- PR state (`OPEN`, `CLOSED`, or `not found`)

This complements the **Deployments** sidebar: that UI reflects GitHub deployment records; this workflow reflects what is actually provisioned in AWS.

---

## Checking what's currently deployed

### GitHub Environments UI

The fastest way to see what PR environments are live: go to the repository home page on GitHub and click **Deployments** in the right sidebar. This shows `staging`, `production`, and `pr-previews`. Click into `pr-previews` to see every PR deployment — each entry shows its unique preview URL and whether it is currently active or has been torn down.

For a full deployment history (timestamps, who triggered, how long it ran), go to **Settings → Environments** and click into any environment.

There is also a `pr-teardowns` environment used exclusively by the two manual teardown workflows. It requires reviewer approval before any teardown job runs.

### Health check all environments

```bash
# Production
curl -fsSI https://water-data-tool.policyinnovation.info/up

# Staging
curl -fsSI https://water-data-tool-staging.policyinnovation.info/up

# A specific PR environment (replace 42 with PR number)
curl -fsSI https://water-data-tool-pr-42.policyinnovation.info/up
```

All should return `HTTP/2 200`.

### ECS service status (production + staging)

```bash
aws ecs describe-services \
  --cluster ep_core__dev_us-east-1 \
  --services \
    ep_app__water_data_tool__dev_us-east-1 \
    ep_app__water_data_tool_staging__dev_us-east-1 \
  --query 'services[*].{name:serviceName,status:status,running:runningCount,desired:desiredCount}' \
  --output table
```

### List all live PR environments

PR environments are named `water_data_tool_pr_<N>`. To find any that are currently running:

```bash
aws ecs list-services \
  --cluster ep_core__dev_us-east-1 \
  --output text \
  | tr '\t' '\n' \
  | grep water_data_tool_pr
```

To get running counts for all of them at once (replace the service names with output from above):

```bash
aws ecs describe-services \
  --cluster ep_core__dev_us-east-1 \
  --services water_data_tool_pr_12 water_data_tool_pr_15 \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}' \
  --output table
```

### What image is currently deployed

The ECS task definition references the moving tag (`prod-latest`, `staging-latest`, `pr-<N>-latest`). To see when that tag was last pushed and what SHA it points to:

```bash
aws ecr describe-images \
  --repository-name ep_app_service_water_data_tool \
  --image-ids imageTag=prod-latest imageTag=staging-latest \
  --query 'imageDetails[*].{tags:imageTags,pushed:imagePushedAt}' \
  --output table
```

To see the most recent 10 images pushed to ECR across all tags:

```bash
aws ecr describe-images \
  --repository-name ep_app_service_water_data_tool \
  --query 'sort_by(imageDetails, &imagePushedAt)[-10:].{tags:imageTags,pushed:imagePushedAt}' \
  --output table
```

### Recent container logs

```bash
# Production (look for "Booted Puma" on startup)
aws logs tail /aws/ecs/ep_app_service__water_data_tool__dev_us-east-1 --since 30m

# Staging
aws logs tail /aws/ecs/ep_app_service__water_data_tool_staging__dev_us-east-1 --since 30m
```

---

## Rollback

To roll back production to the previous image without touching the codebase:

```bash
# Find the previous immutable tag (e.g. prod-abc1234)
aws ecr describe-images \
  --repository-name ep_app_service_water_data_tool \
  --query 'sort_by(imageDetails, &imagePushedAt)[-5:].{tags:imageTags,pushed:imagePushedAt}' \
  --output table

# Re-tag it as prod-latest
PREV_SHA=abc1234   # set to the SHA you want to roll back to
ECR=516937823875.dkr.ecr.us-east-1.amazonaws.com/ep_app_service_water_data_tool

aws ecr batch-get-image \
  --repository-name ep_app_service_water_data_tool \
  --image-ids imageTag=prod-$PREV_SHA \
  --query 'images[0].imageManifest' --output text \
| xargs -I{} aws ecr put-image \
  --repository-name ep_app_service_water_data_tool \
  --image-tag prod-latest \
  --image-manifest '{}'

# Force ECS to pull the updated prod-latest
aws ecs update-service \
  --cluster ep_core__dev_us-east-1 \
  --service ep_app__water_data_tool__dev_us-east-1 \
  --force-new-deployment \
  --no-cli-pager
```

The simpler alternative is to re-run **Promote Staging to Production** after pushing the reverted commit to staging and verifying it there first.

---

## Required GitHub repo configuration

### Environments

Two environments must exist under **Settings → Environments**:

| Environment | Used by | Protection rules |
|---|---|---|
| `pr-previews` | Automated PR deploy and teardown on PR close | None — must run without approval |
| `pr-teardowns` | Manual single and stale-sweep teardown workflows | Required reviewers recommended |

No secrets or variables are configured at the environment level — all secrets and variables are repo-level and available to any job automatically.

### Secrets and variables

The workflow reads these from the repository's **Settings → Secrets and variables → Actions**:

### Variables

| Name | Value |
|---|---|
| `AWS_DEPLOY_ENABLED` | `true` |
| `AWS_REGION` | `us-east-1` |
| `ECR_REPO_URI` | `516937823875.dkr.ecr.us-east-1.amazonaws.com/ep_app_service_water_data_tool` |
| `ECS_CLUSTER` | `ep_core__dev_us-east-1` |
| `ECS_SERVICE_PROD` | `ep_app__water_data_tool__dev_us-east-1` |
| `ECS_SERVICE_STAGING` | `ep_app__water_data_tool_staging__dev_us-east-1` |
| `PROD_URL` | `https://water-data-tool.policyinnovation.info/` |
| `STAGING_URL` | `https://water-data-tool-staging.policyinnovation.info/` |
| `SERVICE_BUILDER_IMAGE_URI` | `516937823875.dkr.ecr.us-east-1.amazonaws.com/ep_service_builder:latest` |

### App environment variables

Set on each ECS task definition. **Preview** = ephemeral per-PR services (`water_data_tool_pr_<N>`) provisioned by `deploy-client-aws.yml`.

| Name | Preview | Staging | Production |
|---|---|---|---|
| `ETL_SOURCE_URL` | Required<br>`…/staging` | Required<br>`…/staging` | Required<br>`…/prod` |
| `PUBLIC_DOWNLOADS_BASE_URL` | Optional<br>Default: shared downloads bucket<br>`…/public-data-downloads/staged` | Optional<br>Default: shared downloads bucket<br>`…/public-data-downloads/staged` | Optional<br>Default: shared downloads bucket<br>`…/public-data-downloads/staged` |
| `METHODOLOGY_PDF_URL` | Optional<br>Default: shared methodology PDF on S3 | Optional<br>Default: shared methodology PDF on S3 | Optional<br>Default: shared methodology PDF on S3 |
| `ETL_SCHEDULE_ENABLED` | Encouraged<br>`true` (testing) | Strongly encouraged<br>`true` | Required<br>`true` |

All ECS services run `RAILS_ENV=production`. Use `ETL_SOURCE_URL` and `ETL_SCHEDULE_ENABLED` — not `RAILS_ENV` — to control data source and recurring imports. PR deploys set `ETL_SOURCE_URL` from the `ETL_SOURCE_URL` GitHub variable.

### Secrets

| Name | What it is |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN for branch deploys (production + staging) |
| `AWS_PR_DEPLOY_ROLE_ARN` | IAM role ARN for per-PR provisioning and teardown |
