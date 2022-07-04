#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
main(){
unsigned char seed[32], public_key[32], private_key[64], signature[64];

if (ed25519_create_seed(seed)) {
    printf("error while generating seed\n");
    exit(1);
}

ed25519_create_keypair(public_key, private_key, seed);

FILE *fp;

fp = fopen("/home/mulbric9/BA/ed25519/src/test.txt", "w+");
fputs(public_key, fp);
fclose(fp);

return 0
}