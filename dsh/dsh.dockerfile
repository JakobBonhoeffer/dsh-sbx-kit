# syntax=docker/dockerfile:1
#
# DeepSeek Harness (DSH) kit: Ubuntu 26.04 base (docker.io/sbx/shell-docker-image) + Node 24 + DSH + RE/ESP32/Android tools.
# Heavy tools (Ghidra, ESP-IDF) are deliberately NOT here; install them inside the
# sandbox and save the result with `sbx template save`.

FROM docker.io/sbx/shell-docker-image

ARG NODE_VERSION
ARG DSH_VERSION
ARG TARGETARCH

USER root
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1) Core packages. If one of these fails, the build fails (on purpose).
# ---------------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      xz-utils socat procps build-essential cmake pkg-config \
      python3 python3-venv python3-dev \
      unzip p7zip-full ripgrep tmux vim file xxd \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2) Tool packages, installed one by one. A missing package is logged to
#    /usr/share/dsh-kit-skipped.txt instead of breaking the whole build.
# ---------------------------------------------------------------------------
RUN apt-get update \
 && for p in \
      binwalk radare2 gdb gdb-multiarch binutils-multiarch ltrace strace \
      squashfs-tools cpio foremost hexedit yara qemu-user-static \
      nmap tcpdump netcat-openbsd dnsutils whois openssl iproute2 iputils-ping \
      picocom minicom usbutils \
      default-jre-headless adb apktool jadx ; do \
        apt-get install -y --no-install-recommends "$p" \
          || echo "SKIPPED: $p" >> /usr/share/dsh-kit-skipped.txt ; \
      done \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3) Node.js (official tarball) into /usr/local
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) node_arch=x64 ;; \
      arm64) node_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1 --no-same-owner; \
    node --version; npm --version

# ---------------------------------------------------------------------------
# 4) DeepSeek Harness. npm 11 skips install scripts unless allowed; node-pty
#    (terminal) and friends need theirs.
# ---------------------------------------------------------------------------
RUN npm install -g \
      --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs \
      "@deepseek-ai/dsh@${DSH_VERSION}" \
 && dsh --version

# ---------------------------------------------------------------------------
# 5) Python RE/ESP32 libraries in their own venv (installed one by one, too)
# ---------------------------------------------------------------------------
RUN /usr/bin/python3 -m venv /opt/re-venv \
 && for p in esptool pyserial pyelftools capstone unicorn keystone-engine r2pipe yara-python; do \
      /opt/re-venv/bin/pip install --no-cache-dir "$p" \
        || echo "SKIPPED (pip): $p" >> /usr/share/dsh-kit-skipped.txt ; \
    done
ENV PATH=/opt/re-venv/bin:$PATH

# ---------------------------------------------------------------------------
# 6) Helper scripts (CRLF -> LF in case the files were saved on Windows)
# ---------------------------------------------------------------------------
COPY files/dsh-start /usr/local/bin/dsh-start
COPY files/dsh-url   /usr/local/bin/dsh-url
RUN sed -i 's/\r$//' /usr/local/bin/dsh-start /usr/local/bin/dsh-url \
 && chmod 0755 /usr/local/bin/dsh-start /usr/local/bin/dsh-url

# The workload's launch command is a login shell; DSH itself is started by the
# kit's startup hook (see dsh.yaml), not here.
USER agent
ENTRYPOINT ["bash"]
CMD ["-l"]
