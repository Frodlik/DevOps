#include <iostream>
#include "funcA.h"
#include <sys/wait.h>

int CreateHTTPserver();

void sigchldHandler(int s)
{
	printf("Caught signal SIGCHLD\n");

	pid_t pid;
	int status;

	while ((pid = waitpid(-1,&status,WNOHANG)) > 0)
	{
		if (WIFEXITED(status)) printf("\nChild process terminated");
	}
}

void sigintHandler(int s)
{
	printf("Caught signal %d. Starting graceful exit procedure\n",s);

	pid_t pid;
	int status;
	while ((pid = waitpid(-1,&status,0)) > 0)
	{
		if (WIFEXITED(status)) printf("\nChild process terminated");
	}
	
	if (pid == -1) printf("\nAll child processes terminated");

	exit(EXIT_SUCCESS);
}

int main() {
	FuncA func;
	//int n = 5;
	//double x = 2.0;
	//std::cout << "FuncA result: " << func.calculate(n, x) << std::endl;
	
	signal(SIGCHLD, sigchldHandler);
	signal(SIGINT, sigintHandler);
	
	
	CreateHTTPserver();
	
	return 0;
}
