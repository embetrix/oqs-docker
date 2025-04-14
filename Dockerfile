FROM ubuntu:24.04

ENV USER oqs
ENV DEBIAN_FRONTEND noninteractive
ENV CMAKE_INSTALL_PREFIX=/usr
ENV OPENSSL_MODULES=/usr/lib64/ossl-modules
ENV OPENSSL_VERSION=openssl-3.2.4
ENV OPENSSH_VERSION=OQS-OpenSSH-snapshot-2024-08
ENV LIBOQS_VERSION=0.12.0
ENV OQS_PROVIDER_VERSION=0.8.0
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
    nano vim sudo strace nginx

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
RUN sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g"          /etc/ssl/openssl.cnf  && \
    sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g"  /etc/ssl/openssl.cnf  && \
    # Selecting TLS1.3 default groups (Hybrid and Pure PQC)
    sed -i "s/providers = provider_sect/providers = provider_sect\nssl_conf = ssl_sect\n\n\[ssl_sect\]\nsystem_default = system_default_sect\n\n\[system_default_sect\]\nGroups = \$ENV\:\:DEFAULT_GROUPS\n/g" /etc/ssl/openssl.cnf  && \
    sed -i "s/HOME\t\t\t= ./HOME           = .\nDEFAULT_GROUPS = X25519MLKEM768:mlkem768/g" /etc/ssl/openssl.cnf

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

# Import PQC Root Certificate
COPY ca-cert.pem /usr/share/ca-certificates/ca-cert.pem
RUN echo "ca-cert.pem" >> /etc/ca-certificates.conf && \
    update-ca-certificates

# Import PQC Root Certificate
COPY pqc-ca-cert.pem /usr/share/ca-certificates/pqc-ca-cert.pem
RUN echo "pqc-ca-cert.pem" >> /etc/ca-certificates.conf && \
    update-ca-certificates

# Create a non-root user
RUN id $USER 2>/dev/null || useradd --create-home $USER
RUN echo "$USER ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

USER $USER
RUN sudo chown -R $USER:$USER /home/$USER

# Generate SSH keys (Calssical and PQC)
RUN ssh-keygen -q -t rsa -N '' -f /home/$USER/.ssh/id_rsa
RUN ssh-keygen -q -t ecdsa -N '' -f /home/$USER/.ssh/id_ecdsa
RUN ssh-keygen -q -t falcon512 -N '' -f /home/$USER/.ssh/id_falcon512
RUN ssh-keygen -q -t falcon1024 -N '' -f /home/$USER/.ssh/id_falcon1024
RUN ssh-keygen -q -t sphincssha2128fsimple -N '' -f /home/$USER/.ssh/id_sphincssha2128fsimple

WORKDIR /home/$USER

CMD ["/bin/bash"]

EXPOSE 4443:4443
