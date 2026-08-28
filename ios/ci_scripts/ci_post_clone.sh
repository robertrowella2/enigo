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

# Xcode Cloud's own auto-increment stamps CFBundleVersion with the CI run
# number, which restarts at 1 and so landed *below* builds already uploaded
# from this machine (16 at the time of writing) — App Store Connect will not
# accept a build that numbers lower than one already used for the version.
# Deriving it here from CI_BUILD_NUMBER with an offset keeps it both
# monotonic and clear of everything uploaded manually. Turn OFF the
# workflow's own auto-increment, or it overrides this.
BUILD_NUMBER=$(( 100 + ${CI_BUILD_NUMBER:-0} ))
echo "Setting CURRENT_PROJECT_VERSION to $BUILD_NUMBER (CI run ${CI_BUILD_NUMBER:-?})"
sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$BUILD_NUMBER\"/" project.yml
grep CURRENT_PROJECT_VERSION project.yml

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
