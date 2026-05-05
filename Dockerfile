# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie AS buildstage

ARG EDEN_VERSION

RUN \
  echo "**** install build deps ****" && \
  apt-get update && \
  apt-get install -y \
    autoconf \
    cmake \
    g++ \
    gcc \
    git \
    glslang-tools \
    libasound2t64 \
    libavcodec-dev \
    libavfilter-dev \
    libboost-context-dev \
    libboost-fiber-dev \
    libcpp-httplib-dev \
    libcpp-jwt-dev \
    libcubeb-dev \
    libenet-dev \
    libfmt-dev \
    libglu1-mesa-dev \
    libhidapi-dev \
    liblz4-dev \
    libopus-dev \
    libpulse-dev \
    libqt6core5compat6 \
    libquazip1-qt6-dev \
    libsdl2-dev \
    libsimpleini-dev \
    libssl-dev \
    libswscale-dev \
    libtool \
    libudev-dev \
    libusb-1.0-0-dev \
    libva-dev \
    libvdpau-dev \
    libvulkan-dev \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxext-dev \
    libxkbcommon-x11-0 \
    libzstd-dev \
    mesa-common-dev \
    nasm \
    ninja-build \
    nlohmann-json3-dev \
    patch \
    pkg-config \
    qt6-base-private-dev \
    qt6-charts-dev \
    qt6-multimedia-dev \
    qt6-tools-dev \
    qt6-webengine-dev \
    spirv-headers \
    spirv-tools \
    zlib1g-dev

RUN \
  echo "**** build eden ****" && \
  mkdir /root-out && \
  if [ -z ${EDEN_VERSION+x} ]; then \
    EDEN_VERSION=$(curl -sX GET 'https://git.eden-emu.dev/api/v1/repos/eden-emu/eden/releases/latest' \
    | awk '/tag_name/{print $6;exit}' FS='[""]'); \
  fi && \
  git clone https://git.eden-emu.dev/eden-emu/eden.git && \
  cd eden/ && \
  git checkout -f ${EDEN_VERSION} && \
  cmake -B build -GNinja \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=None \
    -DCMAKE_C_FLAGS="-march=x86-64-v3 -O2" \
    -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -O2" \
    -DUSE_DISCORD_PRESENCE=ON \
    -DYUZU_ENABLE_LTO=OFF \
    -DYUZU_USE_CPM=OFF \
    -DCPM_USE_LOCAL_PACKAGES=ON \
    -DYUZU_USE_BUNDLED_FFMPEG=OFF \
    -DYUZU_USE_BUNDLED_SDL2=OFF \
    -DYUZU_USE_EXTERNAL_SDL2=OFF \
    -DYUZU_USE_BUNDLED_QT=OFF \
    -DENABLE_QT_TRANSLATION=ON \
    -DYUZU_USE_QT_MULTIMEDIA=ON \
    -DYUZU_USE_QT_WEB_ENGINE=ON \
    -Dhttplib_FORCE_BUNDLED=ON \
    -DTITLE_BAR_FORMAT_RUNNING="eden | ${EDEN_VERSION} {}" \
    -DTITLE_BAR_FORMAT_IDLE="eden ${EDEN_VERSION} {}" \
    -DYUZU_TESTS=OFF \
    -DDYNARMIC_TESTS=OFF \
    -DBUILD_TESTING=OFF \
    -Wno-dev && \
  cmake --build build && \
  mv \
    build/bin/* \
    /root-out/


# Runtime Stage
FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

# set version label
ARG BUILD_DATE
ARG VERSION
ARG EDEN_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

ENV TITLE=Eden \
    PIXELFLUX_WAYLAND=true

RUN \
  echo "**** add icon ****" && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/eden-logo.png && \
  echo "**** install packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    libavcodec61 \
    libboost-context1.83.0 \
    libboost-filesystem1.83.0 \
    libcubeb0 \
    libenet7 \
    libfmt10 \
    liblz4-1 \
    libopus0 \
    libqt6charts6 \
    libqt6multimedia6 \
    libqt6webenginewidgets6 \
    libquazip1-qt6-1t64 \
    libsdl2-2.0-0 \
    libsimpleini1t64 \
    libssl3t64 \
    libusb-1.0-0 \
    libxcb-cursor0 \
    libzstd1 \
    qt6-wayland && \
  echo "**** cleanup ****" && \
  printf \
    "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" \
    > /build_version && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.launchpadlib \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# add local files and files from buildstage
COPY --from=buildstage /root-out/* /usr/bin/
COPY root/ /

# ports and volumes
VOLUME /config
EXPOSE 3001
