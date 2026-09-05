# NAME

WWW::Spotify - Spotify Web API Wrapper

# VERSION

version 1.000

# SYNOPSIS

    use WWW::Spotify ();

    # client id and secret default to $ENV{SPOTIFY_CLIENT_ID} and
    # $ENV{SPOTIFY_CLIENT_SECRET}; every request sends a bearer token
    my $spotify = WWW::Spotify->new();

    my $result;

    $result = $spotify->album('0sNOF9WDwhWunNAHPD3Baj');

    # $result is a json structure, you can operate on it directly
    # or you can use the "get" method see below

    $result = $spotify->albums_tracks( '6akEvsycLGftJxYudPjmqK',
    {
        limit => 1,
        offset => 1

    }
    );

    $result = $spotify->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

    $result = $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

    $result = $spotify->track( '0eGsygTp906u18L0Oimnem' );

    $result = $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 15 , offset => 0 }
    );

    my $names = $spotify->get('artists.items[*].name');

    # $names is an arrayref of every artist name in the search result

    # user-authorized (OAuth authorization code) flow: send the user to
    # authorize_url, exchange the returned code, then call /v1/me endpoints

    my $url = $spotify->authorize_url( { scope => 'playlist-read-private' } );
    my $code = 'CODE';    # the ?code= value Spotify appends to the redirect
    $spotify->get_access_token($code);

    $result = $spotify->get_current_user_playlists();

    my $link = $spotify->get('items[*].href');

    foreach my $playlist (@{$link}) {
        $spotify->query_full_url($playlist);
        my $pl_name = $spotify->get('name');
        print "$pl_name\n";
    }

# DESCRIPTION

Wrapper for the Spotify Web API.

https://developer.spotify.com/web-api/

Have access to a JSON viewer to help develop and debug. The Chrome JSON viewer is
very good and provides the exact path of the item within the JSON in the lower left
of the screen as you mouse over an element.

# UPGRADING FROM 0.017 OR EARLIER

Version 1.000 is a breaking release.  Besides removing the methods for
endpoints Spotify deleted in November 2024 and February 2026 (the full
list with replacements is in the Changes file), three things changed
that affect code calling the endpoints that survived:

- force\_client\_auth, result\_format, get\_oauth\_authorize

    Removed.  Every request now sends a bearer token, so there is nothing
    to force.  Passing `force_client_auth` to `new()` is silently ignored
    by Moo; calling it as a method dies.  Use ["authorize\_url"](#authorize_url) instead of
    `get_oauth_authorize`.

- custom\_request\_handler receives an HTTP::Response

    The callback used to get the WWW::Mechanize object.  It now gets the
    [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse), so `$m->status()` becomes `$res->code`
    and `$m->content()` becomes `$res->decoded_content`.

- last\_result holds UTF-8 bytes

    It was previously a character string.  Decode it with
    ["decode\_json" in JSON::MaybeXS](https://metacpan.org/pod/JSON%3A%3AMaybeXS#decode_json) (or set ["auto\_json\_decode"](#auto_json_decode)) rather than
    printing it to a `:utf8` handle.

# CONSTRUCTOR ARGS

## ua

You may provide your own user agent object to the constructor.  This should be
a [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent) or a subclass of it.  To get extra debugging
information, you can do something like this:

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use LWP::UserAgent ();
    use WWW::Spotify ();

    my $ua = LWP::UserAgent->new;
    debug_ua( $ua );
    my $spotify = WWW::Spotify->new( ua => $ua )

# METHODS

## auto\_json\_decode

When true results will be returned as JSON instead of a perl data structure

    $spotify->auto_json_decode(1);

## get

Returns a specific item or array of items from the JSON result of the
last action.

       $result = $spotify->search(
                           'tania bowra' ,
                           'artist' ,
                           { limit => 15 , offset => 0 }
       );

    my $image_url = $spotify->get( 'artists.items[0].images[0].url' );

JSON::Path is the underlying library that actually parses the JSON.

## query\_full\_url( $url , \[needs o\_auth\] )

Results from some calls (playlist for example) return full urls that can be in their entirety. This method allows you
make a call to that url and use all of the o\_auth and other features provided.

    $spotify->query_full_url( "https://api.spotify.com/v1/users/spotify/playlists/06U6mm6KPtPIg9D4YGNEnu" , 1 );

## album

equivalent to /v1/albums/{id}

    $spotify->album('0sNOF9WDwhWunNAHPD3Baj');

used album vs albums since it is a singular request

## albums\_tracks

equivalent to /v1/albums/{id}/tracks

    $spotify->albums_tracks('6akEvsycLGftJxYudPjmqK',
    {
        limit => 1,
        offset => 1

    }
    );

## artist

equivalent to /v1/artists/{id}

    $spotify->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

used artist vs artists since it is a singular request and avoids collision with "artists" method

## artist\_albums

equivalent to /v1/artists/{id}/albums

    $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

## search

equivalent to /v1/search?type=album (etc)

The query and any extras are UTF-8 encoded before escaping, so pass
character strings (decoded text), not UTF-8 bytes.

    $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 10 , offset => 0 }
    );

Note: as of the February 2026 API changes the maximum `limit` is 10
(previously 50); use `offset` to paginate.

## track

equivalent to /v1/tracks/{id}

    $spotify->track( '0eGsygTp906u18L0Oimnem' );

## get\_playlist

equivalent to GET /v1/playlists/{playlist\_id}

    $spotify->get_playlist('37i9dQZF1DXcBWIGoYBM5M');

This method retrieves a playlist owned by a Spotify user. The playlist must be public or owned by the authenticated user.

## get\_playlist\_items

equivalent to /v1/playlists/{playlist\_id}/items (renamed from /tracks in the
February 2026 API changes)

    $spotify->get_playlist_items('37i9dQZF1DXcBWIGoYBM5M', { limit => 10, offset => 0 });

## create\_playlist

equivalent to POST /v1/me/playlists (replaced /v1/users/{user\_id}/playlists
in the February 2026 API changes) - creates a playlist for the
authenticated user

    $spotify->create_playlist('My New Playlist', 1, 'A description of my playlist');

## get\_current\_user\_playlists

equivalent to /v1/me/playlists

    $spotify->get_current_user_playlists({ limit => 20, offset => 0 });

## add\_items\_to\_playlist

equivalent to /v1/playlists/{playlist\_id}/items (renamed from /tracks in the
February 2026 API changes)

    $spotify->add_items_to_playlist('playlist_id', ['spotify:track:4iV5W9uYEdYUVa79Axb7Rh', 'spotify:track:1301WleyT98MSxVHPZCA6M'], 0);

## unfollow\_playlist

equivalent to DELETE /v1/playlists/{playlist\_id}/followers - removes the
playlist from the authenticated user's library (Spotify has no hard
playlist delete)

    $spotify->unfollow_playlist('playlist_id');

## get\_followed\_artists

equivalent to /v1/me/following

    $spotify->get_followed_artists(
        limit => 20,
        after => '0I2XqVXqHScXjHhk6AYYRe'
    );

Note: This method always sets the 'type' parameter to 'artist' as it's the only supported value.

## save\_library\_items

equivalent to PUT /v1/me/library (February 2026 consolidated library
endpoint; replaces the removed PUT /v1/me/tracks, /v1/me/albums,
/v1/me/episodes, /v1/me/shows, /v1/me/audiobooks, /v1/me/following and
/v1/playlists/{id}/followers endpoints)

Takes Spotify URIs (not bare ids), as a comma-separated string or an
array reference.  Maximum 40 URIs.

    $spotify->save_library_items( [ 'spotify:track:7a3LWj5xSFhFRYmztS8wgK',
                                    'spotify:album:4aawyAB9vmqN3uQ7FjRGTy' ] );

## remove\_library\_items

equivalent to DELETE /v1/me/library (February 2026 consolidated library
endpoint; replaces the removed per-type DELETE endpoints)

    $spotify->remove_library_items( 'spotify:track:7a3LWj5xSFhFRYmztS8wgK' );

## check\_library\_items

equivalent to GET /v1/me/library/contains (February 2026 consolidated
library endpoint; replaces the removed per-type \*/contains endpoints)

    $spotify->check_library_items( [ 'spotify:track:7a3LWj5xSFhFRYmztS8wgK' ] );

## get\_audiobook

equivalent to GET /v1/audiobooks/{id}

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe');

or with market parameter:

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe', 'US');

## get\_users\_saved\_audiobooks

equivalent to GET /v1/me/audiobooks

    $spotify->get_users_saved_audiobooks(20, 0);

## get\_available\_markets

equivalent to GET /v1/markets

    $spotify->get_available_markets();

This method retrieves the list of markets where Spotify is available.

## get\_show

equivalent to GET /v1/shows/{id}

    $spotify->get_show('38bS44xjbVVZ3No3ByF1dJ', 'US');

This method retrieves Spotify catalog information for a single show identified by its unique Spotify ID.

## get\_show\_episodes

equivalent to GET /v1/shows/{id}/episodes

    $spotify->get_show_episodes('38bS44xjbVVZ3No3ByF1dJ', market => 'US', limit => 10, offset => 5);

This method retrieves Spotify catalog information about a show's episodes. Optional parameters can be used to limit the number of episodes returned.

## get\_audiobook\_chapters

equivalent to GET /v1/audiobooks/{id}/chapters

    $spotify->get_audiobook_chapters('3ZXb8FKZGU0EHALYX6uCzU', market => 'US', limit => 50, offset => 0);

This method retrieves the chapters of an audiobook.

## send\_delete\_request

Internal method used to send DELETE requests to the Spotify API.

## send\_put\_request

Internal method used to send PUT requests to the Spotify API.

## get\_users\_saved\_shows

equivalent to GET /v1/me/shows

    $spotify->get_users_saved_shows(limit => 20, offset => 0);

This method retrieves a list of shows saved in the current Spotify user's library. Optional parameters can be used to limit the number of shows returned.

## get\_chapter

equivalent to GET /v1/chapters/{id}

    $spotify->get_chapter('0D5wENdkdwbqlrHoaJ9g29', market => 'US');

## oauth\_client\_id

needed for requests that require OAuth, see Spotify API documentation for more information

    $spotify->oauth_client_id('2xfjijkcjidjkfdi');

Can also be set via environment variable, SPOTIFY\_CLIENT\_ID

## oauth\_client\_secret

needed for requests that require OAuth, see Spotify API documentation for more information

    $spotify->oauth_client_secret('2xfjijkcjidjkfdi');

Can also be set via environment variable, SPOTIFY\_CLIENT\_SECRET

## authorize\_url

builds the URL to send a user to for the OAuth authorization-code flow.
Uses `oauth_client_id` and `oauth_redirect_uri`; `scope` and `state`
are optional

    my $url = $spotify->authorize_url({
        scope => 'user-read-private playlist-modify-private',
        state => $random_string,
    });

Open the URL in a browser; after login Spotify redirects to
`oauth_redirect_uri` with a `code` query parameter.

## get\_access\_token

exchanges an authorization code (from the `authorize_url` redirect) for
a user access token. On success stores `current_access_token`,
`refresh_token`, and `token_expires_at`, and returns true

    $spotify->get_access_token($code);

## refresh\_access\_token

fetches a new access token using the stored `refresh_token` (set by
`get_access_token`). Dies if no refresh token is stored; returns true
on success

    $spotify->refresh_access_token();

## refresh\_token

the OAuth refresh token, set automatically by `get_access_token`. Can
be set manually to restore a persisted session

    $spotify->refresh_token($saved_refresh_token);

## response\_status

returns the response code for the last request made

    my $status = $spotify->response_status();

## response\_content\_type

returns the response type for the last request made, helpful to verify JSON

    my $content_type = $spotify->response_content_type();

## custom\_request\_handler

pass a callback subroutine to this method that will be run at the end of the
request prior to die\_on\_response\_error, if enabled

    # $res is the HTTP::Response object
    $spotify->custom_request_handler(
        sub { my $res = shift;
            if ($res->code == 401) {
                return 1;
            }
        }
    );

## custom\_request\_handler\_result

returns the result of the most recent execution of the custom\_request\_handler callback
this allows you to determine the success/failure criteria of your callback

    my $callback_result = $spotify->custom_request_handler_result();

## die\_on\_response\_error

Boolean - default 0

added to provide minimal automated checking of responses

    $spotify->die_on_response_error(1);

eval {
    # run assuming you do NOT have proper authentication setup
    $result = $spotify->album('0sNOF9WDwhWunNAHPD3Baj');
};

if ($@) {
    warn $spotify->last\_error();
}

## last\_error

returns last\_error (if applicable) from the most recent request.
reset to empty string on each request

    print $spotify->last_error() , "\n";

# THANKS

Paul Lamere at The Echo Nest / Spotify

All the great Perl community members that keep Perl fun

Olaf Alders for all his help and support in maintaining this module

# AUTHOR

Aaron Johnson <aaronjjohnson@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Aaron Johnson.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
