#!/bin/bash
# Fetch the open-source upstream (Mac) repo and stage what the iPad
# build needs. Run from the repo root. No paid app code is used here.
#
#   ./scripts/setup.sh
#
# What it does:
#   1. Clones github.com/JamesQiu2005/SpektraLab (tag spektralab-v1.3.4
#      if it exists, otherwise main) into ./upstream — or reuses it.
#   2. Symlinks ./engine -> upstream/engine (so project.yml's
#      engine/src paths resolve), and copies the Mac app's
#      StockCatalog.json next to the Swift sources for reference.
#   3. Copies upstream engine/resources into
#      SpektraLab-iPad/Resources/engine/ (constants, profiles, LUTs).
#   4. Builds the iOS metallib (see build-metallib-ios.sh) into that
#      same Resources/engine/ folder.
#
# Licence: upstream app + engine are GPL-3.0-or-later, profiles/LUTs
# are CC BY-SA 4.0. Keep LICENSE files with any redistribution, and
# keep this file's attribution in the app's About/credits if you ship it.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d upstream/.git ]; then
  echo "Cloning upstream SpektraLab..."
  git clone https://github.com/JamesQiu2005/SpektraLab.git upstream
  (cd upstream && (git checkout spektralab-v1.3.4 2>/dev/null || git checkout main) || true)
else
  echo "Reusing existing ./upstream (run 'git -C upstream pull' to update)."
fi

ln -sfn upstream/engine engine
mkdir -p SpektraLab-iPad/Resources/engine
cp -R upstream/engine/resources/. SpektraLab-iPad/Resources/engine/
cp upstream/modern_UI/Spektrafilm/Spektrafilm/Resources/StockCatalog.json \
   SpektraLab-iPad/Resources/StockCatalog.json 2>/dev/null || true
cp upstream/LICENSE.txt SpektraLab-iPad/Resources/ 2>/dev/null || true

./scripts/build-metallib-ios.sh

echo "Setup done. Next: xcodegen generate"
echo "Then, in Xcode, set your own Signing team, or use the CI workflow"
echo "to build an unsigned .app and package it as an .ipa for AltStore."
