# Requires docker >= 17.05 (requires support for multi-stage builds)

FROM alpine:3.6 as cryptobox-builder

# compile cryptobox-c
RUN apk add --no-cache cargo libsodium-dev git && \
    cd /tmp && \
    git clone https://github.com/wireapp/cryptobox-c.git && \
    cd cryptobox-c && \
    cargo build --release

FROM alpine:3.6

# install cryptobox-c in the new container
COPY --from=cryptobox-builder /tmp/cryptobox-c/target/release/libcryptobox.so /usr/lib/libcryptobox.so
COPY --from=cryptobox-builder /tmp/cryptobox-c/src/cbox.h /usr/include/cbox.h

# development packages required for wire-server Haskell services
RUN apk add --no-cache \
        alpine-sdk \
        ca-certificates \
        linux-headers \
        zlib-dev \
        ghc \
        libsodium-dev \
        openssl-dev \
        protobuf \
        icu-dev \
        geoip-dev \
        snappy-dev \
        llvm-libunwind-dev \
        bash

# get static version of Haskell Stack and use system ghc by default
ARG STACK_VERSION=1.5.1
RUN curl -sSfL https://github.com/commercialhaskell/stack/releases/download/v${STACK_VERSION}/stack-${STACK_VERSION}-linux-x86_64-static.tar.gz \
    | tar --wildcards -C /usr/local/bin --strip-components=1 -xzvf - '*/stack' && chmod 755 /usr/local/bin/stack && \
    stack config set system-ghc --global true

# download stack indices and compile/cache dependencies to speed up subsequent container creation
# TODO: make this caching step optional?
RUN apk add --no-cache git && \
    mkdir -p /src && cd /src && \
    git clone https://github.com/wireapp/wire-server.git && \
    cd wire-server && \
    stack update && \
    cd services/brig && stack build --pedantic --test --dependencies-only && cd - && \
    cd services/galley && stack build --pedantic --test --dependencies-only && cd - && \
    cd services/cannon && stack build --pedantic --test --dependencies-only && cd - && \
    cd services/cargohold && stack build --pedantic --test --dependencies-only && cd - && \
    cd services/proxy && stack build --pedantic --test --dependencies-only && cd - && \
    cd services/gundeck && stack build --pedantic --test --dependencies-only && cd -
