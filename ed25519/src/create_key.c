#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char *argv[]) {
    
    unsigned char seed[32], public_key[32], private_key[64], signature[64];
    long FILE_SIZE;
    char *buffer;
    
    
    // open update file and read it into a buffer
    FILE *UPDATE_FILE = fopen ( argv[1], "rb" );
    if ( !UPDATE_FILE ) perror(argv[1]), exit(1);

    fseek( UPDATE_FILE , 0L , SEEK_END);
    FILE_SIZE = ftell( UPDATE_FILE );
    rewind( UPDATE_FILE );
    buffer = calloc( 1, FILE_SIZE + 1 );
    if ( !buffer ) fclose(UPDATE_FILE), fputs("memory alloc fails", stderr), exit(1);

    if ( 1 != fread( buffer , FILE_SIZE, 1 , UPDATE_FILE) )
        fclose(UPDATE_FILE), free(buffer), fputs("entire read fails", stderr), exit(1);
    fclose(UPDATE_FILE);
    // write update file from buffer to char array
    unsigned char *message = malloc(FILE_SIZE + 1 );
    for (int i = 0; i < FILE_SIZE; ++i) {
        message[i] = ((char *)buffer)[i];
    }

    free(buffer);
    if (ed25519_create_seed(seed)) {
        printf("error while generating seed\n");
        exit(1);
    }
    ed25519_create_keypair(public_key, private_key, seed);
    ed25519_sign(signature, message, FILE_SIZE, public_key, private_key);
    free(message);
    
    
    FILE *key_file = fopen(argv[2], "w+");
    if (key_file == NULL)
    {
        printf("error opening file\n");
        exit(1);
    }
    for (int i= 0; i < sizeof(public_key); i++) {
        fputc(public_key[i], key_file);
        // Failed to write do error code here.
    }
    for (int i= 0; i < sizeof(signature); i++){
        fputc(signature[i], key_file);
    }

    fclose(key_file);
    /*
    FILE *sig_file = fopen("/home/mulbric9/BA/ed25519/src/signature.txt", "w+");
    if (sig_file == NULL)
    {
        printf("error opening file\n");
        exit(1);
    }
    for (int i = 0; i < sizeof(signature); i++) {
        fputc(signature[i], sig_file);
        // Failed to write do error code here.
    }
    // Failed to write do error code here.

    fclose(sig_file);
    

    if (ed25519_verify(signature, message, FILE_SIZE, public_key)) {
        printf("valid signature\n");
    } else {
        printf("invalid signature\n");
    }*/

    return 0;
}

