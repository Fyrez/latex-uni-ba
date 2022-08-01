create_key: keypair.c seed.c sha512.c create_key.c ge.c sc.c sign.c fe.c
	gcc -O2  create_key.c seed.c sign.c fe.c ge.c keypair.c sc.c sha512.c -o create_key

verify_file:  sha512.c verify.c verify_file.c ge.c sc.c fe.c
	gcc -O2  verify_file.c verify.c fe.c ge.c  sc.c sha512.c -o verify_file

verify_file_arm: sha512.c verify.c verify_file.c ge.c sc.c sign.c fe.c
	arm-angstrom-linux-gnueabi-gcc -mfloat-abi=hard -mcpu=cortex-a9 --sysroot=/usr/local/oecore-x86_64/sysroots/armv7at2hf-neon-angstrom-linux-gnueabi -O2 verify_file.c sign.c verify.c fe.c ge.c sc.c sha512.c -o verify_file_arm