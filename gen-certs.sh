#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix - https://www.embetrix.com
# Author: ayoub.zaki@embetrix.com
#
# Generate PQC and classical (RSA) device certificates

openssl req -new -newkey mldsa65 -keyout pqc-device-client-key.pem \
        -out pqc-device-client-csr.pem -nodes \
        -subj "/C=DE/ST=BW/O=Embetrix/OU=PQC-ClientCert/CN=client" \
        -addext "subjectAltName=DNS:client" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=clientAuth" || exit 1

openssl x509 -req -in pqc-device-client-csr.pem -CA pqc-ca-cert.pem -CAkey pqc-ca-key.pem \
        -CAcreateserial -days 3600 \
        -out pqc-device-client-cert.pem \
        -copy_extensions copy  || exit 1


openssl req -new -newkey rsa:4096 -keyout rsa-device-client-key.pem \
        -out rsa-device-client-csr.pem -nodes \
        -subj "/C=DE/ST=BW/O=Embetrix/OU=DeviceCert/CN=client" \
        -addext "subjectAltName=DNS:client" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=clientAuth" || exit 1

openssl x509 -req -in rsa-device-client-csr.pem -CA ca-cert.pem -CAkey ca-key.pem \
        -CAcreateserial -days 3600 \
        -out rsa-device-client-cert.pem \
        -copy_extensions copy  || exit 1

