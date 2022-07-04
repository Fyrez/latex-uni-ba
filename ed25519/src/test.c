#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char** argv){
unsigned char seed[32], public_key[32], private_key[64], signature[64];
//const unsigned char message[] = "TEST MESSAGE";

char * buffer = 0;
long length;
FILE * f = fopen (argv[1], "rb");

if (f) {
  fseek (f, 0, SEEK_END);
  length = ftell (f);
  fseek (f, 0, SEEK_SET);
  buffer = malloc (length + 1);
  if (buffer)
  {
    fread (buffer, 1, length, f);
  }
  fclose (f);
  buffer[length] = '\0';
}
else {
  printf("could not open file, check file path for errors\n");
  exit(1);
}

if (buffer)
{
  // start to process your data / extract strings here...



/* create a random seed, and a key pair out of that seed */
if (ed25519_create_seed(seed)) {
    printf("error while generating seed\n");
    exit(1);
}

ed25519_create_keypair(public_key, private_key, seed);
int lenpubkey = strlen(public_key);
printf("public_key: %s\n", public_key);
printf("public_key length: %d\n", lenpubkey);

/* create signature on the message with the key pair */
ed25519_sign(signature, buffer, strlen(buffer), public_key, private_key);

int lensig = strlen(signature);
int lenfile = strlen(buffer);

printf("signature: %s\n", signature);
printf("signature length: %d\n", lensig);
printf("file length: %d\n", lenfile);


/* verify the signature */
if (ed25519_verify(signature, buffer, strlen(buffer), public_key)) {
    printf("valid signature\n");
} else {
    printf("invalid signature\n");
}
return 0;
}
}

