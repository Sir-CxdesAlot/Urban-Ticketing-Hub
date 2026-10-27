FROM nginx:stable-alpine@sha256:47928bf67eb62a1863cb08d9ecb52d3e704304ba614eaee17884204677702951
RUN apk add --no-cache 'brotli-libs=1.2.1-r0' 'curl=8.23.0-r0' 'libcurl=8.23.0-r0'
