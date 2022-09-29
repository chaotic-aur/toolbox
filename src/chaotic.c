#define _GNU_SOURCE
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ME_ENV "CAUR_REAL_USER"
#define UID_ENV "CAUR_REAL_UID"

int main(int argc, char *argv[]) {
    char **envp=NULL, *me, *meEnv, euidEnv[sizeof(ME_ENV) + 12];
    
    me = getenv("USER");
    if (me) {
        meEnv = (char*)malloc(sizeof(ME_ENV) + 1 + strlen(me));
        sprintf(meEnv, ME_ENV"=%s", me);
        sprintf(euidEnv, UID_ENV"=%u", getuid());
        envp = malloc(3 * sizeof(char*));
        memcpy(envp, (char*[]){meEnv, euidEnv, NULL}, sizeof envp);
    }

    setuid(0);
    execvpe(PREFIX "/bin/chaotic.sh",
        argv,
        envp);
}
