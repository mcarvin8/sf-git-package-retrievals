#!/bin/bash
set -e

# copy the package.xml to the manifest folder
mkdir -p manifest
cp -f "packages/$PACKAGE_NAME" "manifest/package.xml"
sf project retrieve start --manifest manifest/package.xml --ignore-conflicts --wait $DEPLOY_TIMEOUT

# Check if there are changes in the "force-app" folder
if git status --porcelain | grep '^ M force-app/'; then
    echo "Changes found in your package directories..."
    git add .
    git commit -m "Retrieve latest metadata defined in $PACKAGE_NAME"
    # Push changes to remote, skipping CI pipeline
    git push "$GIT_HTTPS_PATH" -o ci.skip
else
    echo "There are no changes in your package directories."
fi

# hard reset required before switching back to trigger SHA
rm -rf manifest
git reset --hard
