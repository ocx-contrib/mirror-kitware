# Stable smoke test — assert on the contract, never on help or version prose.
#
# What this proves, and why each step is unreachable on a broken artifact:
#
#   1. `cmake --version` resolves on the composed PATH and reports a semver
#      shape. The weakest step BY FAR, and measurably so: against a bundle
#      carrying only `bin/`, `cmake --version` prints `CMake Error: Could not
#      find CMAKE_ROOT !!!` to stderr and then **exits 0 anyway**, having
#      reported the version. A Tier 1 + 2 smoke test would ship that bundle
#      green. This step is here for the version *shape*, not as evidence.
#   2. `cmake` CONFIGURES a project. CMake locates its module tree relative to
#      the executable, so this is the step that proves the archive arrived
#      whole AND relocated: `project()` and `include(CPack)` both load real
#      files out of `<content>/share/cmake-X.Y/Modules/`. This is the
#      assertion that actually catches a broken bundle — verified by running
#      this exact script through `ocx package test` against a repacked
#      bin/-only bundle, which fails here with exit 1 and `Could not find
#      CMAKE_ROOT !!!` while step 1 above passes.
#   3. `ctest` runs the test the configure generated. With no configure — or a
#      configure that failed — ctest exits 1 with `No test configuration file
#      found!` (measured), so this cannot go green on step 2's failure.
#   4. `cpack` produces a real tarball from the CPackConfig.cmake that step 2's
#      `include(CPack)` generated, and the member list is asserted. With no
#      generated config cpack exits 1 with `CPack generator not specified`
#      (measured).
#
# TOOLCHAIN-FREE BY CONSTRUCTION. The container legs are bare `ubuntu:24.04`
# and `fedora:40` — no make, no ninja, no compiler. Two consequences drove the
# shape below and neither is cosmetic:
#
#   * `project(ocx_smoke NONE)` — no language, so no compiler probe.
#   * `set(CMAKE_MAKE_PROGRAM "${CMAKE_COMMAND}")` — the Makefile generator
#     refuses to generate when it cannot find a build tool ("CMake was unable
#     to find a build program corresponding to \"Unix Makefiles\".
#     CMAKE_MAKE_PROGRAM is not set." — measured with an emptied PATH), and
#     pointing it at cmake's own path satisfies that without anything being
#     built. Nothing ever invokes it: this test configures and generates, it
#     does not build.
#
# Everything the CMakeLists needs about the filesystem it derives from
# `${CMAKE_COMMAND}` and `${CMAKE_CURRENT_SOURCE_DIR}`, which CMake normalises
# to forward slashes on every platform — so no absolute path and no path
# separator ever crosses from Starlark into CMake, and the same script runs
# unmodified on Windows.
#
# NOT covered, deliberately:
#
#   * `ccmake` — a curses UI that takes over the terminal and waits for input.
#     There is no headless invocation of it that means anything; it is declared
#     in `binaries` (and `bin_scan: verify` requires that) but never exec'd.
#   * `cmake-gui` — a Qt application. Beyond needing a display, it is the one
#     binary here with a closure the test images do not carry:
#     `readelf -d bin/cmake-gui | grep NEEDED` lists libxcb.so.1,
#     libfontconfig.so.1 and libfreetype.so.6 on top of libc, none of which
#     exist in a bare ubuntu:24.04 or fedora:40. Even `cmake-gui --version`
#     would fail to load there, for a reason that says nothing about the
#     mirror. (By contrast `ccmake` links its curses UI statically — same
#     NEEDED list as `cmake` — so its exclusion is about the TTY, not libraries.)
#   * An actual compile. That would test a C++ toolchain, not this mirror.

CMAKE = "cmake.exe" if ocx.target_platform.os == ocx.os.Windows else "cmake"
CTEST = "ctest.exe" if ocx.target_platform.os == ocx.os.Windows else "ctest"
CPACK = "cpack.exe" if ocx.target_platform.os == ocx.os.Windows else "cpack"

# Tier 1 + 2: liveness on the composed PATH, and version SHAPE — never the
# exact version (churns every release) and never the word "cmake" (a rebrand
# away from breaking).
r_version = ocx.run(CMAKE, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# Tier 3, step 2 — configure. `include(CPack)` is load-bearing twice over: it
# is a real module read from the relocated tree, and it writes the
# CPackConfig.cmake that step 4 consumes.
ocx.mkdir("payload")
ocx.write_file("payload/hello.txt", "ocx\n")
ocx.write_file("CMakeLists.txt", """cmake_minimum_required(VERSION 3.20)
set(CMAKE_MAKE_PROGRAM "${CMAKE_COMMAND}" CACHE FILEPATH "" FORCE)
project(ocx_smoke NONE)
enable_testing()
add_test(NAME ocx_echo COMMAND "${CMAKE_COMMAND}" -E echo ocx-ctest-ran)
set(CPACK_GENERATOR TGZ)
set(CPACK_PACKAGE_NAME ocxsmoke)
set(CPACK_PACKAGE_VERSION 1.0.0)
set(CPACK_PACKAGE_FILE_NAME ocxsmoke-package)
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "ocx smoke")
set(CPACK_INSTALL_CMAKE_PROJECTS "")
set(CPACK_INSTALLED_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/payload;share")
include(CPack)
""")

r_configure = ocx.run(CMAKE, "-G", "Unix Makefiles", "-S", ".", "-B", "build")
expect.ok(r_configure)

# Tier 3, step 3 — ctest executes the generated test list. The summary line is
# NOT decoration here: `expect.ok` alone cannot tell "ran the test and it
# passed" from "found a test file with nothing in it", and a configure that
# silently stopped emitting tests is exactly the drift worth catching.
r_ctest = ocx.run(CTEST, cwd="build")
expect.ok(r_ctest)
expect.contains(r_ctest.stdout, "100% tests passed")

# Tier 3, step 4 — cpack produces a package. Assert the ARTIFACT, not cpack's
# log: a tarball that exists and unpacks to the member the config asked for.
r_cpack = ocx.run(CPACK, cwd="build")
expect.ok(r_cpack)
expect.true(ocx.exists("build/ocxsmoke-package.tar.gz"))

r_listing = ocx.run(CMAKE, "-E", "tar", "tzf", "ocxsmoke-package.tar.gz", cwd="build")
expect.ok(r_listing)
expect.contains(r_listing.stdout, "ocxsmoke-package/share/hello.txt")
