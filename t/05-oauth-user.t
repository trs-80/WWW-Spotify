#!perl
use strict;
use warnings;

use JSON::MaybeXS qw( encode_json );
use Test::More;
use WWW::Spotify ();

use lib 't/lib';
use MockUA ();

# ---------------------------------------------------------------------------
# authorize_url - pure URL builder, no network
# ---------------------------------------------------------------------------

{
    my $s = WWW::Spotify->new(
        oauth_client_id    => 'CLIENT123',
        oauth_redirect_uri => 'http://127.0.0.1:8888/callback',
    );

    my $url = $s->authorize_url(
        {
            scope => 'user-read-private playlist-modify-private',
            state => 'st4te',
        }
    );

    like(
        $url,
        qr{^https://accounts\.spotify\.com/authorize\?},
        'authorize_url starts with the accounts authorize endpoint'
    );
    like( $url, qr{client_id=CLIENT123}, 'client_id present' );
    like( $url, qr{response_type=code},  'response_type=code present' );
    like(
        $url,
        qr{redirect_uri=http%3A%2F%2F127\.0\.0\.1%3A8888%2Fcallback},
        'redirect_uri is URI-escaped'
    );
    like(
        $url,
        qr{scope=user-read-private(?:%20|\+)playlist-modify-private},
        'scope is escaped and space-joined'
    );
    like( $url, qr{state=st4te}, 'state present' );
}

{
    my $s = WWW::Spotify->new(
        oauth_client_id    => 'CLIENT123',
        oauth_redirect_uri => 'http://127.0.0.1:8888/callback',
    );

    my $url = $s->authorize_url();
    unlike( $url, qr{scope=}, 'scope omitted when not given' );
    unlike( $url, qr{state=}, 'state omitted when not given' );
}

# ---------------------------------------------------------------------------
# get_access_token - exchanges a real authorization code
# ---------------------------------------------------------------------------

{
    my $token_json = encode_json(
        {
            access_token  => 'user_access_tok',
            token_type    => 'Bearer',
            expires_in    => 3600,
            refresh_token => 'refresh_tok',
            scope         => 'user-read-private',
        }
    );

    my $mock = MockUA->new( content => $token_json );
    my $s    = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
        oauth_redirect_uri  => 'http://127.0.0.1:8888/callback',
    );

    my $before = time();
    my $result = $s->get_access_token('AUTHCODE99');
    my $after  = time();

    is(
        $mock->{last_url},
        'https://accounts.spotify.com/api/token',
        'get_access_token posts to the token endpoint'
    );
    is(
        $mock->{last_form}{grant_type},
        'authorization_code',
        'grant_type is authorization_code'
    );
    is(
        $mock->{last_form}{code}, 'AUTHCODE99',
        'the real code is posted, not a literal string'
    );
    is(
        $mock->{last_form}{redirect_uri},
        'http://127.0.0.1:8888/callback',
        'redirect_uri is posted'
    );
    like(
        $mock->{headers}{Authorization},
        qr{^Basic \S+$},
        'Basic auth header set on a single line'
    );

    is(
        $s->current_access_token(), 'user_access_tok',
        'access token stored'
    );
    is( $s->refresh_token(), 'refresh_tok', 'refresh token stored' );
    ok(
               $s->token_expires_at() >= $before + 3600
            && $s->token_expires_at() <= $after + 3600,
        'token_expires_at set from expires_in'
    );
    ok( $result, 'get_access_token returns true on success' );
}

{
    my $mock = MockUA->new( content => '{"error":"invalid_grant"}' );
    my $s    = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
        oauth_redirect_uri  => 'http://127.0.0.1:8888/callback',
    );

    my $result = $s->get_access_token('BADCODE');
    ok( !$result, 'get_access_token returns false on failure' );
    is( $s->current_access_token(), q{}, 'no token stored on failure' );
}

# ---------------------------------------------------------------------------
# refresh_access_token - uses the stored refresh token
# ---------------------------------------------------------------------------

{
    my $token_json = encode_json(
        {
            access_token => 'refreshed_tok',
            token_type   => 'Bearer',
            expires_in   => 3600,
        }
    );

    my $mock = MockUA->new( content => $token_json );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
        oauth_client_id      => 'id',
        oauth_client_secret  => 'secret',
        refresh_token        => 'refresh_tok',
        current_access_token => 'stale_tok',
    );

    my $result = $s->refresh_access_token();

    is(
        $mock->{last_url},
        'https://accounts.spotify.com/api/token',
        'refresh_access_token posts to the token endpoint'
    );
    is(
        $mock->{last_form}{grant_type}, 'refresh_token',
        'grant_type is refresh_token'
    );
    is(
        $mock->{last_form}{refresh_token},
        'refresh_tok', 'stored refresh token is posted'
    );

    is(
        $s->current_access_token(), 'refreshed_tok',
        'access token replaced'
    );
    is(
        $s->refresh_token(), 'refresh_tok',
        'refresh token kept when response omits a new one'
    );
    ok( $result, 'refresh_access_token returns true on success' );
}

{
    my $token_json = encode_json(
        {
            access_token  => 'refreshed_tok2',
            refresh_token => 'rotated_refresh',
            expires_in    => 3600,
        }
    );

    my $mock = MockUA->new( content => $token_json );
    my $s    = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
        refresh_token       => 'refresh_tok',
    );

    $s->refresh_access_token();
    is(
        $s->refresh_token(), 'rotated_refresh',
        'rotated refresh token replaces the stored one'
    );
}

{
    my $mock = MockUA->new();
    my $s    = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
    );

    eval { $s->refresh_access_token(); };
    like(
        $@,
        qr/refresh token/,
        'refresh_access_token dies without a stored refresh token'
    );
}

# ---------------------------------------------------------------------------
# D2: oauth_token_url must be an accounts.spotify.com URL
# ---------------------------------------------------------------------------

# 2a. get_client_credentials dies if oauth_token_url is set to an off-origin host.
{
    my $s = WWW::Spotify->new(
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
        oauth_token_url     => 'https://evil.example.com/steal',
    );
    eval { $s->get_client_credentials() };
    like(
        $@, qr/not allowed|invalid.*token.*url|token.*url.*not allowed/i,
        'D2: get_client_credentials dies when oauth_token_url is off-origin'
    );
}

# 2b. _request_token (used by get_access_token/refresh_access_token) also dies
#     for an off-origin oauth_token_url.
{
    my $s = WWW::Spotify->new(
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
        oauth_token_url     => 'https://evil.example.com/steal',
    );
    eval { $s->get_access_token('somecode') };
    like(
        $@, qr/not allowed|invalid.*token.*url|token.*url.*not allowed/i,
        'D2: get_access_token dies when oauth_token_url is off-origin'
    );
}

# 2c. The legitimate default URL must be accepted (no die).
{
    my $mock
        = MockUA->new( content => '{"access_token":"t","expires_in":3600}' );
    my $s = WWW::Spotify->new(
        ua                  => $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
    );
    eval { $s->get_client_credentials() };
    is(
        $@, '',
        'D2: get_client_credentials accepts the default accounts.spotify.com URL'
    );
}

done_testing();
