# Package Manager GUI

Simple Qt-based Python application that exposes a minimal interface for installing software using package managers such as Winget, Chocolatey, and npm.

## Requirements

Python 3 and the `PyQt5` package.

Install the dependency using pip:

```bash
pip install PyQt5
```

## Usage

Run the application directly with Python:

```bash
python src/main.py
```

Enter a package name, choose the package manager, and press **Install**. Command output will be displayed in the text area.

Because Winget and Chocolatey are Windows-specific, the corresponding commands will only work on Windows systems with those tools installed.
