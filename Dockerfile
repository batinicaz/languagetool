FROM eclipse-temurin:21-jdk-alpine@sha256:c98f0d2e171c898bf896dc4166815d28a56d428e218190a1f35cdc7d82efd61f AS builder

ARG LT_VERSION=6.7
ARG MAVEN_VERSION=3.9.12
ARG LOGBACK_VERSION=1.5.25
RUN apk add --no-cache curl git patch xmlstarlet

RUN wget -q "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -O /tmp/maven.tar.gz \
    && tar xzf /tmp/maven.tar.gz -C /opt \
    && rm /tmp/maven.tar.gz

ENV PATH="/opt/apache-maven-${MAVEN_VERSION}/bin:${PATH}"

WORKDIR /build
RUN git clone --depth 1 --branch v${LT_VERSION} https://github.com/languagetool-org/languagetool.git .

# Fix unbounded memory growth in Hunspell dictionary loading (languagetool-org/languagetool#11380)
# Merged to master via PR #11692 but not yet included in a release - remove when v6.8 lands
RUN --mount=type=secret,id=github_token,required=false \
    curl -fsSL \
    $(test -f /run/secrets/github_token && echo "-H \"Authorization: Bearer $(cat /run/secrets/github_token)\"") \
    "https://github.com/languagetool-org/languagetool/commit/0045f6f6f0935a04a2c79d71bc0019f455b65c9b.patch" \
    | git apply

# v6.7 ships logback 1.5.21 which has known CVEs - remove when v6.8 lands
RUN xml edit --inplace --update "//*[name()='ch.qos.logback.version']" --value "${LOGBACK_VERSION}" pom.xml

RUN mvn --no-transfer-progress -B package -DskipTests \
    --projects languagetool-standalone --also-make

# v6.7 ships Netty 4.1.118 which has CVE-2025-58057 (DoS via BrotliDecoder) - remove when v6.8 lands
ARG NETTY_VERSION=4.1.127.Final
RUN cd languagetool-standalone/target/LanguageTool-*/LanguageTool-*/libs \
    && rm -f netty-*.jar \
    && for module in netty-buffer netty-codec netty-codec-dns netty-common netty-handler \
       netty-resolver netty-resolver-dns netty-transport netty-transport-native-unix-common; do \
      wget -q "https://repo1.maven.org/maven2/io/netty/${module}/${NETTY_VERSION}/${module}-${NETTY_VERSION}.jar"; \
    done

RUN DEPS=$(jdeps --ignore-missing-deps --print-module-deps --multi-release 21 \
    --recursive \
    --class-path="languagetool-standalone/target/LanguageTool-*/LanguageTool-*/libs/*" \
    --module-path="languagetool-standalone/target/LanguageTool-*/LanguageTool-*/libs/*" \
    languagetool-standalone/target/LanguageTool-*/LanguageTool-*/languagetool-server.jar 2>/dev/null || echo "java.base") \
    && jlink --add-modules "${DEPS},jdk.crypto.ec,jdk.localedata" \
    --strip-debug --no-man-pages --no-header-files \
    --compress=zip-6 --output /opt/jre

RUN mkdir -p /opt/fasttext \
    && wget -q "https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin" -O /opt/fasttext/lid.176.bin

FROM alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

RUN apk add --no-cache libstdc++ fasttext \
    && addgroup -g 783 -S languagetool \
    && adduser -u 783 -S -G languagetool -h /opt/languagetool languagetool \
    && mkdir -p /ngrams /tmp \
    && chown 783:783 /ngrams /tmp

COPY --from=builder --chown=783:783 /opt/jre /opt/jre
COPY --from=builder --chown=783:783 /opt/fasttext/lid.176.bin /opt/languagetool/fasttext/lid.176.bin
COPY --from=builder --chown=783:783 /build/languagetool-standalone/target/LanguageTool-*/LanguageTool-*/ /opt/languagetool/
COPY --chown=783:783 entrypoint.sh /opt/languagetool/entrypoint.sh

ENV JAVA_HOME=/opt/jre
ENV PATH="/opt/jre/bin:${PATH}"

USER 783:783
WORKDIR /opt/languagetool
EXPOSE 8010

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:${LISTEN_PORT:-8010}/v2/languages || exit 1

ENTRYPOINT ["/bin/sh", "/opt/languagetool/entrypoint.sh"]
