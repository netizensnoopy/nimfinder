# NimFinder

A lightweight, cross-platform GUI tool built with Nim for converting images to JPEG XL (JXL) and viewing them.

## Features

- **Convert Images**: Easily convert PNG, JPG, GIF, BMP, and other formats to JXL.
- **View JXL Files**: Integrated viewer for JXL files (auto-decodes for preview).
- **Quality Control**: Adjustable quality setting (1-100) for conversions.
- **Size Comparison**: See how much space you save with JXL compression.
- **Cross-Platform**: Built using Nim and NiGui.

## Requirements

- [libjxl](https://github.com/libjxl/libjxl) (`cjxl` and `djxl` must be in your system PATH).

## Build

```bash
nimble build -d:release
```
