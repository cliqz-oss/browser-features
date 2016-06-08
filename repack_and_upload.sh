#!/usr/bin/env bash

set -e
set -x

CHANNEL=browser
XPI_URL=$1
PATH=/openssl-0.9.8zg/apps/:$PATH
XPI_NAME=addon.xpi
TMP_PATH=tmp

if [ $# -eq 0 ];
then
  echo "XPI_URL is required"
  echo "  example: ./repack_and_upload.sh http://cliqz.com/latest"
  exit 1
fi

echo "CLIQZ: clobber"
rm -rf $TMP_PATH
mkdir $TMP_PATH

echo "Downloadig $XPI_URL to $TMP_PATH/addon.zip"
wget $XPI_URL -O $TMP_PATH/$XPI_NAME

echo "Unpack $TMP_PATH/addon.xpi to $TMP_PATH/addon"
unzip $TMP_PATH/$XPI_NAME -d $TMP_PATH/addon

ADDON_ID=`grep em:id $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | head -1 | cut -f3`
ADDON_VERSION=`grep em:version $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | cut -f3`
MIN_VERSION=`grep em:minVersion $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | head -1 | cut -f3`
MAX_VERSION=`grep em:maxVersion $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | head -1 | cut -f3`
SECURE_PATH=./secure/$ADDON_ID
echo "Addon: ${ADDON_ID} - ${ADDON_VERSION} - maxVersion: ${MAX_VERSION} - minVersion: ${MIN_VERSION}"

SIGNED_XPI_NAME=$ADDON_ID-$ADDON_VERSION-$CHANNEL-signed.xpi
LATEST_XPI_NAME=latest.xpi
S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL/$ADDON_ID/$SIGNED_XPI_NAME
LATEST_S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL/$ADDON_ID/$LATEST_XPI_NAME
LATEST_RDF_S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL/$ADDON_ID/latest.rdf
DOWNLOAD_URL=https://s3.amazonaws.com/cdncliqz/update/$CHANNEL/$ADDON_ID/$SIGNED_XPI_NAME

echo "CLIQZ: sign"
python ./xpi-sign/xpisign.py \
  --signer openssl \
  --keyfile $SECURE_PATH/certs \
  --passin file:$SECURE_PATH/pass \
  $TMP_PATH/$XPI_NAME \
  $TMP_PATH/$SIGNED_XPI_NAME

echo "CLIQZ: create latest rdf"
./rdf_generator.py \
  --addon-id=$ADDON_ID \
  --addon-version=$ADDON_VERSION \
  --addon-url=$DOWNLOAD_URL \
  --min-version=$MIN_VERSION \
  --max-version=$MAX_VERSION \
  --template=latest.rdf \
  --output-path=$TMP_PATH/latest.rdf

echo "CLIQZ: upload"
source $SECURE_PATH/upload-creds.sh
aws s3 cp $TMP_PATH/$SIGNED_XPI_NAME $S3_UPLOAD_URL --acl public-read
aws s3 cp $TMP_PATH/$SIGNED_XPI_NAME $LATEST_S3_UPLOAD_URL --acl public-read
aws s3 cp $TMP_PATH/latest.rdf $LATEST_RDF_S3_UPLOAD_URL --acl public-read
echo "XPI uploaded to: ${DOWNLOAD_URL}"
