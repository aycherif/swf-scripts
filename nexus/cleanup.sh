#!/bin/bash -eu
# This script removes old continuous deployment releases
# Requried Env vars:
# NEXUS_ADMIN: admin's username
# NEXUS_PASSWORD: admin's password
# NEXUS_URL: Nexus URL with https://
#####

get_suffix() {
    echo $1 | cut -d '-' -f2
}

do_delete_curl() {
    curl -u $NEXUS_ADMIN:$NEXUS_PASSWORD -X "DELETE" -w "%{http_code}" "$NEXUS_URL/$1"
}

NB_RELEASES_TO_KEEP=0 # Nothing in month
CURRENT_MONTH="08"
CURRENT_YEAR=2022
BASE_PATH=/srv/nexus/storage
BASE_PATH_HOSTED=$BASE_PATH/hosted

######################
##Modules
SAML2_ADDON=3.4.0
TASK=3.4.0
PLATFORM_PRIVATE_DISTRIBUTIONS=6.4.0
#####
# Rest API Nexus repositories list
NEXUS_REPOSITORIES_LIST="exo-addons-releases"

# Fetch releases 
releases=($(cat "$BASE_PATH_HOSTED/exo-addons-releases/org/exoplatform/addons/task/task-management/maven-metadata.xml" | grep -oP $TASK-${CURRENT_YEAR}${CURRENT_MONTH}[0-9][0-9] | sort --version-sort | uniq | xargs))
echo "Available releases are:"
echo ${releases[@]}
if [ ${#releases[@]} -le $NB_RELEASES_TO_KEEP ]; then
    echo "Releases number (${#releases[@]}) does not exceed the maximum quota ($NB_RELEASES_TO_KEEP). Nothing to do."
    exit 0
fi
echo "OK, Let's start the cleanup! :-)"
releases_to_be_dropped=("${releases[@]:$NB_RELEASES_TO_KEEP}")
echo "Releases to be dropped are:"
echo ${releases_to_be_dropped[@]}
counter=1
for release in ${releases_to_be_dropped[@]}; do
    rel_suffix=$(get_suffix $release)
    echo "==========================================================================================="
    echo " ($counter/${#releases_to_be_dropped[@]}) Dropping Release:  $PLATFORM_PRIVATE_DISTRIBUTIONS-$rel_suffix..."
    echo "==========================================================================================="
    echo "saml2-addon:$SAML2_ADDON-$rel_suffix"
    find $BASE_PATH_HOSTED/exo-addons-releases/org/exoplatform/addons/sso/saml2-addon-* -type d -name $SAML2_ADDON-$rel_suffix -exec rm -rvf {} \; 2>/dev/null || true
    echo "task:$TASK-$rel_suffix"
    find $BASE_PATH_HOSTED/exo-addons-releases/org/exoplatform/addons/task -type d -name $TASK-$rel_suffix -exec rm -rvf {} \; 2>/dev/null || true
    ((counter++))
done

# Rest API Call 
for repository in ${NEXUS_REPOSITORIES_LIST}; do
    do_delete_curl "service/local/metadata/repositories/${repository}/content"
    do_delete_curl "service/local/data_index/repositories/${repository}/content"
done