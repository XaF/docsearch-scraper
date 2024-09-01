FROM ghcr.io/bitkill/docsearch-scraper-base:latest
LABEL maintainer="bitkill@github.com"

WORKDIR /home/seleuser
USER 1000
COPY scraper/src ./src

COPY scraper/src ./src

ENTRYPOINT ["pipenv", "run", "python", "-m", "src.index"]
