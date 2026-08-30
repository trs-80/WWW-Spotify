use strict;
use warnings;

use Data::Dumper qw( Dumper );

use Test::More;
use Test::RequiresInternet (
    'accounts.spotify.com' => 443,
    'api.spotify.com'      => 443,
    'www.spotify.com'      => 80,
);
use WWW::Spotify ();

SKIP: {
    skip 'No SPOTIFY_CLIENT_ID', 9 unless $ENV{SPOTIFY_CLIENT_ID};

    my $obj = WWW::Spotify->new();
    $obj->oauth_client_id( $ENV{SPOTIFY_CLIENT_ID} );
    $obj->oauth_client_secret( $ENV{SPOTIFY_CLIENT_SECRET} );
    $obj->get_client_credentials();

    sub show_and_pause {
        if ( $obj->debug() ) {
            my $show = shift;
            print Dumper($show);
            sleep 5;
        }
    }

    my $result;

    ok( $obj->oauth_client_id( $ENV{SPOTIFY_CLIENT_ID} ), 'set client id' );

    ok(
        $obj->oauth_client_secret( $ENV{SPOTIFY_CLIENT_SECRET} ),
        'set client secret'
    );

    ok( $obj->get_client_credentials(), 'get client credentials' );

    # GET /v1/albums/{id} — single album, works with client credentials
    $result = $obj->album('0sNOF9WDwhWunNAHPD3Baj');
    ok( $result =~ /name/, 'album endpoint works' );

    # GET /v1/albums/{id}/tracks — album tracks, works with client credentials
    $result = $obj->albums_tracks('6akEvsycLGftJxYudPjmqK');
    ok( $result =~ /items/, 'albums_tracks endpoint works' );

    # GET /v1/artists/{id} — single artist, works with client credentials
    $result = $obj->artist('0LcJLqbBmaGUft1e9Mm8HV');
    ok( $result =~ /name/, 'artist endpoint works' );

    # GET /v1/artists/{id}/albums — artist albums, works with client credentials
    $result = $obj->artist_albums('1vCWHaC5f2uS3yhpwWbIA6');
    ok( $result =~ /items/, 'artist_albums endpoint works' );

    # GET /v1/tracks/{id} — single track, works with client credentials
    $result = $obj->track('0eGsygTp906u18L0Oimnem');
    ok( $result =~ /name/, 'track endpoint works' );

    # GET /v1/search — search, works with client credentials
    $result = $obj->search(
        'tania bowra', 'artist',
        { limit => 10, offset => 0 }
    );
    ok( $result =~ /artists/, 'search endpoint works' );
}

done_testing();
