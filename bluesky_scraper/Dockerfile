# docker build -t playw -f Dockerfile.playwright .
# docker run -it -v /tmp/.X11-unix:/tmp/.X11-unix --rm --ipc=host mcr.microsoft.com/playwright:v1.49.0-noble /bin/bash
# docker run -it -v /tmp/.X11-unix:/tmp/.X11-unix --rm --ipc=host playw ipython
# docker run -it --rm --ipc=host --user pwuser --security-opt seccomp=seccomp_profile.json playw /bin/bash
FROM mcr.microsoft.com/playwright:v1.49.0-noble-arm64

ARG NB_USER="pwuser"
ARG NB_UID="1001"
ARG VENV_PATH=/opt/venv

RUN apt-get update -y && \
    apt-get install -y python3.12-venv

# WORKDIR /src
# RUN python3 -m venv ${VENV_PATH} && \
#     ${VENV_PATH}/bin/pip install playwright==1.49.0 && \
#     ${VENV_PATH}/bin/pip install ipython nest_asyncio

# ENV PATH=${VENV_PATH}/bin:${PATH}

##############################
### Non-Root Configuration ###
##############################
USER $NB_UID

WORKDIR /home/${NB_USER}/src

#######################
# Poetry Installation #
#######################
ENV POETRY_VERSION=1.8.4
ENV POETRY_HOME=/home/${NB_USER}/.poetry
RUN python3 -m venv ${POETRY_HOME} && \
    $POETRY_HOME/bin/pip install poetry==${POETRY_VERSION}

# Add Poetry to PATH.
ENV PATH="${POETRY_HOME}/bin:${PATH}"

####################
# App Installation #
####################
# Set Poetry environment variables to create a virtual environment.
# Not creating a virtualenv will lead poetry to want to install things in a global scope.
# So we just deal with this by sourcing the virtualenv manually right before we give control
# back to the user.
# See https://github.com/python-poetry/poetry/issues/1214
ENV POETRY_VIRTUALENVS_CREATE=true
ENV POETRY_CACHE_DIR="/home/${NB_USER}/.cache/pypoetry"
COPY pyproject.toml poetry.lock /home/${NB_USER}/src/
RUN poetry install --no-interaction --no-ansi --only main

COPY scraper_bluesky/ ./scraper_bluesky

RUN poetry install --no-interaction --no-ansi --only main && mkdir ./scrrenshots

CMD ["poetry", "run",  "python",  "-m", "scraper_bluesky"]