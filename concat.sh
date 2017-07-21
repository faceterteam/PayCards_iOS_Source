# Makes universal(device/simulator) framework

# Set bash script to exit immediately if any commands fail.
set -e

# Setup some constants for use later on.
FRAMEWORK_SIMULATOR="PayCardsRecognizerSim"
FRAMEWORK_DEVICE="PayCardsRecognizer"

# If remnants from a previous build exist, delete them.
if [ -d "${SRCROOT}/build" ]; then
rm -rf "${SRCROOT}/build"
fi

# Build the framework for device and for simulator
# (using all needed architectures).
xcodebuild -target "${FRAMEWORK_DEVICE}" -configuration "${CONFIGURATION}" -arch arm64 -arch armv7 only_active_arch=no defines_module=yes -sdk "iphoneos"
xcodebuild -target "${FRAMEWORK_SIMULATOR}" -configuration "${CONFIGURATION}" -arch x86_64 -arch i386 only_active_arch=no defines_module=yes -sdk "iphonesimulator"

# Remove .framework file from previous run if exists.
if [ -d "${SRCROOT}/${FRAMEWORK_DEVICE}.framework" ]; then
rm -rf "${SRCROOT}/${FRAMEWORK_DEVICE}.framework"
fi

# Copy the device version of framework
cp -r "${SRCROOT}/build/${CONFIGURATION}-iphoneos/${FRAMEWORK_DEVICE}.framework" "${SRCROOT}/${FRAMEWORK_DEVICE}.framework"

# Replace the framework executable within the framework with
# a new version created by merging the device and simulator
# frameworks' executables with lipo.
lipo -create -output "${SRCROOT}/${FRAMEWORK_DEVICE}.framework/${FRAMEWORK_DEVICE}" "${SRCROOT}/build/${CONFIGURATION}-iphoneos/${FRAMEWORK_DEVICE}.framework/${FRAMEWORK_DEVICE}" "${SRCROOT}/build/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_SIMULATOR}.framework/${FRAMEWORK_SIMULATOR}"

# Fix simulator rpath
install_name_tool -id "@rpath/${FRAMEWORK_DEVICE}.framework/${FRAMEWORK_DEVICE}" "${SRCROOT}/${FRAMEWORK_DEVICE}.framework/${FRAMEWORK_DEVICE}"

# Delete the most recent build.
if [ -d "${SRCROOT}/build" ]; then
rm -rf "${SRCROOT}/build"
fi
