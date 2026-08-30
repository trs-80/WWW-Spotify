#!perl
use strict;
use warnings;

use JSON::MaybeXS qw( encode_json );
use Test::More;
use WWW::Spotify ();

# ---------------------------------------------------------------------------
# Mock mech that records post() form params and returns a canned response
# ---------------------------------------------------------------------------

package MockTokenMech;

sub new {
    my ( $class, %args ) = @_;
    return bless {
        content     => $args{content} // '{}',
        headers     => {},
        last_url    => undef,
        last_params => undef,
    }, $class;
}

sub clone      { return $_[0] }
sub add_header { my ( $self, $k, $v ) = @_; $self->{headers}{$k} = $v }
sub status     { 200 }
sub content    { $_[0]->{content} }

sub post {
    my ( $self, $url, $form ) = @_;
    $self->{last_url}    = $url;
    $self->{last_params} = ref $form eq 'ARRAY' ? $form->[0] : $form;
}

package SpotifyOauthTestable;
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
# authorize_url — pure URL builder, no network
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
# get_access_token — exchanges a real authorization code
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

    my $mock = MockTokenMech->new( content => $token_json );
    my $s    = SpotifyOauthTestable->new(
        $mock,
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
        $mock->{last_params}{grant_type},
        'authorization_code',
        'grant_type is authorization_code'
    );
    is(
        $mock->{last_params}{code}, 'AUTHCODE99',
        'the real code is posted, not a literal string'
    );
    is(
        $mock->{last_params}{redirect_uri},
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
    my $mock = MockTokenMech->new( content => '{"error":"invalid_grant"}' );
    my $s    = SpotifyOauthTestable->new(
        $mock,
        oauth_client_id     => 'id',
        oauth_client_secret => 'secret',
        oauth_redirect_uri  => 'http://127.0.0.1:8888/callback',
    );

    my $result = $s->get_access_token('BADCODE');
    ok( !$result, 'get_access_token returns false on failure' );
    is( $s->current_access_token(), q{}, 'no token stored on failure' );
}

# ---------------------------------------------------------------------------
# refresh_access_token — uses the stored refresh token
# ---------------------------------------------------------------------------

{
    my $token_json = encode_json(
        {
            access_token => 'refreshed_tok',
            token_type   => 'Bearer',
            expires_in   => 3600,
        }
    );

    my $mock = MockTokenMech->new( content => $token_json );
    my $s    = SpotifyOauthTestable->new(
        $mock,
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
        $mock->{last_params}{grant_type}, 'refresh_token',
        'grant_type is refresh_token'
    );
    is(
        $mock->{last_params}{refresh_token},
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

    my $mock = MockTokenMech->new( content => $token_json );
    my $s    = SpotifyOauthTestable->new(
        $mock,
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
    my $mock = MockTokenMech->new();
    my $s    = SpotifyOauthTestable->new(
        $mock,
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

done_testing();
