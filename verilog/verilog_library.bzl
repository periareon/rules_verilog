"""verilog_library"""

load(":verilog_info.bzl", "VerilogInfo")

def _find_top(ctx, srcs, top = None):
    """Determine the top entrypoint for executable rules.

    Args:
        ctx (ctx): The rule's context object.
        srcs (list): A list of File objects.
        top (File, optional): An explicit contender for the top entrypoint.

    Returns:
        File: The file to use for the top entrypoint.
    """
    if top:
        if top not in srcs:
            fail("`top` was not found in `srcs`. Please add `{}` to `srcs` for {}".format(
                top.path,
                ctx.label,
            ))
        return top

    if len(srcs) == 1:
        top = srcs[0]
    else:
        for src in srcs:
            if top:
                fail("Multiple files match candidates for `top`. Please explicitly specify which to use for {}".format(
                    ctx.label,
                ))

            basename = src.basename
            if basename.endswith(".sv"):
                basename = basename[:3]
            elif basename.endswith(".v"):
                basename = basename[:2]
            else:
                fail("Unknown extension: {}".format(basename))

            if basename == ctx.label.name:
                top = src

    if not top:
        fail("`top` and no `srcs` were specified. Please update {}".format(
            ctx.label,
        ))

    return top

def _verilog_library_impl(ctx):
    top = _find_top(ctx, ctx.files.srcs, ctx.file.top)

    direct_deps = [dep[VerilogInfo] for dep in ctx.attr.deps]
    transitive_deps = [dep.deps for dep in direct_deps]
    deps = depset(direct_deps, transitive = transitive_deps, order = "preorder")

    return [VerilogInfo(
        srcs = depset(ctx.files.srcs),
        deps = deps,
        compile_data = depset(ctx.files.compile_data),
        hdrs = depset(ctx.files.hdrs),
        top = top,
    )]

verilog_library = rule(
    doc = "TODO",
    implementation = _verilog_library_impl,
    attrs = {
        "compile_data": attr.label_list(
            doc = "TODO",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "The list of other libraries to be linked.",
            providers = [VerilogInfo],
        ),
        "hdrs": attr.label_list(
            doc = "Verilog or SystemVerilog headers.",
            allow_files = [".vh", ".svh"],
        ),
        "srcs": attr.label_list(
            doc = "Verilog or SystemVerilog sources.",
            allow_files = [".v", ".sv"],
        ),
        "top": attr.label(
            doc = "The top of the module. If unset, a file must be found matching the name of the target.",
            allow_single_file = True,
        ),
    },
)
