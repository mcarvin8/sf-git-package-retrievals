#!/bin/bash
################################################################################
# Script: retrieve_packages.sh
# Description: Retrieves Salesforce metadata from the org into the current branch
#              based on package.xml definitions. Optionally pre-purges force-app
#              folders for specific metadata types to ensure clean retrieval.
# Usage: Called from CI/CD pipeline
# Environment Variables Required:
#   - PACKAGE_NAME: XML file name from scripts/packages/ folder
#   - PREPURGE: Set to "true" to enable pre-purge of metadata folders
#   - DEPLOY_TIMEOUT: Wait time for retrieval operation
#   - GIT_HTTPS_PATH: HTTPS path of the Git repo to push changes back to
################################################################################
set -e

# copy the package.xml to the manifest folder, overwriting the current package
mkdir -p manifest
cp -f "scripts/packages/$PACKAGE_NAME" "manifest/package.xml"

# Function to map metadata types to force-app folder names
get_folder_for_metadata_type() {
    local metadata_type=$1
    case $metadata_type in
        ApexClass) echo "classes" ;;
        ApexComponent) echo "components" ;;
        ApexPage) echo "pages" ;;
        ApexTrigger) echo "triggers" ;;
        AuraDefinitionBundle) echo "aura" ;;
        Bot) echo "bots" ;;
        CustomApplication) echo "applications" ;;
        CustomLabel) echo "labels" ;;
        CustomLabels) echo "labels" ;;
        CustomObject) echo "objects" ;;
        CustomPermission) echo "customPermissions" ;;
        DuplicateRule) echo "duplicateRules" ;;
        FlexiPage) echo "flexipages" ;;
        Flow) echo "flows" ;;
        GlobalValueSet) echo "globalValueSets" ;;
        Layout) echo "layouts" ;;
        LightningComponentBundle) echo "lwc" ;;
        PathAssistant) echo "pathAssistants" ;;
        PermissionSet) echo "permissionsets" ;;
        Profile) echo "profiles" ;;
        StandardValueSet) echo "standardValueSets" ;;
        *) echo "" ;;
    esac
}

# Pre-purge folders based on metadata types in package.xml
# Skip pre-purge if variable is not set
if [[ "$PREPURGE" == "true" ]]; then
    echo "Pre-purging force-app folders for metadata types in $PACKAGE_NAME..."
    
    # Extract metadata type names from package.xml using grep
    metadata_types=$(grep -oP '(?<=<name>)[^<]+(?=</name>)' "scripts/packages/$PACKAGE_NAME" || true)
    
    # Process each metadata type
    while IFS= read -r metadata_type; do
        if [ -n "$metadata_type" ]; then
            folder=$(get_folder_for_metadata_type "$metadata_type")
            if [ -n "$folder" ]; then
                folder_path="force-app/main/default/$folder"
                if [ -d "$folder_path" ]; then
                    echo "  Removing $folder_path..."
                    rm -rf "$folder_path"
                fi
            fi
        fi
    done <<< "$metadata_types"
else
    echo "Skipping pre-purge for $PACKAGE_NAME"
fi

echo "Retrieving metadata defined in $PACKAGE_NAME..."
sf project retrieve start --manifest manifest/package.xml --ignore-conflicts --wait $DEPLOY_TIMEOUT
# Check if there are changes in the "force-app" folder
if git diff --ignore-cr-at-eol --name-only | grep '^force-app/'; then
    echo "Changes found in the force-app directory..."
    git add force-app
    git commit -m "Retrieve latest metadata defined in $PACKAGE_NAME"
    # Push changes to remote skipping pipeline
    git push "$GIT_HTTPS_PATH" -o ci.skip
else
    echo "There are no changes in the force-app directory."
fi
# hard reset required before switching back to trigger SHA
rm -rf manifest
git reset --hard
