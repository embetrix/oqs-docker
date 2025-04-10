FROM ubuntu:24.04

ENV USER oqs
ENV DEBIAN_FRONTEND noninteractive
ENV CMAKE_INSTALL_PREFIX=/usr
ENV OPENSSL_MODULES=/usr/lib64/ossl-modules
ENV OPENSSL_VERSION=openssl-3.2.4
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
    autoconf libtool pkg-config \
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
    sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g"  /etc/ssl/openssl.cnf

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

USER $USER
RUN sudo chown -R $USER:$USER /home/$USER

WORKDIR /home/$USER

CMD ["/bin/bash"]

EXPOSE 4443:4443
