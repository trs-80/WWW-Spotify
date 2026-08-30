package WWW::Spotify;

use Moo 2.002004;

our $VERSION = '0.016';

use Carp              qw( carp );
use Data::Dumper      qw( Dumper );
use IO::CaptureOutput qw( capture );
use JSON::Path        ();
use JSON::MaybeXS     qw( decode_json encode_json );
use MIME::Base64      qw( encode_base64 );
use Types::Standard   qw( Bool InstanceOf Int Str CodeRef );
use HTTP::Status      qw( HTTP_OK is_success );
use URI::Escape       qw( uri_escape );

has 'oauth_authorize_url' => (
    is      => 'rw',
    isa     => Str,
    default => 'https://accounts.spotify.com/authorize'
);

has 'oauth_token_url' => (
    is      => 'rw',
    isa     => Str,
    default => 'https://accounts.spotify.com/api/token'
);

has 'oauth_redirect_uri' => (
    is      => 'rw',
    isa     => Str,
    default => 'http://www.spotify.com'
);

has 'oauth_client_id' => (
    is      => 'rw',
    isa     => Str,
    default => $ENV{SPOTIFY_CLIENT_ID} || q{}
);

has 'oauth_client_secret' => (
    is      => 'rw',
    isa     => Str,
    default => $ENV{SPOTIFY_CLIENT_SECRET} || q{}
);

has 'current_oath_code' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'current_access_token' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'refresh_token' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'result_format' => (
    is      => 'rw',
    isa     => Str,
    default => 'json'
);

has 'grab_response_header' => (
    is      => 'rw',
    isa     => Int,
    default => 0
);

has 'results' => (
    is      => 'rw',
    isa     => Int,
    default => '15'
);

has 'debug' => (
    is      => 'rw',
    isa     => Bool,
    default => 0
);

has 'uri_scheme' => (
    is      => 'rw',
    isa     => Str,
    default => 'https'
);

has 'current_client_credentials' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'force_client_auth' => (
    is      => 'rw',
    isa     => Bool,
    default => 1
);

has 'uri_hostname' => (
    is      => 'rw',
    isa     => Str,
    default => 'api.spotify.com'
);

has 'uri_domain_path' => (
    is      => 'rw',
    isa     => Str,
    default => 'api'
);

has 'call_type' => (
    is  => 'rw',
    isa => Str
);

has 'auto_json_decode' => (
    is      => 'rw',
    isa     => Int,
    default => 0
);

has 'last_result' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'last_error' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'response_headers' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'problem' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'ua' => (
    is      => 'ro',
    isa     => InstanceOf ['LWP::UserAgent'],
    handles => { _mech => 'clone' },
    lazy    => 1,
    default => sub {
        require WWW::Mechanize;
        WWW::Mechanize->new( autocheck => 0 );
    },
);

has 'response_status' => (
    is  => 'rw',
    isa => Int
);

has 'response_content_type' => (
    is  => 'rw',
    isa => Str
);

has 'custom_request_handler' => (
    is        => 'rw',
    isa       => CodeRef,
    predicate => '_has_custom_request_handler',
);

has 'custom_request_handler_result' => (
    is     => 'ro',
    writer => '_set_custom_request_handler_result'
);

has 'die_on_response_error' => (
    is      => 'rw',
    isa     => Bool,
    default => 0
);

has 'token_expires_at' => (
    is      => 'rw',
    isa     => Int,
    default => 0
);

my @api_call_options = (
    {
        path   => '/v1/albums/{id}',
        info   => 'Get an album',
        type   => 'GET',
        method => 'album'
    },

    {
        path   => '/v1/audiobooks/{id}',
        info   => 'Get an audiobook',
        type   => 'GET',
        method => 'get_audiobook',
        params => ['market']
    },

    {
        path   => '/v1/audiobooks',
        info   => 'Get several audiobooks',
        type   => 'GET',
        method => 'get_several_audiobooks',
        params => [ 'ids', 'market' ]
    },

    {
        path   => '/v1/audiobooks/{id}/chapters',
        info   => 'Get Audiobook Chapters',
        type   => 'GET',
        method => 'get_audiobook_chapters',
        params => [ 'id', 'market', 'limit', 'offset' ]
    },

    {
        path   => '/v1/me/audiobooks',
        info   => 'Get User\'s Saved Audiobooks',
        type   => 'GET',
        method => 'get_users_saved_audiobooks',
        params => [ 'limit', 'offset' ]
    },

    {
        path   => '/v1/me/audiobooks',
        info   => 'Save Audiobooks for Current User',
        type   => 'PUT',
        method => 'save_audiobooks_for_current_user',
        params => ['ids']
    },

    {
        path   => '/v1/me/audiobooks',
        info   => 'Remove User\'s Saved Audiobooks',
        type   => 'DELETE',
        method => 'remove_users_saved_audiobooks',
        params => ['ids']
    },

    {
        path   => '/v1/me/audiobooks/contains',
        info   => 'Check User\'s Saved Audiobooks',
        type   => 'GET',
        method => 'check_users_saved_audiobooks',
        params => ['ids']
    },

    {
        path   => '/v1/me/shows',
        info   => 'Get User\'s Saved Shows',
        type   => 'GET',
        method => 'get_users_saved_shows',
        params => [ 'limit', 'offset' ]
    },

    {
        path   => '/v1/me/shows',
        info   => 'Save Shows for Current User',
        type   => 'PUT',
        method => 'save_shows_for_current_user',
        params => ['ids']
    },

    {
        path   => '/v1/me/shows/contains',
        info   => 'Check User\'s Saved Shows',
        type   => 'GET',
        method => 'check_users_saved_shows',
        params => ['ids']
    },

    {
        path   => '/v1/browse/categories',
        info   => 'Get Several Browse Categories',
        type   => 'GET',
        method => 'get_categories',
        params => [ 'country', 'locale', 'limit', 'offset' ]
    },

    {
        path   => '/v1/browse/categories/{category_id}',
        info   => 'Get Single Browse Category',
        type   => 'GET',
        method => 'get_category',
        params => [ 'category_id', 'locale' ]
    },

    {
        path   => '/v1/chapters/{id}',
        info   => 'Get a Chapter',
        type   => 'GET',
        method => 'get_chapter',
        params => [ 'id', 'market' ]
    },

    {
        path   => '/v1/chapters',
        info   => 'Get Several Chapters',
        type   => 'GET',
        method => 'get_several_chapters',
        params => [ 'ids', 'market' ]
    },

    {
        path   => '/v1/recommendations/available-genre-seeds',
        info   => 'Get Available Genre Seeds',
        type   => 'GET',
        method => 'get_available_genre_seeds'
    },

    {
        path   => '/v1/markets',
        info   => 'Get Available Markets',
        type   => 'GET',
        method => 'get_available_markets'
    },

    {
        path   => '/v1/shows/{id}',
        info   => 'Get a Show',
        type   => 'GET',
        method => 'get_show',
        params => ['market']
    },

    {
        path   => '/v1/shows',
        info   => 'Get Several Shows',
        type   => 'GET',
        method => 'get_several_shows',
        params => [ 'ids', 'market' ]
    },

    {
        path   => '/v1/shows/{id}/episodes',
        info   => 'Get Show Episodes',
        type   => 'GET',
        method => 'get_show_episodes',
        params => [ 'id', 'market', 'limit', 'offset' ]
    },

    {
        path   => '/v1/albums?ids={ids}',
        info   => 'Get several albums',
        type   => 'GET',
        method => 'albums',
        params => [ 'limit', 'offset' ]
    },

    {
        path   => '/v1/playlists/{playlist_id}',
        info   => 'Get a playlist',
        type   => 'GET',
        method => 'get_playlist'
    },

    {
        path   => '/v1/playlists/{playlist_id}/items',
        info   => 'Get playlist items',
        type   => 'GET',
        method => 'get_playlist_items',
        params => [ 'limit', 'offset', 'market', 'fields' ]
    },

    {
        path   => '/v1/me/playlists',
        info   => 'Create a playlist for the current user',
        type   => 'POST',
        method => 'create_playlist'
    },

    {
        path   => '/v1/me/playlists',
        info   => 'Get current user\'s playlists',
        type   => 'GET',
        method => 'get_current_user_playlists',
        params => [ 'limit', 'offset' ]
    },

    {
        path   => '/v1/playlists/{playlist_id}/items',
        info   => 'Add items to a playlist',
        type   => 'POST',
        method => 'add_items_to_playlist'
    },

    {
        path   => '/v1/playlists/{playlist_id}/followers',
        info   => 'Unfollow (remove) a playlist',
        type   => 'DELETE',
        method => 'unfollow_playlist'
    },

    {
        path   => '/v1/me/tracks',
        info   => 'Remove User\'s Saved Tracks',
        type   => 'DELETE',
        method => 'remove_user_saved_tracks'
    },

    {
        path   => '/v1/me/tracks/contains',
        info   => 'Check User\'s Saved Tracks',
        type   => 'GET',
        method => 'check_users_saved_tracks'
    },

    {
        path   => '/v1/audio-features',
        info   => 'Get Several Tracks\' Audio Features',
        type   => 'GET',
        method => 'get_several_tracks_audio_features'
    },

    {
        path   => '/v1/audio-features/{id}',
        info   => 'Get Track\'s Audio Features',
        type   => 'GET',
        method => 'get_track_audio_features'
    },

    {
        path   => '/v1/audio-analysis/{id}',
        info   => 'Get Track\'s Audio Analysis',
        type   => 'GET',
        method => 'get_track_audio_analysis'
    },

    {
        path   => '/v1/recommendations',
        info   => 'Get Recommendations',
        type   => 'GET',
        method => 'get_recommendations',
        params => [
            'seed_artists', 'seed_genres', 'seed_tracks', 'limit', 'market'
        ]
    },

    {
        path   => '/v1/me/following',
        info   => 'Get Followed Artists',
        type   => 'GET',
        method => 'get_followed_artists',
        params => [ 'type', 'after', 'limit' ]
    },

    {
        path   => '/v1/me/following',
        info   => 'Follow Artists or Users',
        type   => 'PUT',
        method => 'follow_artists_or_users',
        params => [ 'type', 'ids' ]
    },

    {
        path   => '/v1/me/following',
        info   => 'Unfollow Artists or Users',
        type   => 'DELETE',
        method => 'unfollow_artists_or_users',
        params => [ 'type', 'ids' ]
    },

    {
        path   => '/v1/me/following/contains',
        info   => 'Check if Current User Follows Artists or Users',
        type   => 'GET',
        method => 'check_if_user_follows_artists_or_users',
        params => [ 'type', 'ids' ]
    },

    {
        path   => '/v1/playlists/{playlist_id}/followers/contains',
        info   => 'Check if Current User Follows Playlist',
        type   => 'GET',
        method => 'check_if_user_follows_playlist',
        params => [ 'playlist_id', 'ids' ]
    },

    {
        path   => '/v1/albums/{id}/tracks',
        info   => q{Get an album's tracks},
        type   => 'GET',
        method => 'albums_tracks'
    },

    {
        path   => '/v1/artists/{id}',
        info   => 'Get an artist',
        type   => 'GET',
        method => 'artist'
    },

    {
        path   => '/v1/artists?ids={ids}',
        info   => 'Get several artists',
        type   => 'GET',
        method => 'artists'
    },

    {
        path   => '/v1/artists/{id}/albums',
        info   => q{Get an artist's albums},
        type   => 'GET',
        method => 'artist_albums',
        params => [ 'limit', 'offset', 'country', 'album_type' ]
    },

    {
        path   => '/v1/artists/{id}/top-tracks?country={country}',
        info   => q{Get an artist's top tracks},
        type   => 'GET',
        method => 'artist_top_tracks',
        params => ['country']
    },

    {
        path   => '/v1/artists/{id}/related-artists',
        info   => q{Get an artist's related artists},
        type   => 'GET',
        method => 'artist_related_artists',
    },

    # adding q and type to url unlike example since they are both required
    {
        path   => '/v1/search?q={q}&type={type}',
        info   => 'Search for an item',
        type   => 'GET',
        method => 'search',
        params => [ 'limit', 'offset', 'q', 'type' ]
    },

    {
        path   => '/v1/tracks/{id}',
        info   => 'Get a track',
        type   => 'GET',
        method => 'track'
    },

    {
        path   => '/v1/tracks?ids={ids}',
        info   => 'Get several tracks',
        type   => 'GET',
        method => 'tracks'
    },

    {
        path   => '/v1/users/{user_id}',
        info   => q{Get a user's profile},
        type   => 'GET',
        method => 'user'
    },

    {
        path   => '/v1/me',
        info   => q{Get current user's profile},
        type   => 'GET',
        method => 'me'
    },

    {
        path   => '/v1/users/{user_id}/playlists',
        info   => q{Get a list of a user's playlists},
        type   => 'GET',
        method => 'user_playlist'
    },

    {
        path   => '/v1/browse/featured-playlists',
        info   => 'Get a list of featured playlists',
        type   => 'GET',
        method => 'browse_featured_playlists'
    },

    {
        path   => '/v1/browse/new-releases',
        info   => 'Get a list of new releases',
        type   => 'GET',
        method => 'browse_new_releases'
    },

    # February 2026 consolidated library endpoints.  These take Spotify
    # URIs (spotify:track:{id}, spotify:show:{id}, ...) rather than bare
    # ids, passed as a "uris" query parameter on every verb.
    {
        path   => '/v1/me/library?uris={uris}',
        info   => 'Save Items to Library',
        type   => 'PUT',
        method => 'save_library_items',
        params => ['uris']
    },

    {
        path   => '/v1/me/library?uris={uris}',
        info   => 'Remove Items from Library',
        type   => 'DELETE',
        method => 'remove_library_items',
        params => ['uris']
    },

    {
        path   => '/v1/me/library/contains?uris={uris}',
        info   => 'Check Items in Library',
        type   => 'GET',
        method => 'check_library_items',
        params => ['uris']
    },
);

# Methods whose endpoints were removed or consolidated by Spotify's
# February 2026 API changes (plus the November 2024 deprecations).  The
# methods are kept for backwards compatibility; calling one warns once
# per process and the request is still sent (Spotify will reject it).
my %method_deprecated = (
    albums =>
        'GET /v1/albums?ids= removed Feb 2026; fetch albums individually with album()',
    artists =>
        'GET /v1/artists?ids= removed Feb 2026; fetch artists individually with artist()',
    tracks =>
        'GET /v1/tracks?ids= removed Feb 2026; fetch tracks individually with track()',
    get_several_shows =>
        'GET /v1/shows removed Feb 2026; use get_show() per id',
    get_several_audiobooks =>
        'GET /v1/audiobooks removed Feb 2026; use get_audiobook() per id',
    get_several_chapters =>
        'GET /v1/chapters removed Feb 2026; use get_chapter() per id',
    get_several_tracks_audio_features =>
        'GET /v1/audio-features removed Feb 2026',
    get_track_audio_features =>
        'GET /v1/audio-features/{id} deprecated by Spotify (Nov 2024)',
    get_track_audio_analysis =>
        'GET /v1/audio-analysis/{id} deprecated by Spotify (Nov 2024)',
    get_recommendations =>
        'GET /v1/recommendations deprecated by Spotify (Nov 2024)',
    get_available_genre_seeds =>
        'GET /v1/recommendations/available-genre-seeds removed',
    browse_featured_playlists =>
        'GET /v1/browse/featured-playlists removed by Spotify (Nov 2024)',
    browse_new_releases => 'GET /v1/browse/new-releases removed Feb 2026',
    get_categories      => 'GET /v1/browse/categories removed Feb 2026',
    get_category        => 'GET /v1/browse/categories/{id} removed Feb 2026',
    artist_top_tracks   => 'GET /v1/artists/{id}/top-tracks removed Feb 2026',
    artist_related_artists =>
        'GET /v1/artists/{id}/related-artists removed by Spotify (Nov 2024)',
    user => 'GET /v1/users/{user_id} deprecated/removed Feb 2026',
    remove_user_saved_tracks =>
        'DELETE /v1/me/tracks removed Feb 2026; use remove_library_items()',
    check_users_saved_tracks =>
        'GET /v1/me/tracks/contains removed Feb 2026; use check_library_items()',
    save_shows_for_current_user =>
        'PUT /v1/me/shows removed Feb 2026; use save_library_items()',
    check_users_saved_shows =>
        'GET /v1/me/shows/contains removed Feb 2026; use check_library_items()',
    save_audiobooks_for_current_user =>
        'PUT /v1/me/audiobooks removed Feb 2026; use save_library_items()',
    remove_users_saved_audiobooks =>
        'DELETE /v1/me/audiobooks removed Feb 2026; use remove_library_items()',
    check_users_saved_audiobooks =>
        'GET /v1/me/audiobooks/contains removed Feb 2026; use check_library_items()',
    follow_artists_or_users =>
        'PUT /v1/me/following removed Feb 2026; use save_library_items()',
    unfollow_artists_or_users =>
        'DELETE /v1/me/following removed Feb 2026; use remove_library_items()',
    check_if_user_follows_artists_or_users =>
        'GET /v1/me/following/contains removed Feb 2026; use check_library_items()',
    check_if_user_follows_playlist =>
        'GET /v1/playlists/{id}/followers/contains removed Feb 2026; use check_library_items()',
);

my %deprecation_warned;

my %method_to_uri = ();

foreach my $entry (@api_call_options) {
    next if $entry->{method} eq q{};
    $method_to_uri{ $entry->{method} } = $entry->{path};
}

# _build_url: construct the request URL from an attributes hashref.
#
# For send_get_request the URL-building logic is richer (query_full_url
# passthrough, search substitution, extras appended as query params).  That
# full logic stays in send_get_request.  _build_url handles the simpler
# pattern shared by POST / PUT / DELETE.
sub _build_url {
    my ( $self, $attributes ) = @_;

    my $url  = $self->uri_scheme() . '://' . $self->uri_hostname();
    my $path = $method_to_uri{ $attributes->{method} };

    # Params consumed by a {placeholder} in the path are removed from
    # %unused so the request body only carries what the URL did not.
    my %unused = %{ $attributes->{params} || {} };

    if ($path) {
        $path
            =~ s/\{([^}]+)\}/my $v = delete $unused{$1}; defined $v ? $v : q{}/ge;
        $url .= $path;
    }

    warn "$url\n" if $self->debug;
    return wantarray ? ( $url, \%unused ) : $url;
}

# _send_request: shared machinery for every HTTP verb.
#
# Parameters:
#   $verb        - 'get' | 'post' | 'put' | 'delete'
#   $url         - fully-formed request URL
#   $attributes  - original attributes hashref (used for auth flag)
#   $body        - optional request body (undef for GET)
sub _send_request {
    my ( $self, $verb, $url, $attributes, $body ) = @_;

    my $method = $attributes->{method} // q{};
    if ( my $reason = $method_deprecated{$method} ) {
        carp
            "WWW::Spotify: $method() targets a removed/deprecated Spotify endpoint: $reason"
            unless $deprecation_warned{$method}++;
    }

    local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    my $mech = $self->_mech;

    if (   $attributes->{client_auth_required}
        || $self->force_client_auth() != 0 ) {
        if ( $self->current_access_token() eq q{}
            || time() >= $self->token_expires_at() ) {
            warn "Needed to get access token\n" if $self->debug();
            $self->current_access_token(q{});
            $self->get_client_credentials();
        }
        $mech->add_header(
            'Authorization' => 'Bearer ' . $self->current_access_token() );
    }

    if ( defined $body ) {
        $mech->add_header( 'Content-Type' => 'application/json' );
        $mech->$verb( $url, Content => $body );
    }
    else {
        $mech->$verb($url);
    }

    if ( $self->grab_response_header() == 1 ) {
        $self->_set_response_headers($mech);
    }

    $self->response_status( $mech->status() );
    $self->response_content_type( $mech->content_type() );

    if ( $self->_has_custom_request_handler() ) {
        $self->_set_custom_request_handler_result(
            $self->custom_request_handler()->($mech) );
    }

    return $mech;
}

sub send_post_request {
    my ( $self, $attributes ) = @_;

    $self->last_error(q{});

    my ( $url, $body_params ) = $self->_build_url($attributes);
    my $body = %{$body_params} ? encode_json($body_params) : '';
    my $mech = $self->_send_request( 'post', $url, $attributes, $body );

    if (   $self->response_content_type() =~ /application\/json/i
        && $self->response_status() != HTTP_OK ) {
        warn "content type is ", $self->response_content_type(), "\n"
            if $self->debug();
        $self->last_error( "request failed, status("
                . $self->response_status()
                . ") examine last_result for details" );
    }

    if ( $self->die_on_response_error() == 1 && $self->last_error ne '' ) {
        die $self->last_error();
    }

    return $self->format_results(
        $mech->content, $mech->ct(),
        $mech->status()
    );
}

sub send_delete_request {

    # Internal method used to send DELETE requests to the Spotify API.
    my ( $self, $attributes ) = @_;

    $self->last_error(q{});

    my ( $url, $body_params ) = $self->_build_url($attributes);
    my $body = %{$body_params} ? encode_json($body_params) : '';
    my $mech = $self->_send_request( 'delete', $url, $attributes, $body );

    if ( !is_success( $self->response_status() ) ) {
        warn "Delete request failed with status ", $self->response_status(),
            "\n"
            if $self->debug();
        $self->last_error( "Delete request failed, status("
                . $self->response_status()
                . ") examine last_result for details" );
    }

    if ( $self->die_on_response_error() == 1 && $self->last_error ne '' ) {
        die $self->last_error();
    }

    return $self->format_results(
        $mech->content, $mech->ct(),
        $mech->status()
    );
}

sub send_put_request {

    # Internal method used to send PUT requests to the Spotify API.
    my ( $self, $attributes ) = @_;

    $self->last_error(q{});

    my ( $url, $body_params ) = $self->_build_url($attributes);
    my $body = %{$body_params} ? encode_json($body_params) : '';
    my $mech = $self->_send_request( 'put', $url, $attributes, $body );

    if ( !is_success( $self->response_status() ) ) {
        warn "Put request failed with status ", $self->response_status(), "\n"
            if $self->debug();
        $self->last_error( "Put request failed, status("
                . $self->response_status()
                . ") examine last_result for details" );
    }

    if ( $self->die_on_response_error() == 1 && $self->last_error ne '' ) {
        die $self->last_error();
    }

    return $self->format_results(
        $mech->content, $mech->ct(),
        $mech->status()
    );
}

sub send_get_request {

    # need to build the URL here
    my ( $self, $attributes ) = @_;

    my $uri_params = q{};

    # reset last error
    $self->last_error(q{});

    if ( defined $attributes->{extras}
        and ref $attributes->{extras} eq 'HASH' ) {
        my @tmp = ();

        foreach my $key ( keys %{ $attributes->{extras} } ) {
            push @tmp, "$key=" . uri_escape( $attributes->{extras}{$key} );
        }
        $uri_params = join( '&', @tmp );
    }

    if ( exists $attributes->{format}
        && $attributes->{format} =~ /json|jsonp/ ) {
        $self->result_format( $attributes->{format} );
        delete $attributes->{format};
    }

    my $url;
    if ( $attributes->{method} eq 'query_full_url' ) {
        $url = $attributes->{url};
    }
    else {
        $url = $self->uri_scheme() . '://' . $self->uri_hostname();

        my $path = $method_to_uri{ $attributes->{method} };
        if ($path) {

            warn "raw: $path" if $self->debug();

            if ( $path =~ /search/ && $attributes->{method} eq 'search' ) {
                $path =~ s/\{q\}/uri_escape( $attributes->{q} )/e;
                $path =~ s/\{type\}/uri_escape( $attributes->{type} )/e;
            }

            # Generic substitution for all remaining {placeholder} tokens
            $path =~ s/\{([^}]+)\}/$attributes->{params}{$1}/g
                if $attributes->{params};

            warn "modified: $path\n" if $self->debug();
        }

        $url .= $path;
    }

    # append "extras" as query params if present
    if ($uri_params) {
        my $start_with = $url =~ /\?/ ? '&' : '?';
        $url .= $start_with . $uri_params;
    }

    warn "$url\n" if $self->debug;

    my $mech = $self->_send_request( 'get', $url, $attributes, undef );

    # the original code did not provide adequate built in validation
    # of the response for an API call.
    # Adding a new method (die_on_response_error) with a default of 0 to avoid
    # breaking/changing existing code using older versions of this module.
    if (   $self->response_content_type() =~ /application\/json/i
        && $self->response_status() != HTTP_OK ) {
        warn "content type is ", $self->response_content_type(), "\n"
            if $self->debug();
        $self->last_error( "request failed, status("
                . $self->response_status()
                . ") examine last_result for details" );
    }

    if ( $self->die_on_response_error() == 1 && $self->last_error ne '' ) {
        die $self->last_error();
    }

    return $self->format_results(
        $mech->content, $mech->ct(),
        $mech->status()
    );
}

sub _set_response_headers {
    my $self = shift;
    my $mech = shift;

    my $hd;
    capture { $mech->dump_headers(); } \$hd;

    $self->response_headers($hd);
    return;
}

sub format_results {
    my $self    = shift;
    my $content = shift;

    # want to store the result in case
    # we want to interact with it via a helper method
    $self->last_result($content);

    # FIX ME / TEST ME
    # vefify both of these work and return the *same* perl hash

    # when / how should we check the status? Do we need to?
    # if so then we need to create another method that will
    # manage a Sucess vs. Fail request

    if ( $self->auto_json_decode && $self->result_format eq 'json' ) {
        return decode_json $content;
    }

    # results are not altered in this case and would be
    # json instead of a perl data structure

    return $content;
}

sub get_oauth_authorize {
    my $self = shift;

    if ( $self->current_oath_code() ) {
        return $self->current_oath_code();
    }

    my $grant_type = 'authorization_code';
    local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    my $client_and_secret
        = $self->oauth_client_id() . ':' . $self->oauth_client_secret();
    my $encoded = encode_base64($client_and_secret);
    chomp($encoded);
    $encoded =~ s/\n//g;
    my $url = $self->oauth_authorize_url();

    my @parts;

    $parts[0] = 'response_type=code';
    $parts[1] = 'redirect_uri=' . $self->oauth_redirect_uri;

    my $params = join( '&', @parts );
    $url = $url . '?client_id=' . $self->oauth_client_id() . "&$params";

    $self->ua->get($url);

    return $self->ua->content;
}

sub get_client_credentials {
    my $self  = shift;
    my $scope = shift;

    if ( $self->current_access_token() ne q{} ) {
        return $self->current_access_token();
    }
    if ( $self->oauth_client_id() eq q{} ) {
        die "need to set the client oauth parameters\n";
    }

    my $grant_type = 'client_credentials';
    local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    my $mech = $self->_mech;
    my $client_and_secret
        = $self->oauth_client_id() . ':' . $self->oauth_client_secret();
    my $encoded = encode_base64($client_and_secret);
    my $url     = $self->oauth_token_url();

    # $url .= "?grant_type=client_credentials";
    # my $url = $self->oauth_authorize_url();
    # grant_type=client_credentials
    my $extra = {
        grant_type => $grant_type

            #code => 'code',
            #redirect_uri => $self->oauth_redirect_uri
    };
    if ($scope) {
        $extra->{scope} = $scope;
    }

    chomp($encoded);
    $encoded =~ s/\n//g;
    $mech->add_header( 'Authorization' => 'Basic ' . $encoded );

    $mech->post( $url, [$extra] );
    my $content = $mech->content();

    if ( $content =~ /access_token/ ) {
        warn "setting access token\n" if $self->debug();

        my $result = decode_json $content;

        if ( $result->{'access_token'} ) {
            $self->current_access_token( $result->{'access_token'} );
            if ( $result->{'expires_in'} ) {
                $self->token_expires_at( time() + $result->{'expires_in'} );
            }
        }
    }
}

sub authorize_url {
    my ( $self, $args ) = @_;
    $args ||= {};

    my @parts = (
        'client_id=' . uri_escape( $self->oauth_client_id() ),
        'response_type=code',
        'redirect_uri=' . uri_escape( $self->oauth_redirect_uri() ),
    );
    push @parts, 'scope=' . uri_escape( $args->{scope} ) if $args->{scope};
    push @parts, 'state=' . uri_escape( $args->{state} ) if $args->{state};

    return $self->oauth_authorize_url() . '?' . join '&', @parts;
}

sub _request_token {
    my ( $self, $form ) = @_;

    my $encoded = encode_base64(
        $self->oauth_client_id() . ':' . $self->oauth_client_secret(), q{} );

    my $mech = $self->_mech;
    $mech->add_header( 'Authorization' => 'Basic ' . $encoded );
    $mech->post( $self->oauth_token_url(), [$form] );

    my $result = eval { decode_json( $mech->content() ) };

    return 0 unless $result && $result->{access_token};

    $self->current_access_token( $result->{access_token} );
    $self->token_expires_at( time() + $result->{expires_in} )
        if $result->{expires_in};
    $self->refresh_token( $result->{refresh_token} )
        if $result->{refresh_token};

    return 1;
}

sub get_access_token {
    my ( $self, $code ) = @_;

    die "get_access_token requires an authorization code\n"
        unless defined $code && length $code;

    return $self->_request_token(
        {
            grant_type   => 'authorization_code',
            code         => $code,
            redirect_uri => $self->oauth_redirect_uri(),
        }
    );
}

sub refresh_access_token {
    my $self = shift;

    die "refresh_access_token requires a stored refresh token\n"
        unless $self->refresh_token();

    return $self->_request_token(
        {
            grant_type    => 'refresh_token',
            refresh_token => $self->refresh_token(),
        }
    );
}

sub get {

    # This seemed like a simple enough method
    # but everything I tried resulted in unacceptable
    # trade offs and explict defining of the structures
    # The new method, which I hope I remember when I
    # revisit it, was to use JSON::Path
    # It is an awesome module, but a little heavy
    # on dependencies.  However I would not have been
    # able to do this in so few lines without it

    # Making a generalization here
    # if you use a * you are looking for an array
    # if you don't have an * you want the first 1 (or should I say you get the first 1)

    my ( $self, @return ) = @_;

    # my @return = @_;

    my @out;

    my $result = decode_json $self->last_result();

    my $search_ref = $result;

    warn Dumper($result) if $self->debug();

    foreach my $key (@return) {
        my $type = 'value';
        if ( $key =~ /\*\]/ ) {
            $type = 'values';
        }

        my $jpath = JSON::Path->new("\$.$key");

        my @t_arr = $jpath->$type($result);

        if ( $type eq 'value' ) {
            push @out, $t_arr[0];
        }
        else {
            push @out, \@t_arr;
        }
    }
    if (wantarray) {
        return @out;
    }
    else {
        return $out[0];
    }

}

sub build_url_base {

    # first the uri type
    my $self      = shift;
    my $call_type = shift || $self->call_type();

    my $url = $self->uri_scheme();

    # the ://
    $url .= '://';

    # the domain
    $url .= $self->uri_hostname();

    # the path
    if ( $self->uri_domain_path() ) {
        $url .= '/' . $self->uri_domain_path();
    }

    return $url;
}

#- may want to move this at some point

sub query_full_url {
    my $self                 = shift;
    my $url                  = shift;
    my $client_auth_required = shift || 0;
    return $self->send_get_request(
        {
            method               => 'query_full_url',
            url                  => $url,
            client_auth_required => $client_auth_required
        }
    );
}

#-- spotify specific methods

sub album {
    my $self = shift;
    my $id   = shift;

    return $self->send_get_request(
        {
            method               => 'album',
            params               => { 'id' => $id },
            client_auth_required => 1
        }
    );
}

sub albums {
    my $self = shift;
    my $ids  = shift;

    if ( ref($ids) eq 'ARRAY' ) {
        $ids = join_ids($ids);
    }

    return $self->send_get_request(
        {
            method               => 'albums',
            params               => { 'ids' => $ids },
            client_auth_required => 1
        }
    );

}

sub join_ids {
    my $array = shift;
    return join( ',', @$array );
}

sub albums_tracks {
    my $self     = shift;
    my $album_id = shift;
    my $extras   = shift;

    return $self->send_get_request(
        {
            method               => 'albums_tracks',
            params               => { 'id' => $album_id },
            extras               => $extras,
            client_auth_required => 1
        }
    );

}

sub artist {
    my $self = shift;
    my $id   = shift;

    return $self->send_get_request(
        {
            method               => 'artist',
            params               => { 'id' => $id },
            client_auth_required => 1
        }
    );

}

sub artists {
    my $self    = shift;
    my $artists = shift;

    if ( ref($artists) eq 'ARRAY' ) {
        $artists = join_ids($artists);
    }

    return $self->send_get_request(
        {
            method               => 'artists',
            params               => { 'ids' => $artists },
            client_auth_required => 1
        }
    );

}

sub artist_albums {
    my $self      = shift;
    my $artist_id = shift;
    my $extras    = shift;

    return $self->send_get_request(
        {
            method               => 'artist_albums',
            params               => { 'id' => $artist_id },
            extras               => $extras,
            client_auth_required => 1
        }
    );

}

sub artist_top_tracks {
    my $self      = shift;
    my $artist_id = shift;
    my $country   = shift;

    return $self->send_get_request(
        {
            method => 'artist_top_tracks',
            params => {
                'id'                 => $artist_id,
                'country'            => $country,
                client_auth_required => 1
            }
        }
    );

}

sub artist_related_artists {
    my $self      = shift;
    my $artist_id = shift;
    my $country   = shift;

    return $self->send_get_request(
        {
            method => 'artist_related_artists',
            params => { 'id' => $artist_id }

            #            'country' => $country
            #          }
        }
    );

}

sub me {
    my $self = shift;
    return $self->send_get_request(
        {
            method               => 'me',
            client_auth_required => 1
        }
    );
}

sub next_result_set {
    my $self = shift;
    my $url  = $self->get('next');
    return unless defined $url && $url ne 'null' && $url ne q{};
    return $self->query_full_url( $url, 1 );
}

sub previous_result_set {
    my $self = shift;
    my $url  = $self->get('previous');
    return unless defined $url && $url ne 'null' && $url ne q{};
    return $self->query_full_url( $url, 1 );
}

sub search {
    my $self   = shift;
    my $q      = shift;
    my $type   = shift;
    my $extras = shift;

    # looks like search now requires auth
    # we will force authentication but need to
    # reset this to the previous value since not
    # all requests require auth
    my $old_force_client_auth = $self->force_client_auth();
    $self->force_client_auth(1);

    my $params = {
        method => 'search',
        q      => $q,
        type   => $type,
        extras => $extras

    };

    my $response = $self->send_get_request($params);

    # reset auth to what it was before to avoid overly chatty
    # requests
    $self->force_client_auth($old_force_client_auth);
    return $response;
}

sub track {
    my $self = shift;
    my $id   = shift;
    return $self->send_get_request(
        {
            method => 'track',
            params => { 'id' => $id }
        }
    );
}

sub browse_featured_playlists {
    my $self   = shift;
    my $extras = shift;

    # locale
    # country
    # limit
    # offset

    return $self->send_get_request(
        {
            method               => 'browse_featured_playlists',
            extras               => $extras,
            client_auth_required => 1
        }
    );
}

sub browse_new_releases {
    my $self   = shift;
    my $extras = shift;

    # locale
    # country
    # limit
    # offset

    return $self->send_get_request(
        {
            method               => 'browse_new_releases',
            extras               => $extras,
            client_auth_required => 1
        }
    );
}

sub tracks {
    my $self   = shift;
    my $tracks = shift;

    if ( ref($tracks) eq 'ARRAY' ) {
        $tracks = join_ids($tracks);
    }

    return $self->send_get_request(
        {
            method => 'tracks',
            params => { 'ids' => $tracks }
        }
    );

}

sub user {
    my $self    = shift;
    my $user_id = shift;
    return $self->send_get_request(
        {
            method => 'user',
            params => { 'user_id' => $user_id }
        }
    );

}

sub get_playlist {
    my ( $self, $playlist_id ) = @_;
    return $self->send_get_request(
        {
            method               => 'get_playlist',
            params               => { 'playlist_id' => $playlist_id },
            client_auth_required => 1
        }
    );
}

sub get_playlist_items {
    my ( $self, $playlist_id, $extras ) = @_;
    return $self->send_get_request(
        {
            method               => 'get_playlist_items',
            params               => { 'playlist_id' => $playlist_id },
            client_auth_required => 1,
            extras               => $extras
        }
    );
}

sub create_playlist {
    my ( $self, $name, $public, $description ) = @_;

    my %params = ( 'name' => $name );
    $params{public}      = $public ? \1 : \0 if defined $public;
    $params{description} = $description      if defined $description;

    return $self->send_post_request(
        {
            method               => 'create_playlist',
            client_auth_required => 1,
            params               => \%params
        }
    );
}

sub get_current_user_playlists {
    my ( $self, $extras ) = @_;
    return $self->send_get_request(
        {
            method               => 'get_current_user_playlists',
            client_auth_required => 1,
            extras               => $extras
        }
    );
}

sub add_items_to_playlist {
    my ( $self, $playlist_id, $uris, $position ) = @_;

    my %params = (
        'playlist_id' => $playlist_id,
        'uris'        => ref $uris eq 'ARRAY' ? $uris : [$uris],
    );
    $params{position} = $position if defined $position;

    return $self->send_post_request(
        {
            method               => 'add_items_to_playlist',
            client_auth_required => 1,
            params               => \%params
        }
    );
}

sub unfollow_playlist {
    my ( $self, $playlist_id ) = @_;
    return $self->send_delete_request(
        {
            method               => 'unfollow_playlist',
            client_auth_required => 1,
            params               => { 'playlist_id' => $playlist_id }
        }
    );
}

sub remove_user_saved_tracks {
    my ( $self, $ids ) = @_;

    if ( ref($ids) eq 'ARRAY' ) {
        $ids = join_ids($ids);
    }

    return $self->send_delete_request(
        {
            method => 'remove_user_saved_tracks',
            params => { 'ids' => $ids }
        }
    );
}

sub check_users_saved_tracks {
    my ( $self, $ids ) = @_;

    if ( ref($ids) eq 'ARRAY' ) {
        $ids = join_ids($ids);
    }

    return $self->send_get_request(
        {
            method               => 'check_users_saved_tracks',
            params               => { 'ids' => $ids },
            client_auth_required => 1
        }
    );
}

sub get_several_tracks_audio_features {
    my ( $self, $ids ) = @_;

    if ( ref($ids) eq 'ARRAY' ) {
        $ids = join_ids($ids);
    }

    return $self->send_get_request(
        {
            method               => 'get_several_tracks_audio_features',
            params               => { 'ids' => $ids },
            client_auth_required => 1
        }
    );
}

sub get_track_audio_features {
    my ( $self, $id ) = @_;

    return $self->send_get_request(
        {
            method               => 'get_track_audio_features',
            params               => { 'id' => $id },
            client_auth_required => 1
        }
    );
}

sub get_track_audio_analysis {
    my ( $self, $id ) = @_;

    return $self->send_get_request(
        {
            method               => 'get_track_audio_analysis',
            params               => { 'id' => $id },
            client_auth_required => 1
        }
    );
}

sub get_recommendations {
    my ( $self, %params ) = @_;

    return $self->send_get_request(
        {
            method               => 'get_recommendations',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub get_followed_artists {
    my ( $self, %params ) = @_;

    # Ensure 'type' is set to 'artist' as it's the only supported value
    $params{type} = 'artist';

    return $self->send_get_request(
        {
            method               => 'get_followed_artists',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub follow_artists_or_users {
    my ( $self, $type, $ids ) = @_;

    die "Type must be 'artist' or 'user'"
        unless $type eq 'artist' or $type eq 'user';

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_put_request(
        {
            method => 'follow_artists_or_users',
            params => {
                type => $type,
                ids  => $id_list
            },
            client_auth_required => 1
        }
    );
}

sub unfollow_artists_or_users {
    my ( $self, $type, $ids ) = @_;

    die "Type must be 'artist' or 'user'"
        unless $type eq 'artist' or $type eq 'user';

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_delete_request(
        {
            method => 'unfollow_artists_or_users',
            params => {
                type => $type,
                ids  => $id_list
            },
            client_auth_required => 1
        }
    );
}

sub check_if_user_follows_artists_or_users {
    my ( $self, $type, $ids ) = @_;

    die "Type must be 'artist' or 'user'"
        unless $type eq 'artist' or $type eq 'user';

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_get_request(
        {
            method => 'check_if_user_follows_artists_or_users',
            params => {
                type => $type,
                ids  => $id_list
            },
            client_auth_required => 1
        }
    );
}

sub check_if_user_follows_playlist {
    my ( $self, $playlist_id, $ids ) = @_;

    die "playlist_id is required" unless $playlist_id;
    die "ids is required"         unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_get_request(
        {
            method => 'check_if_user_follows_playlist',
            params => {
                playlist_id => $playlist_id,
                ids         => $id_list
            },
            client_auth_required => 1
        }
    );
}

# Spotify URIs contain ':' so they must be escaped before being placed
# in the uris= query parameter.  Commas separating multiple URIs are
# escaped too (%2C), which the API accepts.
sub _uris_param {
    my $uris = shift;
    $uris = join( ',', @{$uris} ) if ref $uris eq 'ARRAY';
    return uri_escape($uris);
}

sub save_library_items {
    my ( $self, $uris ) = @_;

    die "Spotify URIs are required" unless $uris;

    return $self->send_put_request(
        {
            method               => 'save_library_items',
            params               => { uris => _uris_param($uris) },
            client_auth_required => 1
        }
    );
}

sub remove_library_items {
    my ( $self, $uris ) = @_;

    die "Spotify URIs are required" unless $uris;

    return $self->send_delete_request(
        {
            method               => 'remove_library_items',
            params               => { uris => _uris_param($uris) },
            client_auth_required => 1
        }
    );
}

sub check_library_items {
    my ( $self, $uris ) = @_;

    die "Spotify URIs are required" unless $uris;

    return $self->send_get_request(
        {
            method               => 'check_library_items',
            params               => { uris => _uris_param($uris) },
            client_auth_required => 1
        }
    );
}

sub get_audiobook {
    my ( $self, $id, $market ) = @_;

    die "Audiobook ID is required" unless $id;

    my $params = { id => $id };
    $params->{market} = $market if $market;

    return $self->send_get_request(
        {
            method               => 'get_audiobook',
            params               => $params,
            client_auth_required => 1
        }
    );
}

sub get_several_audiobooks {
    my ( $self, $ids, $market ) = @_;

    die "Audiobook IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    my $params = { ids => $id_list };
    $params->{market} = $market if $market;

    return $self->send_get_request(
        {
            method               => 'get_several_audiobooks',
            params               => $params,
            client_auth_required => 1
        }
    );
}

sub get_audiobook_chapters {
    my ( $self, $id, %params ) = @_;

    die "Audiobook ID is required" unless $id;

    $params{id} = $id;

    return $self->send_get_request(
        {
            method               => 'get_audiobook_chapters',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub get_users_saved_audiobooks {
    my ( $self, $limit, $offset ) = @_;

    my $params = {};
    $params->{limit}  = $limit  if $limit;
    $params->{offset} = $offset if defined $offset;

    return $self->send_get_request(
        {
            method               => 'get_users_saved_audiobooks',
            params               => $params,
            client_auth_required => 1
        }
    );
}

sub save_audiobooks_for_current_user {
    my ( $self, $ids ) = @_;

    die "Audiobook IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_put_request(
        {
            method               => 'save_audiobooks_for_current_user',
            params               => { ids => $id_list },
            client_auth_required => 1
        }
    );
}

sub remove_users_saved_audiobooks {
    my ( $self, $ids ) = @_;

    die "Audiobook IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_delete_request(
        {
            method               => 'remove_users_saved_audiobooks',
            params               => { ids => $id_list },
            client_auth_required => 1
        }
    );
}

sub check_users_saved_audiobooks {
    my ( $self, $ids ) = @_;

    die "Audiobook IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_get_request(
        {
            method               => 'check_users_saved_audiobooks',
            params               => { ids => $id_list },
            client_auth_required => 1
        }
    );
}

sub get_users_saved_shows {
    my ( $self, %params ) = @_;

    return $self->send_get_request(
        {
            method               => 'get_users_saved_shows',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub save_shows_for_current_user {
    my ( $self, $ids ) = @_;

    die "Show IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_put_request(
        {
            method               => 'save_shows_for_current_user',
            params               => { ids => $id_list },
            client_auth_required => 1
        }
    );
}

sub check_users_saved_shows {
    my ( $self, $ids ) = @_;

    die "Show IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    return $self->send_get_request(
        {
            method               => 'check_users_saved_shows',
            params               => { ids => $id_list },
            client_auth_required => 1
        }
    );
}

sub get_categories {
    my ( $self, %params ) = @_;

    return $self->send_get_request(
        {
            method               => 'get_categories',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub get_category {
    my ( $self, $category_id, %params ) = @_;

    die "Category ID is required" unless $category_id;

    $params{category_id} = $category_id;

    return $self->send_get_request(
        {
            method               => 'get_category',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub get_chapter {
    my ( $self, $id, %params ) = @_;

    die "Chapter ID is required" unless $id;

    $params{id} = $id;

    return $self->send_get_request(
        {
            method               => 'get_chapter',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub get_several_chapters {
    my ( $self, $ids, %params ) = @_;

    die "Chapter IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    $params{ids} = $id_list;

    return $self->send_get_request(
        {
            method               => 'get_several_chapters',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

sub get_available_genre_seeds {
    my ($self) = @_;

    return $self->send_get_request(
        {
            method               => 'get_available_genre_seeds',
            client_auth_required => 1
        }
    );
}

sub get_available_markets {
    my ($self) = @_;

    return $self->send_get_request(
        {
            method               => 'get_available_markets',
            client_auth_required => 1
        }
    );
}

sub get_show {
    my ( $self, $id, $market ) = @_;

    die "Show ID is required" unless $id;

    my $params = { id => $id };
    $params->{market} = $market if $market;

    return $self->send_get_request(
        {
            method               => 'get_show',
            params               => $params,
            client_auth_required => 1
        }
    );
}

sub get_several_shows {
    my ( $self, $ids, $market ) = @_;

    die "Show IDs are required" unless $ids;

    my $id_list = ref($ids) eq 'ARRAY' ? join( ',', @$ids ) : $ids;

    my $params = { ids => $id_list };
    $params->{market} = $market if $market;

    return $self->send_get_request(
        {
            method               => 'get_several_shows',
            params               => $params,
            client_auth_required => 1
        }
    );
}

sub get_show_episodes {
    my ( $self, $id, %params ) = @_;

    die "Show ID is required" unless $id;

    $params{id} = $id;

    return $self->send_get_request(
        {
            method               => 'get_show_episodes',
            params               => \%params,
            client_auth_required => 1
        }
    );
}

1;

=pod

=encoding UTF-8

=head1 NAME

WWW::Spotify - Spotify Web API Wrapper

=head1 VERSION

version 0.013

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Wrapper for the Spotify Web API.

https://developer.spotify.com/web-api/

Have access to a JSON viewer to help develop and debug. The Chrome JSON viewer is
very good and provides the exact path of the item within the JSON in the lower left
of the screen as you mouse over an element.

=head1 CONSTRUCTOR ARGS

=head2 ua

You may provide your own user agent object to the constructor.  This should be
a L<LWP:UserAgent> or a subclass of it, like L<WWW::Mechanize>. If you are
using L<WWW::Mechanize>, you may want to set autocheck off.  To get extra
debugging information, you can do something like this:

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use WWW::Mechanize ();
    use WWW::Spotify ();

    my $mech = WWW::Mechanize->new( autocheck => 0 );
    debug_ua( $mech );
    my $spotify = WWW::Spotify->new( ua => $mech )

=head1 METHODS

=head2 auto_json_decode

When true results will be returned as JSON instead of a perl data structure

    $spotify->auto_json_decode(1);

=head2 get

Returns a specific item or array of items from the JSON result of the
last action.

    $result = $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 15 , offset => 0 }
    );

 my $image_url = $spotify->get( 'artists.items[0].images[0].url' );

JSON::Path is the underlying library that actually parses the JSON.

=head2 query_full_url( $url , [needs o_auth] )

Results from some calls (playlist for example) return full urls that can be in their entirety. This method allows you
make a call to that url and use all of the o_auth and other features provided.

    $spotify->query_full_url( "https://api.spotify.com/v1/users/spotify/playlists/06U6mm6KPtPIg9D4YGNEnu" , 1 );

=head2 album

equivalent to /v1/albums/{id}

    $spotify->album('0sNOF9WDwhWunNAHPD3Baj');

used album vs albums since it is a singular request

=head2 albums

equivalent to /v1/albums?ids={ids}

    $spotify->albums( '41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4,6UXCm6bOO4gFlDQZV5yL37' );

or

    $spotify->albums( [ '41MnTivkwTO3UUJ8DrqEJJ',
                        '6JWc4iAiJ9FjyK0B59ABb4',
                        '6UXCm6bOO4gFlDQZV5yL37' ] );

=head2 albums_tracks

equivalent to /v1/albums/{id}/tracks

    $spotify->albums_tracks('6akEvsycLGftJxYudPjmqK',
    {
        limit => 1,
        offset => 1

    }
    );

=head2 artist

equivalent to /v1/artists/{id}

    $spotify->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

used artist vs artists since it is a singular request and avoids collision with "artists" method

=head2 artists

equivalent to /v1/artists?ids={ids}

    my $artists_multiple = '0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin';

    $spotify->artists( $artists_multiple );

=head2 artist_albums

equivalent to /v1/artists/{id}/albums

    $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

=head2 artist_top_tracks

equivalent to /v1/artists/{id}/top-tracks

    $spotify->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE', # artist id
                                 'SE' # country
                                            );

=head2 artist_related_artists

equivalent to /v1/artists/{id}/related-artists

    $spotify->artist_related_artists( '43ZHCT0cAZBISjO8DG9PnE' );

=head2 search

equivalent to /v1/search?type=album (etc)

    $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 10 , offset => 0 }
    );

Note: as of the February 2026 API changes the maximum C<limit> is 10
(previously 50); use C<offset> to paginate.

=head2 track

equivalent to /v1/tracks/{id}

    $spotify->track( '0eGsygTp906u18L0Oimnem' );

=head2 tracks

equivalent to /v1/tracks?ids={ids}

    $spotify->tracks( '0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G' );

=head2 browse_featured_playlists

equivalent to /v1/browse/featured-playlists

    $spotify->browse_featured_playlists();

requires OAuth

=head2 browse_new_releases

equivalent to /v1/browse/new-releases

requires OAuth

    $spotify->browse_new_releases

=head2 force_client_auth

Boolean

will pass authentication (OAuth) on all requests when set

    $spotify->force_client_auth(1);

=head2 user

equivalent to /v1/users/{user_id}

    $spotify->user('glennpmcdonald');

=head2 get_playlist

equivalent to GET /v1/playlists/{playlist_id}

    $spotify->get_playlist('37i9dQZF1DXcBWIGoYBM5M');

This method retrieves a playlist owned by a Spotify user. The playlist must be public or owned by the authenticated user.

=head2 get_playlist_items

equivalent to /v1/playlists/{playlist_id}/items (renamed from /tracks in the
February 2026 API changes)

    $spotify->get_playlist_items('37i9dQZF1DXcBWIGoYBM5M', { limit => 10, offset => 0 });

=head2 create_playlist

equivalent to POST /v1/me/playlists (replaced /v1/users/{user_id}/playlists
in the February 2026 API changes) - creates a playlist for the
authenticated user

    $spotify->create_playlist('My New Playlist', 1, 'A description of my playlist');

=head2 get_current_user_playlists

equivalent to /v1/me/playlists

    $spotify->get_current_user_playlists({ limit => 20, offset => 0 });

=head2 add_items_to_playlist

equivalent to /v1/playlists/{playlist_id}/items (renamed from /tracks in the
February 2026 API changes)

    $spotify->add_items_to_playlist('playlist_id', ['spotify:track:4iV5W9uYEdYUVa79Axb7Rh', 'spotify:track:1301WleyT98MSxVHPZCA6M'], 0);

=head2 unfollow_playlist

equivalent to DELETE /v1/playlists/{playlist_id}/followers - removes the
playlist from the authenticated user's library (Spotify has no hard
playlist delete)

    $spotify->unfollow_playlist('playlist_id');

=head2 remove_user_saved_tracks

equivalent to /v1/me/tracks

    $spotify->remove_user_saved_tracks(['4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M']);

=head2 check_users_saved_tracks

equivalent to /v1/me/tracks/contains

    $spotify->check_users_saved_tracks(['4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M']);

=head2 check_users_saved_shows

equivalent to GET /v1/me/shows/contains

    $spotify->check_users_saved_shows(['5CfCWKI5pZ28U0uOzXkDHe', '5as3aKmN2k11yfDDDSrvaZ']);

or

    $spotify->check_users_saved_shows('5CfCWKI5pZ28U0uOzXkDHe,5as3aKmN2k11yfDDDSrvaZ');

This method checks if one or more shows are already saved in the current Spotify user's library.

=head2 get_several_tracks_audio_features

equivalent to /v1/audio-features

    $spotify->get_several_tracks_audio_features(['4iV5W9uYEdYUVa79Axb7Rh', '1301WleyT98MSxVHPZCA6M']);

=head2 get_track_audio_features

equivalent to /v1/audio-features/{id}

    $spotify->get_track_audio_features('4iV5W9uYEdYUVa79Axb7Rh');

=head2 get_track_audio_analysis

equivalent to /v1/audio-analysis/{id}

    $spotify->get_track_audio_analysis('4iV5W9uYEdYUVa79Axb7Rh');

=head2 get_recommendations

equivalent to /v1/recommendations

    $spotify->get_recommendations(
        seed_artists => '4NHQUGzhtTLFvgF5SZesLK',
        seed_genres => 'classical,country',
        seed_tracks => '0c6xIDDpzE81m2q797ordA',
        limit => 10,
        market => 'ES'
    );

=head2 get_followed_artists

equivalent to /v1/me/following

    $spotify->get_followed_artists(
        limit => 20,
        after => '0I2XqVXqHScXjHhk6AYYRe'
    );

Note: This method always sets the 'type' parameter to 'artist' as it's the only supported value.

=head2 follow_artists_or_users

equivalent to PUT /v1/me/following

    $spotify->follow_artists_or_users('artist', ['2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E']);

or

    $spotify->follow_artists_or_users('user', '2CIMQHirSU0MQqyYHq0eOx,57dN52uHvrHOxijzpIgu3E');

=head2 unfollow_artists_or_users

equivalent to DELETE /v1/me/following

    $spotify->unfollow_artists_or_users('artist', ['2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E']);

or

    $spotify->unfollow_artists_or_users('user', '2CIMQHirSU0MQqyYHq0eOx,57dN52uHvrHOxijzpIgu3E');

=head2 check_if_user_follows_artists_or_users

equivalent to GET /v1/me/following/contains

    $spotify->check_if_user_follows_artists_or_users('artist', ['2CIMQHirSU0MQqyYHq0eOx', '57dN52uHvrHOxijzpIgu3E']);

or

    $spotify->check_if_user_follows_artists_or_users('user', '2CIMQHirSU0MQqyYHq0eOx,57dN52uHvrHOxijzpIgu3E');

=head2 check_if_user_follows_playlist

equivalent to GET /v1/playlists/{playlist_id}/followers/contains

    $spotify->check_if_user_follows_playlist('3cEYpjA9oz9GiPac4AsH4n', 'jmperezperez');

or

    $spotify->check_if_user_follows_playlist('3cEYpjA9oz9GiPac4AsH4n', ['jmperezperez']);

=head2 save_library_items

equivalent to PUT /v1/me/library (February 2026 consolidated library
endpoint; replaces the removed PUT /v1/me/tracks, /v1/me/albums,
/v1/me/episodes, /v1/me/shows, /v1/me/audiobooks, /v1/me/following and
/v1/playlists/{id}/followers endpoints)

Takes Spotify URIs (not bare ids), as a comma-separated string or an
array reference.  Maximum 40 URIs.

    $spotify->save_library_items( [ 'spotify:track:7a3LWj5xSFhFRYmztS8wgK',
                                    'spotify:album:4aawyAB9vmqN3uQ7FjRGTy' ] );

=head2 remove_library_items

equivalent to DELETE /v1/me/library (February 2026 consolidated library
endpoint; replaces the removed per-type DELETE endpoints)

    $spotify->remove_library_items( 'spotify:track:7a3LWj5xSFhFRYmztS8wgK' );

=head2 check_library_items

equivalent to GET /v1/me/library/contains (February 2026 consolidated
library endpoint; replaces the removed per-type */contains endpoints)

    $spotify->check_library_items( [ 'spotify:track:7a3LWj5xSFhFRYmztS8wgK' ] );

=head2 DEPRECATED METHODS

Spotify's November 2024 and February 2026 API changes removed or
deprecated a number of endpoints.  The corresponding methods are kept
for backwards compatibility but warn once per process when called, and
Spotify will reject the request:

batch fetch (removed - fetch individually instead): C<albums>, C<artists>,
C<tracks>, C<get_several_shows>, C<get_several_audiobooks>,
C<get_several_chapters>, C<get_several_tracks_audio_features>

browse/artist (removed): C<browse_featured_playlists>,
C<browse_new_releases>, C<get_categories>, C<get_category>,
C<artist_top_tracks>, C<artist_related_artists>

audio/recommendations (deprecated): C<get_track_audio_features>,
C<get_track_audio_analysis>, C<get_recommendations>,
C<get_available_genre_seeds>

library (consolidated into /v1/me/library - use C<save_library_items>,
C<remove_library_items>, C<check_library_items>):
C<remove_user_saved_tracks>, C<check_users_saved_tracks>,
C<save_shows_for_current_user>, C<check_users_saved_shows>,
C<save_audiobooks_for_current_user>, C<remove_users_saved_audiobooks>,
C<check_users_saved_audiobooks>, C<follow_artists_or_users>,
C<unfollow_artists_or_users>, C<check_if_user_follows_artists_or_users>,
C<check_if_user_follows_playlist>

other: C<user> (GET /v1/users/{user_id} deprecated/removed)

=head2 get_audiobook

equivalent to GET /v1/audiobooks/{id}

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe');

or with market parameter:

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe', 'US');

=head2 get_users_saved_audiobooks

equivalent to GET /v1/me/audiobooks

    $spotify->get_users_saved_audiobooks(20, 0);

=head2 remove_users_saved_audiobooks

equivalent to DELETE /v1/me/audiobooks

    $spotify->remove_users_saved_audiobooks(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ']);

or

    $spotify->remove_users_saved_audiobooks('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ');

This method removes one or more audiobooks from the current user's library.

=head2 get_available_genre_seeds

equivalent to GET /v1/recommendations/available-genre-seeds

    $spotify->get_available_genre_seeds();

This method retrieves a list of available genres seed parameter values for recommendations.

=head2 get_available_markets

equivalent to GET /v1/markets

    $spotify->get_available_markets();

This method retrieves the list of markets where Spotify is available.

=head2 get_show

equivalent to GET /v1/shows/{id}

    $spotify->get_show('38bS44xjbVVZ3No3ByF1dJ', 'US');

This method retrieves Spotify catalog information for a single show identified by its unique Spotify ID.

=head2 get_several_shows

equivalent to GET /v1/shows

    $spotify->get_several_shows(['5CfCWKI5pZ28U0uOzXkDHe', '5as3aKmN2k11yfDDDSrvaZ'], 'US');

or

    $spotify->get_several_shows('5CfCWKI5pZ28U0uOzXkDHe,5as3aKmN2k11yfDDDSrvaZ', 'US');

This method retrieves Spotify catalog information for several shows based on their Spotify IDs.

=head2 get_show_episodes

equivalent to GET /v1/shows/{id}/episodes

    $spotify->get_show_episodes('38bS44xjbVVZ3No3ByF1dJ', market => 'US', limit => 10, offset => 5);

This method retrieves Spotify catalog information about a show's episodes. Optional parameters can be used to limit the number of episodes returned.

=head2 get_audiobook_chapters

equivalent to GET /v1/audiobooks/{id}/chapters

    $spotify->get_audiobook_chapters('3ZXb8FKZGU0EHALYX6uCzU', market => 'US', limit => 50, offset => 0);

This method retrieves the chapters of an audiobook.

=head2 get_several_audiobooks

equivalent to GET /v1/audiobooks

    $spotify->get_several_audiobooks(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ'], 'US');

or

    $spotify->get_several_audiobooks('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ', 'US');

This method retrieves multiple audiobooks based on their Spotify IDs.

=head2 send_delete_request

Internal method used to send DELETE requests to the Spotify API.

=head2 send_put_request

Internal method used to send PUT requests to the Spotify API.

=head2 check_users_saved_audiobooks

equivalent to GET /v1/me/audiobooks/contains

    $spotify->check_users_saved_audiobooks(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ']);

or

    $spotify->check_users_saved_audiobooks('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ');

=head2 get_users_saved_shows

equivalent to GET /v1/me/shows

    $spotify->get_users_saved_shows(limit => 20, offset => 0);

This method retrieves a list of shows saved in the current Spotify user's library. Optional parameters can be used to limit the number of shows returned.

=head2 save_shows_for_current_user

equivalent to PUT /v1/me/shows

    $spotify->save_shows_for_current_user(['5CfCWKI5pZ28U0uOzXkDHe', '5as3aKmN2k11yfDDDSrvaZ']);

or

    $spotify->save_shows_for_current_user('5CfCWKI5pZ28U0uOzXkDHe,5as3aKmN2k11yfDDDSrvaZ');

This method saves one or more shows to the current user's library.

=head2 get_categories

equivalent to GET /v1/browse/categories

    $spotify->get_categories(
        country => 'US',
        locale => 'en_US',
        limit => 20,
        offset => 0
    );

=head2 get_category

equivalent to GET /v1/browse/categories/{category_id}

    $spotify->get_category('dinner', locale => 'en_US');

=head2 get_chapter

equivalent to GET /v1/chapters/{id}

    $spotify->get_chapter('0D5wENdkdwbqlrHoaJ9g29', market => 'US');

=head2 get_several_chapters

equivalent to GET /v1/chapters

    $spotify->get_several_chapters(['0IsXVP0JmcB2adSE338GkK', '3ZXb8FKZGU0EHALYX6uCzU', '0D5wENdkdwbqlrHoaJ9g29'], market => 'US');

or

    $spotify->get_several_chapters('0IsXVP0JmcB2adSE338GkK,3ZXb8FKZGU0EHALYX6uCzU,0D5wENdkdwbqlrHoaJ9g29', market => 'US');

=head2 save_audiobooks_for_current_user

equivalent to PUT /v1/me/audiobooks

    $spotify->save_audiobooks_for_current_user(['18yVqkdbdRvS24c0Ilj2ci', '1HGw3J3NxZO1TP1BTtVhpZ']);

or

    $spotify->save_audiobooks_for_current_user('18yVqkdbdRvS24c0Ilj2ci,1HGw3J3NxZO1TP1BTtVhpZ');

This method saves one or more audiobooks to the current user's library.

=head2 oauth_client_id

needed for requests that require OAuth, see Spotify API documentation for more information

    $spotify->oauth_client_id('2xfjijkcjidjkfdi');

Can also be set via environment variable, SPOTIFY_CLIENT_ID

=head2 oauth_client_secret

needed for requests that require OAuth, see Spotify API documentation for more information

    $spotify->oauth_client_secret('2xfjijkcjidjkfdi');

Can also be set via environment variable, SPOTIFY_CLIENT_SECRET

=head2 authorize_url

builds the URL to send a user to for the OAuth authorization-code flow.
Uses C<oauth_client_id> and C<oauth_redirect_uri>; C<scope> and C<state>
are optional

    my $url = $spotify->authorize_url({
        scope => 'user-read-private playlist-modify-private',
        state => $random_string,
    });

Open the URL in a browser; after login Spotify redirects to
C<oauth_redirect_uri> with a C<code> query parameter.

=head2 get_access_token

exchanges an authorization code (from the C<authorize_url> redirect) for
a user access token. On success stores C<current_access_token>,
C<refresh_token>, and C<token_expires_at>, and returns true

    $spotify->get_access_token($code);

=head2 refresh_access_token

fetches a new access token using the stored C<refresh_token> (set by
C<get_access_token>). Dies if no refresh token is stored; returns true
on success

    $spotify->refresh_access_token();

=head2 refresh_token

the OAuth refresh token, set automatically by C<get_access_token>. Can
be set manually to restore a persisted session

    $spotify->refresh_token($saved_refresh_token);

=head2 response_status

returns the response code for the last request made

    my $status = $spotify->response_status();

=head2 response_content_type

returns the response type for the last request made, helpful to verify JSON

    my $content_type = $spotify->response_content_type();

=head2 custom_request_handler

pass a callback subroutine to this method that will be run at the end of the
request prior to die_on_response_error, if enabled

    # $m is the WWW::Mechanize object
    $spotify->custom_request_handler(
        sub { my $m = shift;
            if ($m->status() == 401) {
                return 1;
            }
        }
    );

=head2 custom_request_handler_result

returns the result of the most recent execution of the custom_request_handler callback
this allows you to determine the success/failure criteria of your callback

    my $callback_result = $spotify->custom_request_handler_result();

=head2 die_on_response_error

Boolean - default 0

added to provide minimal automated checking of responses

    $spotify->die_on_response_error(1);

eval {
    # run assuming you do NOT have proper authentication setup
    $result = $spotify->album('0sNOF9WDwhWunNAHPD3Baj');
};

if ($@) {
    warn $spotify->last_error();
}

=head2 last_error

returns last_error (if applicable) from the most recent request.
reset to empty string on each request

    print $spotify->last_error() , "\n";

=head1 THANKS

Paul Lamere at The Echo Nest / Spotify

All the great Perl community members that keep Perl fun

Olaf Alders for all his help and support in maintaining this module

=cut

__END__

# ABSTRACT: Spotify Web API Wrapper

1;    # Return true value at the end of the module
