FROM alpine:latest AS build

RUN apk add --no-cache build-base automake autoconf

WORKDIR /home/optima
COPY . .

RUN autoreconf --install && \
    ./configure && \
    make

FROM alpine:latest

RUN apk add --no-cache libstdc++ libgcc

COPY --from=build /home/optima/funcA /usr/local/bin/funcA

ENTRYPOINT ["/usr/local/bin/funcA"]
