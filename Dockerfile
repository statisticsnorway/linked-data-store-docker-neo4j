FROM azul/zulu-openjdk-alpine:11 as packager

RUN { \
        java --version ; \
        echo "jlink version:" && \
        jlink --version ; \
    }

ENV JAVA_MINIMAL=/opt/jre

# build modules distribution
RUN jlink \
    --verbose \
    --add-modules \
         java.base,java.desktop,java.management,jdk.unsupported,java.xml,java.net.http,java.naming \
        # java.base,java.sql,java.naming,java.desktop,java.management,java.security.jgss,java.instrument \
        # java.naming - javax/naming/NamingException
        # java.desktop - java/beans/PropertyEditorSupport
        # java.management - javax/management/MBeanServer
        # java.security.jgss - org/ietf/jgss/GSSException
        # java.instrument - java/lang/instrument/IllegalClassFormatException

    --compress 2 \
    --strip-debug \
    --no-header-files \
    --no-man-pages \
    --output "$JAVA_MINIMAL"

RUN apk --no-cache add maven

# Build lds
WORKDIR /lds/server

COPY pom.xml /lds/server/
RUN mvn -Pdrone -B verify dependency:go-offline

COPY src /lds/server/src/
RUN mvn -B -o verify && mvn -B -o dependency:copy-dependencies

# Second stage, add only our minimal "JRE" distr and our app
FROM alpine

ENV JAVA_MINIMAL=/opt/jre
ENV PATH="$PATH:$JAVA_MINIMAL/bin"

COPY --from=packager "$JAVA_MINIMAL" "$JAVA_MINIMAL"

# Copy lds jars and dependencies
COPY --from=packager /lds/server/target/dependency /opt/lds/lib/
COPY --from=packager /lds/server/target/linked-data-store-*.jar /opt/lds/server/
RUN touch /opt/lds/saga.log

WORKDIR /opt/lds
VOLUME ["/conf", "/schemas"]
EXPOSE 9090
CMD ["-cp", "/opt/lds/server/*:/opt/lds/lib/*", "no.ssb.lds.server.Server"]
ENTRYPOINT [ "java" ]