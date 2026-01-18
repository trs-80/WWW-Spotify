use strict;
use warnings;

use Test::More;
use Test::RequiresInternet (
    'accounts.spotify.com' => 443,
    'api.spotify.com'      => 443,
);
use WWW::Spotify ();

# -----------------------------------------------------------------------------
# Tests for endpoints that work with CLIENT CREDENTIALS (app-level auth).
# For tests requiring USER authorization, see t/04-live-user-auth.t
# -----------------------------------------------------------------------------

SKIP: {
    skip 'No SPOTIFY_CLIENT_ID', 16 unless $ENV{SPOTIFY_CLIENT_ID};

    my $obj = WWW::Spotify->new();
    $obj->oauth_client_id( $ENV{SPOTIFY_CLIENT_ID} );
    $obj->oauth_client_secret( $ENV{SPOTIFY_CLIENT_SECRET} );

    my $result;

    ok( $obj->oauth_client_id( $ENV{SPOTIFY_CLIENT_ID} ), 'set client id' );
    ok(
        $obj->oauth_client_secret( $ENV{SPOTIFY_CLIENT_SECRET} ),
        'set client secret'
    );
    ok( $obj->get_client_credentials(), 'get client credentials' );

    # Album endpoints
    $result = $obj->album('0sNOF9WDwhWunNAHPD3Baj');
    ok( $result =~ /name/, 'album endpoint works' );

    $result = $obj->albums('41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4');
    ok( $result =~ /albums/, 'albums endpoint works' );

    $result = $obj->albums_tracks('6akEvsycLGftJxYudPjmqK');
    ok( $result =~ /items/, 'albums_tracks endpoint works' );

    # Artist endpoints
    $result = $obj->artist('0LcJLqbBmaGUft1e9Mm8HV');
    ok( $result =~ /name/, 'artist endpoint works' );

    $result = $obj->artists('0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin');
    ok( $result =~ /artists/, 'artists endpoint works' );

    $result = $obj->artist_albums('1vCWHaC5f2uS3yhpwWbIA6');
    ok( $result =~ /items/, 'artist_albums endpoint works' );

    $result = $obj->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE', 'US' );
    ok( $result =~ /tracks/, 'artist_top_tracks endpoint works' );

    # Track endpoints
    $result = $obj->track('0eGsygTp906u18L0Oimnem');
    ok( $result =~ /name/, 'track endpoint works' );

    $result = $obj->tracks('0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G');
    ok( $result =~ /tracks/, 'tracks endpoint works' );

    # User endpoint (public user info)
    $result = $obj->user('spotify');
    ok( $result =~ /display_name/, 'user endpoint works' );

    # Browse endpoints
    $result = $obj->browse_new_releases(
        { country => 'US', limit => 5, offset => 2 } );
    ok( $result =~ /albums/, 'browse_new_releases endpoint works' );

    # Search endpoint
    $result = $obj->search(
        'tania bowra', 'artist',
        { limit => 15, offset => 0 }
    );
    ok( $result =~ /artists/, 'search endpoint works' );

    # Markets endpoint
    $result = $obj->get_available_markets();
    ok( $result =~ /markets/, 'get_available_markets endpoint works' );
}

done_testing();
