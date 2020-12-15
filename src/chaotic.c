#define _GNU_SOURCE
#include <unistd.h>
int main(int argc, char *argv[]) {
    setuid(0);
    execvpe(PREFIX "/bin/chaotic.sh",
        argv,
        NULL);
}
