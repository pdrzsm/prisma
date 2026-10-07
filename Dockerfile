FROM ruby:3.3

# Ferramentas de compilação C, clientes do MariaDB/MySQL e dependências nativas
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      default-mysql-client \
      git \
      pkg-config \
      libvips \
      chromium \
      chromium-driver && \
    rm -rf /var/lib/apt/lists/*

# Chromium sem janela para os testes de navegador (bin/rails test:system)
ENV CHROME_BIN=/usr/bin/chromium

WORKDIR /rails