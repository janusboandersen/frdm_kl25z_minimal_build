
# --- Stage 0: Base ---
FROM ubuntu:24.04 as base
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3=3.12.3-0ubuntu2 \
            python3.12=3.12.3-1ubuntu0.8 \
            python3.12-minimal=3.12.3-1ubuntu0.8 \
            python3.12-venv=3.12.3-1ubuntu0.8 \
        python3-venv=3.12.3-0ubuntu2 \
        curl \
        xz-utils \
        gpgv \
        build-essential \
        pkg-config \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*


# --- Stage 1: Fetch Arm GNU Toolchain ---
FROM base as arm-fetch
ARG DEBIAN_FRONTEND=noninteractive

# Configure Arm GNU Toolchain version
ARG TOOLCHAIN_VER=14.2.rel1

RUN set -eux; \
    arch=$(dpkg --print-architecture); \
    baseurl="https://developer.arm.com/-/media/Files/downloads/gnu/${TOOLCHAIN_VER}/binrel"; \
    if [ "$arch" = "amd64" ]; then \
        tarball="arm-gnu-toolchain-${TOOLCHAIN_VER}-x86_64-arm-none-eabi.tar.xz"; \
    elif [ "$arch" = "arm64" ]; then \
        tarball="arm-gnu-toolchain-${TOOLCHAIN_VER}-aarch64-arm-none-eabi.tar.xz"; \
    else \
        echo "Unsupported architecture: $arch" >&2; exit 2; \
    fi; \
    curl -fsSL "${baseurl}/${tarball}" -o "${tarball}"; \
    mkdir -p /opt/toolchains/; \
    tar -xJf "${tarball}" -C /opt/toolchains; \
    rm -f "${tarball}"

# Symlink to copy from
RUN set -eux; \
    d=$(echo /opt/toolchains/arm-gnu-toolchain-*"-arm-none-eabi"); \
    ln -s "$d" /opt/toolchains/arm-none-eabi

# Prune toolchain size by removing docs
RUN rm -rf \
    /opt/toolchains/*/share/{doc,man,info}

# Prune by removing unneeded architectures. Keep what GCC selects for the architecture
#   arm-none-eabi-gcc -mcpu=cortex-m0plus -mthumb -mfloat-abi=soft -print-multi-directory
#   -> thumb/v6-m/nofp
#
# Keeping:
#   /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/nofp
#   /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v6-m
#
# Removing:
RUN rm -rf \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/arm \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7 \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7-a \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7-m \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7e-m \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8-a \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8-m.base \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8-m.main \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8.1-m.main+mve \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8.1-m.main+pacbti \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+mve \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7+fp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7-a+fp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7-a+simd \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7-r+fp.sp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7e-m+dp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7e-m+fp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v7ve+simd \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8-a+simd \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8-m.main+dp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8-m.main+fp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+dp \
    /opt/toolchains/arm-none-eabi/arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+fp


# --- Stage 2: Build Python venv and pyOCD ---
FROM base as py-build

# Deterministic python from local venv, based off on-hold python3.12 
RUN python3 -m venv /opt/venv

# Deterministic pipx CLI through on-hold python3.12, and
# controlled paths outside any user's home
ENV PIPX_HOME="/opt/pipx" \
    PIPX_BIN_DIR="/usr/local/bin" \
    PIPX_DEFAULT_PYTHON="/opt/venv/bin/python3"

# Ensure overriding system pythons
ENV PATH="/opt/venv/bin:/usr/local/bin:${PATH}"

# Stay with pip24 pckgmgr for compatibility with pip-tools (pip25+pip_tools errors on attribute use_pep517)
RUN pip install --no-cache-dir \
        "pip==24.3.1" \
        "setuptools>=70" \
        "wheel" \
        "pip-tools==7.5.1" \
        "pipx==1.7.1"

RUN pipx install \
        "pyocd==0.39.0" && \
        pyocd --version

COPY verify/requirements.in .
RUN pip-compile --generate-hashes requirements.in && \
    pip install --no-cache-dir --require-hashes --force-reinstall -r requirements.txt

RUN pip cache purge && \
    rm -rf /root/.cache /opt/pipx/.cache


# --- Stage 3: Final image ---
FROM ubuntu:24.04 as final
ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode

# Pinned versions as of October 2025 for reproducibility
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3=3.12.3-0ubuntu2 \
            python3.12=3.12.3-1ubuntu0.8 \
            python3.12-minimal=3.12.3-1ubuntu0.8 \
        cmake=3.28.3-1build7 \
        ninja-build=1.11.1-2 && \
    apt-mark hold \
        cmake \
        ninja-build

# Developer convenience tools, good for devcontainer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        adduser \
        zsh \
        curl \
        ca-certificates \
        git && \
    rm -rf /var/lib/apt/lists/*

# Cross-compiler toolchain
COPY --from=arm-fetch /opt/toolchains /opt/toolchains

# Python build (Python venv, Pipx venv with pyOCD, pyOCD CLI symlink)
COPY --from=py-build /opt/venv /opt/venv       
COPY --from=py-build /opt/pipx/venvs/pyocd /opt/pipx/venvs/pyocd
COPY --from=py-build /opt/pipx/shared /opt/pipx/shared
COPY --from=py-build /usr/local/bin/pyocd /usr/local/bin/pyocd

# Minify image
RUN apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /usr/share/doc/* \
        /usr/share/doc-base/* \
        /usr/share/man/* \
        /usr/share/info/* \
        /usr/share/lintian/* \
        /usr/share/linda/* \
        /usr/share/locale/* && mkdir -p /usr/share/locale/en && true

# Enable UTF-8 instead of ascii for OhMyZsh
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Ensure overriding system compilers and pythons
ENV TOOLCHAIN_PATH="/opt/venv/bin:/usr/local/bin:/opt/toolchains/arm-none-eabi/bin"
ENV PATH="${TOOLCHAIN_PATH}:${PATH}"

# Prepare user environment
RUN adduser --disabled-password --gecos "" --shell /usr/bin/zsh "$USERNAME"

RUN su - "$USERNAME" -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes; \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

# Fix the theme
RUN sed -i 's/ZSH_THEME=.*/ZSH_THEME="agnoster"/' /home/"${USERNAME}"/.zshrc && \
    sed -i 's/^plugins=(.*/plugins=(git)/' /home/"${USERNAME}"/.zshrc && \
    chown "${USERNAME}:${USERNAME}" /home/"${USERNAME}"/.zshrc

RUN mkdir -p /work && \
    chown -R "${USERNAME}:${USERNAME}" /work

USER ${USERNAME}
WORKDIR /work
CMD ["sleep", "infinity"]

# Github Actions must run as root
#USER root