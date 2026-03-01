FROM ubuntu:24.04

ENV USER oqs
ENV DEBIAN_FRONTEND noninteractive
ENV CMAKE_INSTALL_PREFIX=/usr
ENV OPENSSL_MODULES=/usr/lib64/ossl-modules
ENV OPENSSL_VERSION=openssl-3.2.4
ENV OPENSSH_VERSION=OQS-v9
ENV LIBOQS_VERSION=0.15.0
ENV OQS_PROVIDER_VERSION=0.11.0
ENV LIBCURL_VERSION=curl-8_7_1

RUN apt-get update
RUN apt-get install -y software-properties-common

# Set timezone
ENV TZ "Europe/Berlin"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
RUN echo $TZ > /etc/timezone

# Required Packages for the Host Development System
RUN apt-get install -y \
    git build-essential cmake  \
    autoconf libtool libz-dev pkg-config \
    nano vim sudo strace nginx ca-certificates openvpn mosquitto-clients

# Build OpenSSL
RUN git clone -b $OPENSSL_VERSION https://github.com/openssl/openssl && \
    cd openssl && \
    ./Configure  --prefix=/usr --openssldir=/usr/lib/ssl && \
    make -j && \
    make install_sw && \
    echo "/usr/lib64" > /etc/ld.so.conf.d/openssl.conf && \
    ldconfig    

# Build liboqs
RUN git clone -b $LIBOQS_VERSION https://github.com/open-quantum-safe/liboqs.git && \
    cd liboqs && \
    cmake -DBUILD_SHARED_LIBS=ON -DOQS_USE_OPENSSL=ON -DCMAKE_INSTALL_PREFIX=/usr . && \
    make -j install

# Build oqs-provider
RUN git clone -b $OQS_PROVIDER_VERSION https://github.com/open-quantum-safe/oqs-provider.git && \
    cd oqs-provider && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr . && \
    make -j install

# Enable oqsprovider by default
COPY openssl-oqs.cnf /etc/ssl/openssl-oqs.cnf
RUN printf "\n# Enable oqs provider config\n.include /etc/ssl/openssl-oqs.cnf\n"  >> /etc/ssl/openssl.cnf

# Build OpenSSH
RUN git clone -b $OPENSSH_VERSION https://github.com/open-quantum-safe/openssh.git && \
    cd openssh && \
    INSTALL_PREFIX=/usr ./oqs-scripts/build_openssh.sh 

# Build libcurl
RUN git clone -b $LIBCURL_VERSION https://github.com/curl/curl.git && \
    cd curl && \
    autoreconf -fi && \
    ./configure --prefix=/usr --with-openssl --without-libpsl && \
    make -j install && \
    echo "/usr/lib" > /etc/ld.so.conf.d/libcurl.conf && \
    ldconfig


# Create a non-root user
RUN id $USER 2>/dev/null || useradd --create-home $USER
RUN echo "$USER ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

# Import Root Key/Certificate
ADD https://raw.githubusercontent.com/embetrix/meta-oqs/refs/heads/scarthgap/recipes-support/oqs-demos/files/ca-cert.pem \
    /usr/share/ca-certificates/ca-cert.pem
RUN echo "ca-cert.pem" >> /etc/ca-certificates.conf && \
    update-ca-certificates
RUN cp /usr/share/ca-certificates/ca-cert.pem /home/$USER/
ADD https://raw.githubusercontent.com/embetrix/meta-oqs/refs/heads/scarthgap/recipes-support/oqs-demos/files/ca-key.pem \
    /home/$USER/ca-key.pem

# Import PQC Root Key/Certificate
ADD https://raw.githubusercontent.com/embetrix/meta-oqs/refs/heads/scarthgap/recipes-support/oqs-demos/files/pqc-ca-cert.pem \
    /usr/share/ca-certificates/pqc-ca-cert.pem
RUN echo "pqc-ca-cert.pem" >> /etc/ca-certificates.conf && \
    update-ca-certificates
RUN cp /usr/share/ca-certificates/pqc-ca-cert.pem /home/$USER/
ADD https://raw.githubusercontent.com/embetrix/meta-oqs/refs/heads/scarthgap/recipes-support/oqs-demos/files/pqc-ca-key.pem \
    /home/$USER/pqc-ca-key.pem

# Generate client certificates
ADD gen-certs.sh /home/$USER/gen-certs.sh
RUN /bin/sh -c "cd /home/$USER && ./gen-certs.sh"

USER $USER
RUN sudo chown -R $USER:$USER /home/$USER

# Generate SSH keys (Classical and PQC)
RUN ssh-keygen -q -t rsa -N ''     -f /home/$USER/.ssh/id_rsa
RUN ssh-keygen -q -t ecdsa -N ''   -f /home/$USER/.ssh/id_ecdsa
RUN ssh-keygen -q -t mldsa-65 -N '' -f /home/$USER/.ssh/id_mldsa65

WORKDIR /home/$USER

CMD ["/bin/bash"]

