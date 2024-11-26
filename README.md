# sf-package-retrievals
Framework to automate metadata retrievals from a Salesforce org into a Git branch.

This has been developed on GitLab CI/CD, but given tweaks for a specific CI/CD platform, this should be able to work on other platforms.

This assumes you have different long-running git branches for each org.

## Requirements

The docker container requires the Salesforce CLI and git. The git commands requires an active git user in your repository. 

In this example, we will be using a [GitLab project access token](https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.htm) with `write_repository` and `api` access. These CI/CD variables should be created with the token details:
- `BOT_NAME` = should be the name of the project access token bot user
- `BOT_USER_NAME` = should be the bot user name
- `PROJECT_TOKEN` = should contain the token value which is shown 1-time only after creating the token. 

These variables are configured in the `.gitlab-ci.yml` example and the `scripts/retrieve_packages.sh` script. These could be tied to a specific user HTTPS token if desired.

Other CI/CD variables, which are pre-defined GitLab CI/CD variables, the scripts use are:
- `CI_SERVER_HOST` = the instance URL for the CI/CD server
- `CI_COMMIT_BRANCH` = the branch this pipeline is running on, should be the org branch
- `CI_PROJECT_PATH` = the git repo path
- `CI_COMMIT_SHORT_SHA` = the SHA the pipeline is running on

This requires the Force Authorization URL to be assigned to the `ORG_AUTH_URL` environment variable.

The `DEPLOY_TIMEOUT` variable should be configured for the Salesforce CLI `--wait` flag in seconds.

The script assumes you are using the `force-app` directory for metadata, which can be changed based on your package directories.

## Scheduled Pipelines

The GitLab example uses scheduled pipelines to run the automated retrievals. 

When setting up the schedules, ensure the 2 variables are provided:
- `JOB_NAME` should be "metadataRetrieval"
- `PACKAGE_NAME` should be the file-name of the XML, not the full-path. Example: `CustomObjects.xml`

These schedules should be set up on the org branch you want to retrieve metadata for.
