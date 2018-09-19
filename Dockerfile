FROM alpine:latest as build

RUN apk --no-cache add maven curl tar gzip

#
# Install JDK
#
RUN curl https://download.java.net/java/early_access/alpine/28/binaries/openjdk-11+28_linux-x64-musl_bin.tar.gz -o jdk.tar.gz
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
COPY --from=build /lds/target/linked-data-store-neo4j-0.1-SNAPSHOT.jar /opt/lds/linked-data-store-neo4j-0.1-SNAPSHOT.jar
RUN touch /opt/lds/saga.log

ENV PATH=/opt/jdk/bin:$PATH

WORKDIR /opt/lds

VOLUME ["/conf", "/schemas"]

EXPOSE 9090

CMD ["java", "-cp", "linked-data-store-neo4j-0.1-SNAPSHOT.jar:lib/*", "no.ssb.lds.server.Server"]
