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

# Get the first username.
page.wait_for_selector('span.css-1jxf684')
username = page.locator('span.css-1jxf684').nth(0).inner_text().strip()

# Grab posts.
post_containers = page.locator('div.css-175oi2r.r-13awgt0')
post_containers.count()  # can be something like ~50.
container = post_containers.nth(0)

# Even values are usernames, odd values are handles.
username = container.locator('span.css-1jxf684').nth(0).inner_text().strip()
handle = container.locator('span.css-1jxf684').nth(1).inner_text().strip()
txt = container.locator('div[data-testid="postText"]').nth(0).inner_text().strip()
container.locator('css-175oi2r r-1awozwy r-18u37iz r-1w6e6rj r-1udh08x r-l4nmg1').nth(0).inner_text().strip()

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
