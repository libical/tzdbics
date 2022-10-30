#!/bin/bash


# This script does
#
# * download the specified tzdata archive
# * download the specified master zoneinfo archive
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

if [[ ${VZIC_MASTER_ZONEINFO_ARCHIVE_URL} ]]; then
    echo "Downloading master zoneinfo from $VZIC_MASTER_ZONEINFO_ARCHIVE_URL"
    wget -q -O build/zoneinfo_master.tar.gz $VZIC_MASTER_ZONEINFO_ARCHIVE_URL

    export VZIC_MASTER_ZONEINFO_ARCHIVE_PATH=build/zoneinfo_master.tar.gz
fi

export VZIC_ZONEINFO_NEW=`pwd`/build/zoneinfo

if [[ ${VZIC_MASTER_ZONEINFO_ARCHIVE_PATH} ]]; then
    echo "Extracting master zoneinfo $VZIC_MASTER_ZONEINFO_ARCHIVE_PATH"
    mkdir -p build/zoneinfo_master
    tar -xzf $VZIC_MASTER_ZONEINFO_ARCHIVE_PATH -C build/zoneinfo_master

    # define variables used in vzic-merge.pl
    export VZIC_ZONEINFO_MASTER=`pwd`/build/zoneinfo_master
elif [[ -d zoneinfo ]]; then
    echo "Using existing zoneinfo as master."
    export VZIC_ZONEINFO_MASTER=`pwd`/zoneinfo
fi

if [[ ${VZIC_ZONEINFO_MASTER} ]]; then

    echo "Merging"
    ./vzic-merge.pl

    # copy updated zones
    cp -r $VZIC_ZONEINFO_NEW/zones.* $VZIC_ZONEINFO_MASTER 

    if [ "$VZIC_ZONEINFO_MASTER" != "`pwd`/zoneinfo" ]; then 
        if [ -d zoneinfo ]; then rm -r zoneinfo; fi
        mkdir -p zoneinfo
        cp -r $VZIC_ZONEINFO_MASTER zoneinfo
    fi
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
