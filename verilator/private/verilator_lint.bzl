"""Verilator lint rules."""

load("//verilog:verilog_info.bzl", "VerilogInfo")
load(":verilator_utils.bzl", "collect_transitive_verilog_sources")

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _verilator_lint_aspect_impl(target, ctx):
    """Aspect implementation that lints Verilog using Verilator.

    This aspect runs transitively on VerilogInfo targets and performs linting.
    """

    # Only process targets with VerilogInfo
    if VerilogInfo not in target:
        return []

    # Skip external targets
    if target.label.workspace_root.startswith("external"):
        return []

    # Skip if tagged with no-verilator-lint
    sanitized_tags = [t.replace("-", "_") for t in ctx.rule.attr.tags]
    for skip in ["no_verilator_lint", "no_lint", "nolint"]:
        if skip in sanitized_tags:
            return []

    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]

    # Collect all verilog sources transitively
    direct_srcs, includes, inputs = collect_transitive_verilog_sources(target[VerilogInfo])

    # Build verilator lint command
    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator, format = "--verilator=%s")
    args.add_all(direct_srcs, format_each = "--src=%s")
    args.add("--capture_output")

    # Add delimiter before verilator arguments
    args.add("--")

    # Add verilator flags
    args.add("--lint-only")
    args.add("--no-std")
    args.add("--timing")
    args.add("-Wall")  # Enable all warnings
    args.add_all(includes, format_each = "-I%s")
    args.add_all(verilator_toolchain.vopts)

    # Add verilog files (will be replaced by wrapper via source_mappings)
    args.add_all(direct_srcs)

    # Declare output file
    lint_ok = ctx.actions.declare_file("{}.verilator_lint.ok".format(target.label.name))

    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorLint",
        executable = ctx.executable._verilator_process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = inputs,
        outputs = [lint_ok],
        env = {
            "RULES_VERILOG_VERILATOR_LINT_OUTPUT": lint_ok.path,
        },
    )

    return [
        OutputGroupInfo(
            verilator_lint_check = depset([lint_ok]),
        ),
    ]

verilator_lint_aspect = aspect(
    implementation = _verilator_lint_aspect_impl,
    doc = "Aspect for linting Verilog modules with Verilator.",
    required_providers = [VerilogInfo],
    attrs = {
        "_verilator_process_wrapper": attr.label(
            doc = "The Verilator process wrapper binary.",
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_process_wrapper"),
        ),
    },
    toolchains = [
        "//verilator:toolchain_type",
    ],
)

def _verilator_lint_test_impl(ctx):
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]

    direct_srcs, includes, inputs = collect_transitive_verilog_sources(ctx.attr.module[VerilogInfo])

    verilog_files = [_rlocationpath(f, ctx.workspace_name) for f in direct_srcs.to_list()]

    # Build the lint command arguments list
    test_args = []
    test_args.append("--verilator={}".format(_rlocationpath(verilator_toolchain.verilator, ctx.workspace_name)))
    for path in verilog_files:
        test_args.append("--src={}".format(path))
    test_args.append("--capture_output")

    # Add delimiter before verilator arguments
    test_args.append("--")

    # Add verilator flags
    test_args.extend([
        "--lint-only",
        "--no-std",
        "--timing",
        "-Wall",
    ])
    test_args.extend(["-I{}".format(path) for path in includes])
    test_args.extend(verilator_toolchain.vopts)

    # Add verilog files (will be replaced by wrapper via source_mappings)
    test_args.extend(verilog_files)

    # Write arguments to a file (newline delimited)
    args_file = ctx.actions.declare_file(ctx.label.name + ".verilator_lint_args.txt")
    ctx.actions.write(
        output = args_file,
        content = "\n".join(test_args) + "\n",
    )

    # Create a symlink to the process wrapper as the test executable
    test_executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = test_executable,
        target_file = ctx.executable._verilator_process_wrapper,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = test_executable,
            runfiles = ctx.runfiles(
                files = [args_file],
                transitive_files = depset(transitive = [inputs, verilator_toolchain.all_files]),
            ),
        ),
        testing.TestEnvironment({
            "RULES_VERILOG_VERILATOR_ARGS_FILE": _rlocationpath(args_file, ctx.workspace_name),
        }),
    ]

verilator_lint_test = rule(
    doc = """Test rule that runs Verilator lint on a Verilog module.

    This rule runs Verilator in lint-only mode on the specified module
    and all its transitive dependencies. The test passes if linting succeeds.

    Example:
        verilog_library(
            name = "my_module",
            srcs = ["my_module.sv"],
        )

        verilator_lint_test(
            name = "my_module_lint_test",
            module = ":my_module",
        )
    """,
    implementation = _verilator_lint_test_impl,
    attrs = {
        "module": attr.label(
            doc = "The Verilog module to lint.",
            providers = [VerilogInfo],
            mandatory = True,
        ),
        "_verilator_process_wrapper": attr.label(
            doc = "The Verilator process wrapper binary.",
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_process_wrapper"),
        ),
    },
    toolchains = [
        "//verilator:toolchain_type",
    ],
    test = True,
)
