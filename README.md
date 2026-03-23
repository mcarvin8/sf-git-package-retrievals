# Salesforce metadata → Git (scheduled retrievals)

This repository is a **template** for pulling metadata from a Salesforce org into your Git repo on a **schedule** (or on demand). For most package names, the run uses a **manifest** (`package.xml`) from `scripts/packages/`, copies it to `manifest/package.xml`, runs `sf project retrieve start`, and **commits and pushes** any changes under `force-app/` to the **same branch** the job checked out. The special case **`Objects.xml`** is described below.

The core logic lives in `scripts/bash/retrieve_packages.sh`. CI (GitLab or GitHub) installs the Salesforce CLI, authenticates with an org URL, sets git identity, checks out your target branch, runs that script, then resets the workspace.

---

## What you need in the repo

| Requirement | Purpose |
|-------------|---------|
| **SFDX project** | Root `sfdx-project.json` and a default package path (typically `force-app/main/default`). Create with `sf project generate` or copy from an existing project. |
| **Manifests** | One or more XML files in `scripts/packages/` (e.g. `Objects.xml`, `Apex.xml`). Each file lists the metadata types and members to retrieve (except **`Objects.xml`**, where the committed file is mainly for pre-purge typing and comments — the retrieve manifest is generated at runtime; see step 4). |
| **`.gitattributes`** | Keeps line endings consistent so retrievals do not churn on CRLF vs LF (see below). |

---

## How retrieval works (end to end)

1. **Checkout** the branch you want to keep in sync (your scheduled job must target that branch).
2. **Log in** to the org using a **SFDX auth URL** (stored as a CI secret).
3. **Select a manifest** by setting `PACKAGE_NAME` to the **filename only** (e.g. `Objects.xml`), not a path.
4. **`Objects.xml` only — generate manifest from the org:** When `PACKAGE_NAME` is **`Objects.xml`**, the script does **not** copy `scripts/packages/Objects.xml` into `manifest/`. Instead it runs **`sf project generate manifest --from-org $ORG_ALIAS`** (`--metadata CustomObject`, output `manifest/package.xml`), using the **same `ORG_ALIAS`** you used for `sf org login`. That builds an explicit list of **custom objects** that exist in the org **right now**. Package manifests that rely on **wildcards** do not line up with how **standard** objects behave in Metadata API retrieval, so generating from the org keeps custom-object retrieval aligned with reality and avoids relying on a static `*` member list.
5. **Optional pre-purge**: If `PREPURGE=true`, folders under `force-app/main/default/` that correspond to metadata types in that manifest are removed before retrieve, so you get a clean pull for those types. (Pre-purge still reads types from `scripts/packages/$PACKAGE_NAME`, including `Objects.xml`.)
6. **Retrieve** with `sf project retrieve start --manifest manifest/package.xml --ignore-conflicts --wait …`.
7. **Commit and push** only if `force-app/` changed. The push uses credentials supplied by your CI platform. Commits include **`[skip ci]`** so the push does not start another metadata pipeline on GitHub (and GitLab respects the same skip markers).

**Scheduling strategy:** Use **different schedules** (or different workflow files) per manifest so two jobs do not push to the same branch at the same time. Keep each `package.xml` **focused** (fewer types per file) so runs finish faster and failures are easier to isolate.

---

## Environment variables (script + CI)

Used by `scripts/bash/retrieve_packages.sh` and expected to be set before `source ./scripts/bash/retrieve_packages.sh`:

| Variable | Required | Description |
|----------|----------|-------------|
| `PACKAGE_NAME` | Yes | Manifest **file name** under `scripts/packages/`, e.g. `CustomConfigurations.xml`. Use **`Objects.xml`** to generate the retrieve manifest from the org (see step 4 above). |
| `DEPLOY_TIMEOUT` | Yes | Seconds for `sf project retrieve start --wait` (e.g. `240`). |
| `GIT_HTTPS_PATH` | Yes | Remote URL used for `git push` (HTTPS with token embedded per your provider’s docs). |
| `PREPURGE` | No | Set to `true` to delete existing `force-app/...` folders for metadata types in that manifest before retrieve. Requires `jq` on the runner if you use this. |
| `ORG_AUTH_URL` | Yes (in CI) | SFDX auth URL for the org; piped to `sf org login sfdx-url --set-default --alias $ORG_ALIAS --sfdx-url-stdin`. **Treat as a secret.** |
| `ORG_ALIAS` | Yes (in CI) | SFDX org alias for `sf org login` and (when `PACKAGE_NAME` is **`Objects.xml`**) for `sf project generate manifest --from-org`. Must be **exported in the job environment** before sourcing the script — GitHub’s example workflow writes it to `GITHUB_ENV` after login. On GitHub Actions, set a **variable** or **secret** `ORG_ALIAS`, or pass the manual-dispatch **org_alias** input. |

Git identity must be configured **before** sourcing the script (`git config user.name` / `user.email`). The script assumes that is already done.

---

## Line endings

Retrievals may introduce mixed line endings. The script renormalizes `force-app/` before committing. Use the provided **`.gitattributes`** in your repo so Git normalizes text files consistently.

---

## GitLab CI/CD (included)

The example pipeline is **`.gitlab-ci.yml`**.

- **Job** `packageRetrieval` runs only when the pipeline source is a **schedule** and variables match: `JOB_NAME=metadataRetrieval` and `PACKAGE_NAME` is set (see `rules` in the file).
- **Installs**: Node LTS, `@salesforce/cli`, git.
- **Runner**: The sample uses `tags: [aws, prd, us-west-2]` — replace with your runner tags or remove if you use shared runners.
- **Git remote**: `GIT_HTTPS_PATH` is built from `GIT_NAME`, `GIT_HTTPS_TOKEN`, `CI_SERVER_HOST`, and `CI_PROJECT_PATH` (see variables in `.gitlab-ci.yml`).

### Scheduled pipelines (GitLab)

Create a [scheduled pipeline](https://docs.gitlab.com/ee/ci/pipelines/schedules.html) on the **branch** you want to update (e.g. `main`). For each schedule, set CI/CD variables:

| Variable | Value |
|----------|--------|
| `JOB_NAME` | `metadataRetrieval` |
| `PACKAGE_NAME` | Manifest file name only, e.g. `Objects.xml` (see **Objects.xml** behavior above — manifest is generated from the org, not copied from `scripts/packages/`) |
| `ORG_AUTH_URL` | SFDX auth URL for the org (often via masked variable; use “Expand variable reference” if you store the URL in another variable) |
| `ORG_ALIAS` | SFDX auth alias for the org (can be set in CI/CD variables or from the scheduled pipeline) |
| `PREPURGE` | Optional: `true` to enable pre-purge |

Use **separate schedules** (or stagger times) per manifest so jobs do not overlap on the same branch.

---

## GitHub Actions (example)

The example workflow is **`.github/workflows/metadata-retrieval.yml`**.

- **`schedule`**: Cron example (edit times and duplicate the workflow file if each package needs its own cadence).
- **`workflow_dispatch`**: Run manually and choose manifest (`package_name`) and optional pre-purge. If **`package_name`** is **`Objects.xml`**, the job runs **`sf project generate manifest`** for **CustomObject** from the org before **`sf project retrieve start`** (same as scheduled runs with `PACKAGE_NAME=Objects.xml`).
- **Secrets**: Create repository secret `ORG_AUTH_URL` with your SFDX auth URL.
- **`ORG_ALIAS`**: Not a credential — set as a **repository or organization Actions variable** `ORG_ALIAS` (Settings → Secrets and variables → Actions → Variables), or keep using a secret named `ORG_ALIAS` if you prefer. On **workflow_dispatch**, you can also set the **org alias** input to override both for that run. After login, the workflow persists **`ORG_ALIAS` to `GITHUB_ENV`** so the retrieve step (and **`Objects.xml`** manifest generation) sees the same alias.
- **Permissions**: The workflow requests `contents: write` so the default `GITHUB_TOKEN` can push.
- **Optional repository variables** (Settings → Secrets and variables → Actions → Variables): `GIT_USER_NAME` and `GIT_USER_EMAIL` override the default `github-actions[bot]` identity for commits.

For scheduled runs, set the default manifest in the workflow `env` (`PACKAGE_NAME`) or pass it only via manual dispatch — see comments in the workflow file.

To run **multiple packages on different cadences**, copy the workflow file (e.g. `metadata-retrieval-objects.yml`, `metadata-retrieval-apex.yml`) and set a different `PACKAGE_NAME` and `cron` in each.

---

## Adding this to an existing Salesforce DX project

1. Copy **`scripts/bash/`**, **`scripts/packages/`**, and **`scripts/registry/`** into your project’s `scripts/` folder (merge with existing `scripts` if needed).
2. Add the **GitLab** and/or **GitHub** workflow from this repo to yours and adjust names, branches, secrets, and schedules.
3. Ensure **`sfdx-project.json`** and **`force-app/`** exist at the project root.
4. Add or edit **`manifest/`** only as needed — the script creates `manifest/package.xml` either by copying `scripts/packages/$PACKAGE_NAME` or, for **`Objects.xml`**, by running **`sf project generate manifest`**, then removes the folder at the end; `manifest/` is gitignored here.

---

## Security notes

- Never commit SFDX auth URLs or long-lived tokens. Use CI **secrets** / protected variables.
- Rotate org passwords and refresh auth URLs when people leave or sandboxes refresh.
- Limit who can edit schedules and pipeline variables.

---

## Related files

| Path | Role |
|------|------|
| `scripts/bash/retrieve_packages.sh` | Retrieve, optional pre-purge, commit, push |
| `scripts/packages/*.xml` | Per-area manifests |
| `scripts/registry/metadataRegistry.json` | Maps metadata type names to default folder names for pre-purge |
| `.gitlab-ci.yml` | GitLab scheduled job |
| `.github/workflows/metadata-retrieval.yml` | GitHub scheduled + manual job |
