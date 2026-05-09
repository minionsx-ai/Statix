# syntax=docker/dockerfile:1.7

ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}

ARG TARGET=x86_64-linux-musl
ARG RUST_TARGET=x86_64-unknown-linux-musl
ARG UPX_VERSION=4.2.1
ARG BINUTILS_VERSION=2.33.1
ARG GCC_VERSION=15.1.0
ARG MUSL_CROSS_MAKE_REF=e5147dde912478dd32ad42a25003e82d4f5733aa
ARG MUSL_VERSION=1.2.5
ARG RUST_VERSION=1.95.0
ARG ZLIB_VERSION=1.3.2
ARG LIBFFI_VERSION=3.5.2
ARG NCURSES_VERSION=6.6
ARG OPENSSL_VERSION=3.5.6
ARG CURL_VERSION=8.7.1
ARG POSTGRESQL_VERSION=17.2
ARG CMAKE_REF=v4.3.2
ARG LLVM_REF=llvmorg-22.1.4
ARG MUSL_PREFIX=/opt/musl
ARG MUSL_BOOTSTRAP_PREFIX=/opt/musl-toolchain

LABEL org.opencontainers.image.title="Statix" \
      org.opencontainers.image.description="Docker build environment for Rust musl cross compilation with native static dependencies." \
      org.opencontainers.image.source="https://github.com/minionsx-ai/Statix" \
      org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bison \
    build-essential \
    ca-certificates \
    curl \
    file \
    flex \
    gawk \
    git \
    libgmp-dev \
    libisl-dev \
    libmpc-dev \
    libmpfr-dev \
    libssl-dev \
    ninja-build \
    pkg-config \
    python3 \
    texinfo \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp \
    && wget -q "https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-amd64_linux.tar.xz" \
    && tar -xJf "upx-${UPX_VERSION}-amd64_linux.tar.xz" \
    && cp "upx-${UPX_VERSION}-amd64_linux/upx" /usr/local/bin/ \
    && rm -rf "upx-${UPX_VERSION}-amd64_linux"*

WORKDIR /build

RUN git init musl-cross-make \
    && cd musl-cross-make \
    && git remote add origin https://github.com/richfelker/musl-cross-make.git \
    && git fetch --depth 1 origin "${MUSL_CROSS_MAKE_REF}" \
    && git checkout --detach FETCH_HEAD \
    && printf 'TARGET = %s\nOUTPUT = %s\nBINUTILS_VER = %s\nGCC_VER = %s\nMUSL_VER = %s\nCOMMON_CONFIG += --disable-nls\n' \
        "${TARGET}" \
        "${MUSL_BOOTSTRAP_PREFIX}" \
        "${BINUTILS_VERSION}" \
        "${GCC_VERSION}" \
        "${MUSL_VERSION}" > config.mak \
    && make -j"$(nproc)" \
    && make install \
    && make clean \
    && rm -f config.mak \
    && printf 'TARGET = %s\nOUTPUT = %s\nBINUTILS_VER = %s\nGCC_VER = %s\nMUSL_VER = %s\nCOMMON_CONFIG += CC="%s/bin/%s-gcc -static --static" CXX="%s/bin/%s-g++ -static --static"\nCOMMON_CONFIG += --disable-nls\nGCC_CONFIG += --enable-default-pie\n' \
        "${TARGET}" \
        "${MUSL_PREFIX}" \
        "${BINUTILS_VERSION}" \
        "${GCC_VERSION}" \
        "${MUSL_VERSION}" \
        "${MUSL_BOOTSTRAP_PREFIX}" \
        "${TARGET}" \
        "${MUSL_BOOTSTRAP_PREFIX}" \
        "${TARGET}" > config.mak \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf musl-cross-make "${MUSL_BOOTSTRAP_PREFIX}"

ENV PATH="/root/.cargo/bin:${MUSL_PREFIX}/bin:${MUSL_PREFIX}/${TARGET}/bin:${PATH}" \
    TARGET="${TARGET}" \
    RUST_TARGET="${RUST_TARGET}" \
    RUST_VERSION="${RUST_VERSION}" \
    SYSROOT="${MUSL_PREFIX}/${TARGET}" \
    CC="${MUSL_PREFIX}/bin/${TARGET}-gcc" \
    CXX="${MUSL_PREFIX}/bin/${TARGET}-g++" \
    LD="${MUSL_PREFIX}/bin/${TARGET}-ld" \
    AR="${MUSL_PREFIX}/bin/${TARGET}-ar" \
    RANLIB="${MUSL_PREFIX}/bin/${TARGET}-ranlib" \
    STRIP="${MUSL_PREFIX}/bin/${TARGET}-strip" \
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="${MUSL_PREFIX}/bin/${TARGET}-gcc" \
    PKG_CONFIG_ALLOW_CROSS=1 \
    PKG_CONFIG_PATH="${MUSL_PREFIX}/${TARGET}/lib/pkgconfig" \
    C_INCLUDE_PATH="${MUSL_PREFIX}/${TARGET}/include" \
    LIBRARY_PATH="${MUSL_PREFIX}/${TARGET}/lib" \
    OPENSSL_DIR="${MUSL_PREFIX}/${TARGET}" \
    OPENSSL_STATIC=1

ENV STATIX_RUST_TOOLCHAIN="${RUST_VERSION}-${RUST_TARGET}"

RUN case "${TARGET}" in \
        x86_64-linux-musl) ln -sf "${SYSROOT}/lib/libc.so" /lib/ld-musl-x86_64.so.1 ;; \
        *) echo "No default musl loader symlink configured for ${TARGET}" ;; \
    esac

RUN wget -q "https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz" \
    && tar -xzf "zlib-${ZLIB_VERSION}.tar.gz" \
    && cd "zlib-${ZLIB_VERSION}" \
    && CC="${CC}" CFLAGS="-fPIC" ./configure --prefix="${SYSROOT}" --static \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf "zlib-${ZLIB_VERSION}"*

RUN wget -q "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz" \
    && tar -xzf "libffi-${LIBFFI_VERSION}.tar.gz" \
    && cd "libffi-${LIBFFI_VERSION}" \
    && CC="${CC}" CFLAGS="-fPIC" ./configure \
        --build="$(gcc -dumpmachine)" \
        --host="${TARGET}" \
        --prefix="${SYSROOT}" \
        --disable-shared \
        --enable-static \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf "libffi-${LIBFFI_VERSION}"*

RUN wget -q "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz" \
    && tar -xzf "ncurses-${NCURSES_VERSION}.tar.gz" \
    && cd "ncurses-${NCURSES_VERSION}" \
    && ( \
        unset C_INCLUDE_PATH LIBRARY_PATH; \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${MUSL_PREFIX}/bin:${SYSROOT}/bin"; \
        export PATH; \
        CC="${CC}" CXX="${CXX}" CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
            --build="$(/usr/bin/gcc -dumpmachine)" \
            --host="${TARGET}" \
            --with-build-cc=/usr/bin/gcc \
            --with-build-cpp="/usr/bin/gcc -E" \
            --prefix="${SYSROOT}" \
            --disable-shared \
            --enable-static \
            --with-normal \
            --with-cxx-binding \
            --enable-widec \
        && make -j"$(nproc)" \
        && make install \
    ) \
    && cd .. \
    && rm -rf "ncurses-${NCURSES_VERSION}"*

RUN wget -q "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
    && tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz" \
    && cd "openssl-${OPENSSL_VERSION}" \
    && CC="${CC}" CXX="${CXX}" CFLAGS="-fPIC" ./Configure no-shared \
        --prefix="${SYSROOT}" \
        --openssldir="${SYSROOT}" \
        linux-x86_64 \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf "openssl-${OPENSSL_VERSION}"*

RUN wget -q "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" \
    && tar -xzf "curl-${CURL_VERSION}.tar.gz" \
    && cd "curl-${CURL_VERSION}" \
    && CC="${CC}" CFLAGS="-fPIC" ./configure \
        --build="$(gcc -dumpmachine)" \
        --host="${TARGET}" \
        --prefix="${SYSROOT}" \
        --disable-shared \
        --enable-static \
        --with-openssl="${SYSROOT}" \
        --without-brotli \
        --without-nghttp2 \
        --without-libidn2 \
        --without-libssh2 \
        --without-libpsl \
        --disable-ldap \
        --disable-ldaps \
        --disable-rtsp \
        --disable-dict \
        --disable-telnet \
        --disable-tftp \
        --disable-pop3 \
        --disable-imap \
        --disable-smtp \
        --disable-gopher \
        --disable-smb \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf "curl-${CURL_VERSION}"*

RUN wget -q "https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.gz" \
    && tar -xzf "postgresql-${POSTGRESQL_VERSION}.tar.gz" \
    && cd "postgresql-${POSTGRESQL_VERSION}" \
    && ( \
        unset C_INCLUDE_PATH LIBRARY_PATH; \
        PKG_CONFIG_PATH="${SYSROOT}/lib/pkgconfig" \
        PKG_CONFIG_ALLOW_CROSS=1 \
        CC="${CC}" \
        CFLAGS="-fPIC -I${SYSROOT}/include" \
        LDFLAGS="-L${SYSROOT}/lib" \
        ./configure \
            --build="$(gcc -dumpmachine)" \
            --host="${TARGET}" \
            --prefix="${SYSROOT}" \
            --disable-shared \
            --without-readline \
            --without-icu \
            --with-ssl=openssl \
            --without-ldap \
            --without-gssapi \
    ) \
    && sed -i '/^enable_shared/s/yes/no/' src/Makefile.global \
    && make -C src/include install \
    && make -C src/port install \
    && make -C src/common install \
    && make -C src/interfaces/libpq all-static-lib libpq.pc \
    && make -C src/interfaces/libpq install-lib-static install-lib-pc installdirs \
    && sed -i \
        -e 's/-lpgcommon\([[:space:]]\|$\)/-lpgcommon_shlib\1/g' \
        -e 's/-lpgport\([[:space:]]\|$\)/-lpgport_shlib\1/g' \
        "${SYSROOT}/lib/pkgconfig/libpq.pc" \
    && if ! grep -Eq '^Libs.private:.*-lcrypto' "${SYSROOT}/lib/pkgconfig/libpq.pc"; then \
        sed -i "/^Libs.private:/ s|$| -L${SYSROOT}/lib -L${SYSROOT}/lib64 -lssl -lcrypto|" "${SYSROOT}/lib/pkgconfig/libpq.pc"; \
    fi \
    && openssl_libdir="" \
    && for libdir in "${SYSROOT}/lib" "${SYSROOT}/lib64"; do \
        if [ -f "${libdir}/libssl.a" ] && [ -f "${libdir}/libcrypto.a" ]; then \
            openssl_libdir="${libdir}"; \
            break; \
        fi; \
    done \
    && test -n "${openssl_libdir}" \
    && mv "${SYSROOT}/lib/libpq.a" "${SYSROOT}/lib/libpq_base.a" \
    && printf 'CREATE %s/lib/libpq.a\nADDLIB %s/lib/libpq_base.a\nADDLIB %s/lib/libpgcommon_shlib.a\nADDLIB %s/lib/libpgport_shlib.a\nADDLIB %s/libssl.a\nADDLIB %s/libcrypto.a\nSAVE\nEND\n' \
        "${SYSROOT}" \
        "${SYSROOT}" \
        "${SYSROOT}" \
        "${SYSROOT}" \
        "${openssl_libdir}" \
        "${openssl_libdir}" > /tmp/libpq-static.mri \
    && "${AR}" -M < /tmp/libpq-static.mri \
    && "${RANLIB}" "${SYSROOT}/lib/libpq.a" \
    && rm -f /tmp/libpq-static.mri "${SYSROOT}/lib/libpq_base.a" \
    && install -m 644 src/interfaces/libpq/libpq-fe.h "${SYSROOT}/include/libpq-fe.h" \
    && install -m 644 src/interfaces/libpq/libpq-events.h "${SYSROOT}/include/libpq-events.h" \
    && install -m 644 src/interfaces/libpq/libpq-int.h "${SYSROOT}/include/postgresql/internal/libpq-int.h" \
    && install -m 644 src/interfaces/libpq/fe-auth-sasl.h "${SYSROOT}/include/postgresql/internal/fe-auth-sasl.h" \
    && install -m 644 src/interfaces/libpq/pqexpbuffer.h "${SYSROOT}/include/postgresql/internal/pqexpbuffer.h" \
    && install -m 644 src/interfaces/libpq/pg_service.conf.sample "${SYSROOT}/share/pg_service.conf.sample" \
    && cd .. \
    && rm -rf "postgresql-${POSTGRESQL_VERSION}"*

# pq-sys reads PQ_LIB_STATIC, while its pkg-config path reads LIBPQ_STATIC.
ENV PQ_LIB_STATIC=1 \
    LIBPQ_STATIC=1

RUN git clone --depth 1 --branch "${CMAKE_REF}" https://github.com/Kitware/CMake.git \
    && cd CMake \
    && ( \
        unset C_INCLUDE_PATH LIBRARY_PATH; \
        CC="${CC} -static" CXX="${CXX} -static" ./bootstrap \
            --prefix="${SYSROOT}" \
            --parallel="$(nproc)" \
            -- \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="${CC}" \
            -DCMAKE_CXX_COMPILER="${CXX}" \
            -DCMAKE_INCLUDE_PATH="${SYSROOT}/include" \
            -DCMAKE_LIBRARY_PATH="${SYSROOT}/lib" \
            -DCMAKE_EXE_LINKER_FLAGS="-static" \
            -DCMAKE_SHARED_LINKER_FLAGS="-static" \
            -DCMAKE_MODULE_LINKER_FLAGS="-static" \
            -DOPENSSL_ROOT_DIR="${SYSROOT}" \
        && make -j"$(nproc)" \
        && make install \
    ) \
    && cd .. \
    && rm -rf CMake

WORKDIR /root

# Keep the historical llvm-build path without retaining CMake/Ninja intermediates.
RUN git clone --depth 1 --branch "${LLVM_REF}" https://github.com/llvm/llvm-project.git \
    && cd llvm-project \
    && "${SYSROOT}/bin/cmake" -S llvm -B llvm-build -G Ninja \
        -DCMAKE_INSTALL_PREFIX="${MUSL_PREFIX}/llvm-build" \
        -DLLVM_ENABLE_PROJECTS=clang \
        -DLIBCLANG_BUILD_STATIC=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_CXX_COMPILER="${CXX}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_EXE_LINKER_FLAGS="-static-pie" \
        -DLLVM_ENABLE_PIC=ON \
        -DLLVM_ENABLE_PIE=ON \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DCLANG_INCLUDE_TESTS=OFF \
        -DCLANG_DEFAULT_PIE_ON_LINUX=ON \
        -DLLVM_TARGETS_TO_BUILD="X86" \
    && ninja -C llvm-build install \
    && cd .. \
    && rm -rf llvm-project

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain none \
    && source "${HOME}/.cargo/env" \
    && rustup toolchain install "${STATIX_RUST_TOOLCHAIN}" --profile minimal --force-non-host \
    && rustup default "${STATIX_RUST_TOOLCHAIN}" --force-non-host \
    && rustup target add "${RUST_TARGET}"

ENV LLVM_CONFIG_PATH="${MUSL_PREFIX}/llvm-build/bin/llvm-config" \
    LIBCLANG_STATIC_PATH="${MUSL_PREFIX}/llvm-build/lib" \
    LIBCLANG_PATH="${MUSL_PREFIX}/llvm-build/lib" \
    LD_LIBRARY_PATH="${MUSL_PREFIX}/llvm-build/lib:${SYSROOT}/lib" \
    CMAKE="${SYSROOT}/bin/cmake"

WORKDIR /workspace

CMD ["/bin/bash"]
