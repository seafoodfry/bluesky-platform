from playwright.async_api import Page, Locator
from datetime import datetime
from typing import Optional, Tuple  # For better type hints

from scraper_bluesky.screenshots import take_debug_screenshots


RM_CHARS = {ord('\u202a'): None, ord('\u202c'): None, ord('\xa0'): None}


async def get_page_title(page: Page):
    """
    Scrapes and prints the page title.
    """
    title = await page.title()
    print(f"Page Title: {title}")
    return title


def sync_get_first_child(locator: Page) -> Page|None:
    if locator.locator("> *").count() > 0:
        return locator.locator("> *").nth(0)
    else:
        return None
    
async def get_first_child(locator: Locator) -> Optional[Locator]:
    """Get first child of a locator safely."""
    try:
        count = await locator.locator("> *").count()
        return locator.locator("> *").nth(0) if count > 0 else None
    except Exception as e:
        print(f"Error getting first child: {e}")
        return None


async def extract_post_data(post: Locator) -> Optional[Tuple[str, str, str]]:
    """Extract username, handle and content from a post."""
    # First get the post content structure
    post = post.locator('div.css-175oi2r.r-18u37iz.r-1cvj4g8 > div.css-175oi2r.r-13awgt0.r-bnwqim.r-417010')
    post = post.locator('> *')
    
    # Verify we have 3 children as expected
    children_count = await post.count()
    if children_count != 3:
        raise Exception(f'Post should have 3 children, but has {children_count}')
    
    # Navigate to get username/handle section
    child = await get_first_child(post)
    if not child:
        raise Exception('Failed to get first child')
        
    child = await get_first_child(child)
    if not child:
        raise Exception('Failed to get second child')
        
    child = await get_first_child(child)
    if not child:
        raise Exception('Failed to get third child')
    
    # Get the username and handle links
    links = child.locator('> a')
    links_count = await links.count()
    if links_count != 2:
        raise Exception(f'Expected 2 links for username/handle, found {links_count}')
    
    # Extract username and handle
    username = await links.nth(0).inner_text(timeout=5000)
    username = username.translate(RM_CHARS).strip()
    
    handle = await links.nth(1).inner_text(timeout=5000)
    handle = handle.translate(RM_CHARS).strip()
    
    # Get post content
    first_child = await get_first_child(post.nth(1))
    if not first_child:
        raise Exception('Failed to get content section')
    content_text = await first_child.inner_text(timeout=5000)
    
    return username, handle, content_text


async def scrape_posts(page: Page):
    """ Scrape posts from homepage.
    """
    print('waiting for page to load...')
    # Wait for page load with generous timeouts
    await page.wait_for_load_state('domcontentloaded')
    await page.wait_for_timeout(5000)  # Initial wait
    
    # Wait for feed container.
    feed_selector = 'div.css-175oi2r'
    await page.wait_for_selector(feed_selector, state='visible', timeout=30000)
    print('page loaded!')

    # Get posts with explicit waits
    posts_selector = '> div > div.css-175oi2r.r-1loqt21.r-1otgn73 > div.css-175oi2r.r-1loqt21.r-1hfyk0a.r-ry3cjt'
    await page.wait_for_selector(feed_selector + ' ' + posts_selector, timeout=10000)
    
    posts = page.locator(feed_selector).locator(posts_selector)
    post_count = await posts.count()
    print(f"Number of posts found: {post_count}")

    if post_count < 1:
            print("No posts found - taking debug screenshots")
            await take_debug_screenshots(page, "no_posts")
            return

    # Process each post
    for i in range(post_count):
        post = posts.nth(i)
        post_data = await extract_post_data(post)
        
        if post_data:
            username, handle, content = post_data
            print(f'Post {i+1}/{post_count}:')
            print(f'  Username: {username}')
            print(f'  Handle: {handle}')
            print(f'  Content: {content}\n')