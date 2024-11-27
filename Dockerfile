FROM alpine
WORKDIR /home/optima
COPY ./funcA .
RUN apk add libstdc++
RUN apk add libc6-compat
ENTRYPOINT ["./funcA"]
