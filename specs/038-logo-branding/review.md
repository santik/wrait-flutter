# Code Review: Logo Branding (US-038)

> **Feature number:** 038
> **Reviewer:** Codex
> **Date:** 2026-06-29

---

## Critical Findings

### PO: Branch contains unrelated feature changes (US-037)

The `feat/logo-branding` branch includes changes from two separate features:
- US-038 (Logo Branding) - the intended feature for this branch
- US-037 (Entry type refactoring) - an unrelated database schema change

**Files from US-037 present in this branch:**
- `lib/data/entries/entry_dao.dart` - changed from `isDraft` boolean to `type` string
- `lib/data/entries/entry_repository_impl.dart` - changed to use `EntryType` enum
- `lib/domain/model/entry.dart` - added `EntryType` enum, changed `isDraft` to `type`
- `lib/data/entries/local_entry_database.dart` - changed schema, database name to `wrait_entries_v2.sqlite`
- `lib/domain/usecase/cleanup_transcript_use_case.dart` - changed to use `EntryType`
- `lib/presentation/entries/entry_list_formatters.dart` - changed to use `EntryType`
- `lib/presentation/entries/entry_list_row.dart` - changed to use `EntryType`
- `lib/data/entries/entry_mapper.dart` - deleted
- `lib/data/entries/local_entry_database.g.dart` - regenerated
- Multiple test files updated for `EntryType` changes
- `AGENTS.md` updated with US-037 guidance

**Impact:**
- Violates single-responsibility branch principle
- Makes code review for US-038 impossible to isolate
- Database schema change (`wrait_entries.sqlite` → `wrait_entries_v2.sqlite`) is a breaking change that should be in its own feature branch
- Risk of merging unrelated changes together
- Validation evidence in `implementation.md` only covers US-038, not US-037

**Recommendation:**
- Revert or cherry-pick to separate US-037 changes into its own branch
- Ensure `feat/logo-branding` branch contains only US-038 changes
- US-037 should have its own spec, plan, tasks, and review cycle

---

## High Priority Findings

### P1: iOS Xcode project configuration error - Release build uses debug icon

**File:** `ios/Runner.xcodeproj/project.pbxproj`

**Issue:** The Release build configuration is incorrectly set to use `AppIconDebug` instead of `AppIcon`.

```diff
- ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
+ ASSETCATALOG_COMPILER_APPICON_NAME = AppIconDebug;
```

This change appears in line 376 of the diff, affecting the Release configuration. The test in `test/platform/branding_assets_test.dart` (lines 84-89) expects Release to use `AppIcon`, but the actual Xcode project file has been modified to use `AppIconDebug` for Release.

**Impact:**
- Release builds will show the red debug icon instead of the cream release icon
- Users will see debug branding in production
- Test passes because it checks the wrong configuration ID or the test is not actually validating the Release build correctly

**Root cause:** The git diff shows both Debug (line 555) and Release (line 376) configurations were changed to `AppIconDebug`. Only Debug and Profile should use `AppIconDebug`.

**Recommendation:**
- Revert the Release configuration change to use `AppIcon`
- Verify the test actually validates the correct Release configuration ID (`97C147071CF9000F007C117D`)

### P1: PNG dimension parsing is fragile and platform-dependent

**File:** `test/platform/branding_assets_test.dart` (lines 194-201)

**Issue:** The `_readPngDimensions` function assumes PNG IHDR chunk is always at byte offset 16 and uses big-endian byte order without validation.

```dart
({int width, int height}) _readPngDimensions(List<int> bytes) {
  final data = Uint8List.fromList(bytes);
  final byteData = ByteData.sublistView(data);

  final width = byteData.getUint32(16);
  final height = byteData.getUint32(20);
  return (width: width, height: height);
}
```

**Problems:**
- No PNG signature validation (should start with bytes `137 80 78 71 13 10 26 10`)
- No IHDR chunk validation (chunk type should be `IHDR`)
- Assumes fixed byte offsets which may not be reliable for all PNG encodings
- No error handling for malformed PNG files
- `getUint32` uses host endianness by default, not network byte order (big-endian) required by PNG spec

**Impact:**
- Test may pass on some systems but fail on others due to endianness
- False positives if PNG is malformed but happens to have readable values at those offsets
- Not robust against different PNG encoders or compression settings

**Recommendation:**
- Add PNG signature validation
- Parse PNG chunks properly to find IHDR
- Use `getUint32` with explicit endianness or manually parse big-endian bytes
- Add error handling for malformed PNGs

### P1: Xcode project parsing uses hardcoded configuration IDs

**File:** `test/platform/branding_assets_test.dart` (lines 203-213)

**Issue:** The `_buildConfigurationIconName` function uses hardcoded Xcode configuration IDs that may change across Xcode versions or project regeneration.

```dart
String _buildConfigurationIconName(String pbxproj, String configurationId) {
  final pattern = RegExp(
    '${RegExp.escape(configurationId)} = \\{[\\s\\S]*?ASSETCATALOG_COMPILER_APPICON_NAME = ([A-Za-z0-9]+);',
  );
  // ...
}
```

The test calls this with hardcoded IDs:
- `'97C147061CF9000F007C117D /* Debug */'`
- `'249021D4217E4FDB00AE95B9 /* Profile */'`
- `'97C147071CF9000F007C117D /* Release */'`

**Problems:**
- These UUIDs are generated by Xcode and may change when the project is modified or regenerated
- The test will fail if Xcode regenerates the project file with new UUIDs
- Makes the test fragile and dependent on Xcode internals

**Impact:**
- Test may break after Xcode upgrades or project modifications
- False sense of security if test passes but checks wrong configuration after UUID change

**Recommendation:**
- Search by configuration name (Debug/Profile/Release) instead of UUID
- Or make the test more resilient to UUID changes by finding configurations by their display names

---

## Medium Priority Findings

### P2: Asset generation script lacks idempotency check

**File:** `tool/branding/generate_assets.sh`

**Issue:** The script always overwrites existing assets without checking if they need regeneration.

**Problems:**
- No hash or timestamp comparison to skip unchanged assets
- No validation that generated assets match expected dimensions before overwriting
- No backup of previous assets
- If ImageMagick version changes, output may differ without detection

**Impact:**
- Unnecessary file churn in git
- Risk of silently regenerating assets with different appearance
- Hard to detect when assets actually need updating

**Recommendation:**
- Add hash comparison of source SVGs
- Only regenerate if sources changed
- Add validation that output dimensions match expected

### P2: No validation that generated assets are visually correct

**File:** `tool/branding/generate_assets.sh`

**Issue:** The script only checks that ImageMagick exists and runs commands, but does not validate:
- That output files are valid PNGs
- That output dimensions match requested sizes
- That output files are not corrupted
- That color values are as expected

**Impact:**
- Silent failures if ImageMagick produces invalid output
- Corrupted assets could be committed
- No early detection of rendering issues

**Recommendation:**
- Add PNG validation after generation
- Verify dimensions match requested sizes
- Optionally add perceptual hash comparison for regression detection

### P2: SVG sources use hardcoded font family

**Files:** `tool/branding/app_icon_release.svg`, `app_icon_debug.svg`, `launch_mark.svg`

**Issue:** All SVGs use `font-family="Helvetica"` which may not be available on all systems running the generation script.

```svg
<text
  font-family="Helvetica"
  font-size="116"
  font-weight="700"
  fill="#1A1917"
>wrait</text>
```

**Problems:**
- If Helvetica is not available, ImageMagick may substitute a different font
- Text rendering may differ across platforms
- No font embedding or fallback specification

**Impact:**
- Generated assets may look different on different systems
- Inconsistent branding if regenerated on different machines

**Recommendation:**
- Use a font that is guaranteed to be available (e.g., system font)
- Or embed the font as a base64 data URI in the SVG
- Or convert text to paths in the SVG to eliminate font dependency

### P2: Launch screen storyboard uses hardcoded RGB values

**File:** `ios/Runner/Base.lproj/LaunchScreen.storyboard` (line 22)

**Issue:** Background color is specified as hardcoded RGB values instead of using a named color or asset catalog color.

```xml
<color key="backgroundColor" red="0.10196078431372549" green="0.09803921568627451" blue="0.09019607843137255" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
```

**Problems:**
- Hard to maintain if the dark theme color changes
- No single source of truth for the dark background color
- Difficult to ensure consistency with other dark surfaces in the app

**Impact:**
- Maintenance burden if brand colors change
- Risk of color drift across different surfaces

**Recommendation:**
- Define the dark background color in an asset catalog color set
- Reference the named color in the storyboard
- Or at least document the color value in the branding README

### P2: Test for iOS debug icon catalog only checks count, not content

**File:** `test/platform/branding_assets_test.dart` (lines 180-191)

**Issue:** The test only verifies that the Contents.json has 19 images, but doesn't validate:
- That the expected sizes are present
- That the filenames are correct
- That the scales are correct

```dart
test('iOS debug icon catalog declares the expected asset list', () {
  final images = contents['images'] as List<dynamic>;
  expect(images.length, 19);
});
```

**Impact:**
- Test could pass even if the catalog is missing required sizes
- No validation that the catalog structure is correct

**Recommendation:**
- Validate that specific expected sizes/scales are present
- Check that filenames match the expected pattern

---

## Low Priority Findings

### P3: No documentation of color values in branding sources

**Files:** `tool/branding/*.svg`

**Issue:** The SVG files contain color values (`#1A1917`, `#E8E4DD`, `#C62828`) but these are not documented in the README or as comments.

**Impact:**
- Future maintainers must parse SVG to find color values
- No easy reference for brand color palette

**Recommendation:**
- Document the color palette in the README
- Add comments in SVG files explaining color usage

### P3: Asset generation script has no --help or usage documentation

**File:** `tool/branding/generate_assets.sh`

**Issue:** Running the script without arguments or with `--help` provides no usage information.

**Impact:**
- Not self-documenting
- Harder for new contributors to understand what the script does

**Recommendation:**
- Add a `--help` flag
- Add usage documentation at the top of the script

### P3: Integration test uses hardcoded app config

**File:** `integration_test/branding_surfaces_flow_test.dart` (lines 45-49)

**Issue:** The test uses a hardcoded `AppConfig` that may not match the actual app configuration.

```dart
const _appConfig = AppConfig(
  backendUrl: 'https://wrait-backend.vercel.app',
  proxySecret: '',
  recordingHardCapMs: 120000,
);
```

**Impact:**
- Test may not reflect actual runtime behavior
- Config drift if real config changes

**Recommendation:**
- Load actual app config if possible
- Or document why this hardcoded config is acceptable for the test

### P3: No test for Android adaptive icon compatibility

**File:** `test/platform/branding_assets_test.dart`

**Issue:** The test only validates launcher icons but does not check for Android adaptive icon assets (`mipmap-anydpi-v26`).

**Impact:**
- May miss adaptive icon configuration issues
- Android 8.0+ devices may not display icons correctly

**Recommendation:**
- Add validation for adaptive icon assets if they are required
- Or document why adaptive icons are not used

### P3: Flutter_01.png not addressed in spec or implementation

**File:** `flutter_01.png` (repo root)

**Issue:** The implementation notes state this file was left untouched as a "pre-existing reference screenshot", but it's unclear if this should be removed or updated.

**Impact:**
- Unclear purpose of the file
- May be stale or misleading

**Recommendation:**
- Either remove the file or document its purpose
- If it's a reference, update it to show the new branding
