#!/bin/bash

# Butterfly root
BUTTERFLY_ROOT=$1
BUTTERFLY_BUILD_ROOT=$2
TARGET=$3

function usage {
    echo "build_fat_package.sh BUTTERFLY_ROOT BUTTERFLY_BUILD_ROOT TARGET"
    echo "BUTTERFLY_ROOT: absolute path to Butterfly sources root"
    echo "BUTTERFLY_BUILD_ROOT: absolute path to Bitterfly build root"
    echo "TARGET: deb, rpm, etc.. depending on fpm"
}

# Check if fpm is present
fpm -h &> /dev/null
if [ $? != 0 ]; then
    echo "You need fpm installed. Check https://github.com/jordansissel/fpm"
    usage
    exit 1
fi

# Test Butterfly build root
if [ ! -f $BUTTERFLY_BUILD_ROOT/CMakeCache.txt ]; then
    echo "BUTTERFLY_BUILD_ROOT invalid"
    usage
    exit 1
fi

# Test Butterfly root
if [ ! -d $BUTTERFLY_ROOT/api ]; then
    echo "BUTTERFLY_ROOT invalid"
    usage
    exit 1
fi

# Test package type
if [ -z $TARGET ]; then
    echo "TARGET not set"
    usage
    exit 1
fi

INSTALL_ROOT=$BUTTERFLY_BUILD_ROOT/install_root
ORIGINAL_DIR=$(pwd)
BUTTERFLY_VERSION=$(cat $BUTTERFLY_BUILD_ROOT/butterfly_version)

# Clean old files/folders
rm -rf $INSTALL_ROOT &> /dev/null
rm -rf $BUTTERFLY_BUILD_ROOT/*.$TARGET

export DESTDIR=$INSTALL_ROOT
cd $BUTTERFLY_BUILD_ROOT && make package-fat

# FIXME: can't force cmake to use /usr prefix instead of /usr/local
mkdir $INSTALL_ROOT
cd $INSTALL_ROOT
ls -R
mkdir opt/
mkdir etc/
mkdir usr/
mkdir usr/bin/
cp -rv ../fat* opt/
echo '#!/bin/bash' > usr/bin/butterfly-client
echo '#!/bin/bash' > usr/bin/butterfly-server
chmod +x usr/bin/butterfly-client
chmod +x usr/bin/butterfly-server
echo '/opt/fat-butterfly-client/butterfly-client.sh $@' >> usr/bin/butterfly-client
echo '/opt/fat-butterfly-server/butterfly-server.sh $@' >> usr/bin/butterfly-server

cp $BUTTERFLY_ROOT/api/server/original_config.ini etc/

cd $ORIGINAL_DIR
fpm -s dir \
    -t $TARGET \
    -n butterfly \
    -C $INSTALL_ROOT \
    -p butterfly_VERSION_ARCH.$TARGET \
    --url https://github.com/outscale/butterfly \
    --version $BUTTERFLY_VERSION \
    --iteration 1 \
    --license GPLv3 \
    --description "Butterfly is a virtual switch permiting to isolate, connect and filter traffic between virtual machines using VXLAN." \
    --vendor "Outscale SAS" \
    usr opt etc

# clean
rm -rf $INSTALL_ROOT