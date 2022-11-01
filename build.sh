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

echo "Building $VZIC_RELEASE_NAME"

mkdir -p build/out

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

echo "Building vzic"
make -C `pwd`/build/vzic -B OLSON_DIR=tzdata PRODUCT_ID="$VZIC_PRODID" TZID_PREFIX="$VZIC_TZID_PREFIX"

echo "Running vzic"
if [ -d build/zoneinfo ]; then rm -r build/zoneinfo; fi
mkdir -p build/zoneinfo
./build/vzic/vzic --olson-dir tzdata --output-dir build/zoneinfo --pure

export VZIC_ZONEINFO_NEW=`pwd`/build/zoneinfo

if [[ -d zoneinfo ]]; then
    export VZIC_ZONEINFO_MASTER=`pwd`/zoneinfo

    echo "Merging..."
    ./vzic-merge.pl

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
