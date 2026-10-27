FROM apache/kafka:4.4.0@sha256:833b867a9585a141da455dc2b57431c65cbccb27f11c91f694444cca9f777e0f
USER root
# Patch the broker's bundled compression library and OS libraries without changing its configuration.
RUN apk add --no-cache 'brotli-libs=1.2.1-r0' 'libexpat=2.9.0-r0'
ADD --checksum=sha256:58c8e0b813960d2a248e050c353baea73139b48a2ffc55382d42c69707e17325 https://repo.maven.apache.org/maven2/at/yawk/lz4/lz4-java/1.11.4/lz4-java-1.11.4.jar /opt/kafka/libs/lz4-java-1.11.4.jar
RUN rm /opt/kafka/libs/lz4-java-1.11.2.jar && chmod 0644 /opt/kafka/libs/lz4-java-1.11.4.jar
USER appuser
