"""Verilator rules.

This module provides rules and aspects for working with Verilator,
a fast Verilog/SystemVerilog simulator and linter.

Main rules:
  - verilator_cc_library: Compiles Verilog to a C++ library
  - verilator_lint_test: Creates a test that lints Verilog code
  - verilator_toolchain: Defines a Verilator toolchain

Aspects:
  - verilator_lint_aspect: Lints Verilog code transitively
"""

load(
    "//verilator:verilator_cc_library.bzl",
    _verilator_cc_library = "verilator_cc_library",
)
load(
    "//verilator:verilator_lint_aspect.bzl",
    _verilator_lint_aspect = "verilator_lint_aspect",
)
load(
    "//verilator:verilator_lint_test.bzl",
    _verilator_lint_test = "verilator_lint_test",
)
load(
    "//verilator:verilator_toolchain.bzl",
    _verilator_toolchain = "verilator_toolchain",
)

verilator_cc_library = _verilator_cc_library
verilator_lint_aspect = _verilator_lint_aspect
verilator_lint_test = _verilator_lint_test
verilator_toolchain = _verilator_toolchain
