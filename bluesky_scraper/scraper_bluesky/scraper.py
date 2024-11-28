from playwright.async_api import Page
from datetime import datetime


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
    
async def get_first_child(locator: Page) -> Page|None:
    """Get first child of a locator."""
    count = await locator.locator("> *").count()
    if count > 0:
        return locator.locator("> *").nth(0)
    return None
    

async def scrape_posts(page: Page):
    """ Scrape posts from homepage.
    """
    print('waiting for page to load...')
    # Small delay to ensure all posts are rendered.
    await page.wait_for_load_state('domcontentloaded')
    await page.wait_for_timeout(10_000)
    #await page.wait_for_load_state('networkidle', timeout=10000)
    await page.wait_for_selector('div.css-175oi2r', state='visible', timeout=30_000)
    print('page loaded!')

    posts = page.locator('div.css-175oi2r').locator('> div > div.css-175oi2r.r-1loqt21.r-1otgn73 > div.css-175oi2r.r-1loqt21.r-1hfyk0a.r-ry3cjt')
    post_count = await posts.count()
    #print(await page.inner_text())
    print(f"Number of posts found: {post_count}")

    if post_count < 1:
        try:
            # Take both a full page screenshot and a screenshot of the visible area.
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            await page.screenshot(path=f"error_fullpage_{timestamp}.png", full_page=True)
            await page.screenshot(path=f"error_viewport_{timestamp}.png")
            
            # Optionally, save the page HTML for debugging
            html = await page.content()
            with open(f"error_page_{timestamp}.html", "w", encoding="utf-8") as f:
                f.write(html)
                
        except Exception as screenshot_error:
            print(f"Failed to capture error screenshots: {str(screenshot_error)}")

    for i in range(post_count):
        post = posts.nth(i)
        post = post.locator('div.css-175oi2r.r-18u37iz.r-1cvj4g8 > div.css-175oi2r.r-13awgt0.r-bnwqim.r-417010')
        post = post.locator('> *')

        children_num = await post.count()
        if children_num != 3:
            raise RuntimeError(f'a post locator should have 3 children. It has {children_num}')
        
        # Use await with get_first_child since it's now async
        child = await get_first_child(post)
        if not child:
            raise RuntimeError('error getting child of post')
        child = await get_first_child(child)
        if not child:
            raise RuntimeError('error getting child of child of post')
        child = await get_first_child(child)
        if not child:
            raise RuntimeError('error getting child of child of child of post')

        child_links = child.locator('> a')
        children_num = await child.count()
        if children_num != 2:
            raise RuntimeError(f'a username locator should have 2 children. It has {children_num}')

        username = await child_links.nth(0).inner_text()
        username = username.translate(RM_CHARS).strip()
        
        handle = await child_links.nth(1).inner_text()
        handle = handle.translate(RM_CHARS).strip()
        
        post_content = post.nth(1)
        first_content_child = await get_first_child(post_content)
        if first_content_child:
            contents_text = await first_content_child.inner_text()
        else:
            contents_text = "No content found"

        contents_text = get_first_child(post.nth(1)).inner_text()

        print(f'username:{username} handle:{handle} post:{contents_text}')