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

use lib 't/lib';
use MockUA ();

use utf8;

sub mocked {
    my %args = @_;
    my $mock = MockUA->new( status => HTTP_OK, %args );
    my $s    = WWW::Spotify->new(
        ua                   => $mock,
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

    $s->search( 'Björk', 'artist' );
    like(
        $mock->{last_url}, qr{q=Bj%C3%B6rk},
        'search UTF-8 encodes non-ASCII query text before escaping'
    );
}

# ---------------------------------------------------------------------------
# S3: get() must give a meaningful error when last_result is empty or non-JSON
# ---------------------------------------------------------------------------

# 3a. Calling get() before any request has been made (last_result is '')
{
    my $s = WWW::Spotify->new();
    eval { $s->get('artists.items[0].name') };
    like(
        $@, qr/no result/i,
        'get() gives a clear error when last_result is empty'
    );
}

# 3b. Calling get() when the last response was non-JSON (e.g. an HTML error page)
{
    my $s = WWW::Spotify->new();
    $s->last_result('<html><body>503 Service Unavailable</body></html>');
    eval { $s->get('name') };
    like(
        $@, qr/not valid JSON/i,
        'get() gives a clear error when last_result is not valid JSON'
    );
}

# ---------------------------------------------------------------------------
# D1: older methods must die with a clear error on undef/empty ID
# ---------------------------------------------------------------------------

{
    my ($s) = mocked();

    for my $call (
        [ 'album',                 sub { $s->album(undef) } ],
        [ 'album (empty string)',  sub { $s->album('') } ],
        [ 'artist',                sub { $s->artist(undef) } ],
        [ 'artist (empty string)', sub { $s->artist('') } ],
        [ 'artist_albums',         sub { $s->artist_albums(undef) } ],
        [ 'track',                 sub { $s->track(undef) } ],
        [ 'get_playlist',          sub { $s->get_playlist(undef) } ],
        [ 'get_playlist_items',    sub { $s->get_playlist_items(undef) } ],
    ) {
        my ( $label, $code ) = @$call;
        eval { $code->() };
        like(
            $@, qr/required/i,
            "D1: $label dies with 'required' on missing ID"
        );
    }
}

# ---------------------------------------------------------------------------
# S4: format_results must not crash with a raw die when auto_json_decode is on
#     and the API returns non-JSON content
# ---------------------------------------------------------------------------

# 4a. Non-JSON response body with auto_json_decode => 1 must give a clear error,
#     not a raw Cpanel::JSON::XS/JSON::XS parse crash.
{
    my $mock = MockUA->new(
        status  => 200,
        content => '<html>Service Unavailable</html>',
    );
    my $s = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
        auto_json_decode     => 1,
    );

    eval { $s->album('ABC123') };
    like(
        $@, qr/not valid JSON|invalid JSON|json/i,
        'S4: auto_json_decode=1 gives clear error on non-JSON response'
    );
}

# 4b. Valid JSON with auto_json_decode => 1 must return a decoded data structure.
{
    use JSON::MaybeXS qw( encode_json );
    my $payload = encode_json( { name => 'My Album' } );
    my $mock    = MockUA->new( status => 200, content => $payload );
    my $s       = WWW::Spotify->new(
        ua                   => $mock,
        current_access_token => 'tok',
        token_expires_at     => time() + 3600,
        auto_json_decode     => 1,
    );

    my $result = eval { $s->album('ABC123') };
    is(
        $@, '',
        'S4: auto_json_decode=1 does not die on valid JSON response'
    );
    is(
        ref($result), 'HASH',
        'S4: auto_json_decode=1 returns a decoded hashref'
    );
    is( $result->{name}, 'My Album', 'S4: decoded result has correct value' );
}

# ---------------------------------------------------------------------------
# S5: search() must die clearly on undef/empty $q or $type
# ---------------------------------------------------------------------------

{
    my ($s) = mocked();

    for my $call (
        [ 'search undef q',    sub { $s->search( undef,       'track' ) } ],
        [ 'search empty q',    sub { $s->search( '',          'track' ) } ],
        [ 'search undef type', sub { $s->search( 'beethoven', undef ) } ],
        [ 'search empty type', sub { $s->search( 'beethoven', '' ) } ],
    ) {
        my ( $label, $code ) = @$call;
        eval { $code->() };
        like( $@, qr/required/i, "S5: $label dies with 'required'" );
    }
}

# ---------------------------------------------------------------------------
# S6: albums_tracks / add_items_to_playlist / unfollow_playlist need ID guards
# ---------------------------------------------------------------------------

{
    my ($s) = mocked();

    for my $call (
        [ 'albums_tracks undef', sub { $s->albums_tracks(undef) } ],
        [ 'albums_tracks empty', sub { $s->albums_tracks('') } ],
        [
            'add_items_to_playlist undef',
            sub { $s->add_items_to_playlist( undef, ['spotify:track:abc'] ) }
        ],
        [
            'add_items_to_playlist empty',
            sub { $s->add_items_to_playlist( '', ['spotify:track:abc'] ) }
        ],
        [ 'unfollow_playlist undef', sub { $s->unfollow_playlist(undef) } ],
        [ 'unfollow_playlist empty', sub { $s->unfollow_playlist('') } ],
    ) {
        my ( $label, $code ) = @$call;
        eval { $code->() };
        like( $@, qr/required/i, "S6: $label dies with 'required'" );
    }
}

done_testing();
