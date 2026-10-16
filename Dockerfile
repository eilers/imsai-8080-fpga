FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
      sed -i 's/Components: main$/Components: main universe/' /etc/apt/sources.list.d/ubuntu.sources; \
    fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      git \
      python3 \
      libglu1-mesa-dev \
      libjpeg-dev \
      libx11-dev \
      patch \
 && rm -rf /var/lib/apt/lists/*

ARG Z80PACK_REF=1.38
RUN git clone --depth 1 --branch "${Z80PACK_REF}" https://github.com/udo-munk/z80pack.git /src/z80pack

# The photographed 2D panel is the IMSAI face. Software OpenGL in Docker
# draws it reliably; the 3D model is optional and much heavier.
WORKDIR /src/z80pack/imsaisim
RUN rm -f conf && ln -s conf_2d conf

COPY autorun.patch /tmp/autorun.patch
COPY add-tape-handler.py /tmp/add-tape-handler.py
RUN patch -p1 -d /src/z80pack < /tmp/autorun.patch \
 && python3 /tmp/add-tape-handler.py

WORKDIR /src/z80pack/imsaisim/srcsim
RUN make -j"$(nproc)"

WORKDIR /src/z80pack
COPY collect-software.sh /tmp/collect-software.sh
RUN chmod +x /tmp/collect-software.sh && /tmp/collect-software.sh

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    IMSAI_BOOT=imsai-cpm13 \
    IMSAI_AUTORUN=1

RUN if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
      sed -i 's/Components: main$/Components: main universe/' /etc/apt/sources.list.d/ubuntu.sources; \
    fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      libgl1 \
      libgl1-mesa-dri \
      libglu1-mesa \
      libjpeg-turbo8 \
      libjpeg9 \
      libx11-6 \
      novnc \
      python3 \
      websockify \
      x11-utils \
      x11vnc \
      xdotool \
      xvfb \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/z80pack/imsaisim /opt/z80pack/imsaisim
COPY --from=build /src/z80pack/webfrontend/www/imsai /opt/z80pack/webfrontend/www/imsai
COPY --from=build /src/z80pack/imsaisim/disks /opt/z80pack/disk-library
COPY shelf /opt/z80pack/imsaisim/shelf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/z80pack/imsaisim/shelf \
 && chmod a+rwx /opt/z80pack/imsaisim/disks \
 && sed -i 's/^fp_fps.*/fp_fps 15/' /opt/z80pack/imsaisim/conf/system.conf

WORKDIR /opt/z80pack/imsaisim
EXPOSE 8080 6080
ENTRYPOINT ["/entrypoint.sh"]
