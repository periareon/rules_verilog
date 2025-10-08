/**
 * @file verilator_process_wrapper.cc
 * @brief A process wrapper for Verilator actions (compile and lint).
 */

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <vector>

#ifndef _WIN32
#include <sys/wait.h>
#else
#include <windows.h>
#define popen _popen
#define pclose _pclose
#endif

#include "tools/cpp/runfiles/runfiles.h"

namespace fs = std::filesystem;

using bazel::tools::cpp::runfiles::Runfiles;

/**
 * @brief Struct to hold parsed command-line arguments.
 */
struct Args {
    /** The path to verilator. */
    std::string verilator_binary;

    /** key: original path, value: resolved path */
    std::map<std::string, std::string> source_mappings;

    /** key: original path, value: normalized path (never runfiles) */
    std::map<std::string, std::string> output_mappings;

    /** The optional sources output dir */
    std::string output_srcs;

    /** The optional headers output dir */
    std::string output_hdrs;

    /** Whether to capture subprocess output */
    bool capture_output = false;

    /** Direct arguments to verilator (anything after `--`) */
    std::vector<std::string> verilator_args;
};

/**
 * @brief Checks if a string starts with a given prefix.
 *
 * @param str The string to check.
 * @param prefix The prefix to look for.
 * @return true if str starts with prefix, false otherwise.
 */
bool starts_with(const std::string& str, const std::string& prefix) {
    return str.size() >= prefix.size() &&
           str.compare(0, prefix.size(), prefix) == 0;
}

/**
 * @brief Normalizes a path for the current platform.
 *
 * @param path The path to normalize.
 * @return The normalized path string.
 */
std::string normalize_path(const std::string& path) {
    return fs::path(path).make_preferred().string();
}

std::string resolve_path(const std::string& path, Runfiles* runfiles) {
    if (runfiles != nullptr) {
        std::string resolved_path = runfiles->Rlocation(path);
        if (!resolved_path.empty()) {
            return resolved_path;
        }
    }

    return normalize_path(path);
}

/**
 * @brief Parses command-line arguments into an Args struct.
 *
 * @param out_args The args object to populate
 * @param argc The number of command-line arguments.
 * @param argv The command-line argument array.
 * @param runfiles Optional runfiles instance for path resolution.
 * @param use_runfiles Whether to use runfiles for path resolution.
 * @return 0 if parsing was successful
 */
int parse_args(Args& out_args, int argc, char* argv[], Runfiles* runfiles) {
    Args args = {};
    bool after_delimiter = false;

    // Parse arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        // Check for -- delimiter
        if (arg == "--") {
            after_delimiter = true;
            continue;
        }

        if (after_delimiter) {
            // Replace any source and output mappings in the argument
            std::string modified_arg = arg;

            // Replace source mappings
            for (const std::pair<const std::string, std::string>& mapping :
                 args.source_mappings) {
                const std::string& original = mapping.first;
                const std::string& resolved = mapping.second;
                size_t pos = 0;
                while ((pos = modified_arg.find(original, pos)) !=
                       std::string::npos) {
                    modified_arg.replace(pos, original.length(), resolved);
                    pos += resolved.length();
                }
            }

            // Replace output mappings
            for (const std::pair<const std::string, std::string>& mapping :
                 args.output_mappings) {
                const std::string& original = mapping.first;
                const std::string& resolved = mapping.second;
                size_t pos = 0;
                while ((pos = modified_arg.find(original, pos)) !=
                       std::string::npos) {
                    modified_arg.replace(pos, original.length(), resolved);
                    pos += resolved.length();
                }
            }

            args.verilator_args.push_back(modified_arg);
        } else if (starts_with(arg, "--verilator=")) {
            // Length of "--verilator="
            int len = 12;
            args.verilator_binary = resolve_path(arg.substr(len), runfiles);
        } else if (starts_with(arg, "--src=")) {
            // Length of "--src="
            int len = 6;
            std::string src_path = arg.substr(len);
            args.source_mappings[src_path] = resolve_path(src_path, runfiles);
        } else if (starts_with(arg, "--output=")) {
            // Length of "--output="
            int len = 9;
            std::string output_path = arg.substr(len);
            // Outputs are never runfiles, only normalize the path
            args.output_mappings[output_path] = normalize_path(output_path);
        } else if (starts_with(arg, "--output_srcs=")) {
            // Length of "--output_srcs="
            int len = 14;
            args.output_srcs = arg.substr(len);
        } else if (starts_with(arg, "--output_hdrs=")) {
            // Length of "--output_hdrs="
            int len = 14;
            args.output_hdrs = arg.substr(len);
        } else if (arg == "--capture_output") {
            args.capture_output = true;
        } else {
            std::cerr << "Error: Unknown argument: " << arg << std::endl;
            return 1;
        }
    }

    out_args = args;
    return 0;
}

/**
 * @brief Checks if a filename ends with any of the given suffixes.
 *
 * @param filename The name of the file.
 * @param suffixes A vector of suffixes to match.
 * @return true if the filename ends with any suffix, false otherwise.
 */
bool ends_with_any(const std::string& filename,
                   const std::vector<std::string>& suffixes) {
    for (const std::string& suffix : suffixes) {
        if (filename.size() >= suffix.size() &&
            filename.compare(filename.size() - suffix.size(), suffix.size(),
                             suffix) == 0) {
            return true;
        }
    }
    return false;
}

/**
 * @brief Deletes files in the specified directory that match given suffixes.
 *
 * @param dir The directory to scan for matching files.
 * @param suffixes The list of suffixes to check for deletion.
 * @return A non-zero exit code if any issues occurred.
 */
int delete_matching_files(const std::string& dir,
                          const std::vector<std::string>& suffixes) {
    if (dir.empty()) return 0;

    fs::path dir_path(dir);
    if (!fs::exists(dir_path) || !fs::is_directory(dir_path)) {
        return 0;  // Directory doesn't exist, nothing to delete
    }

    for (const fs::directory_entry& entry : fs::directory_iterator(dir_path)) {
        if (entry.is_regular_file()) {
            std::string filename = entry.path().filename().string();
            if (ends_with_any(filename, suffixes)) {
                std::error_code ec;
                fs::remove(entry.path(), ec);
                if (ec) {
                    std::cerr << "Error: Failed to delete: " << entry.path()
                              << " - " << ec.message() << std::endl;
                    return 1;
                }
            }
        }
    }

    return 0;
}

/**
 * @brief Copies files from output directory to separate source and header
 * directories.
 *
 * @param output_dir The output directory containing generated files.
 * @param output_srcs The destination directory for source files (cc/cpp/c).
 * @param output_hdrs The destination directory for header files (h/hpp/hh).
 * @return A non-zero exit code if any issues occurred.
 */
int copy_and_filter_outputs(const std::string& output_dir,
                            const std::string& output_srcs,
                            const std::string& output_hdrs) {
    if (output_dir.empty() || (output_srcs.empty() && output_hdrs.empty())) {
        return 0;
    }

    fs::path dir_path(output_dir);
    if (!fs::exists(dir_path) || !fs::is_directory(dir_path)) {
        std::cerr << "Error: Output directory does not exist: " << output_dir
                  << std::endl;
        return 1;
    }

    // Create destination directories if they don't exist
    if (!output_srcs.empty()) {
        fs::create_directories(output_srcs);
    }
    if (!output_hdrs.empty()) {
        fs::create_directories(output_hdrs);
    }

    // Define file extensions
    std::vector<std::string> source_extensions = {".cc", ".cpp", ".c"};
    std::vector<std::string> header_extensions = {".h", ".hpp", ".hh"};

    for (const fs::directory_entry& entry : fs::directory_iterator(dir_path)) {
        if (entry.is_regular_file()) {
            std::string filename = entry.path().filename().string();
            fs::path dest_path;
            bool should_copy = false;

            if (!output_srcs.empty() &&
                ends_with_any(filename, source_extensions)) {
                dest_path = fs::path(output_srcs) / filename;
                should_copy = true;
            } else if (!output_hdrs.empty() &&
                       ends_with_any(filename, header_extensions)) {
                dest_path = fs::path(output_hdrs) / filename;
                should_copy = true;
            }

            if (should_copy) {
                // Copy the file
                std::error_code ec;
                fs::copy_file(entry.path(), dest_path,
                              fs::copy_options::overwrite_existing, ec);
                if (ec) {
                    std::cerr << "Error: Failed to copy " << entry.path()
                              << " to " << dest_path << " - " << ec.message()
                              << std::endl;
                    return 1;
                }
            }

            // Delete the original file if it's a source or header
            if (ends_with_any(filename, source_extensions) ||
                ends_with_any(filename, header_extensions)) {
                std::error_code ec;
                fs::remove(entry.path(), ec);
                if (ec) {
                    std::cerr << "Error: Failed to delete: " << entry.path()
                              << " - " << ec.message() << std::endl;
                    return 1;
                }
            } else {
                // Delete files that are neither source nor header
                std::error_code ec;
                fs::remove(entry.path(), ec);
                if (ec) {
                    std::cerr << "Error: Failed to delete: " << entry.path()
                              << " - " << ec.message() << std::endl;
                    return 1;
                }
            }
        }
    }

    // Verify that output directories contain files if they were specified
    if (!output_srcs.empty()) {
        bool has_files = false;
        for (const fs::directory_entry& entry :
             fs::directory_iterator(output_srcs)) {
            if (entry.is_regular_file()) {
                has_files = true;
                break;
            }
        }
        if (!has_files) {
            std::cerr << "Error: output_srcs directory is empty: "
                      << output_srcs << std::endl;
            return 1;
        }
    }

    if (!output_hdrs.empty()) {
        bool has_files = false;
        for (const fs::directory_entry& entry :
             fs::directory_iterator(output_hdrs)) {
            if (entry.is_regular_file()) {
                has_files = true;
                break;
            }
        }
        if (!has_files) {
            std::cerr << "Error: output_hdrs directory is empty: "
                      << output_hdrs << std::endl;
            return 1;
        }
    }

    return 0;
}

/**
 * @brief Executes a command, optionally capturing output.
 *
 * This function provides cross-platform support for Windows and POSIX systems:
 * - Windows: Uses _popen/_pclose (returns exit code directly)
 * - POSIX: Uses popen/pclose (returns status that needs WEXITSTATUS decoding)
 *
 * @param cmd The command to execute.
 * @param capture_output Whether to capture stdout/stderr.
 * @param captured_output Output parameter to store captured output.
 * @return The exit code of the command.
 */
int execute_command(const std::string& cmd, bool capture_output,
                    std::string& captured_output) {
    if (!capture_output) {
        // No capture needed, use system() directly
        return std::system(cmd.c_str());
    }

    // Capture output using popen/pclose (platform-specific)
    // Redirect stderr to stdout so we capture both
    std::string full_cmd = cmd + " 2>&1";
    FILE* pipe = popen(full_cmd.c_str(), "r");

    if (!pipe) {
        std::cerr << "Error: Failed to execute command" << std::endl;
        return 1;
    }

    // Read output
    char buffer[256];
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        captured_output += buffer;
    }

    int status = pclose(pipe);
#ifdef _WIN32
    return status;
#else
    // Extract the actual exit code using WEXITSTATUS
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }

    return status;
#endif
}

int main(int argc, char* argv[]) {
    // Check if we should load arguments from a file
    const char* args_file_env =
        std::getenv("RULES_VERILOG_VERILATOR_ARGS_FILE");
    Args args = {};

    if (args_file_env != nullptr) {
        std::vector<std::string> file_args;
        std::vector<char*> file_argv = {};

        std::string error;
        std::unique_ptr<Runfiles> runfiles(
            Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
        if (runfiles == nullptr) {
            std::cerr << "Error: Failed to create runfiles: " << error
                      << std::endl;
            return 1;
        }

        // Resolve the args file path via runfiles if needed
        std::string args_file_path = args_file_env;
        std::string resolved = runfiles->Rlocation(std::string(args_file_path));
        if (resolved.empty()) {
            std::cerr << "Error: Find runfile: " << args_file_path << std::endl;
            return 1;
        }

        // Read arguments from file
        std::ifstream args_file(resolved);
        if (!args_file) {
            std::cerr << "Error: Failed to open args file: " << resolved
                      << std::endl;
            return 1;
        }

        std::string line;
        while (std::getline(args_file, line)) {
            if (!line.empty()) {
                file_args.push_back(line);
            }
        }
        args_file.close();

        // Build new argv array from file args
        file_argv.push_back(argv[0]);  // Keep program name
        for (std::string& arg : file_args) {
            file_argv.push_back(const_cast<char*>(arg.c_str()));
        }

        // Parse arguments from file
        if (parse_args(args, file_argv.size(), file_argv.data(),
                       runfiles.get())) {
            std::cerr << "Error: Failed to parse arguments" << std::endl;
            return 1;
        }
    } else {
        // Parse arguments from command line
        if (parse_args(args, argc, argv, nullptr)) {
            std::cerr << "Error: Failed to parse arguments" << std::endl;
            return 1;
        }
    }

    // Build command
    std::string cmd = {};
    {
        std::vector<std::string> command;

        if (!args.verilator_binary.empty()) {
            command.push_back(args.verilator_binary);
        }

        // Add verilator arguments (already have source and output files
        // replaced in parse_args)
        for (const std::string& arg : args.verilator_args) {
            command.push_back(arg);
        }

        if (command.empty()) {
            std::cerr << "Error: No command provided to execute." << std::endl;
            return 1;
        }

        for (const std::string& part : command) {
            cmd += part + " ";
        }
    }

    // Execute verilator command with optional output capture
    std::string captured_output;
    int result = execute_command(cmd, args.capture_output, captured_output);

    // Print captured output if needed
    if (args.capture_output && !captured_output.empty()) {
        // Check if we should print the output
        bool should_print = false;

        // Print if there was an error
        if (result != 0) {
            should_print = true;
        }

        // Print if debug environment variable is set
        const char* debug_env = std::getenv("RULES_VERILOG_VERILATOR_DEBUG");
        if (debug_env != nullptr) {
            should_print = true;
        }

        if (should_print) {
            std::cout << captured_output;
        }
    }

    if (result != 0) {
        return result;
    }

    // If lint succeeded, touch the output file
    const char* lint_output =
        std::getenv("RULES_VERILOG_VERILATOR_LINT_OUTPUT");
    if (lint_output != nullptr) {
        // Create parent directories if they don't exist
        fs::path output_path(lint_output);
        if (output_path.has_parent_path()) {
            fs::create_directories(output_path.parent_path());
        }

        // Touch the file
        std::ofstream output_file(lint_output);
        if (!output_file) {
            std::cerr << "Error: Failed to create output file: " << lint_output
                      << std::endl;
            return 1;
        }
        output_file.close();
    }

    // Copy and filter output files to separate source and header directories
    if (!args.output_srcs.empty() || !args.output_hdrs.empty()) {
        for (auto it = args.output_mappings.begin();
             it != args.output_mappings.end(); ++it) {
            if (copy_and_filter_outputs(it->first, args.output_srcs,
                                        args.output_hdrs)) {
                return 1;
            }
        }
    }

    return 0;
}
