#!perl

# Mocked replacements for the long-dead live tests that sat in a =pod
# block in t/01-spotify.t: catalog method URL building and response
# handling, no network.

use strict;
use warnings;

use HTTP::Status  qw( HTTP_OK );
use JSON::MaybeXS qw( encode_json );
use Test::More;
use WWW::Spotify ();

package MockMech;

sub new {
    my ( $class, %args ) = @_;
    return bless {
        status       => $args{status}       // 200,
        content      => $args{content}      // '{}',
        content_type => $args{content_type} // 'application/json',
        headers      => {},
        last_url     => undef,
    }, $class;
}

sub clone        { return $_[0] }
sub add_header   { my ( $self, $k, $v ) = @_; $self->{headers}{$k} = $v }
sub status       { $_[0]->{status} }
sub content      { $_[0]->{content} }
sub content_type { $_[0]->{content_type} }
sub ct           { $_[0]->{content_type} }
sub get          { my ( $self, $url ) = @_; $self->{last_url} = $url }

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

# suppress the (already-tested) deprecation warnings for removed endpoints
local $SIG{__WARN__} = sub { };

sub mocked {
    my %args = @_;
    my $mock = MockMech->new( status => HTTP_OK, %args );
    my $s    = SpotifyTestable->new(
        $mock,
        force_client_auth    => 0,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
    );
    return ( $s, $mock );
}

# ---------------------------------------------------------------------------
# Living catalog methods
# ---------------------------------------------------------------------------

{
    my ( $s, $mock ) = mocked();
    $s->albums_tracks(
        '6akEvsycLGftJxYudPjmqK',
        { limit => 5, offset => 1 }
    );
    like(
        $mock->{last_url}, qr{/v1/albums/6akEvsycLGftJxYudPjmqK/tracks},
        'albums_tracks builds correct URL'
    );
    like( $mock->{last_url}, qr{limit=5},  'albums_tracks appends limit' );
    like( $mock->{last_url}, qr{offset=1}, 'albums_tracks appends offset' );
}

{
    my ( $s, $mock ) = mocked();
    $s->artist('0LcJLqbBmaGUft1e9Mm8HV');
    like(
        $mock->{last_url}, qr{/v1/artists/0LcJLqbBmaGUft1e9Mm8HV},
        'artist builds correct URL'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->artist_albums(
        '1vCWHaC5f2uS3yhpwWbIA6',
        { album_type => 'single', limit => 2, offset => 0 }
    );
    like(
        $mock->{last_url}, qr{/v1/artists/1vCWHaC5f2uS3yhpwWbIA6/albums},
        'artist_albums builds correct URL'
    );
    like(
        $mock->{last_url}, qr{album_type=single},
        'artist_albums appends album_type'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->track('0eGsygTp906u18L0Oimnem');
    like(
        $mock->{last_url}, qr{/v1/tracks/0eGsygTp906u18L0Oimnem},
        'track builds correct URL'
    );
}

# ---------------------------------------------------------------------------
# search + get() JSON path traversal
# ---------------------------------------------------------------------------

{
    my $search_json = encode_json(
        {
            artists => {
                items => [
                    {
                        name   => 'Tania Bowra',
                        images =>
                            [ { url => 'https://img.example/tania.jpg' } ],
                    }
                ],
            },
        }
    );

    my ( $s, $mock ) = mocked( content => $search_json );
    my $result
        = $s->search( 'tania bowra', 'artist', { limit => 15, offset => 0 } );

    like( $mock->{last_url}, qr{/v1/search\?}, 'search hits /v1/search' );
    like(
        $mock->{last_url},
        qr{q=tania(?:%20|\+)bowra},
        'search escapes the query term'
    );
    like( $mock->{last_url}, qr{type=artist}, 'search passes type' );
    like( $mock->{last_url}, qr{limit=15},    'search appends extras' );

    is(
        $s->get('artists.items[0].images[0].url'),
        'https://img.example/tania.jpg',
        'get() traverses the last result with a JSON path'
    );
}

# ---------------------------------------------------------------------------
# Removed/deprecated catalog methods still build their historical URLs
# ---------------------------------------------------------------------------

{
    my ( $s, $mock ) = mocked();
    $s->albums('41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4');
    like(
        $mock->{last_url},
        qr{/v1/albums\?ids=41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4},
        'albums (comma string) builds correct URL'
    );

    $s->albums( [ '41MnTivkwTO3UUJ8DrqEJJ', '6JWc4iAiJ9FjyK0B59ABb4' ] );
    like(
        $mock->{last_url},
        qr{/v1/albums\?ids=41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4},
        'albums (arrayref) joins ids'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->artists('0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin');
    like(
        $mock->{last_url}, qr{/v1/artists\?ids=0oSGxfWSnnOXhD2fKuz2Gy},
        'artists builds correct URL'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->tracks( [ '0eGsygTp906u18L0Oimnem', '1lDWb6b6ieDQ2xT7ewTC3G' ] );
    like(
        $mock->{last_url},
        qr{/v1/tracks\?ids=0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G},
        'tracks (arrayref) joins ids'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE', 'SE' );
    like(
        $mock->{last_url},
        qr{/v1/artists/43ZHCT0cAZBISjO8DG9PnE/top-tracks},
        'artist_top_tracks builds correct URL'
    );
    like(
        $mock->{last_url}, qr{country=SE},
        'artist_top_tracks passes country'
    );
    unlike(
        $mock->{last_url}, qr{client_auth_required},
        'internal auth flag does not leak into the query string'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->artist_related_artists('43ZHCT0cAZBISjO8DG9PnE');
    like(
        $mock->{last_url},
        qr{/v1/artists/43ZHCT0cAZBISjO8DG9PnE/related-artists},
        'artist_related_artists builds correct URL'
    );
}

{
    my ( $s, $mock ) = mocked();
    $s->user('glennpmcdonald');
    like(
        $mock->{last_url}, qr{/v1/users/glennpmcdonald},
        'user builds correct URL'
    );
}

done_testing();
