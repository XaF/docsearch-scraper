FROM ghcr.io/bitkill/docsearch-scraper-base:latest
LABEL maintainer="bitkill@github.com"

WORKDIR /root
COPY scraper/src ./src

ENTRYPOINT ["pipenv", "run", "python", "-m", "src.index"]
