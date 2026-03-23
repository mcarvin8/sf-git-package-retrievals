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

# Function to map metadata types to force-app folder names using this repo's version of metadataRegistry.json
# copied from @salesforce/source-deploy-retrieve
get_folder_for_metadata_type() {
    local metadata_type=$1
    local registry_file="scripts/registry/metadataRegistry.json"
    
    # Check if registry file exists
    if [[ ! -f "$registry_file" ]]; then
        echo ""
        return
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq not found, cannot lookup metadata type folder. Falling back to empty string." >&2
        echo ""
        return
    fi
    
    # Look up the metadata type in the registry JSON
    # Search for a type where the name field matches (case-insensitive)
    local folder_name
    folder_name=$(jq -r --arg type "$metadata_type" '
        .types | to_entries[] | 
        select((.value.name | ascii_downcase) == ($type | ascii_downcase)) | 
        .value.directoryName
    ' "$registry_file" 2>/dev/null | head -1)
    
    # Return the folder name if found, otherwise empty string
    if [[ -n "$folder_name" && "$folder_name" != "null" ]]; then
        echo "$folder_name"
    else
        echo ""
    fi
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
# Normalize line-endings from CR/LF to LF first
git add --renormalize force-app/ 2>/dev/null || true
if [[ -n $(git status --porcelain force-app/) ]]; then
    echo "Changes found in the force-app directory..."
    git add force-app
    git commit -m "Retrieve latest metadata defined in $PACKAGE_NAME [skip ci]"
    # Push changes to remote skipping pipeline
    git push "$GIT_HTTPS_PATH" -o ci.skip
else
    echo "There are no changes in the force-app directory."
fi
# hard reset required before switching back to trigger SHA
rm -rf manifest
git reset --hard
