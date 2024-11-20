#include <iostream>
#include "funcA.h"

int main() {
	FuncA func;
	int n = 5;
	double x = 2.0;
	std::cout << "FuncA result: " << func.calculate(n, x) << std::endl;
	return 0;
}
