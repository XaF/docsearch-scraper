FROM ubuntu:22.04

RUN export DEBIAN_FRONTEND=noninteractive \
        && apt-get update -y \
        && apt-get install -y \
                jq nginx git curl \
                python3 python3-pip \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
        && pip install --no-cache-dir --trusted-host pypi.python.org pipenv \
        && python3 --version \
        && pip --version \
        && jq --version

ARG WORKDIR=/root
ARG SCRAPERDIR=/scraper
ARG ENCODING=C.UTF-8

ENV WORKDIR=$WORKDIR
ENV WORKON_HOME=$WORKDIR
ENV PIPENV_PIPFILE=$WORKDIR/Pipfile
ENV SCRAPERDIR=$SCRAPERDIR
ENV LC_ALL=$ENCODING
ENV LANG=$ENCODING

# Install the dependencies
COPY Pipfile* $WORKDIR/
RUN cd "$WORKDIR" && \
        pipenv install --deploy --ignore-pipfile

# Change the working directory
WORKDIR $WORKDIR

# Copy the scraper source code
COPY scraper/ $SCRAPERDIR

# Copy the entrypoint
COPY action-resources/entrypoint.sh /entrypoint.sh

# Copy the template of the nginx configuration
COPY action-resources/nginx.conf.template /nginx.conf.template

# Copy the index binary
COPY action-resources/index.sh /usr/bin/index

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
