#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
int main(int argc, char** argv) {

	// public key has to be 32-Byte writable char array
	// signature has to be 64-Byte writable char array
	
	long FILE_SIZE;
	char *BUFFER;
	unsigned char PUBLIC_KEY[32], SIGNATURE[64];


	// load public key and signature

	FILE *SIGNATURE_FILE = fopen ( argv[2] , "rb" );
	if ( !SIGNATURE_FILE ) {
		perror(argv[2]), exit(1);
	}

	fseek( SIGNATURE_FILE , 0L , SEEK_END);
	FILE_SIZE = ftell( SIGNATURE_FILE );

	// "SIGNATURE_FILE" has to be 96 Bytes ((public_key)32+64(signature))
	if (FILE_SIZE != sizeof(PUBLIC_KEY)+sizeof(SIGNATURE)) fclose(SIGNATURE_FILE), fputs("incompatible signature type\n", stderr), exit(1); 
	
	rewind( SIGNATURE_FILE );

	BUFFER = calloc( 1, FILE_SIZE + 1 );
	if ( !BUFFER ) fclose(SIGNATURE_FILE), fputs("memory alloc fails", stderr), exit(1);

	if ( 1 != fread( BUFFER , FILE_SIZE, 1 , SIGNATURE_FILE) )
		fclose(SIGNATURE_FILE), free(BUFFER), fputs("entire read fails", stderr), exit(1);
	fclose(SIGNATURE_FILE);

	// write public key and signature to respective variables

	for (int i = 0; i < FILE_SIZE; ++i) {
		if ( i < sizeof(PUBLIC_KEY)) {
			PUBLIC_KEY[i] = ((char *)BUFFER)[i];
		}
		else 
			SIGNATURE[i-sizeof(PUBLIC_KEY)] = ((char *)BUFFER)[i];
	}

	free(BUFFER);

	// load update file

	FILE *UPDATE_FILE = fopen ( argv[1], "rb" );
	if ( !UPDATE_FILE ) perror(argv[1]), exit(1);

	fseek( UPDATE_FILE , 0L , SEEK_END);
	FILE_SIZE = ftell( UPDATE_FILE );
	rewind( UPDATE_FILE );

	BUFFER = calloc( 1, FILE_SIZE + 1 );
	if ( !BUFFER ) fclose(UPDATE_FILE), fputs("memory alloc for reading in the update file failed", stderr), exit(1);

	if ( 1 != fread( BUFFER , FILE_SIZE, 1 , UPDATE_FILE) )
		fclose(UPDATE_FILE), free(BUFFER), fputs("reading of update file failed", stderr), exit(1);
	fclose(UPDATE_FILE);

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

	// verify integrity of update file

	if (ed25519_verify(SIGNATURE, message, FILE_SIZE, PUBLIC_KEY)) {
		printf("\nvalid signature\n");
		return 0;
	} else {
		printf("\ninvalid signature\n");
		return 1;
	}
	free(message);


}