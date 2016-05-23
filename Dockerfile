FROM ubuntu:16.04

# general build deps
RUN apt-get update && apt-get install -y \
  sudo \
  git \
  wget \
  build-essential \
  zip \
  python-dev \
  python-pip

RUN pip install \
  awscli \
  requests \
  pycrypto \
  jinja2 \
  argparse

RUN wget https://www.openssl.org/source/old/0.9.x/openssl-0.9.8zg.tar.gz && \
  tar zxf openssl-0.9.8zg.tar.gz && \
  cd ./openssl-0.9.8zg && \
  ./config && \
  make
