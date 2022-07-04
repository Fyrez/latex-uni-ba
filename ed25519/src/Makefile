test2: keypair.c seed.c sha512.c verify.c test2.c ge.c sc.c sign.c fe.c
	gcc add_scalar.c test2.c key_exchange.c seed.c sign.c verify.c fe.c ge.c keypair.c sc.c sha512.c -o test2
create_key: keypair.c seed.c sha512.c verify.c create_key.c ge.c sc.c sign.c fe.c
	gcc -g add_scalar.c create_key.c key_exchange.c seed.c sign.c verify.c fe.c ge.c keypair.c sc.c sha512.c -o create_key

verify_file: keypair.c seed.c sha512.c verify.c verify_file.c ge.c sc.c sign.c fe.c
	gcc add_scalar.c verify_file.c key_exchange.c seed.c sign.c verify.c fe.c ge.c keypair.c sc.c sha512.c -o verify_file
example: keypair.c seed.c sha512.c verify.c example.c ge.c sc.c sign.c fe.c
	gcc add_scalar.c example.c key_exchange.c seed.c sign.c verify.c fe.c ge.c keypair.c sc.c sha512.c -o example