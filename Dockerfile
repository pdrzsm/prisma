FROM ruby:3.3

# Ferramentas de compilação C, clientes do MariaDB/MySQL e dependências nativas
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      default-mysql-client \
      git \
      pkg-config \
      libvips && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails