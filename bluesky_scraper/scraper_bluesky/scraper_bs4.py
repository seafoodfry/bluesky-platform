from typing import Optional, Tuple
from bs4 import BeautifulSoup, Tag
from playwright.async_api import Page
from opentelemetry import trace

from scraper_bluesky.screenshots import take_debug_screenshots
from scraper_bluesky.txt import RM_CHARS
from scraper_bluesky.trace_utils import get_span_name, span_name


tracer = trace.get_tracer("bluesky")


@span_name()
async def get_first_child(element: Tag) -> Optional[Tag]:
    """Get first child of BeautifulSoup element."""
    child = element.find()
    if child and isinstance(child, Tag):
        return child
    return None


@span_name()
async def extract_post_data(post: Tag) -> Optional[Tuple[str, str, str]]:
    """Extract username, handle and content from a post."""
    # First get the post content structure.
    post_div = post.find("div", class_="css-175oi2r r-18u37iz r-1cvj4g8")
    if not isinstance(post_div, Tag):
        raise Exception("Error finding first div")
    content_div = post_div.find("div", class_="css-175oi2r r-13awgt0 r-bnwqim r-417010")
    if not isinstance(content_div, Tag):
        raise Exception("Error finding subsequent div")

    # Get all direct children, similar to post.locator("> *").
    children = [
        c for c in content_div.children if isinstance(c, Tag)
    ]

    # Verify we have 3 children as expected.
    children_count = len(children)
    if children_count != 3:
        raise Exception(f"Post should have 3 children, but has {children_count}")

    # Handle user section (first child).
    child = await get_first_child(children[0])
    if not child:
        raise Exception("Failed to get first child")

    child = await get_first_child(child)
    if not child:
        raise Exception("Failed to get second child")

    child = await get_first_child(child)
    if not child:
        raise Exception("Failed to get third child")

    # Get the username and handle links.
    links = [anchor for anchor in child.find_all("a", recursive=False)]
    if len(links) != 2:
        raise Exception(f"Expected 2 links for username/handle, found {len(links)}")

    # Extract username and handle.
    username = links[0].get_text()
    username = username.translate(RM_CHARS).strip()

    handle = links[1].get_text()
    handle = handle.translate(RM_CHARS).strip()

    # Get post content using the second child.
    first_child = await get_first_child(children[1])
    if not first_child:
        raise Exception("Failed to get content section")
    content_text = first_child.get_text()

    return username, handle, content_text


@span_name()
async def scrape_posts(page: Page):
    """Scrape posts from homepage."""
    p_span = trace.get_current_span()

    print("waiting for page to load...")
    # Wait for page load with generous timeouts.
    with tracer.start_as_current_span(get_span_name("wait_until_domcontentloaded")):
        await page.wait_for_load_state("domcontentloaded")

    # Wait for feed container.
    with tracer.start_as_current_span(get_span_name("wait_for_selector")):
        feed_selector = "div.css-175oi2r"
        await page.wait_for_selector(feed_selector, state="visible", timeout=30000)
        print("page loaded!")

    # Wait for posts to be visible.
    with tracer.start_as_current_span(get_span_name("wait_for_selector")):
        posts_selector = "> div > div.css-175oi2r.r-1loqt21.r-1otgn73 > div.css-175oi2r.r-1loqt21.r-1hfyk0a.r-ry3cjt"
        await page.wait_for_selector(
            feed_selector + " " + posts_selector, timeout=10000
        )

    # Get all HTML at once.
    with tracer.start_as_current_span(get_span_name("wait_for_content")):
        html = await page.content()
        soup = BeautifulSoup(html, "html.parser")

    # Find all posts.
    posts = soup.select(f"{feed_selector} {posts_selector}")
    post_count = len(posts)
    print(f"Number of posts found: {post_count}")
    p_span.set_attribute("posts_count", post_count)

    if post_count < 1:
        print("No posts found - taking debug screenshots")
        await take_debug_screenshots(page, "no_posts")
        return

    # Process each post using your familiar extraction function.
    for i, post in enumerate(posts):
        post_data = await extract_post_data(post)
        if post_data:
            username, handle, content = post_data
            print(f"Post {i+1}/{post_count}:")
            print(f"  Username: {username}")
            print(f"  Handle: {handle}")
            print(f"  Content: {content}\n")
