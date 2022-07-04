#include "ed25519.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char** argv) {

	long lSize;
	char *buffer;
	int i;
	FILE *key_file = fopen ( argv[2] , "rb" );
	if ( !key_file ) perror(argv[2]), exit(1);

	fseek( key_file , 0L , SEEK_END);
	lSize = ftell( key_file );
	rewind( key_file );

	/* allocate memory for entire content */
	buffer = calloc( 1, lSize + 1 );
	if ( !buffer ) fclose(key_file), fputs("memory alloc fails", stderr), exit(1);

	/* copy the file into the buffer */
	if ( 1 != fread( buffer , lSize, 1 , key_file) )
		fclose(key_file), free(buffer), fputs("entire read fails", stderr), exit(1);
	fclose(key_file);

	unsigned char public_key[32];
	//strcpy (public_key, buffer);
	for (i = 0; i < lSize + 1; ++i) {
		public_key[i] = ((char *)buffer)[i];
	}
	/* do your work here, buffer is a string contains the whole text */
	free(buffer);
	FILE *key_test_file = fopen("/home/mulbric9/BA/ed25519/src/key_test.txt", "w+");
	if (key_test_file == NULL)
	{
		printf("error opening file\n");
		exit(1);
	}
	for (i = 0; i < sizeof(public_key); i++) {
		fputc(public_key[i], key_test_file);
		// Failed to write do error code here.
	}
	fclose(key_test_file);


	FILE *sig_file = fopen ( argv[3] , "rb" );
	if ( !sig_file ) perror(argv[3]), exit(1);

	fseek( sig_file , 0L , SEEK_END);
	lSize = ftell( sig_file );
	rewind( sig_file );

	/* allocate memory for entire content */
	buffer = calloc( 1, lSize + 1 );
	if ( !buffer ) fclose(sig_file), fputs("memory alloc fails", stderr), exit(1);

	/* copy the file into the buffer */
	if ( 1 != fread( buffer , lSize, 1 , sig_file) )
		fclose(sig_file), free(buffer), fputs("entire read fails", stderr), exit(1);
	fclose(sig_file);

	unsigned char signature[64];
	//strcpy (signature, buffer);
	for (i = 0; i < lSize + 1; ++i) {
		signature[i] = ((char *)buffer)[i];
	}
	/* do your work here, buffer is a string contains the whole text */
	free(buffer);
	FILE *sig_test_file = fopen("/home/mulbric9/BA/ed25519/src/sig_test.txt", "w+");
	if (sig_test_file == NULL)
	{
		printf("error opening file\n");
		exit(1);
	}
	for (i = 0; i < sizeof(signature); i++) {
		fputc(signature[i], sig_test_file);
		// Failed to write do error code here.
	}
	fclose(sig_test_file);

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

	unsigned char *message = malloc(lSize + 1 );
	for (i = 0; i < lSize; ++i) {
		message[i] = ((char *)buffer)[i];
	}

	//printf("%.*s\n", 32, public_key);
	//printf("%.*s", 64, signature);
	if (ed25519_verify(signature, message, lSize, public_key)) {
		printf("valid signature\n");
	} else {
		printf("invalid signature\n");
	}

	/*FILE *test_file = fopen("/home/mulbric9/BA/ed25519/src/message.txt", "w+");
	if (test_file == NULL)
	{
	    printf("error opening file\n");
	    exit(1);
	}
	for (i = 0; i < lSize; ++i){
	fprintf(test_file, "%c", ((char *)message)[i]);
	}
	fclose(test_file);
	*/
	//printf("public_key: %s\n", public_key);
	//printf("signature: %s\n", signature);

	/* do your work here, buffer is a string contains the whole text */
	free(message);


	return 0;
}