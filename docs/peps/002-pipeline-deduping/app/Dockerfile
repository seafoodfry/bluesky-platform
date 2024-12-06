FROM python:3.13-bookworm AS builder

ARG NB_USER="jovyan"
WORKDIR /home/${NB_USER}/work

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

COPY src/ ./src


# https://github.com/python-poetry/poetry-plugin-bundle
# Creating a dummy README because it is mentioned in the pyproject.toml file and thus required for the
# bundle process to work.
RUN poetry install --no-interaction --no-ansi --only main

CMD ["poetry", "run",  "opentelemetry-instrument", "python",  "-m", "src"]