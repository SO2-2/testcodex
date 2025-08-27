# Package Manager GUI

Simple FLTK-based C++ application that exposes a minimal interface for installing software using package managers such as Winget, Chocolatey, and npm.

## Building

This project requires FLTK development libraries (e.g. `libfltk1.3-dev`).

```bash
mkdir build
cd build
cmake ..
make
```

## Usage

Run the compiled `package-manager-gui` binary. Enter a package name, choose the package manager, and press **Install**. Command output will be displayed in the text area.

Because Winget and Chocolatey are Windows-specific, the corresponding commands will only work on Windows systems with those tools installed.
