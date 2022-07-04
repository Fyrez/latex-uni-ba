#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char *argv[]) {
    unsigned char seed[32], public_key[32], private_key[64], signature[64];
    long lSize;
    int bSize = 32;
    char *buffer;
    int i;
    /*const unsigned char message[] = "TEST";
    const int message_len = strlen((char*) message);
    */
    FILE *msg_file = fopen ( argv[1], "rb" );
    if ( !msg_file ) perror(argv[1]), exit(1);

    fseek( msg_file , 0L , SEEK_END);
    lSize = ftell( msg_file );
    rewind( msg_file );
    /* allocate memory for entire content */
    buffer = calloc( 1, lSize + 1 );
    if ( !buffer ) fclose(msg_file), fputs("memory alloc fails", stderr), exit(1);

    /* copy the file into the buffer */
    if ( 1 != fread( buffer , lSize, 1 , msg_file) )
        fclose(msg_file), free(buffer), fputs("entire read fails", stderr), exit(1);
    fclose(msg_file);

    /*for (i = 0; i < lSize+1; ++i){
        printf("%c", ((char *)buffer)[i]);
    }*/

    unsigned char *message = malloc(lSize + 1 );
    for (i = 0; i < lSize; ++i) {
        message[i] = ((char *)buffer)[i];
    }


    free(buffer);
    if (ed25519_create_seed(seed)) {
        printf("error while generating seed\n");
        exit(1);
    }
    ed25519_create_keypair(public_key, private_key, seed);
    //printf("%.*s", bSize, public_key);
    FILE *key_file = fopen("/home/mulbric9/BA/ed25519/src/key.txt", "w+");
    if (key_file == NULL)
    {
        printf("error opening file\n");
        exit(1);
    }
    for (i = 0; i < sizeof(public_key); i++) {
        fputc(public_key[i], key_file);
        // Failed to write do error code here.
    }

    fclose(key_file);
    /*for (i = 0; i < pSize; ++i){
        printf("%c", ((char *)public_key)[i]);
    }
    printf("/n%ld", pSize);

    */
    /*for (i = 0; i < lSize+1; ++i){
        printf("%c", ((char *)message)[i]);
    }*/
    //printf("%.*s", bSize, public_key);

    ed25519_sign(signature, message, lSize, public_key, private_key);
    FILE *sig_file = fopen("/home/mulbric9/BA/ed25519/src/signature.txt", "w+");
    if (sig_file == NULL)
    {
        printf("error opening file\n");
        exit(1);
    }
    for (i = 0; i < sizeof(signature); i++) {
        fputc(signature[i], sig_file);
        // Failed to write do error code here.
    }
    // Failed to write do error code here.

    fclose(sig_file);

    //printf("\nPUB:_%ld\n", sizeof(public_key));
    //printf("\nSIG: %ld\n", sizeof(signature));
    if (ed25519_verify(signature, message, lSize, public_key)) {
        printf("valid signature\n");
    } else {
        printf("invalid signature\n");
    }

    free(message);
    /*FILE *mesg_file = fopen("/home/mulbric9/BA/ed25519/src/message.txt", "w+");
    if (mesg_file == NULL)
    {
        printf("error opening file\n");
        exit(1);
    }
    fclose(msg_file);*/


    return 0;
}

