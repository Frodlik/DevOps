#include <iostream>
#include <cassert>
#include "funcA.h"

void test_calculate() {
    FuncA func;

    // Тест 1: Сума перших 5 елементів з x = 2.0
    int n = 5;
    double x = 2.0;
    double result = func.calculate(n, x);
    assert(result == 31.0);

    // Тест 2: Сума перших 3 елементів з x = 3.0
    n = 3;
    x = 3.0;
    result = func.calculate(n, x);
    assert(result == 13.0);

    // Тест 3: Сума перших 0 елементів з x = 2.0
    n = 0;
    x = 2.0;
    result = func.calculate(n, x);
    assert(result == 0.0);

    // Тест 4: Сума перших 4 елементів з x = 1.0
    n = 4;
    x = 1.0;
    result = func.calculate(n, x);
    assert(result == 4.0);

    std::cout << "All tests passed!" << std::endl;
}

int main() {
    test_calculate();
    return 0;
}
