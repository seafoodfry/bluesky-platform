# bluesky-platform

A comprehensive platform for developing, deploying, and researching machine learning models powered by custom data collection pipelines.

This platform provides an end-to-end solution for:

* Building and managing data collection scrapers for publicly available datasets (some scrapers may be just for fun)
* Training and deploying ML models for content recommendation, mathematical expression extraction, OCR, etc
* Supporting development, production, and research workflows in a unified environment

---
## Development

### Python

We recommend installing poetry like this:

```sh
VENV_PATH=~/.poetry
python3 -m venv $VENV_PATH
$VENV_PATH/bin/pip install poetry
```

Then,
```
export PATH=~/.poetry/bin/:$PATH
```