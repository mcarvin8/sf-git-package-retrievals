# sf-git-package-retrievals
Framework to automate metadata retrievals from a Salesforce org into a Git branch on a scheduled basis. This has been developed on GitLab CI/CD, but given tweaks for a specific CI/CD platform, this should be able to work on other platforms.

This assumes you have different long-running git branches for each org.

## Requirements

The docker container requires the Salesforce CLI and git. The git commands requires an active git user in your repository. In this example, we will be using a [GitLab project access token](https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.html) with `write_repository` and `api` access to make the git commands.

The git configuration should all be done in the CI/CD configuration file. The `scripts/retrieve_packages.sh` script assumes the git configuration is done. 

The script depends on 2 environment variables:
- `DEPLOY_TIMEOUT` = The wait period in seconds the Salesforce CLI should wait when running retrieve commands
- `GIT_HTTPS_PATH` = The HTTPS path which should be used by the `git push` command. In this example, it contains pre-defined GitLab CI/CD variables and the Project Access Token variables.

In the CI/CD configuration file, the following environment variables should be set:
- `GIT_HTTPS_PATH` and `DEPLOY_TIMEOUT` variables required for the script
  - In this example, `GIT_HTTPS_PATH` is "https://${BOT_NAME}:${PROJECT_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git"
- `BOT_NAME` = should be the name of the project access token bot user
- `BOT_USER_NAME` = should be the bot user name
- `PROJECT_TOKEN` = should contain the token value which is shown 1-time only after creating the token. 
- `CI_SERVER_HOST` = the instance URL for the CI/CD server
- `CI_COMMIT_BRANCH` = the branch this pipeline is running on, should be the org branch
- `CI_PROJECT_PATH` = the git repo path
- `CI_COMMIT_SHORT_SHA` = the SHA the pipeline is running on
-  `ORG_AUTH_URL` = Force Authorization URL for the intended Salesforce org

## Line-Endings

The script will ignore line-ending changes after the retrievals, but you should use a `.gitattributes` file like the one provided to normalize line-endings in your repo.

## Scheduled Pipelines

The GitLab example uses scheduled pipelines to run the automated retrievals. 

When setting up the schedules, ensure the 2 variables are provided:
- `JOB_NAME` should be "metadataRetrieval"
- `PACKAGE_NAME` should be the file-name of the XML, not the full-path. Example: `CustomObjects.xml`

These schedules should be set up on the org branch you want to retrieve metadata for.

## Adding to SFDX Project Template

You can easily slide this into an existing sfdx project (`sfdx-project.json` file) by adding the `bash` and `packages` sub-folders into the `scripts` folder and then add the jobs to your CI/CD configuration file.

Your project's `.gitignore` should be updated to ignore the `manifest` folder.
