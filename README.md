# sf-git-package-retrievals
Schedule automated metadata retrievals from a Salesforce org into a Git branch using manifest files (package.xml). This has been developed on GitLab CI/CD, but given tweaks for a specific CI/CD platform, this should be able to work on other git platforms.

## Requirements

The docker container requires the Salesforce CLI, bash, and git. The git commands requires an active git user in your repository. In this example, we will be using a [GitLab project access token](https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.html) with `write_repository` and `api` access to make the git commands.

The git configuration (user name and email) should all be done in the CI/CD configuration file. The `scripts/retrieve_packages.sh` script assumes the git configuration is already set. 

The script depends on 2 environment variables:
- `DEPLOY_TIMEOUT` = The wait period in seconds the Salesforce CLI should wait when running retrieve commands
- `GIT_HTTPS_PATH` = The HTTPS path which should be used by the `git push` command. In this example, it contains pre-defined GitLab CI/CD variables and the Project Access Token variables.

In the CI/CD configuration file, the following environment variables should be set:
- `GIT_HTTPS_PATH` and `DEPLOY_TIMEOUT` variables required for the script
  - In this example, `GIT_HTTPS_PATH` is `https://${BOT_NAME}:${PROJECT_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git`
- `GIT_NAME` = should be the name of the git user
- `GIT_USER_NAME` = should be the git user name
- `GIT_USER_EMAIL` = should be the git user email. By default in the GitLab example, this is the pre-defined GitLab project access token email address format. Provide this variable if you want to override it.
- `GIT_HTTPS_TOKEN` = should contain the HTTPS token value 
- `CI_SERVER_HOST` = the instance URL for the CI/CD server
- `CI_COMMIT_BRANCH` = the branch this pipeline is running on, should be the branch you want to push metadata back to
- `CI_PROJECT_PATH` = the git repo path
- `CI_COMMIT_SHORT_SHA` = the SHA the pipeline is running on
- `ORG_AUTH_URL` = Force Authorization URL for the intended Salesforce org

You can add/modify manifest files in `scripts/packages` to retrieve the specific metadata you want regularly retrieved into git. I recommend limiting the number of metadata types in each package to ensure the retrievals run faster. I also recommend ensuring your retrieval schedules are unique to avoid any overlap when pushing to the git branch.

## Line-Endings

The script will ignore line-ending changes after the retrievals, but you should use a `.gitattributes` file like the one provided to normalize line-endings in your repo.

## Scheduled Pipelines

The GitLab example uses scheduled pipelines to run the automated retrievals. 

When setting up the schedules, ensure these variables are set:
- `JOB_NAME` should be `metadataRetrieval`
- `PACKAGE_NAME` should be the manifest file-name, not the full-path, i.e. `CustomObjects.xml`
- `ORG_AUTH_URL` should be the Force Authorization UFL for the org. Use "Expand variable reference" to use existing URLs stored as variables.

These schedules should be set up on the git branch you want to retrieve metadata for.

## Adding to an Existing SFDX Project

You can easily slide this into an existing sfdx project (`sfdx-project.json` file) by:
- adding the `bash` and `packages` sub-folders into the `scripts` folder
- adding the jobs to your CI/CD configuration file
