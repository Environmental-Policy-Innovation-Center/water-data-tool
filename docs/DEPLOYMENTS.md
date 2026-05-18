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
| **ECS service** | `ep_app__water_data_tool__dev_us-east-1` | `ep_app__water_data_tool_staging__dev_us-east-1` | `water_data_tool_pr_<N>` |
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
4. The environment is available at `https://water-data-tool-pr-<N>.policyinnovation.info`.
5. GitHub registers a deployment against the shared `pr-previews` environment. The PR timeline shows a **View deployment** button linked to the preview URL. Clicking into `pr-previews` from the repository Deployments sidebar shows all PR deployments with individual URLs and statuses. When a PR is closed, `pr-teardown` marks that specific deployment inactive.

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

### Tear down PR environments manually

Use **Actions → Teardown PR Environments → Run workflow** to destroy one or more PR environments on demand. Two modes:

**Specific** — destroy a single PR environment by number:
1. Set **Mode** to `specific`
2. Enter the PR number
3. Type `teardown` in the confirmation field
4. Click **Run workflow**

**Stale** — sweep all PR environments whose last commit is older than N days:
1. Set **Mode** to `stale`
2. Optionally set **Days old** (default: 14)
3. Type `teardown` in the confirmation field
4. Click **Run workflow**

The stale sweep lists all ECS services matching `water_data_tool_pr_*`, checks each PR's last commit date via the GitHub API, and destroys any that haven't been updated within the threshold. PRs that are already closed or not found are also torn down.

---

## Checking what's currently deployed

### GitHub Environments UI

The fastest way to see what PR environments are live: go to the repository home page on GitHub and click **Deployments** in the right sidebar. This shows `staging`, `production`, and `pr-previews`. Click into `pr-previews` to see every PR deployment — each entry shows its unique preview URL and whether it is currently active or has been torn down.

For a full deployment history (timestamps, who triggered, how long it ran), go to **Settings → Environments** and click into any environment.

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

### Secrets

| Name | What it is |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN for branch deploys (production + staging) |
| `AWS_PR_DEPLOY_ROLE_ARN` | IAM role ARN for per-PR provisioning and teardown |

---

## Known gaps / TODO

### Data population strategy

All three databases (`water_data_tool_production`, `water_data_tool_staging`, `water_data_tool_preview`) start empty after provisioning. Only production self-populates automatically via the recurring SolidQueue ETL job. Staging and preview need an explicit strategy:

**Staging** — recommended: schedule a weekly `pg_dump` of the production DB piped into a `pg_restore` against staging. Both databases live on the same RDS instance so there is no network egress cost. This keeps staging representative of production without waiting for ETL to run independently.

```bash
# Run from within the VPC (e.g. SSH to an ECS host)
pg_dump "$PROD_URL" | psql "$STAGING_URL"
```

**PR / preview** — recommended: trigger a one-time state seed after the PR environment comes up, using the app's existing seed task. A few states is enough to exercise all features including the map.

```bash
# Via ECS exec after container is healthy
aws ecs execute-command \
  --cluster ep_core__dev_us-east-1 \
  --task <task-arn> \
  --container water_data_tool_pr_<N> \
  --interactive \
  --command "bin/rails 'db:seed:states[VT,RI,OH,CO]'"
```

This seed command pulls public data from S3 over HTTPS — no AWS credentials required. It could be added as a post-deploy step directly in the `pr-deploy` workflow job once the ECS task is confirmed healthy.

Neither strategy is wired up yet — both are day-two operational items before staging and PR environments are used for meaningful review work.

---

### Stale PR environment cleanup

PR environments are torn down automatically by the `pr-teardown` job when a PR is closed. If teardown fails, environments can be cleaned up manually using the **Teardown PR Environments** workflow (see [Tear down PR environments manually](#tear-down-pr-environments-manually) above).

A scheduled automatic sweep (e.g. nightly cron) does not exist yet. If stale environments become a recurring problem, the `teardown-pr-envs.yml` workflow could be extended with a `schedule:` trigger using the existing `stale` mode logic.
