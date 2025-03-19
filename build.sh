#!/bin/bash


# This script does
#
# * download the specified tzdata archive
# * build vzic
# * run vzic on the downloaded tzdata
# * merge the new zoneinfo into the master zoneinfo
# * archive the result and copy it to the specified output dir
# 
# The URLS for the master zoneinfo and new tzdata are read from settings.config file.
#

set -e

# read settings file
. ./settings.config

echo "Building vzic"
eval "make -C '`pwd`/vzic' -B OLSON_DIR=tzdata $VZIC_MAKE_ARGS"

if [ ! -d build ]; then mkdir -p build; fi
if [ ! -d build/out ]; then mkdir -p build/out; fi

if [ -f tzdb_version.txt ]; then
    VZIC_CURRENT_RELEASE_NAME=$(cat tzdb_version.txt)
    echo "Start version set to $VZIC_CURRENT_RELEASE_NAME from tzdb_version.txt"
else
    echo "tzdb_version.txt not found. Exiting."
    exit 1
fi

tzversions=$(wget -q -O - $VZIC_TZDB_RELEASES_URL | grep -oP 'tzdata\K[\d]+[a-z](?=\.tar\.gz)' | awk '{print ($0 ~ /^9/ ? "19" $0 : $0)}' | sort | uniq)

# Filter tzversions to skip versions before VZIC_CURRENT_RELEASE_NAME
tzversions=$(echo "$tzversions" | awk -v start="$VZIC_CURRENT_RELEASE_NAME" '$0 > start')

export VZIC_RELEASE_NAME=

for version in $tzversions; do

    export VZIC_RELEASE_NAME=$version

    echo "Processing version: $version";

    export VZIC_TZDATA_ARCHIVE_URL=$VZIC_TZDB_RELEASES_URL/tzdata$VZIC_RELEASE_NAME.tar.gz
    if [[ ${VZIC_TZDATA_ARCHIVE_URL} ]]; then
        echo "Downloading tzdata from $VZIC_TZDATA_ARCHIVE_URL"
        wget -q -O build/tzdata$VZIC_RELEASE_NAME.tar.gz $VZIC_TZDATA_ARCHIVE_URL
        export VZIC_TZDATA_ARCHIVE_PATH=build/tzdata$VZIC_RELEASE_NAME.tar.gz
    fi

    if [[ ${VZIC_TZDATA_ARCHIVE_PATH} ]]; then
        echo "Extracting new tzdata"
        if [ -d tzdata ]; then rm -rf tzdata; fi
        mkdir -p tzdata
        tar -xzf $VZIC_TZDATA_ARCHIVE_PATH -C tzdata

        cp $VZIC_TZDATA_ARCHIVE_PATH build/out
    fi

    echo "Running vzic"
    if [ -d build/zoneinfo ]; then rm -r build/zoneinfo; fi
    mkdir -p build/zoneinfo
    eval "./vzic/vzic --olson-dir tzdata --output-dir build/zoneinfo $VZIC_INVOCATION_ARGS"

    export VZIC_ZONEINFO_NEW=`pwd`/build/zoneinfo

    if [[ -d zoneinfo ]]; then
        export VZIC_ZONEINFO_MASTER=`pwd`/zoneinfo

        echo "Merging..."
        ./vzic/vzic-merge.pl

        # copy updated zones
        cp -r $VZIC_ZONEINFO_NEW/zones.* $VZIC_ZONEINFO_MASTER 

    else
        cp -r "$VZIC_ZONEINFO_NEW" zoneinfo
        export VZIC_ZONEINFO_MASTER=`pwd`/zoneinfo
        echo "No master zoneinfo configured. The new zoneinfo will not be merged and kept as is."
    fi

    echo "Creating output archive"
    VZIC_OUT_TAR="`pwd`/build/out/zoneinfo-$VZIC_RELEASE_NAME.tar.gz"
    pushd $VZIC_ZONEINFO_MASTER
    tar -czf "$VZIC_OUT_TAR" * 
    popd

    echo $VZIC_RELEASE_NAME > tzdb_version.txt

    git add .

    git commit -m "Update zoneinfo to $VZIC_RELEASE_NAME"
done
