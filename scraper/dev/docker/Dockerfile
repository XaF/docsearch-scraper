FROM selenium/standalone-chrome
LABEL maintainer="bitkill@github.com"

WORKDIR /root

# Install DocSearch dependencies
COPY Pipfile .
COPY Pipfile.lock .

USER root
RUN apt-get update -y && apt-get install -yq \
    python3-pip jq

RUN pip3 install --break-system-packages pipenv
RUN pipenv install

COPY scraper/src ./src

USER ${SEL_UID}

ENTRYPOINT ["pipenv", "run", "python", "-m", "src.index"]
