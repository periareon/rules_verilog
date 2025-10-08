"""Verilator actions"""

def collect_transitive_verilog_sources(verilog_info):
    """Collect all transitive Verilog sources from a target.

    Args:
        verilog_info: A VerilogInfo provider.

    Returns:
        tuple:
            - Direct Verilog/SystemVerilog sources from target.
            - includes for each module
            - All transitive sources, headers, and compile data in addition to direct
                sources and headers.
    """

    # Collect transitively from this target and all deps
    transitive_srcs = [verilog_info.srcs]
    transitive_hdrs = [verilog_info.hdrs]
    transitive_data = [verilog_info.compile_data]

    includes = [verilog_info.top.dirname]

    for dep_info in verilog_info.deps.to_list():
        transitive_srcs.append(dep_info.srcs)
        transitive_hdrs.append(dep_info.hdrs)
        transitive_data.append(dep_info.compile_data)
        includes.append(dep_info.top.dirname)

    inputs = depset(transitive = transitive_srcs + transitive_hdrs + transitive_data + [
        verilog_info.srcs,
        verilog_info.hdrs,
        verilog_info.compile_data,
    ])

    return (verilog_info.srcs, depset(includes).to_list(), inputs)
