FROM alpine:3.7

RUN apk add --no-cache curl coreutils build-base linux-headers git cmake libcap

WORKDIR /tmp
ARG BOOST_VERSION
ENV BOOST_VERSION ${BOOST_VERSION}
ARG BOOST_CHECKSUM
ENV BOOST_CHECKSUM ${BOOST_CHECKSUM}
RUN curl -sSLO "https://dl.bintray.com/boostorg/release/$(echo ${BOOST_VERSION} | tr '_' '.')/source/boost_${BOOST_VERSION}.tar.bz2"
RUN echo "${BOOST_CHECKSUM} boost_${BOOST_VERSION}.tar.bz2" | sha256sum -c -
RUN tar -xjf boost_${BOOST_VERSION}.tar.bz2 && rm boost_${BOOST_VERSION}.tar.bz2

ENV BOOST_ROOT /tmp/boost_${BOOST_VERSION}
WORKDIR ${BOOST_ROOT}
RUN ./bootstrap.sh
RUN ./b2 -q -j $(nproc --all) \
  --with-atomic \
  --with-chrono \
  --with-date_time \
  --with-filesystem \
  --with-log \
  --with-program_options \
  --with-regex \
  --with-system \
  --with-thread \
  link=static \
  runtime-link=static

WORKDIR /tmp
RUN git clone https://github.com/clemahieu/raiblocks.git

WORKDIR /tmp/raiblocks
RUN git submodule update --init
RUN cmake -DBOOST_ROOT=${BOOST_ROOT} .
RUN make -j $(nproc --all)
RUN mv rai_node /usr/local/bin
RUN setcap cap_net_bind_service=+ep /usr/local/bin/rai_node

FROM alpine:3.7

RUN apk add --no-cache dumb-init
RUN addgroup -S node
RUN adduser -S -h /data -G node node
RUN chown node:node /data
WORKDIR /data

COPY --chown=node:node config.json .
COPY --from=0 /usr/local/bin/rai_node /usr/local/bin

USER node
EXPOSE 7075 7075/udp 7076
ENTRYPOINT ["dumb-init", "--"]
CMD ["rai_node", "--daemon", "--data_path", "/data"]
