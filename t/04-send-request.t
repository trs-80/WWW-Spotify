#!perl
use strict;
use warnings;

use HTTP::Response ();
use HTTP::Status   qw( HTTP_OK HTTP_NO_CONTENT HTTP_UNAUTHORIZED );
use JSON::MaybeXS  qw( encode_json );
use Test::More;
use WWW::Spotify ();

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Build a minimal mock mechanize object that records the last HTTP verb/URL
# called and returns a canned HTTP::Response.
package MockMech;

sub new {
    my ( $class, %args ) = @_;
    return bless {
        status       => $args{status}       // 200,
        content      => $args{content}      // '{}',
        content_type => $args{content_type} // 'application/json',
        headers      => {},
        last_verb    => undef,
        last_url     => undef,
        last_content => undef,
    }, $class;
}

sub clone        { return $_[0] }    # _mech calls clone() on ua
sub add_header   { my ( $self, $k, $v ) = @_; $self->{headers}{$k} = $v }
sub status       { $_[0]->{status} }
sub content      { $_[0]->{content} }
sub content_type { $_[0]->{content_type} }
sub ct           { $_[0]->{content_type} }

sub get {
    my ( $self, $url ) = @_;
    $self->{last_verb} = 'get';
    $self->{last_url}  = $url;
}

sub post {
    my ( $self, $url, %args ) = @_;
    $self->{last_verb}    = 'post';
    $self->{last_url}     = $url;
    $self->{last_content} = $args{Content};
}

sub put {
    my ( $self, $url, %args ) = @_;
    $self->{last_verb}    = 'put';
    $self->{last_url}     = $url;
    $self->{last_content} = $args{Content};
}

sub delete {
    my ( $self, $url, %args ) = @_;
    $self->{last_verb}    = 'delete';
    $self->{last_url}     = $url;
    $self->{last_content} = $args{Content};
}

# SpotifyTestable overrides ua so _mech returns our MockMech
package SpotifyTestable;
use parent -norequire, 'WWW::Spotify';

sub new {
    my ( $class, $mock, %args ) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{_mock} = $mock;
    return $self;
}

sub _mech { return $_[0]->{_mock} }

package main;

# ---------------------------------------------------------------------------
# send_get_request — URL building
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
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
# send_get_request — query_full_url passthrough
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    my $full = 'https://api.spotify.com/v1/some/custom/path';
    $s->send_get_request( { method => 'query_full_url', url => $full } );

    is(
        $mock->{last_url}, $full,
        'send_get_request passes query_full_url through unchanged'
    );
}

# ---------------------------------------------------------------------------
# send_get_request — extra query params appended
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
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
# send_get_request — auth header set when token present
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 1,
        current_access_token => 'mytoken',
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
# send_post_request — verb, URL, and body
# add_items_to_playlist maps to /v1/playlists/{playlist_id}/items
# (renamed from /tracks in the Feb 2026 API changes)
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
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
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
# send_put_request — verb and URL
# save_shows_for_current_user maps to /v1/me/shows
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_NO_CONTENT );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    $s->send_put_request(
        {
            method => 'save_shows_for_current_user',
            params => { ids => 'show1' },
        }
    );

    is( $mock->{last_verb}, 'put', 'send_put_request uses PUT verb' );
    like(
        $mock->{last_url},
        qr{/v1/me/shows},
        'send_put_request builds correct URL'
    );
}

# ---------------------------------------------------------------------------
# send_delete_request — verb and URL
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    $s->send_delete_request(
        {
            method => 'remove_user_saved_tracks',
            params => { ids => 'track1' },
        }
    );

    is(
        $mock->{last_verb}, 'delete',
        'send_delete_request uses DELETE verb'
    );
    like(
        $mock->{last_url},
        qr{/v1/me/tracks},
        'send_delete_request builds correct URL'
    );
}

# ---------------------------------------------------------------------------
# die_on_response_error honoured across all verbs
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new(
        status       => HTTP_UNAUTHORIZED,
        content_type => 'application/json',
    );
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth     => 0,
        current_access_token  => 'tok',
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
    my $mock = MockMech->new(
        status       => HTTP_UNAUTHORIZED,
        content_type => 'application/json',
    );
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth     => 0,
        current_access_token  => 'tok',
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
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    my $mock = MockMech->new( status => HTTP_NO_CONTENT );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_put_request(
        {
            method => 'save_audiobooks_for_current_user',
            params => { ids => 'ab1' }
        }
    );
    like(
        $mock->{last_url}, qr{/v1/me/audiobooks},
        'save_audiobooks_for_current_user builds correct URL'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_delete_request(
        {
            method => 'remove_users_saved_audiobooks',
            params => { ids => 'ab1' }
        }
    );
    like(
        $mock->{last_url}, qr{/v1/me/audiobooks},
        'remove_users_saved_audiobooks builds correct URL'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    my $mock = MockMech->new( status => HTTP_NO_CONTENT );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_put_request(
        {
            method => 'save_shows_for_current_user',
            params => { ids => 'sh1' }
        }
    );
    like(
        $mock->{last_url}, qr{/v1/me/shows},
        'save_shows_for_current_user builds correct URL'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    my $mock = MockMech->new( status => HTTP_NO_CONTENT );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_put_request(
        {
            method => 'follow_artists_or_users',
            params => { type => 'artist', ids => 'id1' }
        }
    );
    like(
        $mock->{last_url}, qr{/v1/me/following},
        'follow_artists_or_users builds correct URL'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_delete_request(
        {
            method => 'unfollow_artists_or_users',
            params => { type => 'artist', ids => 'id1' }
        }
    );
    like(
        $mock->{last_url}, qr{/v1/me/following},
        'unfollow_artists_or_users builds correct URL'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );

    $s->send_get_request(
        { method => 'user_playlist', params => { user_id => 'u1' } } );
    like(
        $mock->{last_url}, qr{/v1/users/u1/playlists},
        'user_playlist builds correct URL'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
# User-authorized playlist methods must always send the Authorization
# header, even with force_client_auth=0 (their endpoints reject
# unauthenticated requests)
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
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'usertok',
        token_expires_at     => time() + 3600,
    );

    $invoke->($s);
    is(
        $mock->{headers}{Authorization}, 'Bearer usertok',
        "$name sends Authorization header despite force_client_auth=0"
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    is(
        $mock->{last_content}, '',
        'save_library_items sends no request body'
    );
}

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
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
# Deprecated-endpoint methods warn (once) but still send the request
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    $s->send_get_request(
        { method => 'get_several_chapters', params => { ids => 'c1,c2' } } );

    is( scalar(@warnings), 1, 'deprecated method warns' );
    like(
        $warnings[0],
        qr{get_several_chapters.*removed},
        'warning names the method and reason'
    );
    like(
        $mock->{last_url}, qr{/v1/chapters},
        'request is still sent for deprecated method'
    );

    $s->send_get_request(
        { method => 'get_several_chapters', params => { ids => 'c1,c2' } } );
    is(
        scalar(@warnings), 1,
        'deprecation warning fires only once per method'
    );
}

# ---------------------------------------------------------------------------
# Token auto-refresh tests
# ---------------------------------------------------------------------------

# MockMechTokenRefresh: returns a canned token response when post() is called
# (simulates the Spotify token endpoint), and tracks how many times
# get_client_credentials was called so we can assert refresh behaviour.
package MockMechTokenRefresh;

use JSON::MaybeXS qw( encode_json );

sub new {
    my ( $class, %args ) = @_;
    return bless {
        status         => $args{status}       // 200,
        content        => $args{content}      // '{}',
        content_type   => $args{content_type} // 'application/json',
        token_response => $args{token_response},    # optional JSON string
        headers        => {},
        last_verb      => undef,
        last_url       => undef,
        post_calls     => 0,
    }, $class;
}

sub clone        { return $_[0] }
sub add_header   { my ( $self, $k, $v ) = @_; $self->{headers}{$k} = $v }
sub status       { $_[0]->{status} }
sub content_type { $_[0]->{content_type} }
sub ct           { $_[0]->{content_type} }

sub content {
    my $self = shift;

    # After a POST (token fetch), return the token response if configured.
    if ( $self->{last_verb} eq 'post' && $self->{token_response} ) {
        return $self->{token_response};
    }
    return $self->{content};
}

sub get {
    my ( $self, $url ) = @_;
    $self->{last_verb} = 'get';
    $self->{last_url}  = $url;
}

sub post {
    my ( $self, $url, @rest ) = @_;
    $self->{last_verb} = 'post';
    $self->{last_url}  = $url;
    $self->{post_calls}++;
}

sub put {
    my ( $self, $url, @rest ) = @_;
    $self->{last_verb} = 'put';
    $self->{last_url}  = $url;
}

sub delete {
    my ( $self, $url, @rest ) = @_;
    $self->{last_verb} = 'delete';
    $self->{last_url}  = $url;
}

# SpotifyRefreshable: SpotifyTestable variant that uses MockMechTokenRefresh
package SpotifyRefreshable;
use parent -norequire, 'WWW::Spotify';

sub new {
    my ( $class, $mock, %args ) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{_mock}              = $mock;
    $self->{_credentials_calls} = 0;
    return $self;
}

sub _mech { return $_[0]->{_mock} }

sub get_client_credentials {
    my $self = shift;
    $self->{_credentials_calls}++;
    return $self->SUPER::get_client_credentials(@_);
}

package main;

# Test 1: expired token triggers a re-fetch of client credentials
{
    my $token_json = encode_json(
        {
            access_token => 'new_token',
            token_type   => 'Bearer',
            expires_in   => 3600,
        }
    );

    my $mock = MockMechTokenRefresh->new(
        status         => HTTP_OK,
        token_response => $token_json,
    );

    my $s = SpotifyRefreshable->new(
        $mock,
        force_client_auth    => 1,
        current_access_token => 'old_token',
        oauth_client_id      => 'id',
        oauth_client_secret  => 'secret',
    );

    # Backdate the expiry so the token appears expired
    $s->token_expires_at( time() - 1 );

    $s->send_get_request( { method => 'album', params => { id => 'X' } } );

    is(
        $s->{_credentials_calls}, 1,
        'expired token triggers get_client_credentials'
    );
    is(
        $mock->{headers}{Authorization}, 'Bearer new_token',
        'new token is used after refresh'
    );
}

# Test 2: valid (unexpired) token is NOT re-fetched
{
    my $mock = MockMechTokenRefresh->new( status => HTTP_OK );

    my $s = SpotifyRefreshable->new(
        $mock,
        force_client_auth    => 1,
        current_access_token => 'valid_token',
        oauth_client_id      => 'id',
        oauth_client_secret  => 'secret',
    );

    # Token expires well in the future
    $s->token_expires_at( time() + 3600 );

    $s->send_get_request( { method => 'album', params => { id => 'Y' } } );

    is(
        $s->{_credentials_calls}, 0,
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

    my $mock = MockMechTokenRefresh->new(
        status         => HTTP_OK,
        token_response => $token_json,
    );

    my $s = SpotifyRefreshable->new(
        $mock,
        force_client_auth   => 0,
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

done_testing();
