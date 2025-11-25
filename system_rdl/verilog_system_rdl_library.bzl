"""verilog_system_rdl_library"""

load("//system_rdl/private:system_rdl.bzl", "TOOLCHAIN_TYPE")
load("//verilog:verilog_info.bzl", "VerilogInfo")
load(":system_rdl_info.bzl", "SystemRdlInfo")

def _verilog_system_rdl_library_impl(ctx):
    lib = ctx.attr.lib

    if OutputGroupInfo not in lib:
        fail("No output groups were found in `lib` - `{}`".format(
            lib.label,
        ))

    toolchain = ctx.toolchains[TOOLCHAIN_TYPE]
    if not hasattr(lib[OutputGroupInfo], "system_rdl_regblock"):
        fail("system_rdl_library `{}` does not have a `regblock` output. Is the current toolchain configured for this? `{}`".format(
            lib.label,
            toolchain.label,
        ))

    srcs = lib[OutputGroupInfo].system_rdl_regblock

    return [
        DefaultInfo(
            files = srcs,
        ),
        VerilogInfo(
            compile_data = depset(),
            deps = depset(),
            hdrs = depset(),
            srcs = srcs,
            top = srcs.to_list()[0],
        ),
    ]

verilog_system_rdl_library = rule(
    doc = "A rule which extracts a `verilog_library` from a `system_rdl_library`.",
    implementation = _verilog_system_rdl_library_impl,
    attrs = {
        "lib": attr.label(
            doc = "The `system_rdl_library` to extract Verilog from.",
            mandatory = True,
            providers = [SystemRdlInfo],
        ),
    },
    provides = [VerilogInfo],
    toolchains = [TOOLCHAIN_TYPE],
)
