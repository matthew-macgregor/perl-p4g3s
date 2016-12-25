Welcome to perl-p4g3s (Perl-Pages)
==================================

![Perl-Pages](/site/img/camel.jpeg)

Getting started with perl-p4g3s is pretty easy. Check out the code from
GitHub. The project contains a starter folder structure:

    site-root/
        data/
            page/
            post/
        lib/
        site/
            img/

* **index.pl**: This is the main application script.
* **data**: Contains two subdirectories, one to store **pages/** and the
other for **posts/**. The contents of pages and posts and just markdown files with
some metadata in the header.
* **lib**: Contains Markdown.pl, for transforming Markdown to html.
* **site**: Stylesheets and JavaScript go here. This is just a convention, you can
put them where you like.
* **site/img**: Home for images, although you could put them anywhere.

Format for Posts:
----------------------------------

All content in perl-p4g3s is markdown with a (semi) required header. The header
is used to provide metadata for the post, such as author's name, post date, etc.

The header has the following format:

    ---
    post.title: Friendly Title
    author: Your Name
    date: 02/08/2015
    tags: comma, delimited, tags, no-spaces-allowed
    ---

If you don't include the header, nothing will blow up but your post won't show
up in the archive correctly.

Posts use a naming convention to cleverly sort the posts into order. Use the
following naming format:

    YYYYMMDD-name-of-your-post-no-spaces.md
    20150215-my-awesome-post.md

Technically, the numeric id doesn't need to be a date, it could just be an number.
Just make sure that the id is larger for the newest posts so they sort correctly.

Drop an appropriately-named markdown file into the post/ directory, make sure it
has the right metadata in the header, and perl-p4g3s will process it.

Format for Pages:
----------------------------------

The format for pages is identical to the format for posts. The only difference
is:

1. Pages will route to domain.com/page/pagename.
2. Pages won't show up in the archive of posts, and won't display on the home
page.
3. Pages don't require the date-based naming convention like posts.

See? Easy!

Caching:
----------------------------------

perl-p4g3s provides built-in static file caching. The first time that a page or
post is fetched, it will be stored in the cache/ directory. Future requests will
simply use this cached html instead of parsing the markdown again.

If you want to disable this behavior (for example, if you're working on the site
and don't want to have to keep clearing the cache), you can do so with the
config setting:

    "caching.enabled" => 0

Switching this to 0 will disable all caching behaviors. It is recommended that
you leave caching enabled in production.

When you update content, you may need to clear the cache before it will show up.
To do this, you can simply make a request to the *rmcache* endpoint:

    http://your-domain-name.com/rmcache

This will delete the entire cached data tree. If you want to make sure that the
cache is primed, make one request to each page or post. At the very least, you
can prime the cache for the home page. The Archives page is never cached.
