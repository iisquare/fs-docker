ARG TRINO_VERSION

FROM trinodb/trino:${TRINO_VERSION}

ARG TRINO_VERSION

RUN curl -L -o /usr/lib/trino/bin/trino-cli "https://github.com/trinodb/trino/releases/download/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}"
RUN chmod +x /usr/lib/trino/bin/trino-cli

EXPOSE 8080
