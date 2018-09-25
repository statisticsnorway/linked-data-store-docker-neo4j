FROM statisticsnorway/lds-server-base:latest as build

#
# Build LDS Server
#
RUN ["jlink", "--strip-debug", "--no-header-files", "--no-man-pages", "--compress=2", "--module-path", "/opt/jdk/jmods", "--output", "/linked",\
 "--add-modules", "jdk.unsupported,java.base,java.management,java.net.http,java.xml,java.naming"]
COPY pom.xml /lds/server/
WORKDIR /lds
RUN cat server/pom.xml | /clone_snapshots.sh && for i in $(ls -d */ | cut -f1 -d'/'); do cd $i; mvn -B install; cd ..; done
WORKDIR /lds/server
RUN mvn -B verify dependency:go-offline
COPY src /lds/server/src/
RUN mvn -B -o verify && mvn -B -o dependency:copy-dependencies

#
# Build LDS image
#
FROM alpine:latest

#
# Resources from build image
#
COPY --from=build /linked /opt/jdk/
COPY --from=build /lds/server/target/dependency /opt/lds/lib/
COPY --from=build /lds/server/target/linked-data-store-*.jar /opt/lds/server/
RUN touch /opt/lds/saga.log

ENV PATH=/opt/jdk/bin:$PATH

WORKDIR /opt/lds

VOLUME ["/conf", "/schemas"]

EXPOSE 9090

CMD ["java", "-cp", "/opt/lds/server/*:/opt/lds/lib/*", "no.ssb.lds.server.Server"]
