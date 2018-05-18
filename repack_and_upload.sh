#!/usr/bin/env bash

set -e
set -x

CHANNEL=browser
XPI_URL=$1
PATH=/openssl-0.9.8zg/apps/:$PATH
XPI_NAME=addon.xpi
XPI_WITH_UPDATER=addon_with_update_url.xpi
TMP_PATH=tmp
XPI_ID=

if [ $# -eq 0 ];
then
  echo "XPI_URL is required"
  echo "  example: ./repack_and_upload.sh http://cliqz.com/latest"
  exit 1
fi

# optional channel
if [ $# -eq 2 ];
then
  CHANNEL=$2
fi

# optional xpi id
if [ $# -eq 3 ];
then
  XPI_ID=$3
fi

echo "CLIQZ: clobber"
rm -rf $TMP_PATH
mkdir $TMP_PATH

echo "Downloadig $XPI_URL to $TMP_PATH/addon.zip"
wget $XPI_URL -O $TMP_PATH/$XPI_NAME

echo "Unpack $TMP_PATH/addon.xpi to $TMP_PATH/addon"
unzip $TMP_PATH/$XPI_NAME -d $TMP_PATH/addon

echo "Ensure folder permissions"
find $TMP_PATH/addon -type d -exec chmod 755 {} \;

function bootstrapAddon {
  ADDON_ID=`grep em:id $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | head -1 | cut -f3`
  ADDON_VERSION=`grep em:version $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | cut -f3`
  MIN_VERSION=`grep em:minVersion $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | head -1 | cut -f3`
  MAX_VERSION=`grep em:maxVersion $TMP_PATH/addon/install.rdf | sed -e 's/[<>]/	/g' | head -1 | cut -f3`
  SECURE_PATH=./secure/$ADDON_ID
  echo "Addon: ${ADDON_ID} - ${ADDON_VERSION} - maxVersion: ${MAX_VERSION} - minVersion: ${MIN_VERSION}"

  SIGNED_XPI_NAME=$ADDON_ID-$ADDON_VERSION-$CHANNEL-signed.xpi
  LATEST_XPI_NAME=latest.xpi

  # put all the output files to a *_pre folder before going live
  S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL"_pre"/$ADDON_ID/$SIGNED_XPI_NAME
  LATEST_S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL"_pre"/$ADDON_ID/$LATEST_XPI_NAME
  LATEST_RDF_S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL"_pre"/$ADDON_ID/latest.rdf

  # no "_pre" for the update URL!!!
  DOWNLOAD_URL=https://s3.amazonaws.com/cdncliqz/update/$CHANNEL/$ADDON_ID/$SIGNED_XPI_NAME
  UPDATE_URL=https://s3.amazonaws.com/cdncliqz/update/$CHANNEL/$ADDON_ID/latest.rdf

  echo "CLIQZ: add update URL"
  python ./rdf_updater.py \
    --input-installer $TMP_PATH/addon/install.rdf \
    --update-url $UPDATE_URL \

  cd $TMP_PATH/addon
  zip ../$XPI_WITH_UPDATER -r *
  cd ../../

  echo "CLIQZ: sign"
  python ./xpi-sign/xpisign.py \
    --signer openssl \
    --keyfile $SECURE_PATH/certs \
    --passin file:$SECURE_PATH/pass \
    $TMP_PATH/$XPI_WITH_UPDATER \
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
}

function webExtension {
  if [[ "$XPI_ID" == "" ]]
  then
    ADDON_ID=`cat $TMP_PATH/addon/manifest.json | jq -r '.applications.gecko.id'`
  else
    ADDON_ID=$XPI_ID
  fi

  ADDON_VERSION=`cat $TMP_PATH/addon/manifest.json | jq -r '.version'`
  SECURE_PATH=./secure/$ADDON_ID
  echo "Addon: ${ADDON_ID} - version ${ADDON_VERSION}"

  SIGNED_XPI_NAME=$ADDON_ID-$ADDON_VERSION-$CHANNEL-signed.xpi
  LATEST_XPI_NAME=latest.xpi

  # for beta channels, we upload to _beta, otherwise upload to _pre
  if [[ "$CHANNEL" == *_beta ]]
  then
    CHANNEL_DIR=$CHANNEL
  else
    # put all the output files to a *_pre folder before going live
    CHANNEL_DIR=$CHANNEL"_pre"
  fi

  S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL_DIR/$ADDON_ID/$SIGNED_XPI_NAME
  LATEST_S3_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL_DIR/$ADDON_ID/$LATEST_XPI_NAME
  S3_UPDATE_JSON_UPLOAD_URL=s3://cdncliqz/update/$CHANNEL_DIR/$ADDON_ID/update.json

  # no _pre for emeded urls
  DOWNLOAD_URL=https://s3.amazonaws.com/cdncliqz/update/$CHANNEL/$ADDON_ID/$SIGNED_XPI_NAME
  UPDATE_URL=https://s3.amazonaws.com/cdncliqz/update/$CHANNEL/$ADDON_ID/update.json

  echo "CLIQZ: update manifest.json"
  cat $TMP_PATH/addon/manifest.json | jq --arg url $UPDATE_URL '.applications.gecko.update_url = $url' > $TMP_PATH/manifest.json
  mv $TMP_PATH/manifest.json $TMP_PATH/addon/manifest.json

  cd $TMP_PATH/addon
  zip ../$XPI_WITH_UPDATER -r *
  cd ../../

  echo "CLIQZ: generate update.json"
  printf '{
  "addons": {
    "%s": {
      "updates": [
        {
          "version": "%s",
          "update_link": "%s"
        }
      ]
    }
  }
}' $ADDON_ID $ADDON_VERSION $DOWNLOAD_URL $CHECKSUM > $TMP_PATH/update.json

  echo "CLIQZ: sign"
  python ./xpi-sign/xpisign.py \
    --signer openssl \
    --keyfile $SECURE_PATH/certs \
    --passin file:$SECURE_PATH/pass \
    $TMP_PATH/$XPI_WITH_UPDATER \
    $TMP_PATH/$SIGNED_XPI_NAME

  echo "CLIQZ: upload"
  source $SECURE_PATH/upload-creds.sh
  aws s3 cp $TMP_PATH/update.json $S3_UPDATE_JSON_UPLOAD_URL --acl public-read
  aws s3 cp $TMP_PATH/$SIGNED_XPI_NAME $S3_UPLOAD_URL --acl public-read
  aws s3 cp $TMP_PATH/$SIGNED_XPI_NAME $LATEST_S3_UPLOAD_URL --acl public-read
  echo "XPI uploaded to: ${DOWNLOAD_URL}"
}

# CHECK ADDON TYPE

if [ -f $TMP_PATH/addon/install.rdf ]; then
  echo 'Detected addon type: bootstrap'
  bootstrapAddon
else
  echo 'Detected addon type: web-extension'
  webExtension
fi
