# include <stdio.h>

int main() {
	int i, n=5, sum=0;
	for (i=1; i <= 5; i++) {
		sum += i;
	}
	printf("Sum of numbers 1 to %d is %d\n", n, sum);
	return 0;
}