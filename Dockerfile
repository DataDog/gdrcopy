ARG BUILDER_IMAGE

FROM registry.ddbuild.io/images/nvidia-cuda-base:12.9.0

LABEL maintainers="Compute"

ENV CUDA=/usr/local/cuda

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    devscripts \
    debhelper \
    dkms \
    fakeroot \
    gcc-12 \
    pkg-config

RUN mkdir -p /work/build
WORKDIR /work/build

COPY include/ /work/include
COPY packages/ /work/packages
COPY scripts/ /work/scripts
COPY src/ /work/src
COPY tests/ /work/tests
COPY config_arch /work/config_arch
COPY Makefile /work/Makefile
COPY README.md /work/README.md

RUN /work/packages/build-deb-packages.sh -t

COPY nvidia-gdrcopy-driver.sh /usr/local/bin/nvidia-gdrcopy-driver

ENTRYPOINT [ "nvidia-gdrcopy-driver", "install" ]
