#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char *argv[]) {
    
    unsigned char seed[32], public_key[32], private_key[64], signature[64];
    long FILE_SIZE;
    char *BUFFER;
    
    
    // open update file and read it into a BUFFER

    FILE *UPDATE_FILE = fopen ( argv[1], "rb" );
    if ( !UPDATE_FILE ) perror(argv[1]), exit(1);

    fseek( UPDATE_FILE , 0L , SEEK_END);
    FILE_SIZE = ftell( UPDATE_FILE );
    rewind( UPDATE_FILE );
    BUFFER = calloc( 1, FILE_SIZE + 1 );
    if ( !BUFFER ) fclose(UPDATE_FILE), fputs("memory alloc fails", stderr), exit(1);

    if ( 1 != fread( BUFFER , FILE_SIZE, 1 , UPDATE_FILE) )
        fclose(UPDATE_FILE), free(BUFFER), fputs("entire read fails", stderr), exit(1);
    fclose(UPDATE_FILE);

    // write update file from BUFFER to char array
    
    unsigned char *message = malloc(FILE_SIZE + 1 );
    
    if (message == NULL) {
        printf("error while allocating memory for update file");
        free(BUFFER);
        exit(1);
    }

    for (int i = 0; i < FILE_SIZE; ++i) {
        message[i] = ((char *)BUFFER)[i];
    }

    free(BUFFER);
    
    if (ed25519_create_seed(seed)) {
        printf("error while generating seed\n");
        exit(1);
    }

    ed25519_create_keypair(public_key, private_key, seed);

    ed25519_sign(signature, message, FILE_SIZE, public_key, private_key);

    free(message);


    /*  splitting key creation and signing process:
        - after ed25519_create_keypair, write public_key and private_key to any file
        - in a separate program (signing) : load public_key private_key and the update file ("message") into char arrays
        - file size of the update file and an empty 64 Byte char array (signature) are needed
        - call ed25519_sign and pass the prepared parameters
        - write public_key and signature to any file
        - file size should be 96 Byte (32 Byte public_key + 64 Byte signature in that specific order)
    */

    // write signature and public key to given file

    FILE *KEY_SIG_FILE = fopen(argv[2], "wb+");
    if (KEY_SIG_FILE == NULL)
    {
        printf("error opening file\n");
        exit(1);
    }
    for (int i= 0; i < sizeof(public_key); i++) {
        fputc(public_key[i], KEY_SIG_FILE);
    }
    for (int i= 0; i < sizeof(signature); i++){
        fputc(signature[i], KEY_SIG_FILE);
    }

    fclose(KEY_SIG_FILE);

    return 0;
}

