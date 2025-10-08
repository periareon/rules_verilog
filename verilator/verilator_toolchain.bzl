"""verilator_toolchain"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _verilator_toolchain_impl(ctx):
    all_files = ctx.attr.verilator[DefaultInfo].default_runfiles.files

    return [platform_common.ToolchainInfo(
        verilator = ctx.executable.verilator,
        libverilator = ctx.attr.libverilator,
        deps = ctx.attr.deps,
        vopts = ctx.attr.vopts,
        copts = ctx.attr.copts,
        linkopts = ctx.attr.linkopts,
        all_files = all_files,
    )]

verilator_toolchain = rule(
    doc = "Define a Verilator toolchain.",
    implementation = _verilator_toolchain_impl,
    attrs = {
        "copts": attr.string_list(
            doc = "Extra compiler flags to pass when compiling Verilator outputs.",
        ),
        "deps": attr.label_list(
            doc = "Global Verilator dependencies to link into downstream targets.",
            providers = [CcInfo],
        ),
        "libverilator": attr.label(
            doc = "The Verilator library.",
            cfg = "target",
            providers = [CcInfo],
            mandatory = True,
        ),
        "linkopts": attr.string_list(
            doc = "Extra linker flags to pass when linking Verilator outputs.",
        ),
        "verilator": attr.label(
            doc = "The Verilator binary.",
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "vopts": attr.string_list(
            doc = "Extra flags to pass to `VerilatorCompile` actions.",
        ),
    },
)
