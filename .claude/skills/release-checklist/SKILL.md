---
name: release-checklist
description: Step-by-step release checklist for Smart Player iOS app submission to App Store. Use when preparing release, updating version, submitting to App Store, or mentioning App Store submission.
metadata:
  author: Smart Player Team
  version: 1.0.0
  category: deployment
  tags: [release, fastlane, app-store, ios]
---

# Smart Player Release Checklist

**IMPORTANT FOR CLAUDE**: このスキルを使う際は、すべてのコマンドを **自動で実行** すること。ユーザーに「手動でやってください」と言ってはいけない。各ステップのコマンドは Claude が Bash ツールで直接叩く。確認が必要な場合は AskUserQuestion を使う。

**IMPORTANT**: Complete ALL steps before App Store submission.

## Prerequisites

- Xcode installed
- `bundle install` completed (in `ios/` directory)
- App Store Connect API Key configured (environment variables)
- Apple Developer account access

---

## Workflow: iOS Release

**Claude はこのワークフローをすべて自動実行する。** 各ステップのコマンドを Bash ツールで直接叩くこと。ユーザーに手動実行を求めてはいけない。

```
iOS Release Progress:
- [ ] Step 1: Update release notes (ja + en-US)
- [ ] Step 2: Bump version in project.pbxproj
- [ ] Step 3: Commit and create git tag
- [ ] Step 4: Archive and upload to App Store Connect
- [ ] Step 5: Run fastlane upload_metadata
- [ ] Step 5.1: Configure App Store Connect (if needed)
- [ ] Step 6: Create GitHub Release
```

### Step 1: Update Release Notes

**Files to update:**
- `ios/fastlane/metadata/ja/release_notes.txt` (日本語 - 必須)
- `ios/fastlane/metadata/en-US/release_notes.txt` (英語 - 必須)

**Format:**
```
バージョン 1.x.x

【新機能】
・新機能の説明

【改善】
・改善点

【修正】
・バグ修正
```

### Step 2: Bump Version

**File**: `ios/videoPlayer.xcodeproj/project.pbxproj`

```bash
# 現在のバージョン確認
grep "MARKETING_VERSION" ios/videoPlayer.xcodeproj/project.pbxproj | head -1

# バージョンアップ (例: 1.1.0 → 1.2.0)
sed -i '' 's/MARKETING_VERSION = 1.1.0;/MARKETING_VERSION = 1.2.0;/g' ios/videoPlayer.xcodeproj/project.pbxproj
```

### Step 3: Commit and Create Git Tag

```bash
git add ios/fastlane/metadata/
git add ios/videoPlayer.xcodeproj/project.pbxproj
git commit -m "chore: bump version to 1.x.x

- Update release notes
- Increment version number

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git tag v1.x.x
git push origin main
git push origin v1.x.x
```

### Step 4: Archive and Upload to App Store Connect

```bash
# ExportOptions.plist を作成
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>4YZQY4C47E</string>
</dict>
</plist>
EOF

# アーカイブ
rm -rf build/videoPlayer.xcarchive
xcodebuild -project ios/videoPlayer.xcodeproj -scheme videoPlayer -configuration Release \
  -archivePath build/videoPlayer.xcarchive archive 2>&1 | grep -E "error:|warning:|ARCHIVE SUCCEEDED|ARCHIVE FAILED"

# アップロード
xcodebuild -exportArchive \
  -archivePath build/videoPlayer.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates 2>&1 | tail -10
```

### Step 5: Run Fastlane

```bash
cd ios && bundle exec fastlane upload_metadata
```

This command will:
- Upload metadata (app description, keywords, etc.)
- Select the latest build
- Attempt to submit for review

**⚠️ IMPORTANT**: If submission fails with "missing required attribute" errors, proceed to Step 5.1.

### Step 5.1: Configure App Store Connect (Manual Setup)

If fastlane submission fails, manually configure in App Store Connect:

1. Go to https://appstoreconnect.apple.com
2. Navigate to: **マイApp** → **Smart Player** → version 1.x.x → **App情報**
3. Configure required attributes and click **審査に提出**

### Step 6: Create GitHub Release

```bash
gh release create v1.x.x --title "v1.x.x" --latest --notes "## Smart Player v1.x.x

### 新機能
- 変更内容をここに記載"
```

---

## Quick Reference

**Claude はこれらのコマンドをすべて自動で実行する。**

### App Info
- **Bundle ID**: `com.entaku.smartVideoPlayer`
- **Team ID**: `4YZQY4C47E`
- **Scheme**: `videoPlayer`
- **Project**: `ios/videoPlayer.xcodeproj`
- **Fastlane dir**: `ios/`

### Environment Variables (API Key)
```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="R2Q4FFAG8D"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="ios/fastlane/AuthKey_R2Q4FFAG8D.p8"
```

---

## Common Issues & Troubleshooting

### Issue: Archive build fails
**Solution**:
1. Swift パッケージ解決: `xcodebuild -resolvePackageDependencies -project ios/videoPlayer.xcodeproj`
2. ビルドフォルダクリーン後に再実行

### Issue: Fastlane authentication fails
**Solution**:
1. 環境変数 `APP_STORE_CONNECT_API_KEY_*` を確認
2. `ios/fastlane/AuthKey_R2Q4FFAG8D.p8` ファイルの存在を確認

### Issue: upload_metadata が "build could not be added" で失敗
**Solution**: Apple のビルド処理中。数分後に再実行。

### Issue: Git tag already exists
**Solution**:
```bash
git tag -d v1.x.x
git push origin :refs/tags/v1.x.x
git tag v1.x.x && git push origin v1.x.x
```

---

## Post-Release Checklist

- [ ] GitHub Release 作成済み
- [ ] App Store Connect でステータスが "Waiting for Review" になっていることを確認
- [ ] Firebase Crashlytics でクラッシュレポートを監視
