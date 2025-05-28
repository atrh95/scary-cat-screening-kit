#!/bin/bash
#  $ .github/scripts/run-local-ci.sh                    # 全ステップ実行 (ユニットテスト、アーカイブ)
#  $ .github/scripts/run-local-ci.sh --unit-test        # ユニットテストのみ実行
#  $ .github/scripts/run-local-ci.sh --archive-only     # アーカイブビルドのみ実行

set -euo pipefail

# === 設定 ===
OUTPUT_DIR="ci-outputs"
TEST_RESULTS_DIR="$OUTPUT_DIR/test-results"
UNIT_TEST_RESULTS_DIR="$TEST_RESULTS_DIR/unit"
PRODUCTION_DIR="$OUTPUT_DIR/production"
ARCHIVE_DIR="$PRODUCTION_DIR/archives"
PRODUCTION_DERIVED_DATA_DIR="$ARCHIVE_DIR/DerivedData" # アーカイブビルド用
EXPORT_DIR="$PRODUCTION_DIR/Export"
SCHEME_NAME="SampleApp"
TEST_TARGET="ScaryCatScreeningKitTests"
PROJECT_FILE="SampleApp.xcodeproj"

# === フラグ ===
run_unit_tests=false
run_archive=false
run_all_ci_steps=true # デフォルト: 全CIステップ (ユニットテスト、アーカイブ)

# === 引数解析 ===
specific_action_requested=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --unit-test)
      run_unit_tests=true
      run_archive=false
      run_all_ci_steps=false
      specific_action_requested=true
      shift
      ;;
    --archive-only)
      run_unit_tests=false
      run_archive=true
      run_all_ci_steps=false
      specific_action_requested=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# 引数なしなら全CIステップ実行 (ユニットテスト、アーカイブ)
if [ "$specific_action_requested" = false ]; then
  run_unit_tests=true
  run_archive=true
fi

# === ヘルパー関数 ===
step() {
  echo ""
  echo "──────────────────────────────────────────────────────────────────────"
  echo "▶️  $1"
  echo "──────────────────────────────────────────────────────────────────────"
}

success() {
  echo "✅ $1"
}

fail() {
  echo "❌ Error: $1" >&2
  exit 1
}

# === XcodeGen ===
if [ "$run_archive" = true ]; then
  step "Generating Xcode project for Archive using XcodeGen"
  if ! command -v mint >/dev/null 2>&1; then
      fail "Mint is not installed. Please install mint first. (brew install mint)"
  fi
  if ! mint list | grep -q -E '(XcodeGen|xcodegen)'; then
      echo "XcodeGen not found via mint. Running 'mint bootstrap'..."
      mint bootstrap || fail "Failed to bootstrap mint packages."
  fi
  echo "Running xcodegen..."
  mint run xcodegen generate || fail "XcodeGen failed to generate the project."
  success "Xcode project generated successfully."
fi

# === メイン処理 ===

# 出力ディレクトリ初期化
step "Cleaning previous outputs and creating directories"
echo "Removing old $OUTPUT_DIR directory if it exists..."
rm -rf "$OUTPUT_DIR"
echo "Creating directories..."
mkdir -p "$UNIT_TEST_RESULTS_DIR" \
         "$ARCHIVE_DIR" "$PRODUCTION_DERIVED_DATA_DIR" "$EXPORT_DIR"
success "Directories created under $OUTPUT_DIR."

# === ユニットテスト実行 ===
if [ "$run_unit_tests" = true ]; then
  step "Running Unit Tests"

  echo "Finding simulator for Unit Tests..."
  FIND_SIMULATOR_SCRIPT=".github/scripts/find-simulator.sh"
  if [ ! -x "$FIND_SIMULATOR_SCRIPT" ]; then
    echo "Making $FIND_SIMULATOR_SCRIPT executable..."
    chmod +x "$FIND_SIMULATOR_SCRIPT" || fail "Failed to make $FIND_SIMULATOR_SCRIPT executable."
  fi

  SIMULATOR_ID=$("$FIND_SIMULATOR_SCRIPT")
  SCRIPT_EXIT_CODE=$?
  if [ $SCRIPT_EXIT_CODE -ne 0 ]; then
      fail "$FIND_SIMULATOR_SCRIPT failed with exit code $SCRIPT_EXIT_CODE."
  fi
  if [ -z "$SIMULATOR_ID" ]; then
    fail "Could not find a suitable simulator ($FIND_SIMULATOR_SCRIPT returned empty ID)."
  fi
  echo "Using Simulator ID: $SIMULATOR_ID for Unit Tests"
  success "Simulator selected for Unit Tests."

  echo "Running unit tests..."
  xcodebuild test \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -only-testing:$TEST_TARGET \
    CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "./$UNIT_TEST_RESULTS_DIR/TestResults.xcresult" \
    | xcbeautify --report junit --report-path "./$UNIT_TEST_RESULTS_DIR/junit.xml" || fail "Unit tests failed."
  success "Unit tests completed. Results in $UNIT_TEST_RESULTS_DIR"
fi

# === アーカイブビルド ===
if [ "$run_archive" = true ]; then
  step "Building Archive"
  echo "Building archive for $SCHEME_NAME..."
  xcodebuild archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_DIR/$SCHEME_NAME.xcarchive" \
    -derivedDataPath "$PRODUCTION_DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    | xcbeautify || fail "Archive build failed."
  success "Archive build completed. Archive at $ARCHIVE_DIR/$SCHEME_NAME.xcarchive"
fi

success "CI process completed successfully."