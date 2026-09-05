#!perl
use strict;
use warnings;

use HTTP::Response ();
use HTTP::Status   qw( HTTP_OK HTTP_NO_CONTENT HTTP_UNAUTHORIZED );
use JSON::MaybeXS  qw( encode_json );
use Test::More;
use WWW::Spotify ();

use lib 't/lib';
use MockUA ();

# ---------------------------------------------------------------------------
# send_get_request - URL building
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        { method => 'album', params => { id => 'ABC123' } } );

    like(
        $mock->{last_url},
        qr{https://api\.spotify\.com/v1/albums/ABC123},
        'send_get_request builds correct URL for album'
    );
    is( $mock->{last_verb}, 'get', 'send_get_request uses GET verb' );
}

# ---------------------------------------------------------------------------
# send_get_request - query_full_url passthrough
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    my $full = 'https://api.spotify.com/v1/some/custom/path';
    $s->send_get_request( { method => 'query_full_url', url => $full } );

    is(
        $mock->{last_url}, $full,
        'send_get_request passes query_full_url through unchanged'
    );
}

# ---------------------------------------------------------------------------
# send_get_request - extra query params appended
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        {
            method => 'album',
            params => { id    => 'X1' },
            extras => { limit => 5 },
        }
    );

    like(
        $mock->{last_url},
        qr{limit=5},
        'send_get_request appends extras as query params'
    );
}

# ---------------------------------------------------------------------------
# send_get_request - auth header set when token present
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'mytoken',
        token_expires_at     => time() + 3600,
    );
    $s->token_expires_at( time() + 3600 );    # token is not expired

    $s->send_get_request( { method => 'album', params => { id => 'X2' } } );

    is(
        $mock->{headers}{Authorization},
        'Bearer mytoken',
        'send_get_request sets Authorization header'
    );
}

# ---------------------------------------------------------------------------
# send_post_request - verb, URL, and body
# add_items_to_playlist maps to /v1/playlists/{playlist_id}/items
# (renamed from /tracks in the Feb 2026 API changes)
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_post_request(
        {
            method => 'add_items_to_playlist',
            params => { playlist_id => 'PL1', uris => 'spotify:track:X' },
        }
    );

    is( $mock->{last_verb}, 'post', 'send_post_request uses POST verb' );
    like(
        $mock->{last_url},
        qr{/v1/playlists/PL1/items},
        'send_post_request builds correct URL'
    );
    like(
        $mock->{last_content},
        qr{spotify:track:X},
        'send_post_request serialises non-path params as JSON body'
    );
    unlike(
        $mock->{last_content},
        qr{PL1},
        'params consumed by the URL path are excluded from the body'
    );
}

# add_items_to_playlist body shape: uris must be a JSON array, position
# omitted unless given (the API rejects a string uris with "No uris provided")
{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->add_items_to_playlist( 'PL1', 'spotify:track:X' );
    like(
        $mock->{last_content},
        qr{"uris":\["spotify:track:X"\]},
        'a single uri string is sent as a JSON array'
    );
    unlike(
        $mock->{last_content}, qr{position},
        'position omitted when not given'
    );

    $s->add_items_to_playlist(
        'PL1',
        [ 'spotify:track:X', 'spotify:track:Y' ], 0
    );
    like(
        $mock->{last_content},
        qr{"uris":\["spotify:track:X","spotify:track:Y"\]},
        'an arrayref of uris is sent as a JSON array'
    );
    like(
        $mock->{last_content}, qr{"position":0},
        'position included when given'
    );
}

# ---------------------------------------------------------------------------
# send_put_request - verb and URL
# save_library_items maps to /v1/me/library
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_NO_CONTENT );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_put_request(
        {
            method => 'save_library_items',
            params => { uris => 'spotify%3Ashow%3A1' },
        }
    );

    is( $mock->{last_verb}, 'put', 'send_put_request uses PUT verb' );
    like(
        $mock->{last_url},
        qr{/v1/me/library},
        'send_put_request builds correct URL'
    );
}

# ---------------------------------------------------------------------------
# send_delete_request - verb and URL
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_delete_request(
        {
            method => 'remove_library_items',
            params => { uris => 'spotify%3Atrack%3A1' },
        }
    );

    is(
        $mock->{last_verb}, 'delete',
        'send_delete_request uses DELETE verb'
    );
    like(
        $mock->{last_url},
        qr{/v1/me/library},
        'send_delete_request builds correct URL'
    );
}

# ---------------------------------------------------------------------------
# die_on_response_error honoured across all verbs
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new(
        status       => HTTP_UNAUTHORIZED,
        content_type => 'application/json',
    );
    my $s = WWW::Spotify->new(
        ua                    => $mock,
        current_access_token  => 'tok',
        token_expires_at      => time() + 3600,
        die_on_response_error => 1,
    );

    eval {
        $s->send_get_request(
            { method => 'album', params => { id => 'X' } } );
    };
    like(
        $@, qr/request failed/,
        'send_get_request dies on error when die_on_response_error=1'
    );
}

{
    my $mock = MockUA->new(
        status       => HTTP_UNAUTHORIZED,
        content_type => 'application/json',
    );
    my $s = WWW::Spotify->new(
        ua                    => $mock,
        current_access_token  => 'tok',
        token_expires_at      => time() + 3600,
        die_on_response_error => 1,
    );

    eval {
        $s->send_post_request(
            { method => 'create_playlist', params => { user_id => 'me' } } );
    };
    like(
        $@, qr/request failed/,
        'send_post_request dies on error when die_on_response_error=1'
    );
}

# ---------------------------------------------------------------------------
# URL-building correctness for previously-broken methods
# (duplicate hash key collisions in %api_call_options)
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        { method => 'get_users_saved_audiobooks', params => {} } );
    like(
        $mock->{last_url}, qr{/v1/me/audiobooks},
        'get_users_saved_audiobooks builds correct URL'
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        { method => 'get_users_saved_shows', params => {} } );
    like(
        $mock->{last_url}, qr{/v1/me/shows},
        'get_users_saved_shows builds correct URL'
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        { method => 'get_followed_artists', params => { type => 'artist' } }
    );
    like(
        $mock->{last_url}, qr{/v1/me/following},
        'get_followed_artists builds correct URL'
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->create_playlist( 'My List', 0, 'desc' );
    like(
        $mock->{last_url}, qr{/v1/me/playlists},
        'create_playlist posts to /v1/me/playlists (Feb 2026 change)'
    );
    like(
        $mock->{last_content}, qr{"name":"My List"},
        'create_playlist sends name in JSON body'
    );
    unlike(
        $mock->{last_content}, qr{user_id},
        'create_playlist body has no user_id'
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        {
            method => 'get_playlist_items', params => { playlist_id => 'pl1' }
        }
    );
    like(
        $mock->{last_url}, qr{/v1/playlists/pl1/items},
        'get_playlist_items builds correct URL (Feb 2026 /items rename)'
    );
}

# ---------------------------------------------------------------------------
# User-authorized playlist methods send the Authorization header
# ---------------------------------------------------------------------------

for my $call (
    [
        get_current_user_playlists =>
            sub { $_[0]->get_current_user_playlists() }
    ],
    [ create_playlist => sub { $_[0]->create_playlist( 'u1', 'n' ) } ],
    [
        add_items_to_playlist =>
            sub { $_[0]->add_items_to_playlist( 'pl1', 'spotify:track:X' ) }
    ],
    [ get_playlist_items => sub { $_[0]->get_playlist_items('pl1') } ],
    [ unfollow_playlist  => sub { $_[0]->unfollow_playlist('pl1') } ],
) {
    my ( $name, $invoke ) = @$call;
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'usertok',
        token_expires_at     => time() + 3600,
    );

    $invoke->($s);
    is(
        $mock->{headers}{Authorization}, 'Bearer usertok',
        "$name sends Authorization header"
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->unfollow_playlist('pl9');
    is( $mock->{last_verb}, 'delete', 'unfollow_playlist uses DELETE verb' );
    like(
        $mock->{last_url}, qr{/v1/playlists/pl9/followers},
        'unfollow_playlist builds correct URL'
    );
}

# ---------------------------------------------------------------------------
# Feb 2026 consolidated library endpoints (/v1/me/library)
# ---------------------------------------------------------------------------

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->save_library_items( [ 'spotify:track:AAA', 'spotify:album:BBB' ] );

    is( $mock->{last_verb}, 'put', 'save_library_items uses PUT verb' );
    like(
        $mock->{last_url},
        qr{/v1/me/library\?uris=spotify%3Atrack%3AAAA%2Cspotify%3Aalbum%3ABBB},
        'save_library_items sends escaped uris as query param'
    );
    ok(
        !defined $mock->{last_content},
        'save_library_items sends no request body'
    );
    ok(
        !exists $mock->{headers}{'Content-Type'},
        'save_library_items sends no Content-Type header'
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->remove_library_items('spotify:track:AAA');

    is(
        $mock->{last_verb}, 'delete',
        'remove_library_items uses DELETE verb'
    );
    like(
        $mock->{last_url},
        qr{/v1/me/library\?uris=spotify%3Atrack%3AAAA},
        'remove_library_items sends escaped uris as query param'
    );
}

{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->check_library_items( ['spotify:track:AAA'] );

    is( $mock->{last_verb}, 'get', 'check_library_items uses GET verb' );
    like(
        $mock->{last_url},
        qr{/v1/me/library/contains\?uris=spotify%3Atrack%3AAAA},
        'check_library_items sends escaped uris as query param'
    );
}

# ---------------------------------------------------------------------------
# Token auto-refresh tests
# ---------------------------------------------------------------------------

# Test 1: expired token triggers a re-fetch of client credentials
{
    my $token_json = encode_json(
        {
            access_token => 'new_token',
            token_type   => 'Bearer',
            expires_in   => 3600,
        }
    );

    my $mock = MockUA->new(
        status         => HTTP_OK,
        token_response => $token_json,
    );

    my $s = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'old_token',
        token_expires_at     => time() + 3600,
        oauth_client_id      => 'id',
        oauth_client_secret  => 'secret',
    );

    # Backdate the expiry so the token appears expired
    $s->token_expires_at( time() - 1 );

    $s->send_get_request( { method => 'album', params => { id => 'X' } } );

    is(
        $mock->{post_calls}, 1,
        'expired token triggers get_client_credentials'
    );
    is(
        $mock->{headers}{Authorization}, 'Bearer new_token',
        'new token is used after refresh'
    );
}

# Test 2: valid (unexpired) token is NOT re-fetched
{
    my $mock = MockUA->new( status => HTTP_OK );

    my $s = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'valid_token',
        token_expires_at     => time() + 3600,
        oauth_client_id      => 'id',
        oauth_client_secret  => 'secret',
    );

    # Token expires well in the future
    $s->token_expires_at( time() + 3600 );

    $s->send_get_request( { method => 'album', params => { id => 'Y' } } );

    is(
        $mock->{post_calls}, 0,
        'valid token does not trigger get_client_credentials'
    );
    is(
        $mock->{headers}{Authorization}, 'Bearer valid_token',
        'existing valid token is used unchanged'
    );
}

# Test 3: get_client_credentials stores token_expires_at after a successful fetch
{
    my $token_json = encode_json(
        {
            access_token => 'fresh_token',
            token_type   => 'Bearer',
            expires_in   => 3600,
        }
    );

    my $mock = MockUA->new(
        status         => HTTP_OK,
        token_response => $token_json,
    );

    my $s = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
    );

    my $before = time();
    $s->get_client_credentials();
    my $after = time();

    ok(
               $s->token_expires_at() >= $before + 3600
            && $s->token_expires_at() <= $after + 3600,
        'get_client_credentials sets token_expires_at to time() + expires_in'
    );
}

# ---------------------------------------------------------------------------
# S1: query_full_url origin validation (SSRF / token-leak prevention)
# ---------------------------------------------------------------------------

# 1a. A URL on the allowed origin (api.spotify.com) must be sent normally.
{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->query_full_url('https://api.spotify.com/v1/me/playlists');

    is(
        $mock->{last_url},
        'https://api.spotify.com/v1/me/playlists',
        'query_full_url passes allowed origin through unchanged'
    );
    is(
        $mock->{headers}{Authorization},
        'Bearer tok',
        'query_full_url sends auth header for allowed origin'
    );
}

# 1b. A URL on a different host must be rejected (die) when auth would be sent.
{
    my $mock = MockUA->new( status => HTTP_OK );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    eval { $s->query_full_url('https://evil.example.com/steal'); };
    like(
        $@, qr/not allowed/i,
        'query_full_url dies for off-origin credentialed URL'
    );
    is(
        $mock->{last_url}, undef,
        'query_full_url makes no HTTP request for off-origin URL'
    );
}

# 1c. next_result_set / previous_result_set feed query_full_url from API data -
#     a non-Spotify "next" URL in the response must be rejected.
{
    my $evil_json = encode_json(
        {
            next => 'https://evil.example.com/exfiltrate',
        }
    );
    my $mock = MockUA->new( status => HTTP_OK, content => $evil_json );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    # Seed last_result so get('next') returns the evil URL
    $s->last_result($evil_json);

    eval { $s->next_result_set() };
    like(
        $@, qr/not allowed/i,
        'next_result_set rejects off-origin URL from API response'
    );
    is(
        $mock->{last_url}, undef,
        'next_result_set makes no HTTP request for off-origin URL'
    );
}

# ---------------------------------------------------------------------------
# D5: uri_hostname and uri_scheme must be read-only (ro)
# ---------------------------------------------------------------------------

# 5a. Attempting to mutate uri_hostname via the accessor must die.
{
    my $s = WWW::Spotify->new();
    eval { $s->uri_hostname('evil.example.com') };
    like(
        $@, qr/read.?only|cannot|modify|Usage/i,
        'D5: uri_hostname is read-only - cannot be changed after construction'
    );
}

# 5b. Attempting to mutate uri_scheme via the accessor must die.
{
    my $s = WWW::Spotify->new();
    eval { $s->uri_scheme('http') };
    like(
        $@, qr/read.?only|cannot|modify|Usage/i,
        'D5: uri_scheme is read-only - cannot be changed after construction'
    );
}

# 5c. The values set at construction time are honoured.
{
    my $s = WWW::Spotify->new(
        uri_hostname => 'api.spotify.com',
        uri_scheme   => 'https',
    );
    is(
        $s->uri_hostname, 'api.spotify.com',
        'D5: uri_hostname readable after construction'
    );
    is(
        $s->uri_scheme, 'https',
        'D5: uri_scheme readable after construction'
    );
}

# ---------------------------------------------------------------------------
# D4: response_status and response_content_type must have safe defaults
# ---------------------------------------------------------------------------

# Calling send_post_request checks response_content_type() in a regex before
# any response has arrived.  Without a default the attribute is undef and Perl
# emits "Use of uninitialized value in pattern match".
# Verify both attributes exist and are defined on a freshly constructed object.
{
    my $s = WWW::Spotify->new();
    ok(
        defined $s->response_status(),
        'D4: response_status is defined on a fresh object'
    );
    ok(
        defined $s->response_content_type(),
        'D4: response_content_type is defined on a fresh object'
    );
    is( $s->response_status(), 0, 'D4: response_status defaults to 0' );
    is(
        $s->response_content_type(), '',
        'D4: response_content_type defaults to empty string'
    );
}

# ---------------------------------------------------------------------------
# D3: get_client_credentials must die (not silently continue) on token failure
# ---------------------------------------------------------------------------

# When the token endpoint returns no access_token (e.g. wrong credentials,
# rate limited, etc.) the caller must get a clear exception, not silent
# continuation that leads to a Bearer '' request later.
{
    my $mock = MockUA->new(
        status         => HTTP_OK,
        token_response => '{"error":"invalid_client"}',
    );

    my $s = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'wrong_secret',
    );

    eval { $s->get_client_credentials() };
    like(
        $@, qr/failed.*token|token.*fail|access token/i,
        'D3: get_client_credentials dies when token endpoint returns no access_token'
    );
}

done_testing();
