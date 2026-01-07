#!/bin/sh

# Xcode Cloud用のポストクローンスクリプト
# Swift Macrosを有効化する

set -e

echo "Enabling Swift Macros for Xcode Cloud..."

# マクロプラグインを信頼する設定
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

echo "Swift Macros enabled successfully."
