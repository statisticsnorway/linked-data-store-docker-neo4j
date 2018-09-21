FROM alpine:latest as build

RUN apk --no-cache add maven curl tar gzip

#
# Install JDK
#
# Using the official JDK link does not work with docker cloud build (fails with socket close during download),
# hence we get the jdk from a private repository.
# Other users of this file are encouraged to replace the jdk link below with the official link:
#   https://download.java.net/java/early_access/alpine/28/binaries/openjdk-11+28_linux-x64-musl_bin.tar.gz
ADD "https://storage.googleapis.com/ssb-jdk-mirror/openjdk-11%2B28_linux-x64-musl_bin.tar.gz" /jdk.tar.gz
RUN mkdir -p /opt/jdk
RUN tar xzf /jdk.tar.gz --strip-components=1 -C /opt/jdk
ENV PATH=/opt/jdk/bin:$PATH
ENV JAVA_HOME=/opt/jdk

#
# Build LDS Server
#
RUN ["jlink", "--strip-debug", "--no-header-files", "--no-man-pages", "--compress=2", "--module-path", "/opt/jdk/jmods", "--output", "/linked",\
 "--add-modules", "jdk.unsupported,java.base,java.management,java.net.http,java.xml,java.naming"]
COPY pom.xml /lds/
WORKDIR /lds
RUN mvn verify dependency:go-offline
COPY src /lds/src/
RUN mvn -o verify && mvn -o dependency:copy-dependencies

#
# Build LDS image
#
FROM alpine:latest

#
# Resources from build image
#
COPY --from=build /linked /opt/jdk/
COPY --from=build /lds/target/dependency /opt/lds/lib/
COPY --from=build /lds/target/linked-data-store-*.jar /opt/lds/server/
RUN touch /opt/lds/saga.log

ENV PATH=/opt/jdk/bin:$PATH

WORKDIR /opt/lds

VOLUME ["/conf", "/schemas"]

EXPOSE 9090

CMD ["java", "-cp", "/opt/lds/server/*:/opt/lds/lib/*", "no.ssb.lds.server.Server"]
