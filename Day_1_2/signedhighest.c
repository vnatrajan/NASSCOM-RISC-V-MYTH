#include <stdio.h>
#include <math.h>

int main() {
	long long int max_neg = (long long int) (pow(2,63)* -1);
	printf("Highest negative number respreented by long long int is %lld\n", max_neg);
	return 0;
}