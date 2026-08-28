#!/bin/sh
set -e

# Xcode Cloud clones the repository fresh, and Enigo.xcodeproj is generated
# from project.yml rather than committed (see ios/.gitignore — a
# machine-generated pbxproj is a merge-conflict magnet). Without this there
# is no project for the build to open.
#
# Building here rather than locally is deliberate: this Mac runs a beta
# macOS, and Apple stamps the build machine's OS into BuildMachineOSBuild
# and rejects binaries produced on an unreleased OS with ITMS-90111 — the
# same code it uses for an outdated Xcode, which is what made it so hard to
# read. Xcode Cloud's machines run released macOS, so the stamp comes out
# clean no matter what this laptop is running.

echo "Installing XcodeGen…"
brew install xcodegen

echo "Generating Enigo.xcodeproj from project.yml…"
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
xcodegen generate

echo "Generated:"
ls -d Enigo.xcodeproj
