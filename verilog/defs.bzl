"""# verilog rules

Bazel rules for [Verilog](https://en.wikipedia.org/wiki/Verilog) / [SystemVerilog](https://en.wikipedia.org/wiki/SystemVerilog).

## Setup

## Setup

```python
bazel_dep(name = "rules_verilog", version = "{version}")
```
"""

load(":verilog_info.bzl", _VerilogInfo = "VerilogInfo")
load(":verilog_library.bzl", _verilog_library = "verilog_library")

VerilogInfo = _VerilogInfo
verilog_library = _verilog_library
