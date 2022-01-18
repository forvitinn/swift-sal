#!/bin/sh

XCODE_PATH="/Applications/Xcode.app"
XCODE_BUILD_PATH="$XCODE_PATH/Contents/Developer/usr/bin/xcodebuild"
MUNKI_PKG=$(which munkipkg)
if [ -z "$MUNKI_PKG" ]; then
    echo "munkipkg is not installed. Please install and retry."
    exit 2
fi

echo "Building sal-submit"
if [ -e $XCODE_BUILD_PATH ]; then
  XCODE_BUILD="$XCODE_BUILD_PATH"
else
  ls -la /Applications
  echo "Could not find required Xcode build. Exiting..."
  exit 1
fi
$XCODE_BUILD -project sal-scripts/sal-scripts.xcodeproj
XCB_RESULT="$?"
if [ "${XCB_RESULT}" != "0" ]; then
    echo "Error running xcodebuild: ${XCB_RESULT}" 1>&2
    exit 1
fi

# move binary into build dir
/bin/mv sal-scripts/build/Release/sal-scripts payload/usr/local/bin/sal-submit-swift
# make sure its still executable
/bin/chmod +x payload/usr/local/bin/sal-submit-swift

# clean up xcode build
/bin/rm -rf sal-scripts/build

$MUNKI_PKG .