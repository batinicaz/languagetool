FROM eclipse-temurin:21.0.11_10-jdk-alpine@sha256:4fb80de7aeb277ad949cfbe89b4f504e50bb34c57fd908c5825236473d71e986 AS builder

ARG LT_VERSION=6.8
ARG MAVEN_VERSION=3.9.14
# renovate: datasource=maven depName=ch.qos.logback:logback-classic
ARG LOGBACK_VERSION=1.5.25
# renovate: datasource=maven depName=org.apache.opennlp:opennlp-tools
ARG OPENNLP_VERSION=2.5.9
RUN apk add --no-cache curl git patch xmlstarlet

RUN wget -q "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -O /tmp/maven.tar.gz \
    && tar xzf /tmp/maven.tar.gz -C /opt \
    && rm /tmp/maven.tar.gz

ENV PATH="/opt/apache-maven-${MAVEN_VERSION}/bin:${PATH}"

WORKDIR /build
RUN git clone --depth 1 --branch v${LT_VERSION} https://github.com/languagetool-org/languagetool.git .

# Re-enable confusion pairs disabled in v6.4 for premium differentiation (there/their, etc.)
# The aids/aides pair is excluded as it would false-positive on "AIDS" (case-insensitive matching)
RUN sed -i -e 's/^#\([a-z]\)/\1/' -e 's/^aids;aides/#&/' \
    languagetool-language-modules/en/src/main/resources/org/languagetool/resource/en/confusion_sets.txt

# v6.8 ships logback 1.5.21 which has known CVEs
RUN xml edit --inplace --update "//*[name()='ch.qos.logback.version']" --value "${LOGBACK_VERSION}" pom.xml

# v6.8 ships opennlp-tools 1.9.4 which has GHSA-cx4m-2p55-rw7j and GHSA-4v8g-86x5-3vrc (Critical)
RUN xml edit --inplace --update "//*[name()='org.apache.opennlp.opennlp-tools.version']" --value "${OPENNLP_VERSION}" pom.xml

RUN mvn --no-transfer-progress -B package -DskipTests \
    --projects languagetool-standalone --also-make

# v6.8 ships Netty 4.1.x with multiple DoS CVEs (GHSA-x4gw-5cx5-pgmh, GHSA-cm33-6792-r9fm, etc.)
# renovate: datasource=maven depName=io.netty:netty-handler
ARG NETTY_VERSION=4.2.15.Final
RUN cd languagetool-standalone/target/LanguageTool-*/LanguageTool-*/libs \
    && rm -f netty-*.jar \
    && for module in netty-buffer netty-codec netty-codec-dns netty-common netty-handler \
       netty-resolver netty-resolver-dns netty-transport netty-transport-native-unix-common; do \
      wget -q "https://repo1.maven.org/maven2/io/netty/${module}/${NETTY_VERSION}/${module}-${NETTY_VERSION}.jar"; \
    done

# v6.7 ships jackson-core 2.18.0 which has GHSA-72hv-8253-57qq (DoS via async parser) - remove when v6.8 lands
ARG JACKSON_VERSION=2.18.6
RUN cd languagetool-standalone/target/LanguageTool-*/LanguageTool-*/libs \
    && rm -f jackson-core.jar jackson-core-*.jar \
    && wget -q "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/${JACKSON_VERSION}/jackson-core-${JACKSON_VERSION}.jar" \
       -O jackson-core.jar

RUN mkdir -p /opt/fasttext \
    && wget -q "https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin" -O /opt/fasttext/lid.176.bin

FROM eclipse-temurin:21.0.11_10-jre-alpine@sha256:704db3c40204a44f471191446ddd9cda5d60dab40f0e15c6507b815ed897238b AS runtime

RUN apk upgrade --no-cache \
    && apk add --no-cache fasttext \
    && addgroup -g 783 -S languagetool \
    && adduser -u 783 -S -G languagetool -h /opt/languagetool languagetool \
    && mkdir -p /ngrams /tmp \
    && chown 783:783 /ngrams /tmp

COPY --from=builder --chown=783:783 /opt/fasttext/lid.176.bin /opt/languagetool/fasttext/lid.176.bin
COPY --from=builder --chown=783:783 /build/languagetool-standalone/target/LanguageTool-*/LanguageTool-*/ /opt/languagetool/
COPY --chown=783:783 entrypoint.sh /opt/languagetool/entrypoint.sh

USER 783:783
WORKDIR /opt/languagetool
EXPOSE 8010

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:${LISTEN_PORT:-8010}/v2/languages || exit 1

ENTRYPOINT ["/bin/sh", "/opt/languagetool/entrypoint.sh"]
