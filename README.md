# oqs-docker

Docker image using Ubuntu Noble and includes all necessary dependencies to work with OpenSSL and OQS post-quantum cryptography library.

For more information about OQS, visit the [Open Quantum Safe website](https://openquantumsafe.org).


## Docker Setup

### Build Image

```
docker build --rm=true --tag oqs-docker .
```

### Run Docker Image

```
docker run --rm -ti oqs-docker
```

## Proof of Concept

Proof of Concept using PQC Certificates for TLS1.3 handshake and PQC Key exchange


### Generate PQC Root CA

```
openssl req -x509 -new -newkey dilithium3 -keyout pqc-ca-key.pem -nodes \
            -subj "/O=Embetrix Root CA PQC" \
            -days 3650  -out pqc-ca-cert.pem
```

### Generate PQC Server certificate 

```
openssl req -new -newkey dilithium3 -keyout pqc-server-key.pem \
        -out pqc-server-csr.pem -nodes \
        -subj "/C=DE/ST=BW/O=Embetrix/CN=localhost" \
        -addext "subjectAltName=DNS:localhost, DNS:localhost,IP:127.0.0.1"

openssl x509 -req -in pqc-server-csr.pem -CA pqc-ca-cert.pem -CAkey pqc-ca-key.pem \
        -CAcreateserial -days 360 \
        -out pqc-server-cert.pem \
        -copy_extensions copy
```

### Inspect PQC certificates

```
openssl x509 -in pqc-ca-cert.pem -noout -text

openssl x509 -in pqc-server-cert.pem -noout -text
```

### Start OpenSSL TLS server

```
openssl s_server -cert pqc-server-cert.pem -key pqc-server-key.pem -CAfile pqc-ca-cert.pem \
                 -groups kyber768:kyber1024:frodo640shake -www -tls1_3 -accept 4443 &
```

### Connect to OpenSSL TLS server using openssl

```
echo "q" | openssl s_client -CAfile  pqc-ca-cert.pem \
                            -groups frodo640shake -showcerts -connect localhost:4443
```

### Connect to OpenSSL TLS server using curl

```
curl --cacert pqc-ca-cert.pem  --curves kyber768 https://localhost:4443
```
