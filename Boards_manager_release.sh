#!/bin/bash

##########################################################
##                                                      ##
## Shell script for generating a boards manager release ##
## Created by MCUdude                                   ##
## Requires wget, jq and a bash environment             ##
##                                                      ##
##########################################################

# Change these to match your repo
AUTHOR=SpenceKonde       # Github username
REPOSITORY=DxCore # Github repo name
REPOWNER=felias-fogg # Repository owner (not necessarily author)
PAOOWNER=felias-fogg # Github owner of PyAvrOCD

# Get the version number of most recent (or specified) PyAvrOCD version
PAOVERSION=$1
if [ -z "${PAOVERSION}" ]; then
    PAOVERSION=$(curl -s https://api.github.com/repos/$PAOOWNER/PyAvrOCD/releases/latest | grep "tag_name" |  awk -F\" '{print $4}')
fi

echo "PAOVERSION: ${PAOVERSION}"

AVROCDVERSION=${PAOVERSION#"v"}

AVRDUDE_VERSION="6.3.0-arduino17or18"

# Get the download URL for the latest release from Github
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPOWNER/$REPOSITORY/releases/latest | grep "tarball_url" | awk -F\" '{print $4}')

echo "Download URL: ${DOWNLOAD_URL}"

# Get filename
DOWNLOADED_FILE=$(echo $DOWNLOAD_URL | awk -F/ '{print $8}')

echo "Downloaded file: ${DOWNLOADED_FILE}"


# Check whether most recent board file is already in the index
if grep -q ${REPOSITORY}-${DOWNLOADED_FILE#"v"}\" package_${AUTHOR}_${REPOSITORY}_index.json; then
    echo "Most recent board version is already in the index file. Nothing to do."
    exit 1
fi

# Check whether current PyAvrOCD is already part of the index
if grep -q "avrocd-tools-"${AVROCDVERSION} package_${AUTHOR}_${REPOSITORY}_index.json; then
    echo "Current PyAvrOCD version is in index. Continue ..."
else
    echo "Current PyAvrOCD version is not in index. Add it first."
    exit 1
fi


# Download file
wget --no-verbose $DOWNLOAD_URL

# Add .tar.bz2 extension to downloaded file
mv $DOWNLOADED_FILE ${DOWNLOADED_FILE}.tar.bz2

# Extract downloaded file and place it in a folder
printf "\nExtracting folder ${DOWNLOADED_FILE}.tar.bz2 to $REPOSITORY-${DOWNLOADED_FILE#"v"}\n"
mkdir -p "$REPOSITORY-${DOWNLOADED_FILE#"v"}" && tar -xzf ${DOWNLOADED_FILE}.tar.bz2 -C "$REPOSITORY-${DOWNLOADED_FILE#"v"}" --strip-components=1
printf "Done!\n"

# Move files out of the megaavr folder
mv $REPOSITORY-${DOWNLOADED_FILE#"v"}/megaavr/* $REPOSITORY-${DOWNLOADED_FILE#"v"}

# Delete downloaded file and empty megaavr folder
rm -rf ${DOWNLOADED_FILE}.tar.bz2 $REPOSITORY-${DOWNLOADED_FILE#"v"}/megaavr

# Compress folder to tar.bz2
printf "\nCompressing folder $REPOSITORY-${DOWNLOADED_FILE#"v"} to $REPOSITORY-${DOWNLOADED_FILE#"v"}.tar.bz2\n"
tar -cjSf $REPOSITORY-${DOWNLOADED_FILE#"v"}.tar.bz2 $REPOSITORY-${DOWNLOADED_FILE#"v"}
printf "Done!\n"

# Get file size on bytes
FILE_SIZE=$(wc -c "$REPOSITORY-${DOWNLOADED_FILE#"v"}.tar.bz2" | awk '{print $1}')

# Get SHA256 hash
SHA256="SHA-256:$(shasum -a 256 "$REPOSITORY-${DOWNLOADED_FILE#"v"}.tar.bz2" | awk '{print $1}')"

# Create Github download URL
URL="https://${REPOWNER}.github.io/${REPOSITORY}/$REPOSITORY-${DOWNLOADED_FILE#"v"}.tar.bz2"

cp "package_${AUTHOR}_${REPOSITORY}_index.json" "package_${AUTHOR}_${REPOSITORY}_index.json.tmp"

# Add new boards release entry
jq -r                                   \
--arg repository $REPOSITORY            \
--arg version    ${DOWNLOADED_FILE#"v"} \
--arg url        $URL                   \
--arg checksum   $SHA256                \
--arg file_size  $FILE_SIZE             \
--arg avrdude_ver $AVRDUDE_VERSION      \
--arg avrocdversion $AVROCDVERSION      \
--arg file_name  $REPOSITORY-${DOWNLOADED_FILE#"v"}.tar.bz2  \
'.packages[].platforms[.packages[].platforms | length] |= . +
{
  "name": "DxCore (Debug enabled)",
  "architecture": "megaavr",
  "version": $version,
  "category": "Contributed",
  "url": $url,
  "archiveFileName": $file_name,
  "checksum": $checksum,
  "size": $file_size,
  "boards": [
            {
              "name": "<b>DxCore</b>: For all modern non-tinyAVR AVR devices: All AVRxxDAyy, AVRxxDByy, AVRxxDDyy, and now AVRxxDUyy (no USB support yet), AVRxxEAyy (now with uploads and burn bootloader fixed) as well as the AVR, and now the Ex-series p AVRxxEByy and AVRxxDUyy. <br/>These parts are available in flash sizes as small as 16k or as large as 128k, 1k to 16k of RAM, and run at up to 24 (Dx) or up to 20 (Ex) MHz. Each family is available in 2 or 3 flash sizes, and each combination of flash size and featureset is usually available on three or four different pincounts ."
            },
            {
              "name": "<b>Supported:</b> AVR128DA28/32/48/64, AVR128DB28/32/48/64, AVR64DA28/32/48/64, AVR64DB28/32/48/64, AVR64DD14/20/28/32, AVR64DU28/32<br/>AVR32DA28/32/48, AVR32DB28/32/48,  AVR32DD14/20/28/32, AVR16DD14/20/28/32<br/>AVR64EA28/32/48, AVR32EA28/32/48, AVR16EA28/32/48"
            },
            {
              "name": "<b>Release Notes:</b> 1.6.2 - Add avrdude 8.1 for non-serialupdi uploads, many critical fixes. Should be a lot closer.  1.6.1 - 1.6.0 omitted the new toolchain, and none of the new parts worked as a result. This should correct that. 1.6.0 - Experimental release so that automated testing can be run with new toolchain. Further information will be posted on github when more information about release plans is available. "
            },
            {
              "name": "<b>Supported UPDI programmers:</b> SerialUPDI (serial adapter w/diode or resistor), jtag2updi, nEDBG, mEDBG, EDBG, SNAP, Atmel-ICE and PICkit4 - or use one of those to <br/>load Optiboot (included) for serial programming if you determine that it is appropriate for your application. <br/>SerialUPDI may not be functionally spectacular, but it supports the latest parts released, and it is fast as all hell, and the adapters cost practically nothing."
            }

  ],
  "toolsDependencies": [
    {
      "packager": "DxCore",
      "name": "avr-gcc",
      "version": "7.3.0-atmel3.6.1-azduino7b1"
    },
    {
      "packager": "DxCore",
      "name": "avrdude",
      "version":  $avrdude_ver
    },
    {
      "packager": "arduino",
      "name": "arduinoOTA",
      "version": "1.3.0"
    },
    {
      "packager": "DxCore",
      "name": "avrocd-tools",
      "version": $avrocdversion
    }   
  ]
}' "package_${AUTHOR}_${REPOSITORY}_index.json.tmp" > "package_${AUTHOR}_${REPOSITORY}_index.json"

# Remove files that's no longer needed
rm -rf "$REPOSITORY-${DOWNLOADED_FILE#"v"}" "package_${AUTHOR}_${REPOSITORY}_index.json.tmp"
