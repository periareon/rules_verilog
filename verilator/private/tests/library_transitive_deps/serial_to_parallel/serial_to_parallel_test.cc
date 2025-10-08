#include <verilated.h>
#include <verilated_vcd_c.h>

#include <bitset>
#include <cstdlib>
#include <iostream>
#include <memory>

#include "Vserial_to_parallel.h"

namespace {

void Clock(Vserial_to_parallel* dut) {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
}

void Reset(Vserial_to_parallel* dut) {
    dut->rst_n = 0;
    Clock(dut);
    dut->rst_n = 1;
    Clock(dut);
}

bool RunTest() {
    std::unique_ptr<Vserial_to_parallel> dut =
        std::make_unique<Vserial_to_parallel>();

    bool success = true;

    Reset(dut.get());

    // Test pattern: shift in the nibble 0b1010 serially (LSB first)
    uint8_t test_pattern = 0b1010;

    std::cout << "Shifting in pattern 0b" << std::bitset<4>(test_pattern)
              << std::endl;

    // Shift in 4 bits
    for (int bit_idx = 0; bit_idx < 4; bit_idx++) {
        dut->serial_in = (test_pattern >> bit_idx) & 1;
        dut->load_enable = 0;
        Clock(dut.get());
        std::cout << "  Cycle " << bit_idx << ": shifted in "
                  << ((test_pattern >> bit_idx) & 1) << std::endl;
    }

    // Load the output register
    dut->load_enable = 1;
    dut->serial_in = 0;
    Clock(dut.get());

    // Check output
    uint8_t expected = test_pattern;
    uint8_t actual = dut->parallel_out;

    std::cout << "Expected: 0b" << std::bitset<4>(expected) << " ("
              << (int)expected << ")" << std::endl;
    std::cout << "Actual:   0b" << std::bitset<4>(actual) << " (" << (int)actual
              << ")" << std::endl;
    std::cout << "Valid:    " << (int)dut->valid << std::endl;

    if (actual != expected) {
        std::cerr << "Pattern mismatch!" << std::endl;
        success = false;
    }

    if (dut->valid != 1) {
        std::cerr << "Valid signal not asserted!" << std::endl;
        success = false;
    }

    // Test another pattern: 0b0101
    test_pattern = 0b0101;
    std::cout << "\nShifting in pattern 0b" << std::bitset<4>(test_pattern)
              << std::endl;

    for (int bit_idx = 0; bit_idx < 4; bit_idx++) {
        dut->serial_in = (test_pattern >> bit_idx) & 1;
        dut->load_enable = 0;
        Clock(dut.get());
        std::cout << "  Cycle " << bit_idx << ": shifted in "
                  << ((test_pattern >> bit_idx) & 1) << std::endl;
    }

    dut->load_enable = 1;
    dut->serial_in = 0;
    Clock(dut.get());

    expected = test_pattern;
    actual = dut->parallel_out;

    std::cout << "Expected: 0b" << std::bitset<4>(expected) << " ("
              << (int)expected << ")" << std::endl;
    std::cout << "Actual:   0b" << std::bitset<4>(actual) << " (" << (int)actual
              << ")" << std::endl;

    if (actual != expected) {
        std::cerr << "Pattern mismatch!" << std::endl;
        success = false;
    }

    return success;
}

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    bool ok = RunTest();
    if (ok) {
        std::cout << "\nAll tests passed." << std::endl;
        return 0;
    } else {
        std::cerr << "\nSome tests failed." << std::endl;
        return 1;
    }
}
