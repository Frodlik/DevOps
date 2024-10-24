#include "funcA.h"
#include <cmath>

// Function to calculate sum of first n elements in the geometric series
// Param n: number of elements
// Param x: value of x in the series
double FuncA::calculate(int n, double x) {
	double sum = 0;
	for(int i = 0; i < n; ++i) {
		sum += pow(x, i);
	}
	return sum;
}
