FROM golang:1.27.3-alpine@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS privilege-tool
WORKDIR /src
ADD --checksum=sha256:207a2045e890d3ca3326027c5f585733085960b401a49dbc00e3bb628c054cf8 https://github.com/tianon/gosu/archive/refs/tags/1.20.tar.gz /tmp/gosu.tgz
# Rebuild unchanged upstream source: its published binary still embeds the vulnerable Go 1.24 library.
RUN tar -xzf /tmp/gosu.tgz --strip-components=1 --directory=/src && CGO_ENABLED=0 go build -trimpath -buildvcs=false -o /gosu .

FROM mongo:8.0@sha256:8e7d23aa641b0ec6c86418866d5d18d74d5abf89061bc5db7bc4b80929021ef6
# Dependency hardening: keep MongoDB 8.0 and its entrypoint while updating bundled helper tools.
COPY --from=privilege-tool --chmod=0755 /gosu /usr/local/bin/gosu
ADD --checksum=sha256:7f005cf0b8ee639b4557e0e321dc067c1f2aa0a442d096e03f2ab53353738794 https://registry.npmjs.org/js-yaml/-/js-yaml-3.15.2.tgz /tmp/js-yaml.tgz
RUN tar -xzf /tmp/js-yaml.tgz --strip-components=1 --directory=/opt/js-yaml && rm /tmp/js-yaml.tgz
