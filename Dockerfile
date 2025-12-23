FROM fedora:latest

ENV GIT_TERMINAL_PROMPT=0
ENV GIT_ASKPASS=true

ENV WORKSPACE=/workspace
WORKDIR /workspace

COPY . .

RUN chmod +x scripts/build-iso.sh scripts/start.sh

# Base dependencies (Fedora 43 compatible)
RUN dnf update --refresh -y && \
    dnf install --refresh -y \
      kernel \
      gcc \
      gcc-c++ \
      make \
      nasm \
      redhat-rpm-config \
      elfutils-libelf-devel \
      git \
      cmake \
      coreutils \
      libglvnd-devel \
      qhexedit2-qt5-devel \
      qt5-qtbase-devel \
      qt5-qtwayland \
      zlib-devel \
      pciutils-devel \
      libusb1-devel \
      libjaylink-devel \
      libftdi-devel \
      innoextract \
      livecd-tools \
      python3 \
      python3-devel \
      python3-pip \
      python3-wheel \
    && dnf clean all

# CHIPSEC: build wheel but DO NOT build the Linux kernel driver in the image build.
# We patch setup.py to bypass driver build hooks.
RUN git clone https://github.com/chipsec/chipsec.git chipsec-build && \
    mkdir -p chipsec && \
    cd chipsec-build && \
    python3 --version && \
    \
    # Common patterns across chipsec versions:
    # - calls into _build_linux_driver()
    # - calls a driver build function from a custom build cmdclass
    # Neutralize both conservatively.
    sed -i \
      -e 's/^\(\s*\)_build_linux_driver\s*(\s*)\s*$/\1print("Skipping linux driver build in container image build")/g' \
      -e 's/\<_build_linux_driver\>\s*(\s*)/print("Skipping linux driver build in container image build")/g' \
      -e 's/\<driver_build_function\>\s*(\s*)/print("Skipping linux driver build in container image build")/g' \
      setup.py && \
    \
    python3 setup.py bdist_wheel && \
    cp dist/*.whl $WORKSPACE/chipsec/ && \
    cd /workspace && \
    rm -rf chipsec-build

# UEFIPatch from UEFITool repo's old_engine branch
RUN set -eux; \
    git clone https://github.com/LongSoft/UEFITool.git uefitool-build; \
    cd uefitool-build; \
    git fetch --all --prune; \
    git checkout old_engine; \
    test -f UEFIPatch/uefipatch.pro; \
    cd UEFIPatch; \
    qmake-qt5 uefipatch.pro; \
    make -j"$(nproc)"; \
    mkdir -p "$WORKSPACE/uefipatch"; \
    cp -v ./UEFIPatch "$WORKSPACE/uefipatch/UEFIPatch"; \
    cp -v ./patches.txt ./patches-misc.txt "$WORKSPACE/uefipatch/"; \
    cd /workspace; \
    rm -rf uefitool-build

# flashrom, get specific tag
RUN set -eux; \
    git clone https://github.com/flashrom/flashrom.git flashrom-build; \
    cd flashrom-build; \
    git fetch --tags --force; \
    git checkout v1.2; \
    make -j"$(nproc)" WERROR=0 CFLAGS+=' -Wno-error=enum-conversion'; \
    mkdir -p "$WORKSPACE/flashrom"; \
    install -m 0755 flashrom "$WORKSPACE/flashrom/flashrom"; \
    cd /workspace; \
    rm -rf flashrom-build

# Download and patch BIOS images
RUN mkdir -p $WORKSPACE/bios && \
    cd $WORKSPACE/bios && \
    curl -R https://download.lenovo.com/pccbbs/mobiles/g2uj33us.exe -o X230.exe && \
    curl -R https://download.lenovo.com/pccbbs/mobiles/gcuj34us.exe -o X230t.exe && \
    curl -R https://download.lenovo.com/pccbbs/mobiles/g5uj39us.exe -o W530.exe && \
    curl -R https://download.lenovo.com/pccbbs/mobiles/g4uj41us.exe -o T530.exe && \
    curl -R https://download.lenovo.com/pccbbs/mobiles/g7uj29us.exe -o T430s.exe && \
    curl -R https://download.lenovo.com/pccbbs/mobiles/g1uj49us.exe -o T430.exe && \
    cp X230.exe X330.exe && \
    for bios in *.exe; do \
      innoextract "$bios" && \
      find . -type f -name "*.FL1" -exec cp {} "$(basename -s .exe "$bios").FL1" \; && \
      rm -rf app && \
      bash $WORKSPACE/patcher/patcher.sh "$(basename -s .exe "$bios").FL1"; \
    done

ENTRYPOINT ["/workspace/scripts/build-iso.sh"]
CMD ["/workspace/ks/livecd-fedora-minimal.ks"]
