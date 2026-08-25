#!perl
use strict;
use warnings;

use HTTP::Response ();
use HTTP::Status   qw( HTTP_OK HTTP_NO_CONTENT HTTP_UNAUTHORIZED );
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

sub clone       { return $_[0] }    # _mech calls clone() on ua
sub add_header  { my ( $self, $k, $v ) = @_; $self->{headers}{$k} = $v }
sub status      { $_[0]->{status} }
sub content     { $_[0]->{content} }
sub content_type { $_[0]->{content_type} }
sub ct          { $_[0]->{content_type} }

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
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    $s->send_get_request( { method => 'album', params => { id => 'ABC123' } } );

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
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    my $full = 'https://api.spotify.com/v1/some/custom/path';
    $s->send_get_request( { method => 'query_full_url', url => $full } );

    is( $mock->{last_url}, $full,
        'send_get_request passes query_full_url through unchanged' );
}

# ---------------------------------------------------------------------------
# send_get_request — extra query params appended
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
    );

    $s->send_get_request(
        {
            method => 'album',
            params => { id => 'X1' },
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
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth    => 1,
        current_access_token => 'mytoken',
    );

    $s->send_get_request( { method => 'album', params => { id => 'X2' } } );

    is(
        $mock->{headers}{Authorization},
        'Bearer mytoken',
        'send_get_request sets Authorization header'
    );
}

# ---------------------------------------------------------------------------
# send_post_request — verb, URL, and body
# add_items_to_playlist maps to /v1/playlists/{playlist_id}/tracks
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_OK );
    my $s = SpotifyTestable->new(
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
        qr{/v1/playlists/PL1/tracks},
        'send_post_request builds correct URL'
    );
    like(
        $mock->{last_content},
        qr{PL1},
        'send_post_request serialises params as JSON body'
    );
}

# ---------------------------------------------------------------------------
# send_put_request — verb and URL
# save_shows_for_current_user maps to /v1/me/shows
# ---------------------------------------------------------------------------

{
    my $mock = MockMech->new( status => HTTP_NO_CONTENT );
    my $s = SpotifyTestable->new(
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
    my $s = SpotifyTestable->new(
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

    is( $mock->{last_verb}, 'delete', 'send_delete_request uses DELETE verb' );
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
        force_client_auth    => 0,
        current_access_token => 'tok',
        die_on_response_error => 1,
    );

    eval {
        $s->send_get_request(
            { method => 'album', params => { id => 'X' } } );
    };
    like( $@, qr/request failed/, 'send_get_request dies on error when die_on_response_error=1' );
}

{
    my $mock = MockMech->new(
        status       => HTTP_UNAUTHORIZED,
        content_type => 'application/json',
    );
    my $s = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        die_on_response_error => 1,
    );

    eval {
        $s->send_post_request(
            { method => 'create_playlist', params => { user_id => 'me' } } );
    };
    like( $@, qr/request failed/, 'send_post_request dies on error when die_on_response_error=1' );
}

done_testing();
