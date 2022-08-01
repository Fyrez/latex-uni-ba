C:
- Cross Compiler für Arm installieren: https://developer-archives.toradex.com/getting-started/module-2-my-first-hello-world-in-c/configure-toolchain-colibri-imx6

! Wichtig ! . /usr/local/oecore-x86_64/environment-setup-armv7at2hf-neon-angstrom-linux-gnueabi
In jeder neuen Terminal Session muss das environment setup mit dem gezeigten Befehl ausgeführt werden,
damit cross compiling möglich ist.

Makefile --
	make create_key      => Programm zur Schlüsselerstellung und Signierung
	make verify_file 	 => Programm zum Verifizieren
	make verify_file_arm => Programm zum Verifizieren auf iCSmini2 (ARM Cortex-A9)

--> die 3 Varianten finden sich zur Not im Ordner C/vorgefertigt

Beispielausführung:
	./create_key ZU_SIGNIERENDE_DATEI SIGNATUR_DATEI
	-- Die Signaturdatei muss nicht vorher existieren
	Bsp.: ./create_key iseg_update.zip signature.sig

	./verify_file ZU_VERIFIZIERENDE_DATEI SIGNATUR_DATEI
	-- Für die ARM Variante gelten diesselben Parameter
	Bsp.: ./verify_file iseg_update.zip signature.sig

GPG:
- Ed25519 Schlüsselpaar erstellen --- 
	gpg --full-gen-key --expert -> (10) ECC (sign only) -> Curve 25519
- Public-Key auf dem Zielgerät als trusted Schlüssel einrichten

Beispielausführung:

	gpg --sign ZU_SIGNIERENDE_DATEI
	-- erstellt .gpg-Datei
	Bsp.: gpg --sign iseg_update.zip --> iseg_update.zip.gpg
	
	gpg --detach-sign
	-- erstellt unabhängige .sig-Datei
	Bsp.: gpg --detach-sign iseg_update.zip --> iseg_update.zip.sig
	
	gpg --verify .gpg-Datei
	-- verifiziert .gpg-Datei ; soll entschlüsselt werden, so muss --output flag gegeben werden
	Bsp.: gpg --verify iseg_update.zip.gpg

	gpg --verify .sig-Datei ZU_VERIFIZIERENDE_DATEI
	-- verifiziert ZU_VERIFIZIERENDE_DATEI mit .sig-Datei
	Bsp.: gpg --verify iseg_update.zip.sig iseg_update.zip

icsupdate.sh:

Beispielausführung:

.gpg-Datei: ./icsupdate.sh -f iseg_update.zip.gpg
.sig-Datei: ./icsupdate.sh -f iseg_update.zip -S iseg_update.zip.sig
C 		  : ./icsupdate.sh -f iseg_update.zip -C signature.sig
