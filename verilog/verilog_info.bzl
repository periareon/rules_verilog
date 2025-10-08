"""VerilogInfo"""

VerilogInfo = provider(
    doc = "Verilog provider",
    fields = {
        "compile_data": "Depset[File]: Files required at compile time.",
        "deps": "Depset[VerilogInfo]: Transitive Verilog dependencies.",
        "hdrs": "Depset[File]: Verilog/SystemVerilog header files.",
        "srcs": "Depset[File]: Verilog/SystemVerilog source files.",
        "top": "File: The source file that represents the module top. The file name is expected to match the module name.",
    },
)
