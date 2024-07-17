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
    skip 'No SPOTIFY_CLIENT_ID', 30 unless $ENV{SPOTIFY_CLIENT_ID};

    my $obj = WWW::Spotify->new();
    $obj->oauth_client_id($ENV{SPOTIFY_CLIENT_ID});
    $obj->oauth_client_secret($ENV{SPOTIFY_CLIENT_SECRET});
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

    ok( $obj->oauth_client_secret( $ENV{SPOTIFY_CLIENT_SECRET} ),
        'set client secret' );

    ok( $obj->get_client_credentials(), 'get client credentials' );

    # Test all GET endpoints
    $result = $obj->album('0sNOF9WDwhWunNAHPD3Baj');
    ok( $result =~ /name/, 'album endpoint works' );

    $result = $obj->albums('41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4');
    ok( $result =~ /albums/, 'albums endpoint works' );

    $result = $obj->albums_tracks('6akEvsycLGftJxYudPjmqK');
    ok( $result =~ /items/, 'albums_tracks endpoint works' );

    $result = $obj->artist('0LcJLqbBmaGUft1e9Mm8HV');
    ok( $result =~ /name/, 'artist endpoint works' );

    $result = $obj->artists('0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin');
    ok( $result =~ /artists/, 'artists endpoint works' );

    $result = $obj->artist_albums('1vCWHaC5f2uS3yhpwWbIA6');
    ok( $result =~ /items/, 'artist_albums endpoint works' );

    $result = $obj->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE', 'US' );
    ok( $result =~ /tracks/, 'artist_top_tracks endpoint works' );

    $result = $obj->artist_related_artists('43ZHCT0cAZBISjO8DG9PnE');
    ok( $result =~ /artists/, 'artist_related_artists endpoint works' );

    $result = $obj->track('0eGsygTp906u18L0Oimnem');
    ok( $result =~ /name/, 'track endpoint works' );

    $result = $obj->tracks('0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G');
    ok( $result =~ /tracks/, 'tracks endpoint works' );

    $result = $obj->user('spotify');
    ok( $result =~ /display_name/, 'user endpoint works' );

    $result = $obj->browse_featured_playlists();
    ok( $result =~ /playlists/, 'browse_featured_playlists endpoint works' );

    $result =
      $obj->browse_new_releases( { country => 'US', limit => 5, offset => 2 } );
    ok( $result =~ /albums/, 'browse_new_releases endpoint works' );

    $result =
      $obj->search( 'tania bowra', 'artist', { limit => 15, offset => 0 } );
    ok( $result =~ /artists/, 'search endpoint works' );

    $result = $obj->get_playlist('37i9dQZF1DXcBWIGoYBM5M');
    ok( $result =~ /name/, 'get_playlist endpoint works' );

    $result = $obj->get_playlist_items( '37i9dQZF1DXcBWIGoYBM5M',
        { limit => 10, offset => 0 } );
    ok( $result =~ /items/, 'get_playlist_items endpoint works' );

    $result = $obj->get_current_user_playlists( { limit => 20, offset => 0 } );
    ok( $result =~ /items/, 'get_current_user_playlists endpoint works' );

    $result = $obj->check_users_saved_tracks(
        [ '4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M' ] );
    ok( ref($result) eq 'ARRAY', 'check_users_saved_tracks endpoint works' );

    $result = $obj->get_several_tracks_audio_features(
        [ '4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M' ] );
    ok( $result =~ /audio_features/,
        'get_several_tracks_audio_features endpoint works' );

    $result = $obj->get_track_audio_features('4iV5W9uYEdYUVa79Axb7Rh');
    ok( $result =~ /id/, 'get_track_audio_features endpoint works' );

    $result = $obj->get_track_audio_analysis('4iV5W9uYEdYUVa79Axb7Rh');
    ok( $result =~ /track/, 'get_track_audio_analysis endpoint works' );

    $result = $obj->get_recommendations(
        seed_artists => '4NHQUGzhtTLFvgF5SZesLK',
        seed_genres  => 'classical,country',
        seed_tracks  => '0c6xIDDpzE81m2q797ordA',
        limit        => 10,
        market       => 'ES'
    );
    ok( $result =~ /tracks/, 'get_recommendations endpoint works' );

    $result = $obj->get_followed_artists( limit => 20 );
    ok( $result =~ /artists/, 'get_followed_artists endpoint works' );

    $result = $obj->check_if_user_follows_artists_or_users( 'artist',
        [ '2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E' ] );
    ok( ref($result) eq 'ARRAY',
        'check_if_user_follows_artists_or_users endpoint works' );

    $result = $obj->get_available_genre_seeds();
    ok( $result =~ /genres/, 'get_available_genre_seeds endpoint works' );

    $result = $obj->get_available_markets();
    ok( $result =~ /markets/, 'get_available_markets endpoint works' );
}

done_testing();
