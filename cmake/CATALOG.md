---
title: CMake
description: Cross-platform build system generator — one configuration, native build files for Make, Ninja, Visual Studio and Xcode
keywords: cmake,build,build-system,cpp,c,cross-platform,kitware,ctest,cpack
---

# CMake

CMake is the de facto standard for building C and C++ projects. It reads one
platform-independent description of a project and generates native build files
for whatever the host actually uses — Makefiles, Ninja files, Visual Studio
solutions, Xcode workspaces — so the same source tree builds on Linux, macOS
and Windows without a second build description.

It is more than the generator, though. `ctest` drives the test suites a project
registers, and `cpack` turns a built tree into installers and archives; both
ship in this package and read the same project description.

These are Kitware's own release binaries, republished unmodified. CMake bundles
everything it needs — no system libraries beyond libc, no interpreter, nothing
to install first.

## What's included

- **cmake** — configure a project and generate its native build files
- **ctest** — run the test suite a project registers with `add_test()`
- **cpack** — package a built tree into installers and archives
- **ccmake** — terminal (curses) UI for browsing and editing the cache; Linux
  and macOS only
- **cmake-gui** — Qt UI for the same; needs a desktop environment
- **cmcldeps** — MSVC dependency-scanning helper used by the Ninja generator;
  Windows only, invoked by generated build rules rather than by hand

## Links

BSD-3-Clause licensed.

- [CMake Documentation](https://cmake.org/cmake/help/latest/)
- [CMake on GitHub](https://github.com/Kitware/CMake)
- [CMake Downloads](https://cmake.org/download/)
