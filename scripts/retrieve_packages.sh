#!/bin/bash
set -e

# copy the package.xml to the manifest folder
mkdir -p manifest
cp -f "packages/$PACKAGE_NAME" "manifest/package.xml"
sf project retrieve start --manifest manifest/package.xml --ignore-conflicts --wait $DEPLOY_TIMEOUT

# Check if there are changes in the "force-app" folder
if git status --porcelain | grep '^ M force-app/'; then
    echo "Changes found in the force-app directory..."
    git add force-app
    git commit -m "Retrieve latest metadata defined in $PACKAGE_NAME"
    # Push changes to remote, skipping CI pipeline
    git push "https://${BOT_NAME}:${PROJECT_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git" -o ci.skip
else
    echo "There are no changes in the force-app directory."
fi

# hard reset required before switching back to trigger SHA
rm -rf manifest
git reset --hard

# Cleanup, switch back to the SHA that triggered this pipeline and delete local branches
git -c advice.detachedHead=false checkout -q $CI_COMMIT_SHORT_SHA
git branch -D $CI_COMMIT_BRANCH
