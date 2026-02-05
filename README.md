# SouthCraftX's Custom FFmpeg Builder (Target GNU/Linux x86-64-v3)

A high-performance, containerized build system designed to produce an minimal, static FFmpeg binary optimized for **x86-64-v3** processors with full hardware acceleration support (NVENC, VAAPI, Vulkan, etc.).

---

## Prerequisites
Before starting, ensure your host system (preferably Arch Linux or any forks like CachyOS) has the following tools installed:
- `pacman` (to bootstrap the rootfs)
- `bubblewrap` (bwrap)
- `fakeroot` & `fakechroot`
- `pixz` (for fast multi-threaded compression)
- `aria2` (for fast source downloads)

---

## Folder Structure & Scripts

### 1. Core Build Flow
- **`setup-rootfs.sh`**: 
  The bootstrap script. It creates a minimal CachyOS-v3 root filesystem (`rootfs/`) using `pacman`. It excludes documentation and locales to keep the environment lean.
  - **Usage**: `./setup-rootfs.sh [--pack]`
  - **Option**: `--pack` will create a `tar.xz` archive of the finished rootfs using `pixz`.
- **`run-build.sh`**: 
  The main driver script on the host. It launches the container via `bwrap`, executes the internal build script, logs the entire process to `build_full.log`, and extracts the final `.tar.xz` artifact to the `output/` folder.
- **`_build_ffmpeg.sh`**: 
  The actual compilation logic located inside the container (`/opt/build_ffmpeg.sh`). It compiles `x264` and `FFmpeg` with aggressive LTO (Link Time Optimization) and v3-specific flags. DON'T INVOKE IT RIGHT HERE.

### 2. Utilities
- **`start-shell.sh`**: 
  Enters the CachyOS-v3 container interactively. Useful for manual debugging or testing compilation flags.
- **`manage.sh`**: 
  General maintenance script for cleaning up logs, temporary sources, or the build environment.
- **`add-pkg.sh`**: 
  **Warning**: This is a **debug-only tool**. It allows adding packages to an *already existing* rootfs. It should **not** be used for standard production builds, as it bypasses the clean-room bootstrap process.

---

## Step-by-Step Instructions

### Step 1: Bootstrap the Environment
First, create the isolated v3 compilation environment:
```bash
chmod +x *.sh
./setup-rootfs.sh
```
*This will create the `./rootfs` directory and install all necessary toolchains (GCC, Git, Base-devel, etc.).*

### Step 2: Build FFmpeg
Execute the automated build process:
```bash
./run-build.sh
```
*This script will:*
1. Enter the container.
2. Compile `x264`.
3. Compile `FFmpeg 8.0.1`.
4. Generate a timestamped `.tar.xz` package.
5. Move the package to `./output/`.
6. Provide a stage-by-stage time summary in `build_history.log`.

---

## Logs and Outputs
- **`output/`**: Contains the final static FFmpeg distribution (includes `bin`, `include`, and `lib`).
- **`build_full.log`**: Every single line of the compilation output (useful for debugging).
- **`build_history.log`**: A summary of build status and time elapsed for each stage.
- **`setup_rootfs.log`**: Logs from the environment initialization phase.

## Notes on Architecture
This project targets **x86-64-v3**. The resulting binaries will **not** run on older CPUs (pre-Haswell for Intel). If you need broader compatibility, change the `ARCH` and `CFLAGS` in `setup-rootfs.sh` and `_build_ffmpeg.sh` to `x86-64-v2` or generic `x86-64`.

## License
This project is under MIT License
