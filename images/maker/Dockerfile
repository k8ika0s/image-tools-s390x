# Copyright Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

ARG DOCKER_IMAGE=docker.io/library/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659
ARG ALPINE_BASE_IMAGE=docker.io/library/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659
ARG GOLANG_IMAGE=docker.io/library/golang:1.26.0@sha256:c83e68f3ebb6943a2904fa66348867d108119890a2c6a2e6f07b38d0eb6c25c5

FROM ${DOCKER_IMAGE} AS docker-dist
RUN apk add --no-cache docker-cli

FROM ${GOLANG_IMAGE} AS go-builder

# hadolint ignore=SC2215
RUN --mount=type=bind,readwrite,target=/src \
    --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/go/pkg/mod \
    /src/build-go-deps.sh

FROM ${ALPINE_BASE_IMAGE} AS builder
ARG TARGETARCH

RUN apk add --no-cache \
    curl \
    && true

RUN mkdir -p /out/etc/apk && cp -r /etc/apk/* /out/etc/apk/

RUN if [ "${TARGETARCH}" = "s390x" ]; then \
      echo "Skipping shellcheck install for TARGETARCH=${TARGETARCH} (package unavailable)."; \
      extra_pkgs=""; \
      apk_root_opts="--initdb --no-cache --root /out --no-scripts"; \
    else \
      extra_pkgs="shellcheck"; \
      apk_root_opts="--initdb --no-cache --root /out"; \
    fi && \
    apk add ${apk_root_opts} \
      alpine-baselayout \
      bash \
      ca-certificates \
      coreutils \
      git \
      make \
      jq \
      yq \
      ${extra_pkgs} \
      && true

COPY --from=docker-dist /usr/bin/docker /out/usr/local/bin/docker
COPY --from=go-builder /out /out

ARG HADOLINT_VERSION=2.12.0

RUN case "${TARGETARCH}" in \
    'amd64') export ARCH='x86_64' ;; \
    'arm64') export ARCH='arm64' ;; \
    's390x') export ARCH='' ;; \
    *) echo "Unsupported TARGETARCH for hadolint: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    if [ -n "${ARCH}" ]; then \
      curl --fail --show-error --silent --location \
      "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-${ARCH}" \
      --output /out/usr/local/bin/hadolint \
      && chmod +x /out/usr/local/bin/hadolint; \
    else \
      echo "Skipping hadolint install for TARGETARCH=${TARGETARCH} (no upstream binary available)."; \
    fi

RUN mkdir -p /out/etc/docker/cli-plugins \
    && echo '{ "experimental": "enabled", "credsStore" : "env" }' > /out/etc/docker/config.json \
    && ln -fs /usr/local/bin/docker-buildx /out/etc/docker/cli-plugins

FROM scratch
ENV DOCKER_CONFIG=/etc/docker
# when `buldx create` is used, by default it stores configs of builder isntances in
# $BUILDX_CONFIG/buildx (or custom path set with $BUILDX_CONFIG);
# default location works as long as home directory is persisted, across invocations,
# but when invoked from inside a container the $DOCKER_CONFIG/buildx directory is not
# persisten unless it's mounted from the host;
# in GitHub Actions it is relatively safe to assume that $PWD/.buildx is where the
# builder instance of a single job need to be stored, which can be achived by using
# relative path here (see also https://github.com/docker/buildx/issues/308)
ENV BUILDX_CONFIG=.buildx
ENV MAKER_CONTAINER=true
COPY --from=builder /out /
