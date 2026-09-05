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

# Ensure pip works system-wide for the runner user.
RUN python3 -m pip install --break-system-packages --upgrade pip setuptools wheel pyyaml 2>/dev/null || \
    python3 -m pip install --upgrade pip setuptools wheel pyyaml

# Back to the runner user (ARC expects the runner to run as 'runner').
USER runner

# Confirm tool versions (visible at deploy time / for debugging).
RUN git --version && python3 --version && ruby --version && make --version | head -1 && autoconf --version | head -1
