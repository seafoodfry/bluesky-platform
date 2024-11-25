# Version https://devguide.python.org/versions/
FROM python:3.13-bookworm AS builder

# Same values as docker-stack-foundation.
# See
# https://github.com/jupyter/docker-stacks/blob/aabaa58072623dcc62a71c9e84e3501ab11f5e9d/images/docker-stacks-foundation/Dockerfile#L11-L13
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"


# Install system dependencies and tools.
USER root

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" --no-user-group "${NB_USER}" && \
    chown -R ${NB_USER} "/home/${NB_USER}"

RUN apt-get update -y && \
    apt-get install less vim -y

##############################
### Non-Root Configuration ###
##############################
USER $NB_UID

WORKDIR /home/jovyan/work

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
COPY pyproject.toml poetry.lock /home/jovyan/work/
RUN poetry install --no-interaction --no-ansi --only main

COPY scraper_bluesky/ ./scraper_bluesky


# https://github.com/python-poetry/poetry-plugin-bundle
# Creating a dummy README because it is mentioned in the pyproject.toml file and thus required for the
# bundle process to work.
RUN poetry self add poetry-plugin-bundle && \
    touch README.md && \
    poetry install --no-interaction --no-ansi --only main && \
    poetry bundle venv /home/${NB_USER}/app/venv --only=main


# # https://github.com/GoogleContainerTools/distroless
FROM gcr.io/distroless/python3-debian12 AS prod

# Create the same user in distroless.
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Copy from the exact path used in builder.
COPY --from=builder --chown=${NB_UID}:${NB_GID} /home/${NB_USER}/app/venv /app/venv

# Switch to non-root user.
USER ${NB_UID}

# Set environment variables to match the new path.
ENV PYTHONPATH=/app/venv/lib/python3.13/site-packages
CMD ["/app/venv/bin/scraper-bluesky"]
