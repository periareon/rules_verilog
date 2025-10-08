"""Verilator Cc Rules."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cpp_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//verilog:verilog_info.bzl", "VerilogInfo")

VerilatorCcInfo = provider(
    doc = "Provider for Verilator-compiled C++ outputs.",
    fields = {
        "compilation_context": "CcCompilationContext with headers and includes",
        "compilation_outputs": "CcCompilationOutputs with object files",
        "hdrs_dir": "Directory containing generated C++ header files",
        "module_name": "Name of the Verilog module",
        "srcs_dir": "Directory containing generated C++ source files",
    },
)

def _verilator_cc_aspect_impl(target, ctx):
    """Aspect implementation that compiles Verilog modules to C++ using Verilator.

    This aspect runs on verilog_library targets and compiles each module to C++
    object files using Verilator's hierarchical compilation mode.
    """

    # Only process targets with VerilogInfo
    if VerilogInfo not in target:
        fail("`_verilator_cc_aspect` can only run on targets with `VerilogInfo` providers. Provider not found on: {}".format(target.label))

    # Only process targets with VerilogInfo
    if VerilatorCcInfo in target:
        return []

    # Get the verilator toolchain
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]

    # Get module information
    module_info = target[VerilogInfo]
    module_name, _, _ = module_info.top.basename.partition(".")

    # Collect direct sources and includes
    direct_srcs = module_info.srcs.to_list()
    includes = [module_info.top.dirname]

    # Collect transitive sources and includes for compilation
    transitive_srcs = [module_info.srcs]
    transitive_hdrs = [module_info.hdrs]
    transitive_data = [module_info.compile_data]

    for dep_info in module_info.deps.to_list():
        transitive_srcs.append(dep_info.srcs)
        transitive_hdrs.append(dep_info.hdrs)
        transitive_data.append(dep_info.compile_data)
        includes.append(dep_info.top.dirname)

    inputs = depset(transitive = transitive_srcs + transitive_hdrs + transitive_data)

    # Create output directories with new naming scheme
    label_name = target.label.name
    output_src_dir = ctx.actions.declare_directory("{}_V/srcs".format(label_name))
    output_hdr_dir = ctx.actions.declare_directory("{}_V/hdrs".format(label_name))
    output_dir = output_src_dir.dirname

    # Build verilator compile command
    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator, format = "--verilator=%s")
    args.add_all(direct_srcs, format_each = "--src=%s")
    args.add(output_dir, format = "--output=%s")
    args.add(output_src_dir.path, format = "--output_srcs=%s")
    args.add(output_hdr_dir.path, format = "--output_hdrs=%s")
    args.add("--capture_output")

    # Add delimiter before verilator arguments
    args.add("--")

    # Add verilator flags
    args.add("--no-std")
    args.add("--cc")
    args.add("--hierarchical")
    args.add("--Mdir", output_dir)
    args.add("--top-module", module_name)
    args.add("--prefix", "V" + module_name)
    args.add_all(includes, format_each = "-I%s")
    args.add_all(verilator_toolchain.vopts)

    # Add verilog files
    args.add_all(direct_srcs)

    # Run verilator compile action
    ctx.actions.run(
        mnemonic = "Verilate",
        executable = ctx.executable._verilator_process_wrapper,
        arguments = [args],
        tools = verilator_toolchain.all_files,
        inputs = inputs,
        outputs = [output_src_dir, output_hdr_dir],
    )

    # Compile the C++ code to object files (no linking)
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # Collect C++ compilation contexts from verilator toolchain and transitive deps
    compilation_contexts = [verilator_toolchain.libverilator[CcInfo].compilation_context]

    for dep in verilator_toolchain.deps:
        compilation_contexts.append(dep[CcInfo].compilation_context)

    # Collect transitive VerilatorCcInfo from deps
    for dep in ctx.rule.attr.deps:
        if VerilatorCcInfo in dep:
            compilation_contexts.append(dep[VerilatorCcInfo].compilation_context)

    # Compile C++ sources to object files only
    compilation_context, compilation_outputs = cc_common.compile(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = verilator_toolchain.copts,
        srcs = [output_src_dir],
        includes = [output_hdr_dir.path, output_src_dir.path],
        public_hdrs = [output_hdr_dir],
        compilation_contexts = compilation_contexts,
    )

    return [
        VerilatorCcInfo(
            compilation_context = compilation_context,
            compilation_outputs = compilation_outputs,
            srcs_dir = output_src_dir,
            hdrs_dir = output_hdr_dir,
            module_name = module_name,
        ),
    ]

_verilator_cc_aspect = aspect(
    implementation = _verilator_cc_aspect_impl,
    doc = "Aspect for compiling Verilog modules to C++ object files with Verilator.",
    attr_aspects = ["deps"],
    attrs = {
        "_verilator_process_wrapper": attr.label(
            doc = "The Verilator process wrapper binary.",
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_process_wrapper"),
        ),
    },
    toolchains = [
        "@rules_cc//cc:toolchain_type",
        "//verilator:toolchain_type",
    ],
    fragments = ["cpp"],
)

def _verilator_cc_library_impl(ctx):
    # Get the verilator toolchain
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]

    # The aspect has already compiled the module and all its dependencies to object files
    if VerilatorCcInfo not in ctx.attr.module:
        fail("Module {} does not have VerilatorCcInfo - aspect did not run".format(ctx.attr.module.label))

    # Collect all compilation contexts and outputs from the module (includes transitive deps via aspect)
    verilator_info = ctx.attr.module[VerilatorCcInfo]

    # Collect all compilation contexts and outputs
    compilation_contexts = [verilator_info.compilation_context]
    all_compilation_outputs = [verilator_info.compilation_outputs]

    # Also include verilator library dependencies
    compilation_contexts.append(verilator_toolchain.libverilator[CcInfo].compilation_context)
    linking_contexts = [verilator_toolchain.libverilator[CcInfo].linking_context]

    for dep in verilator_toolchain.deps:
        compilation_contexts.append(dep[CcInfo].compilation_context)
        linking_contexts.append(dep[CcInfo].linking_context)

    # Merge all compilation outputs
    merged_compilation_outputs = cc_common.merge_compilation_outputs(
        compilation_outputs = all_compilation_outputs,
    )

    # Link everything together
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # Create linking context from all the compiled objects
    linking_context, linking_output = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = merged_compilation_outputs,
        linking_contexts = linking_contexts,
        name = ctx.label.name,
        user_link_flags = verilator_toolchain.linkopts + ctx.attr.linkopts,
        disallow_dynamic_library = True,
    )

    # Merge compilation contexts
    merged_compilation_context = cc_common.merge_compilation_contexts(
        compilation_contexts = compilation_contexts,
    )

    output_files = []
    if linking_output.library_to_link.static_library != None:
        output_files.append(linking_output.library_to_link.static_library)
    if linking_output.library_to_link.pic_static_library != None:
        output_files.append(linking_output.library_to_link.pic_static_library)

    return [
        DefaultInfo(
            files = depset(output_files),
            runfiles = ctx.runfiles(files = ctx.files.data),
        ),
        CcInfo(
            compilation_context = merged_compilation_context,
            linking_context = linking_context,
        ),
    ]

verilator_cc_library = rule(
    doc = """Compiles a Verilog module to a C++ library using Verilator.

    This rule uses an aspect to compile each Verilog module in the dependency tree
    to C++ object files using Verilator's hierarchical compilation mode, then links
    them all together into a single static library.

    Example:

    ```python
    verilog_library(
        name = "my_module",
        srcs = ["my_module.sv"],
    )

    verilator_cc_library(
        name = "my_module_cc",
        module = ":my_module",
    )
    ```
    """,
    implementation = _verilator_cc_library_impl,
    attrs = {
        "data": attr.label_list(
            doc = "Data used at runtime by the library",
            allow_files = True,
        ),
        "linkopts": attr.string_list(
            doc = "List of additional C++ linker flags",
            default = [],
        ),
        "module": attr.label(
            doc = "The top level Verilog module target to compile with Verilator.",
            providers = [VerilogInfo],
            mandatory = True,
            aspects = [_verilator_cc_aspect],
        ),
    },
    provides = [
        CcInfo,
        DefaultInfo,
    ],
    toolchains = [
        "@rules_cc//cc:toolchain_type",
        "//verilator:toolchain_type",
    ],
    fragments = ["cpp"],
)
