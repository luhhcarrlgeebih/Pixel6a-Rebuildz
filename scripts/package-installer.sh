name: Build SHRP recovery

on:
  workflow_dispatch:
    inputs:
      manifest_url:
        description: Repo manifest URL
        required: true
        default: https://github.com/SHRP/manifest.git
      manifest_branch:
        description: Manifest branch
        required: true
        default: v3_11.0
      device_tree_url:
        description: Device tree URL
        required: true
        default: https://github.com/LineageOS/android_device_google_bluejay
      device_tree_branch:
        description: Device tree branch
        required: true
        default: lineage-19.1
      vendor_tree_url:
        description: Optional vendor tree URL
        required: false
        default: ""
      vendor_path:
        description: Optional vendor path
        required: false
        default: ""
      vendor_tree_branch:
        description: Vendor branch
        required: false
        default: main
      kernel_tree_url:
        description: Optional kernel tree URL
        required: false
        default: ""
      kernel_path:
        description: Optional kernel path
        required: false
        default: ""
      kernel_tree_branch:
        description: Kernel branch
        required: false
        default: main
      lunch_target:
        description: Lunch target
        required: true
        default: shrp_bluejay-eng
      build_target:
        description: Make target
        required: true
        default: recoveryimage

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-22.04
    timeout-minutes: 360

    steps:
      - name: Checkout build repository
        uses: actions/checkout@v4

      - name: Free disk space
        run: |
          sudo rm -rf \
            /usr/share/dotnet \
            /usr/local/lib/android \
            /opt/ghc || true
          df -h

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            git-core gnupg flex bison build-essential zip curl \
            zlib1g-dev libc6-dev-i386 libncurses5 lib32ncurses5-dev \
            x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev \
            libxml2-utils xsltproc unzip fontconfig python3 rsync \
            schedtool squashfs-tools openjdk-11-jdk ccache
          mkdir -p "$HOME/bin"
          curl -fsSL \
            https://storage.googleapis.com/git-repo-downloads/repo \
            -o "$HOME/bin/repo"
          chmod +x "$HOME/bin/repo"
          echo "$HOME/bin" >> "$GITHUB_PATH"

      - name: Configure git
        run: |
          git config --global user.name "github-actions"
          git config --global user.email \
            "41898282+github-actions[bot]@users.noreply.github.com"

      - name: Build recovery
        env:
          MANIFEST_URL: ${{ inputs.manifest_url }}
          MANIFEST_BRANCH: ${{ inputs.manifest_branch }}
          DEVICE_TREE_URL: ${{ inputs.device_tree_url }}
          DEVICE_TREE_BRANCH: ${{ inputs.device_tree_branch }}
          VENDOR_TREE_URL: ${{ inputs.vendor_tree_url }}
          VENDOR_PATH: ${{ inputs.vendor_path }}
          VENDOR_TREE_BRANCH: ${{ inputs.vendor_tree_branch }}
          KERNEL_TREE_URL: ${{ inputs.kernel_tree_url }}
          KERNEL_PATH: ${{ inputs.kernel_path }}
          KERNEL_TREE_BRANCH: ${{ inputs.kernel_tree_branch }}
          DEVICE_PATH: device/google/bluejay
          DEVICE_NAME: bluejay
          LUNCH_TARGET: ${{ inputs.lunch_target }}
          BUILD_TARGET: ${{ inputs.build_target }}
          CCACHE_DIR: ${{ github.workspace }}/.ccache
        run: bash ./scripts/build-recovery.sh

      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: SHRP-bluejay-${{ github.run_number }}
          if-no-files-found: warn
          retention-days: 30
          path: |
            out/
            *.zip
            build.log

      - name: Create release
        if: success()
        uses: softprops/action-gh-release@v2
        with:
          tag_name: build-${{ github.run_number }}
          name: SHRP bluejay build ${{ github.run_number }}
          files: |
            *.zip
            out/target/product/bluejay/recovery.img
            out/target/product/bluejay/boot.img
