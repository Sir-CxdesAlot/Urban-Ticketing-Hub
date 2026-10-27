FROM maven:3.9.16-eclipse-temurin-21@sha256:99e61abcff91a9b1333463bd8451fb18495d6eba9250ac66a338b518f8278320 AS database
WORKDIR /src/database
COPY database/ .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package

FROM ballerina/ballerina:2201.14.1@sha256:da95f4c1f332ebaa9211d53379521ef4e84dc1b2e5810cbef02391ba3965bb49 AS build
USER root
WORKDIR /src
COPY --from=database /src/database/target/uth-database-1.0.0.jar database/target/uth-database-1.0.0.jar
COPY core/ core/
RUN --mount=type=cache,target=/root/.ballerina/repositories/central.ballerina.io,sharing=locked cd core && bal pack && bal push --repository local
ARG SERVICE
COPY ${SERVICE}_service/ service/
WORKDIR /src/service
RUN --mount=type=cache,target=/root/.ballerina/repositories/central.ballerina.io,sharing=locked bal build

FROM eclipse-temurin:25-jre-alpine@sha256:b7528962e65d43064d8a8b67ba175367896bc948363ea2d3fcd7f10d34e1f048
RUN apk add --no-cache 'brotli-libs=1.2.1-r0' && addgroup -S uth && adduser -S uth -G uth
WORKDIR /app
COPY --from=build --chown=uth:uth /src/service/target/bin/*.jar app.jar
COPY --from=build --chown=uth:uth /src/service/Dependencies.toml Dependencies.toml
COPY --from=build --chown=uth:uth /src/core/Dependencies.toml core-Dependencies.toml
USER uth
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=70", "-jar", "app.jar"]
