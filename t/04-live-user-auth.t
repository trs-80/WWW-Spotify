use strict;
use warnings;

use Test::More;
use Test::RequiresInternet (
    'accounts.spotify.com' => 443,
    'api.spotify.com'      => 443,
);
use WWW::Spotify ();

# -----------------------------------------------------------------------------
# Tests for endpoints that require USER AUTHORIZATION (OAuth with user scopes).
# These endpoints access /v1/me/* resources and require a user access token.
#
# Required environment variables:
#   SPOTIFY_CLIENT_ID     - Your Spotify app client ID
#   SPOTIFY_CLIENT_SECRET - Your Spotify app client secret
#   SPOTIFY_USER_TOKEN    - A valid user access token with appropriate scopes
#
# Required scopes for these tests:
#   - playlist-read-private (for get_current_user_playlists)
#   - user-library-read (for check_users_saved_tracks)
#   - user-follow-read (for get_followed_artists, check_if_user_follows_artists_or_users)
#
# For client-credentials tests, see t/02-live.t
# -----------------------------------------------------------------------------

SKIP: {
    skip
        'No SPOTIFY_USER_TOKEN - user auth tests require a user access token',
        4
        unless $ENV{SPOTIFY_USER_TOKEN};

    my $obj = WWW::Spotify->new();
    $obj->current_access_token( $ENV{SPOTIFY_USER_TOKEN} );

    my $result;

    # Current user's playlists (requires playlist-read-private scope)
    $result
        = $obj->get_current_user_playlists( { limit => 20, offset => 0 } );
    ok( $result =~ /items/, 'get_current_user_playlists endpoint works' );

    # Check saved tracks (requires user-library-read scope)
    # Returns JSON array string like '[true,false]', not a Perl array ref
    $result = $obj->check_users_saved_tracks(
        [ '4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M' ] );
    ok( $result =~ /^\[/, 'check_users_saved_tracks endpoint works' );

    # Followed artists (requires user-follow-read scope)
    $result = $obj->get_followed_artists( limit => 20 );
    ok( $result =~ /artists/, 'get_followed_artists endpoint works' );

    # Check if user follows artists (requires user-follow-read scope)
    # Returns JSON array string like '[true,false]', not a Perl array ref
    $result = $obj->check_if_user_follows_artists_or_users(
        'artist',
        [ '2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E' ]
    );
    ok(
        $result =~ /^\[/,
        'check_if_user_follows_artists_or_users endpoint works'
    );
}

# -----------------------------------------------------------------------------
# Tests for endpoints that may work with client credentials but have known
# issues (deprecated, changed API, etc.)
#
# These are wrapped in TODO blocks as they may fail due to:
# - Spotify API changes or deprecations
# - Rate limiting
# - Regional restrictions
# -----------------------------------------------------------------------------

SKIP: {
    skip 'No SPOTIFY_CLIENT_ID', 7 unless $ENV{SPOTIFY_CLIENT_ID};

    my $obj = WWW::Spotify->new();
    $obj->oauth_client_id( $ENV{SPOTIFY_CLIENT_ID} );
    $obj->oauth_client_secret( $ENV{SPOTIFY_CLIENT_SECRET} );
    $obj->get_client_credentials();

    my $result;

TODO: {
        local $TODO = 'Playlist endpoints may require investigation';

        # Public playlist endpoints (should work with client credentials)
        $result = $obj->get_playlist('37i9dQZF1DXcBWIGoYBM5M');
        ok( $result =~ /name/, 'get_playlist endpoint works' );

        $result = $obj->get_playlist_items(
            '37i9dQZF1DXcBWIGoYBM5M',
            { limit => 10, offset => 0 }
        );
        ok( $result =~ /items/, 'get_playlist_items endpoint works' );
    }

TODO: {
        local $TODO
            = 'Audio features/analysis endpoints may be deprecated or restricted';

        $result = $obj->get_several_tracks_audio_features(
            [ '4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M' ] );
        ok(
            $result =~ /audio_features/,
            'get_several_tracks_audio_features endpoint works'
        );

        $result = $obj->get_track_audio_features('4iV5W9uYEdYUVa79Axb7Rh');
        ok( $result =~ /id/, 'get_track_audio_features endpoint works' );

        $result = $obj->get_track_audio_analysis('4iV5W9uYEdYUVa79Axb7Rh');
        ok( $result =~ /track/, 'get_track_audio_analysis endpoint works' );
    }

TODO: {
        local $TODO
            = 'Recommendations endpoint may be deprecated or restricted';

        $result = $obj->get_recommendations(
            seed_artists => '4NHQUGzhtTLFvgF5SZesLK',
            seed_genres  => 'classical,country',
            seed_tracks  => '0c6xIDDpzE81m2q797ordA',
            limit        => 10,
            market       => 'ES'
        );
        ok( $result =~ /tracks/, 'get_recommendations endpoint works' );

        $result = $obj->get_available_genre_seeds();
        ok( $result =~ /genres/, 'get_available_genre_seeds endpoint works' );
    }
}

done_testing();
