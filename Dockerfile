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

# Back to the runner user (ARC expects the runner to run as 'runner').
USER runner

# Confirm tool versions (visible at deploy time / for debugging).
RUN git --version && python3 --version && ruby --version && make --version | head -1 && autoconf --version | head -1 && dagger version
