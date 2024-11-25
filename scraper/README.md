# Bluesky Scraper

## Exploration

```
docker build -t playw -f Dockerfile.playwright .
```

```
xhost +localhost 

export DISPLAY=host.docker.internal:0 

docker run -it \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=host.docker.internal:0 \
    --rm --ipc=host playw ipython
```

```python
 # This is needed to use sync API in repl.
import nest_asyncio; nest_asyncio.apply()
from playwright.sync_api import sync_playwright

pw = sync_playwright().start()
browser = pw.chromium.launch(headless=False)
page = browser.new_page()
page.goto("https://bsky.app/")
print(page.title())

visible_text = page.locator("body").inner_text()
visible_text.index('sometext')
visible_text.count('\n\u202a')

browser.close()
pw.stop()
```

References:

1. https://scrapfly.io/blog/web-scraping-with-playwright-and-python/
1. https://playwright.dev/python/docs/library
1. https://github.com/jessfraz/dockerfiles/blob/master/chrome/stable/Dockerfile
1. https://github.com/jessfraz/dockerfiles/blob/master/firefox/Dockerfile
1. https://playwright.dev/docs/docker
1. https://mcr.microsoft.com/en-us/artifact/mar/playwright/tags
