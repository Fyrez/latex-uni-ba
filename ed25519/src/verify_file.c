#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
int main(int argc, char** argv) {

	// declare variables for later use
	// public key has to be 32-Byte writable char array
	// signature has to be 64-Byte writable char array
	long FILE_SIZE;
	char *BUFFER;
	unsigned char PUBLIC_KEY[32], SIGNATURE[64];

	// open public key, prepare and load it into a buffer
	FILE *PUBLIC_KEY_FILE = fopen ( argv[2] , "rb" );
	if ( !PUBLIC_KEY_FILE ) {
		perror(argv[2]), exit(1);
	}

	fseek( PUBLIC_KEY_FILE , 0L , SEEK_END);
	FILE_SIZE = ftell( PUBLIC_KEY_FILE );
	rewind( PUBLIC_KEY_FILE );

	BUFFER = calloc( 1, FILE_SIZE + 1 );
	if ( !BUFFER ) fclose(PUBLIC_KEY_FILE), fputs("memory alloc fails", stderr), exit(1);

	if ( 1 != fread( BUFFER , FILE_SIZE, 1 , PUBLIC_KEY_FILE) )
		fclose(PUBLIC_KEY_FILE), free(BUFFER), fputs("entire read fails", stderr), exit(1);
	fclose(PUBLIC_KEY_FILE);

	//write public key from buffer to char array
	for (int i = 0; i < sizeof(PUBLIC_KEY); ++i) {
		PUBLIC_KEY[i] = ((char *)BUFFER)[i];
	}
	free(BUFFER);

	// open signature, prepare and load it into a buffer
	FILE *SIGNATURE_FILE = fopen ( argv[3] , "rb" );
	if ( !SIGNATURE_FILE ) perror(argv[3]), exit(1);

	fseek( SIGNATURE_FILE , 0L , SEEK_END);
	FILE_SIZE = ftell( SIGNATURE_FILE );
	rewind( SIGNATURE_FILE );

	BUFFER = calloc( 1, FILE_SIZE + 1 );
	if ( !BUFFER ) fclose(SIGNATURE_FILE), fputs("memory alloc fails", stderr), exit(1);

	if ( 1 != fread( BUFFER , FILE_SIZE, 1 , SIGNATURE_FILE) )
		fclose(SIGNATURE_FILE), free(BUFFER), fputs("entire read fails", stderr), exit(1);
	fclose(SIGNATURE_FILE);

	// write signature from buffer to char array
	for (int i = 0; i < sizeof(SIGNATURE); ++i) {
		SIGNATURE[i] = ((char *)BUFFER)[i];
	}
	free(BUFFER);

	// open update file
	FILE *UPDATE_FILE = fopen ( argv[1], "rb" );
	if ( !UPDATE_FILE ) perror(argv[1]), exit(1);

	// check update file size for memory allocation
	fseek( UPDATE_FILE , 0L , SEEK_END);
	FILE_SIZE = ftell( UPDATE_FILE );
	rewind( UPDATE_FILE );

	// allocate memory
	BUFFER = calloc( 1, FILE_SIZE + 1 );
	if ( !BUFFER ) fclose(UPDATE_FILE), fputs("memory alloc fails", stderr), exit(1);

	// read file into buffer
	if ( 1 != fread( BUFFER , FILE_SIZE, 1 , UPDATE_FILE) )
		fclose(UPDATE_FILE), free(BUFFER), fputs("entire read fails", stderr), exit(1);
	fclose(UPDATE_FILE);

	// read update file (buffer) into char array for use in verification process
	unsigned char *message = malloc(FILE_SIZE + 1 );
	for (int i = 0; i < FILE_SIZE; ++i) {
		message[i] = ((char *)BUFFER)[i];
	}
	free(BUFFER);

	// verify integrity of update file
	if (ed25519_verify(SIGNATURE, message, FILE_SIZE, PUBLIC_KEY)) {
		printf("valid SIGNATURE\n");
	} else {
		printf("invalid SIGNATURE\n");
	}
	free(message);

	return 0;
}