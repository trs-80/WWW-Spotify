# NAME

WWW::Spotify - Spotify Web API Wrapper

# VERSION

version 0.014

# SYNOPSIS

    use WWW::Spotify ();

    my $spotify = WWW::Spotify->new();

    my $result;

    $result = $spotify->album('0sNOF9WDwhWunNAHPD3Baj');

    # $result is a json structure, you can operate on it directly
    # or you can use the "get" method see below

    $result = $spotify->albums( '41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4,6UXCm6bOO4gFlDQZV5yL37' );

    $result = $spotify->albums_tracks( '6akEvsycLGftJxYudPjmqK',
    {
        limit => 1,
        offset => 1

    }
    );

    $result = $spotify->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

    my $artists_multiple = '0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin';

    $result = $spotify->artists( $artists_multiple );

    $result = $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

    $result = $spotify->track( '0eGsygTp906u18L0Oimnem' );

    $result = $spotify->tracks( '0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G' );

    $result = $spotify->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE', # artist id
                                            'SE' # country
                                            );

    $result = $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 15 , offset => 0 }
    );

    $result = $spotify->user( 'glennpmcdonald' );

    # public play interaction example
    # NEED TO SET YOUR o_auth client_id and secret for these to work

    $spotify->browse_featured_playlists( country => 'US' );

    my $link = $spotify->get('playlists.items[*].href');

    # $link is an arrayfef of the all the playlist urls

    foreach my $playlist (@{$link}) {
        # make sure the links look valid
        next if $playlist !~ /playlists/;
        $spotify->query_full_url($playlist,1);
        my $pl_name = $spotify->get('name');
        my $tracks  = $spotify->get('tracks.items[*].track.id');
        foreach my $track (@{$tracks}) {
                print "$track\n";
            }
        }

# DESCRIPTION

Wrapper for the Spotify Web API.

Since version 0.014 the implementation has been modularised:

    WWW::Spotify             – public wrapper (this module)
    WWW::Spotify::Client     – role with authentication / OAuth helpers
    WWW::Spotify::Endpoint   – role with low‑level HTTP verbs
    WWW::Spotify::Response   – object wrapper around an HTTP response

Splitting the code into roles and small classes keeps the public API
completely intact while making the internals much easier to test and
extend.  If you were subclassing `WWW::Spotify` directly nothing
changes – the roles are composed automatically.

The attribute `current_oath_code` was misspelled; it is now
`current_oauth_code`.  A shim accessor is retained for backwards
compatibility.

https://developer.spotify.com/web-api/

Have access to a JSON viewer to help develop and debug. The Chrome JSON viewer is
very good and provides the exact path of the item within the JSON in the lower left
of the screen as you mouse over an element.

# NAME

WWW::Spotify - Spotify Web API Wrapper

# VERSION

version 0.013

# CONSTRUCTOR ARGS

## ua

You may provide your own user agent object to the constructor.  This should be
a [LWP:UserAgent](LWP:UserAgent) or a subclass of it, like [WWW::Mechanize](https://metacpan.org/pod/WWW%3A%3AMechanize). If you are
using [WWW::Mechanize](https://metacpan.org/pod/WWW%3A%3AMechanize), you may want to set autocheck off.  To get extra
debugging information, you can do something like this:

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use WWW::Mechanize ();
    use WWW::Spotify ();

    my $mech = WWW::Mechanize->new( autocheck => 0 );
    debug_ua( $mech );
    my $spotify = WWW::Spotify->new( ua => $mech )

# METHODS

## auto\_json\_decode

When true results will be returned as JSON instead of a perl data structure

    $spotify->auto_json_decode(1);

## get

Returns a specific item or array of items from the JSON result of the
last action.

       $result = $spotify->search(
                           'tania bowra' ,
                           'artist' ,
                           { limit => 15 , offset => 0 }
       );

    my $image_url = $spotify->get( 'artists.items[0].images[0].url' );

JSON::Path is the underlying library that actually parses the JSON.

## query\_full\_url( $url , \[needs o\_auth\] )

Results from some calls (playlist for example) return full urls that can be in their entirety. This method allows you
make a call to that url and use all of the o\_auth and other features provided.

    $spotify->query_full_url( "https://api.spotify.com/v1/users/spotify/playlists/06U6mm6KPtPIg9D4YGNEnu" , 1 );

## album

equivalent to /v1/albums/{id}

    $spotify->album('0sNOF9WDwhWunNAHPD3Baj');

used album vs albums since it is a singular request

## albums

equivalent to /v1/albums?ids={ids}

    $spotify->albums( '41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4,6UXCm6bOO4gFlDQZV5yL37' );

or

    $spotify->albums( [ '41MnTivkwTO3UUJ8DrqEJJ',
                        '6JWc4iAiJ9FjyK0B59ABb4',
                        '6UXCm6bOO4gFlDQZV5yL37' ] );

## albums\_tracks

equivalent to /v1/albums/{id}/tracks

    $spotify->albums_tracks('6akEvsycLGftJxYudPjmqK',
    {
        limit => 1,
        offset => 1

    }
    );

## artist

equivalent to /v1/artists/{id}

    $spotify->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

used artist vs artists since it is a singular request and avoids collision with "artists" method

## artists

equivalent to /v1/artists?ids={ids}

    my $artists_multiple = '0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin';

    $spotify->artists( $artists_multiple );

## artist\_albums

equivalent to /v1/artists/{id}/albums

    $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

## artist\_top\_tracks

equivalent to /v1/artists/{id}/top-tracks

    $spotify->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE', # artist id
                                 'SE' # country
                                            );

## artist\_related\_artists

equivalent to /v1/artists/{id}/related-artists

    $spotify->artist_related_artists( '43ZHCT0cAZBISjO8DG9PnE' );

## search

equivalent to /v1/search?type=album (etc)

    $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 15 , offset => 0 }
    );

## track

equivalent to /v1/tracks/{id}

    $spotify->track( '0eGsygTp906u18L0Oimnem' );

## tracks

equivalent to /v1/tracks?ids={ids}

    $spotify->tracks( '0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G' );

## browse\_featured\_playlists

equivalent to /v1/browse/featured-playlists

    $spotify->browse_featured_playlists();

requires OAuth

## browse\_new\_releases

equivalent to /v1/browse/new-releases

requires OAuth

    $spotify->browse_new_releases

## force\_client\_auth

Boolean

will pass authentication (OAuth) on all requests when set

    $spotify->force_client_auth(1);

## user

equivalent to /v1/users/{user\_id}

    $spotify->user('glennpmcdonald');

## get\_playlist

equivalent to GET /v1/playlists/{playlist\_id}

    $spotify->get_playlist('37i9dQZF1DXcBWIGoYBM5M');

This method retrieves a playlist owned by a Spotify user. The playlist must be public or owned by the authenticated user.

## get\_playlist\_items

equivalent to /v1/playlists/{playlist\_id}/tracks

    $spotify->get_playlist_items('37i9dQZF1DXcBWIGoYBM5M', { limit => 10, offset => 0 });

## create\_playlist

equivalent to /v1/users/{user\_id}/playlists

    $spotify->create_playlist('user_id', 'My New Playlist', 1, 'A description of my playlist');

## get\_current\_user\_playlists

equivalent to /v1/me/playlists

    $spotify->get_current_user_playlists({ limit => 20, offset => 0 });

## add\_items\_to\_playlist

equivalent to /v1/playlists/{playlist\_id}/tracks

    $spotify->add_items_to_playlist('playlist_id', ['spotify:track:4iV5W9uYEdYUVa79Axb7Rh', 'spotify:track:1301WleyT98MSxVHPZCA6M'], 0);

## remove\_user\_saved\_tracks

equivalent to /v1/me/tracks

    $spotify->remove_user_saved_tracks(['4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M']);

## check\_users\_saved\_tracks

equivalent to /v1/me/tracks/contains

    $spotify->check_users_saved_tracks(['4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M']);

## check\_users\_saved\_shows

equivalent to GET /v1/me/shows/contains

    $spotify->check_users_saved_shows(['5CfCWKI5pZ28U0uOzXkDHe', '5as3aKmN2k11yfDDDSrvaZ']);

or

    $spotify->check_users_saved_shows('5CfCWKI5pZ28U0uOzXkDHe,5as3aKmN2k11yfDDDSrvaZ');

This method checks if one or more shows are already saved in the current Spotify user's library.

## get\_several\_tracks\_audio\_features

equivalent to /v1/audio-features

    $spotify->get_several_tracks_audio_features(['4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M']);

## get\_track\_audio\_features

equivalent to /v1/audio-features/{id}

    $spotify->get_track_audio_features('4iV5W9uYEdYUVa79Axb7Rh');

## get\_track\_audio\_analysis

equivalent to /v1/audio-analysis/{id}

    $spotify->get_track_audio_analysis('4iV5W9uYEdYUVa79Axb7Rh');

## get\_recommendations

equivalent to /v1/recommendations

    $spotify->get_recommendations(
        seed_artists => '4NHQUGzhtTLFvgF5SZesLK',
        seed_genres => 'classical,country',
        seed_tracks => '0c6xIDDpzE81m2q797ordA',
        limit => 10,
        market => 'ES'
    );

## get\_followed\_artists

equivalent to /v1/me/following

    $spotify->get_followed_artists(
        limit => 20,
        after => '0I2XqVXqHScXjHhk6AYYRe'
    );

Note: This method always sets the 'type' parameter to 'artist' as it's the only supported value.

## follow\_artists\_or\_users

equivalent to PUT /v1/me/following

    $spotify->follow_artists_or_users('artist', ['2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E']);

or

    $spotify->follow_artists_or_users('user', '2CIMQHirSU0MQqyYHq0eOx,57dN52uHvrHOxijzpIgu3E');

## unfollow\_artists\_or\_users

equivalent to DELETE /v1/me/following

    $spotify->unfollow_artists_or_users('artist', ['2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E']);

or

    $spotify->unfollow_artists_or_users('user', '2CIMQHirSU0MQqyYHq0eOx,57dN52uHvrHOxijzpIgu3E');

## check\_if\_user\_follows\_artists\_or\_users

equivalent to GET /v1/me/following/contains

    $spotify->check_if_user_follows_artists_or_users('artist', ['2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E']);

or

    $spotify->check_if_user_follows_artists_or_users('user', '2CIMQHirSU0MQqyYHq0eOx,57dN52uHvrHOxijzpIgu3E');

## check\_if\_user\_follows\_playlist

equivalent to GET /v1/playlists/{playlist\_id}/followers/contains

    $spotify->check_if_user_follows_playlist('3cEYpjA9oz9GiPac4AsH4n', 'jmperezperez');

or

    $spotify->check_if_user_follows_playlist('3cEYpjA9oz9GiPac4AsH4n', ['jmperezperez']);

## get\_audiobook

equivalent to GET /v1/audiobooks/{id}

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe');

or with market parameter:

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe', 'US');

## get\_users\_saved\_audiobooks

equivalent to GET /v1/me/audiobooks

    $spotify->get_users_saved_audiobooks(20, 0);

## remove\_users\_saved\_audiobooks

equivalent to DELETE /v1/me/audiobooks

    $spotify->remove_users_saved_audiobooks(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ']);

or

    $spotify->remove_users_saved_audiobooks('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ');

This method removes one or more audiobooks from the current user's library.

## get\_available\_genre\_seeds

equivalent to GET /v1/recommendations/available-genre-seeds

    $spotify->get_available_genre_seeds();

This method retrieves a list of available genres seed parameter values for recommendations.

## get\_available\_markets

equivalent to GET /v1/markets

    $spotify->get_available_markets();

This method retrieves the list of markets where Spotify is available.

## get\_show

equivalent to GET /v1/shows/{id}

    $spotify->get_show('38bS44xjbVVZ3No3ByF1dJ', 'US');

This method retrieves Spotify catalog information for a single show identified by its unique Spotify ID.

## get\_several\_shows

equivalent to GET /v1/shows

    $spotify->get_several_shows(['5CfCWKI5pZ28U0uOzXkDHe', '5as3aKmN2k11yfDDDSrvaZ'], 'US');

or

    $spotify->get_several_shows('5CfCWKI5pZ28U0uOzXkDHe,5as3aKmN2k11yfDDDSrvaZ', 'US');

This method retrieves Spotify catalog information for several shows based on their Spotify IDs.

## get\_show\_episodes

equivalent to GET /v1/shows/{id}/episodes

    $spotify->get_show_episodes('38bS44xjbVVZ3No3ByF1dJ', market => 'US', limit => 10, offset => 5);

This method retrieves Spotify catalog information about a show's episodes. Optional parameters can be used to limit the number of episodes returned.

## get\_audiobook\_chapters

equivalent to GET /v1/audiobooks/{id}/chapters

    $spotify->get_audiobook_chapters('3ZXb8FKZGU0EHALYX6uCzU', market => 'US', limit => 50, offset => 0);

This method retrieves the chapters of an audiobook.

## get\_several\_audiobooks

equivalent to GET /v1/audiobooks

    $spotify->get_several_audiobooks(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ'], 'US');

or

    $spotify->get_several_audiobooks('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ', 'US');

This method retrieves multiple audiobooks based on their Spotify IDs.

## send\_delete\_request

Internal method used to send DELETE requests to the Spotify API.

## send\_put\_request

Internal method used to send PUT requests to the Spotify API.

## check\_users\_saved\_audiobooks

equivalent to GET /v1/me/audiobooks/contains

    $spotify->check_users_saved_audiobooks(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ']);

or

    $spotify->check_users_saved_audiobooks('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ');

## get\_users\_saved\_shows

equivalent to GET /v1/me/shows

    $spotify->get_users_saved_shows(limit => 20, offset => 0);

This method retrieves a list of shows saved in the current Spotify user's library. Optional parameters can be used to limit the number of shows returned.

## save\_shows\_for\_current\_user

equivalent to PUT /v1/me/shows

    $spotify->save_shows_for_current_user(['5CfCWKI5pZ28U0uOzXkDHe', '5as3aKmN2k11yfDDDSrvaZ']);

or

    $spotify->save_shows_for_current_user('5CfCWKI5pZ28U0uOzXkDHe,5as3aKmN2k11yfDDDSrvaZ');

This method saves one or more shows to the current user's library.

## get\_categories

equivalent to GET /v1/browse/categories

    $spotify->get_categories(
        country => 'US',
        locale => 'en_US',
        limit => 20,
        offset => 0
    );

## get\_category

equivalent to GET /v1/browse/categories/{category\_id}

    $spotify->get_category('dinner', locale => 'en_US');

## get\_chapter

equivalent to GET /v1/chapters/{id}

    $spotify->get_chapter('0D5wENdkdwbqlrHoaJ9g29', market => 'US');

## get\_several\_chapters

equivalent to GET /v1/chapters

    $spotify->get_several_chapters(['0IsXVP0JmcB2adSE338GkK', '3ZXb8FKZGU0EHALYX6uCzU', '0D5wENdkdwbqlrHoaJ9g29'], market => 'US');

or

    $spotify->get_several_chapters('0IsXVP0JmcB2adSE338GkK,3ZXb8FKZGU0EHALYX6uCzU,0D5wENdkdwbqlrHoaJ9g29', market => 'US');

## save\_audiobooks\_for\_current\_user

equivalent to PUT /v1/me/audiobooks

    $spotify->save_audiobooks_for_current_user(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ']);

or

    $spotify->save_audiobooks_for_current_user('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ');

This method saves one or more audiobooks to the current user's library.

## oauth\_client\_id

needed for requests that require OAuth, see Spotify API documentation for more information

    $spotify->oauth_client_id('2xfjijkcjidjkfdi');

Can also be set via environment variable, SPOTIFY\_CLIENT\_ID

## oauth\_client\_secret

needed for requests that require OAuth, see Spotify API documentation for more information

    $spotify->oauth_client_secret('2xfjijkcjidjkfdi');

Can also be set via environment variable, SPOTIFY\_CLIENT\_SECRET

## response\_status

returns the response code for the last request made

    my $status = $spotify->response_status();

## response\_content\_type

returns the response type for the last request made, helpful to verify JSON

    my $content_type = $spotify->response_content_type();

## custom\_request\_handler

pass a callback subroutine to this method that will be run at the end of the
request prior to die\_on\_response\_error, if enabled

    # $m is the WWW::Mechanize object
    $spotify->custom_request_handler(
        sub { my $m = shift;
            if ($m->status() == 401) {
                return 1;
            }
        }
    );

## custom\_request\_handler\_result

returns the result of the most recent execution of the custom\_request\_handler callback
this allows you to determine the success/failure criteria of your callback

    my $callback_result = $spotify->custom_request_handler_result();

## die\_on\_response\_error

Boolean - default 0

added to provide minimal automated checking of responses

    $spotify->die_on_response_error(1);

eval {
    # run assuming you do NOT have proper authentication setup
    $result = $spotify->album('0sNOF9WDwhWunNAHPD3Baj');
};

if ($@) {
    warn $spotify->last\_error();
}

## last\_error

returns last\_error (if applicable) from the most recent request.
reset to empty string on each request

    print $spotify->last_error() , "\n";

# THANKS

Paul Lamere at The Echo Nest / Spotify

All the great Perl community members that keep Perl fun

Olaf Alders for all his help and support in maintaining this module

# AUTHOR

Aaron Johnson <aaronjjohnson@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Aaron Johnson.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
