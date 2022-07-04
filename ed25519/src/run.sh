#!/bin/sh
#./create_key /home/mulbric9/BA/ed25519/src/isegUpdate_20220519_system_iCSV2.9.3.zip
#./verify_file /home/mulbric9/BA/ed25519/src/isegUpdate_20220519_system_iCSV2.9.3.zip /home/mulbric9/BA/ed25519/src/key.txt /home/mulbric9/BA/ed25519/src/signature.txt

./create_key /home/mulbric9/BA/ed25519/src/test.txt
./verify_file /home/mulbric9/BA/ed25519/src/test.txt /home/mulbric9/BA/ed25519/src/key.txt /home/mulbric9/BA/ed25519/src/signature.txt

#echo "\nPUBKEY VORHER: \n";
#hexdump key.txt
#echo "\nPUBKEY NACHHER: \n";
#hexdump key_test.txt
#echo "\nSIG VORHER: \n";
#hexdump signature.txt
#echo "\nSIG NACHHER: \n";
#hexdump sig_test.txt

diff -s key.txt key_test.txt