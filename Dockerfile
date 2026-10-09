# Full-featured GitHub Actions self-hosted runner image for ARC.
# Extends the official ARC runner base (ghcr.io/actions/actions-runner)
# with the tools we need for node builds + template validation:
#   - ruby          (YAML/tooling)
#   - python3       (already present on base, kept explicit)
#   - git           (already present, kept explicit)
#   - build-essential (make/gcc/g++ for building node daemons)
#   - autotools     (autoconf/automake/libtool for ./autogen.sh && ./configure)
# Docker daemon is provided separately by ARC's dind sidecar (containerMode: dind).
FROM ghcr.io/actions/actions-runner:latest

# Switch to root to install packages, then back to runner.
USER root

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      python3 \
      python3-pip \
      ruby \
      build-essential \
      autoconf \
      automake \
      libtool \
      pkg-config \
      curl \
      ca-certificates \
      jq \
    && rm -rf /var/lib/apt/lists/*

# Install pyyaml etc. (do NOT upgrade pip — it's Debian-managed, no RECORD file).
RUN python3 -m pip install --break-system-packages --no-warn-script-location setuptools wheel pyyaml

# Pin the Dagger CLI to match the always-on Dagger Engine (v0.21.9) so jobs
# reuse the shared engine's cache instead of auto-provisioning a per-job
# engine (which would be cold every run). Install to /usr/local/bin so it's on
# the 'runner' user's PATH (the default installer uses BIN_DIR=./bin which is
# CWD-relative and not visible to ARC's runner user).
RUN curl -fsSL https://dl.dagger.io/dagger/install.sh | DAGGER_VERSION=0.21.9 BIN_DIR=/usr/local/bin sh

# otel-cli: emit OTel traces from workflow steps to our in-cluster collector.
# Outbound-only (self-hosted runner -> collector over the LAN/cluster); no
# inbound exposure or GitHub webhook required. Pinned to the Linux amd64 build
# of the prebuilt release (installed to /usr/local/bin, on the 'runner' PATH).
RUN curl -fsSL "https://github.com/equinix-labs/otel-cli/releases/download/v0.4.5/otel-cli_0.4.5_linux_amd64.tar.gz" -o /tmp/otel-cli.tgz \
 && tar -xzf /tmp/otel-cli.tgz -C /usr/local/bin \
 && rm /tmp/otel-cli.tgz

# OTel shell SDK (5.63.0 = the fork snoby/opentelemetry-github VERSION): bake it
# so instrumented jobs skip the per-pod 46MB deb download + postinst pip wheels.
# install.sh's `type otel.sh` guard makes that path a no-op at runtime when present.
RUN curl -fsSL -o /tmp/otel-shell.deb \
      "https://github.com/plengauer/Thoth/releases/download/v5.63.0/opentelemetry-shell_5.63.0_amd64.deb" \
 && apt-get install -y --no-install-recommends /tmp/otel-shell.deb \
 && rm /tmp/otel-shell.deb

# unzip + parallel + nodejs/npm are apt-installed in every job pod today
# (inject_and_init.sh install.sh line); bake them so `ensure_installed` no-ops.
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip parallel nodejs npm \
 && rm -rf /var/lib/apt/lists/*

# Pre-bake the instrumentation action's node_modules (@actions/artifact 6.2.1,
# @actions/cache 6.3.0 per the fork's package-lock.json) so instrumented jobs
# skip the per-pod `npm ci` (172 packages). inject_and_init.sh on lab-patches
# copies this into the action checkout when present, npm ci as fallback.
# NOTE: bumping @actions/* in the fork's lockfile requires rebuilding this image.
RUN git clone --depth 1 --branch lab-patches \
      https://github.com/snoby/opentelemetry-github /tmp/otelfork \
 && cd /tmp/otelfork/actions/instrument/job \
 && npm ci --omit=dev \
 && mkdir -p /opt/otel-action-node_modules \
 && cp -a node_modules/. /opt/otel-action-node_modules/ \
 && rm -rf /tmp/otelfork

# Back to the runner user (ARC expects the runner to run as 'runner').
USER runner

# Confirm tool versions (visible at deploy time / for debugging).
RUN git --version && python3 --version && ruby --version && make --version | head -1 && autoconf --version | head -1 && dagger version
