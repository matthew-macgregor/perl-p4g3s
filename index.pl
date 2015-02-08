#!/usr/bin/perl

# The MIT License (MIT)
#
# Copyright (c) 2015 Matthew MacGregor
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


#use v5.14;
use warnings;
use strict;

use CGI;
use FindBin;
use lib "$FindBin::Bin/lib";
use Markdown;
use File::Path qw(rmtree);

#
# Global configuration data. 
#
my %config = (
    "site.title"        => "perl-p4g3s",
    "copyright"         => "&copy; 2015 You",
    "caching.enabled"   => 1
);

#
# Accepts an open file handle and extracts the metadata from a Unit,
# returning it as a string. Metadata is defined as occurring in a Unit
# from the beginning of the file until '...' is encountered.
#
sub readMetaFromFile {
    my $FH = shift;
    my $meta;

    my $first = <$FH>;
    $first = trim( $first);
    if ($first ne "---") {
        seek($FH, 0, 0);
        return "";
    }
    while ( <$FH> ){

        if( trim($_) eq "..."){

            last;
        }
        $meta .= "$_\n";

    }
    return $meta;
}

#
# Accepts a meta string and transforms it into a hash.
# Meta strings have the format:
#
# key: value
# key: value-text
# key: value1, value2, value3
#
sub transformMeta {
    my $metastr = shift;
    my %meta;
    for my $line ( split( "\n",  $metastr ) ) {
        chomp( $line );
        #TODO: if the line startswith #, ignore
        my ($k, $v) = newchomp(split( ":", $line, 2 ));
        #chomp($k, $v);
        if ( $k eq "tags" ) {
            my  @tags = split( ",", $v );
            $meta{$k} = \@tags;
        } else {
            $meta{$k} = $v;
        }
    }

   return %meta;
}


#
# Accepts an open file handle and extracts the markdown portion from
# a Unit. Markdown is considered to be everything following (and excluding)
# the '...'. This will also read the metadata from the header if it
# hasn't already been extracted. Be sure to readMetaFromFile first.
#
sub readMarkdownFromFile {
    my $FH = shift;
    my $text;
    while( <$FH> ) {
	    $text .= $_;
    }
    return $text;
}

#
# Reads a Unit (markdown file), extracting the metadata section first and
# text/markdown next.
#
# readUnit PATH
#
sub readUnit {
    my $filename = shift;
    if ( ! $filename ) { return ""; }
    open(my $FH, "<", $filename) or die "You can't open $filename!";
    my %meta = transformMeta(readMetaFromFile($FH));
    my $text = readMarkdownFromFile($FH);
    close($FH);
    $meta{text} = Markdown::Markdown($text);
    return %meta;
}


#
# Accepts a filename/path to a markdown file and returns the equivalent filename
# /path for the cached version.
#
# getCachedFilename FILENAME
#
sub getCachedFilename {
    my $ofn = shift;
    (my $fn = $ofn) =~ s/\.[^.]+$//;
    $fn .= ".html";

    if ( index($fn, 'cache') == -1 ) {
        $fn =~ s/data/data\/cache/;
    }

    return $fn;
}

#
# Creates the directories used by the caching functionality.
#
sub createCacheDirectories {

    if (! -d "data/cache" || ! -d "data/cache/post" || ! -d "data/cache/page") {
        mkdir( "data/cache" );
        mkdir( "data/cache/post" );
        mkdir( "data/cache/page" );
    }
}

#
# Does the work of caching. Accepts the filename for the cached file.
#
# cache HTML, FILENAME
#
sub cache {
    my $html = shift;
    my $ofn = shift;

    if( ! $config{"caching.enabled"} ) {
        return $html;
    }

    my $fn = getCachedFilename($ofn);
    createCacheDirectories();

    if( ! -e $fn ) {
        open( my $fh, '>', $fn ) or die "Could not open file '$fn d' $!";
        print $fh $html;
        close $fh;
    }

    return $html;
}

#
# Removes the entire data/cache/ directory tree.
#
sub clearCache {
    if( ! $config{"caching.enabled"} ) {
        return;
    }

    rmtree( "data/cache" );
}

#
# Attempts to use the cached version of a file. Accepts the uncached filename/
# path and translates this to the cached version.
#
# useCachedFile FILENAME
#
sub useCachedFile {
    if( ! $config{"caching.enabled"} ) {
        return "";
    }

    my $ofn = shift;
    my $fn = getCachedFilename( $ofn );
    my $html = "";

    if( -e $fn ) {
        if (open(my $fh, '<:encoding(UTF-8)', $fn)) {
            while (my $row = <$fh>) {
                $html .= $row;
            }
        } else {
            warn "Could not open file '$fn' $!";
        }
    }
    return $html; # returns empty string (false) if couldn't do anything.
}

#
# Render a single view (post, page).
#
# viewSingle FILENAME
#
sub viewSingle {
	my $fn = shift;
    my $html = useCachedFile( $fn );

    if( $html ) {
        return $html;
    }

	if( -e $fn ) {
		my %unit = readUnit($fn);
		$html = $unit{text};
		$html .= "<p class='post-date'>Posted: $unit{date} by $unit{author}</p>";
		return cache( view( $html ), $fn);
	} else {
		return view( error() );
	}
}

#
# Render a multi-view (home page).
#
# viewMulti FILELIST
#
sub viewMulti {

	my @fn = (glob shift);
    my $cachedHome = "data/cache/cached-home.html";
	my $html = useCachedFile( $cachedHome );

    if( $html ) {
        return $html;
    }

	for my $fn ( (sort { $b cmp $a } @fn)[0..7]) {
        my $pn = $fn;
        $pn =~ s/\.md$//;
        $pn =~ s|/data||;
        my %unit = readUnit($fn);
        if ( ! $unit{text} ) { last; }
        $html .= $unit{text};
        $html .= "<p class='post-date'>Posted: $unit{date} by $unit{author} | <a href='$pn'>View</a></p>\n<hr/>\n<br/>\n<br/>";
	}
	$html .= "<p class='center'>See more in the <a href='/archive'>Archive</a></p>\n";
	return cache( view( $html ), $cachedHome  );

}

#
# Renders the archive view.
#
# viewArchive FILELIST
#
sub viewArchive {
	my @fn = (glob shift);

	my $html = "<h3>Archive</h3>\n";
	$html .= "<table>";
	for my $fn (sort { $b cmp $a } @fn) {
		my %unit = readUnit($fn);
		my $title = $unit{'post.title'};
		my $date = $unit{'date'};
		if (! $title ) { next; }
		my ($postid) = $fn =~ m|post/([\w-]+)\.md|;
		$html .= "<tr><td class='list'><a href='/post/$postid'>[$date]</a>&nbsp;&nbsp;</td>\n";
		$html .= "<td class='list'><a href='/post/$postid'>$title</a></td></tr>\n";
	}
	$html.= "</table>\n";
	return view( $html );
}


#
# Renders a message that the cache was cleared.
#
# viewCacheCleared BOOL
#
sub viewCacheCleared {
    my $result = shift;
    my $not = ( $result ) ? "" : "NOT";
    my $msg = "<h3>System Notice</h3>";
    $msg .= "<p>The cached files were $not cleared.</p>";
    return $msg ;
}

#
# Provides an error message.
#
sub error {
    my $error = "<h3>Oh, shit</h3>";
    $error .= "<p>Whatever you were looking for doesn't seem to be here any more...</p>";
    return $error ;
}


#
# Manages the routes for the application.
#
sub routes {
   my ($cgi) = @_;
   my $route = $cgi->param('q');
   if ( ! $route ) {
     $route = '/';
   }
   #print $ENV{REQUEST_URI} . "<br/>"; #/blog/
   #print $ENV{SERVER_NAME} . "<br/>"; #webserver.local
   if ($route eq '/') {
		print viewMulti( "data/post/*.md" );
   } elsif (my ($post) = $route =~ m|post/([\w-]+)|) {
   		print viewSingle( "data/post/$post.md" );
   } elsif (my ($page) = $route =~ m|page/([\w-]+)|) {
		print viewSingle( "data/page/$page.md" );
   } elsif ( $route eq 'archive' ) {
   		print viewArchive( "data/post/*.md" );
   } elsif ( $route eq 'rmcache' ) {
        my $result = clearCache();
        print( view( viewCacheCleared($result) ));
   } else {
		print( view(error()) );
   }
}

#
# Chomps white space from a string or array of string, and returns the value or
# an array of values.
#
sub newchomp {
	my @strs;
	for my $str (@_) {
        $str = trim( $str );
		# $str =~ s/^\s+//; # strip white space from the beginning
    	# $str =~ s/\s+$//; # strip white space from the end
    	push( @strs, $str );
    }
    return wantarray ? @strs : $strs[0]; #expected behavior
}

#
# Trims whitespace from front and back of string.
#
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

#
# ----------------------------------------------------------------------------
#                                    MAIN
# ----------------------------------------------------------------------------
#
#
sub main {

    my $cgi = CGI->new();
    print $cgi->header(-type=>"text/html; charset=utf-8");
    routes($cgi);

}

unless (caller) {
    main();
}


#
# Renders the wrapper html for all views.
#
sub view {
    my $html = shift;
    my $title = $config{"site.title"};
    my $copyright = $config{"copyright"};

    return <<HTML;
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <meta charset="UTF-8">
    <link href='http://fonts.googleapis.com/css?family=Open+Sans' rel='stylesheet' type='text/css'>
    <link href='/site/styles.css' rel='stylesheet' type='text/css'>
    <link href="//maxcdn.bootstrapcdn.com/font-awesome/4.2.0/css/font-awesome.min.css" rel="stylesheet">
    <script src="https://google-code-prettify.googlecode.com/svn/loader/run_prettify.js"></script>
    <meta name="viewport" content="width=device-width" />
</head>
<body>
    <div class="header">
        <div class="top">
            <div class="navbar">
                <div class="blog-title">
                    <h1 class="title">$title</h1>
                </div>
                <div class="nav-links">
                    <a href="/"><i class="fa fa-home"></i> home</a>
                    <a href="/archive"><i class="fa fa-database"></i> archives</a>
                    <a href="/page/about"><i class="fa fa-male"></i>about</a>
                </div>
            </div>
        </div>
    </div>
    <hr/>
    <div class="main">
        $html
        <footer>
            <p>Created with perl-p4g3s</p>
            <p>$copyright</p>
        </footer>
    </div>
</body>
</html>
HTML

}
