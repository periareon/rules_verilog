#include <verilated.h>
#include <verilated_vcd_c.h>

#include <cstdlib>
#include <iostream>
#include <memory>

#include "Vadder.h"

namespace {

bool RunTest() {
    std::unique_ptr<Vadder> v_adder = std::make_unique<Vadder>();

    v_adder->x = 1;
    v_adder->y = 2;
    v_adder->eval();

    int expected = 3;
    int actual = v_adder->sum;

    if (actual != expected) {
        std::cerr << "Test failed: expected " << expected << ", got " << actual
                  << std::endl;
        return false;
    }

    return true;
}

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    if (RunTest()) {
        std::cout << "All tests passed." << std::endl;
        return 0;
    } else {
        std::cerr << "Some tests failed." << std::endl;
        return 1;
    }
}
