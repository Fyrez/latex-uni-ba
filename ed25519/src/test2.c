#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(){
unsigned char seed[32], public_key[32], private_key[64], signature[64];
const unsigned char message[] = "TEST";
const int message_len = strlen((char*) message);

if (ed25519_create_seed(seed)) {
    printf("error while generating seed\n");
    exit(1);
}
ed25519_create_keypair(public_key, private_key, seed);
ed25519_sign(signature, message, message_len, public_key, private_key);

FILE *fp = fopen("/home/mulbric9/BA/ed25519/src/test.txt", "w+");
	if (fp == NULL)
	{
		printf("error opening file\n");
		exit(1);
	}
fprintf(fp, "Message: %s\n", message);
fprintf(fp, "public_key: %s\n", public_key);
fprintf(fp, "private_key: %s\n", private_key);
fprintf(fp, "signature: %s\n", signature);

fclose(fp);

if (ed25519_verify(signature, message, strlen(message), public_key)) {
    printf("valid signature\n");
} else {
    printf("invalid signature\n");
}


return 0;
}