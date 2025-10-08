"""# Verilator rules.

Bazel rules for [Verilator](https://verilator.org/guide/latest/index.html)

## Setup

```python
bazel_dep(name = "rules_verilog", version = "{version}")

register_toolchain(
    # Define a custom toolchain or use the `rules_verilog` provided toolchain.
    "@rules_verilog//verilator/toolchain",
)
```
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
