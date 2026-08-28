#!/bin/sh
set -e

# Xcode Cloud clones the repository fresh, and Enigo.xcodeproj is generated
# from project.yml rather than committed (see ios/.gitignore — a
# machine-generated pbxproj is a merge-conflict magnet). Without this there
# is no project for the build to open.
#
# Building here rather than locally is deliberate: this project's usual Mac
# runs a beta macOS, and Apple stamps the build machine's OS into
# BuildMachineOSBuild and rejects binaries produced on an unreleased OS with
# ITMS-90111 — the same code it uses for an outdated Xcode, which is what
# made it so hard to read. Xcode Cloud's machines run released macOS.

echo "Installing XcodeGen…"
brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH/ios"

# Note: CFBundleVersion is NOT set here. Xcode Cloud overwrites it with its
# own run number whenever the archive targets an App Store audience, and that
# is not configurable — the workflow has no build-number field at all. An
# earlier version of this script set CURRENT_PROJECT_VERSION from
# CI_BUILD_NUMBER; it was silently overridden, so it has been removed rather
# than left here implying control it does not have.

echo "Generating Enigo.xcodeproj from project.yml…"
xcodegen generate

# Xcode Cloud disables automatic package resolution and requires a lockfile
# inside the project. The canonical copy is tracked at ios/Package.resolved
# because the project it normally lives in is not committed — so it has to be
# put back after generation, on every build.
echo "Restoring Package.resolved into the generated project…"
SPM_DIR="Enigo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$SPM_DIR"
cp Package.resolved "$SPM_DIR/Package.resolved"

echo "Ready:"
ls -d Enigo.xcodeproj
ls -l "$SPM_DIR/Package.resolved"
