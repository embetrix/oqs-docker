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
