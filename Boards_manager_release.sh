#!/bin/bash

##########################################################
##                                                      ##
## Shell script for generating a boards manager release ##
## Created by MCUdude                                   ##
## Requires wget, jq and a bash environment             ##
##                                                      ##
##########################################################

# Called by the release workflow of the master branch with the tag,
# e.g. "bash Boards_manager_release.sh v1.7.0-pre5"; by hand as well.

AUTHOR=SpenceKonde       # author, part of the index file name
REPOSITORY=DxCore        # Github repo name
REPOWNER=felias-fogg     # owner of this fork, where the releases and gh-pages are

# Which index to write. The workflow sets INDEX_FILE: a release candidate goes
# into an index of its own, so the board manager of an ordinary user never
# offers it. Without the variable, this is the stable index, the one the README
# names.
INDEX="${INDEX_FILE:-package_${AUTHOR}_${REPOSITORY}_index.json}"

# The tools the platform depends on, as in the 1.7.0-pre4 entry. The debug tools
# are no dependency any more since 1.7.0-pre5: they come from the AvrDebugger
# package, which the user installs separately and the platform finds as
# runtime.tools.avr-debugger.path. python3 is what SerialUPDI runs (since
# 1.7.0-pre5; the earlier entries of this fork lacked it).
AVRDUDE_VERSION="avrdude_v8.1-released"
AVR_GCC_VERSION="7.3.0-atmel3.6.1-azduino8"
PYTHON3_VERSION="3.7.2-post1"

TAG="$1"
if [ -z "$TAG" ]; then
    echo "You need to specify a tag, e.g. v1.7.0-pre5"
    exit 1
fi
DOWNLOAD_URL="https://api.github.com/repos/$REPOWNER/$REPOSITORY/tarball/$TAG"
DOWNLOADED_FILE="$TAG"
NAME="$REPOSITORY-${TAG#"v"}"
echo "Packaging ${TAG} into ${INDEX}"

# Check whether this exact version is already in the index. The archive name has
# to be matched in full: without the extension, "DxCore-1.7.0-pre5" also matches
# "DxCore-1.7.0-pre5-rc1.tar.bz2", and the final release would be refused because
# one of its own release candidates is in the index.
if grep -q "\"${NAME}.tar.bz2\"" "$INDEX"; then
    echo "This version is already in the index file. Nothing to do."
    exit 1
fi

# Download file
wget --no-verbose -O "${DOWNLOADED_FILE}.tar.gz" "$DOWNLOAD_URL" || exit 1

# Extract downloaded file and place it in a folder
printf "\nExtracting ${DOWNLOADED_FILE}.tar.gz to ${NAME}\n"
mkdir -p "$NAME" && tar -xzf "${DOWNLOADED_FILE}.tar.gz" -C "$NAME" --strip-components=1 || exit 1

# The platform is the megaavr folder of the repository: keep only that
mv "$NAME" "$NAME.full" && mv "$NAME.full/megaavr" "$NAME" && rm -rf "$NAME.full" "${DOWNLOADED_FILE}.tar.gz"
test -f "$NAME/platform.txt" || { echo "no platform.txt in the megaavr folder of ${TAG}"; exit 1; }

# Make sure there are no macOS related files added to the archive that's soon to be
# generated. dot_clean only exists on macOS; elsewhere there is nothing to clean.
if command -v dot_clean > /dev/null 2>&1; then
    dot_clean "$NAME"
fi
find "$NAME" -name "._*" -delete 2>/dev/null

# Compress folder to tar.bz2
printf "\nCompressing folder ${NAME} to ${NAME}.tar.bz2\n"
tar -cjSf "${NAME}.tar.bz2" "$NAME"
printf "Done!\n"

# Get file size on bytes
FILE_SIZE=$(wc -c "${NAME}.tar.bz2" | awk '{print $1}')

# Get SHA256 hash: shasum is a macOS thing, sha256sum a Linux one
if command -v shasum > /dev/null 2>&1; then
    SHA256="SHA-256:$(shasum -a 256 "${NAME}.tar.bz2" | awk '{print $1}')"
else
    SHA256="SHA-256:$(sha256sum "${NAME}.tar.bz2" | awk '{print $1}')"
fi

# The archive is served from this branch (gh-pages)
URL="https://${REPOWNER}.github.io/${REPOSITORY}/${NAME}.tar.bz2"

cp "$INDEX" "$INDEX.tmp"

# Add new boards release entry
jq -r                                          \
--arg version          "${TAG#"v"}"            \
--arg url              "$URL"                  \
--arg checksum         "$SHA256"               \
--arg file_size        "$FILE_SIZE"            \
--arg avrdude_ver      "$AVRDUDE_VERSION"      \
--arg avr_gcc_ver      "$AVR_GCC_VERSION"      \
--arg python3_ver      "$PYTHON3_VERSION"      \
--arg file_name        "${NAME}.tar.bz2"       \
'.packages[].platforms[.packages[].platforms | length] |= . +
{
  "name": "DxCore (debug-configured)",
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
            { "name": "1.7.0-pre1 to pre3 were the first experimental versions to include the debug capability. 1.7.0-pre4 can be installed stand-alone and uses avrdude 8.1. Since 1.7.0-pre5, the core is based on the current master of SpenceKonde/DxCore, and the debug tools come from the AvrDebugger package, which has to be installed in addition."
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
      "version": $avr_gcc_ver
    },
    {
      "packager": "DxCore",
      "name": "avrdude",
      "version": $avrdude_ver
    },
    {
      "packager": "arduino",
      "name": "arduinoOTA",
      "version": "1.3.0"
    },
    {
      "packager": "DxCore",
      "name": "python3",
      "version": $python3_ver
    }
  ]
}' "$INDEX.tmp" > "$INDEX" || { mv "$INDEX.tmp" "$INDEX"; echo "jq failed, index unchanged"; exit 1; }

# Remove files that are no longer needed (the archive stays: it is what the URL serves)
rm -rf "$NAME" "$INDEX.tmp"
