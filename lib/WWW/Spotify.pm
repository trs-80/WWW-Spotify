package WWW::Spotify;

use Moo 2.002004;

our $VERSION = '1.001';

use JSON::Path      ();
use JSON::MaybeXS   qw( decode_json encode_json );
use MIME::Base64    qw( encode_base64 );
use Types::Standard qw( Bool InstanceOf Int Str CodeRef );
use HTTP::Status    qw( HTTP_OK is_success );
use URI::Escape     qw( uri_escape uri_escape_utf8 );
use LWP::UserAgent  ();

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

has 'grab_response_header' => (
    is      => 'rw',
    isa     => Bool,
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
    is      => 'ro',
    isa     => Str,
    default => 'https'
);

has 'current_client_credentials' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
);

has 'uri_hostname' => (
    is      => 'ro',
    isa     => Str,
    default => 'api.spotify.com'
);

has 'auto_json_decode' => (
    is      => 'rw',
    isa     => Bool,
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

has 'ua' => (
    is      => 'ro',
    isa     => InstanceOf ['LWP::UserAgent'],
    lazy    => 1,
    default => sub { LWP::UserAgent->new },
);

has 'response_status' => (
    is      => 'rw',
    isa     => Int,
    default => 0
);

has 'response_content_type' => (
    is      => 'rw',
    isa     => Str,
    default => q{}
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
        path   => '/v1/me/shows',
        info   => 'Get User\'s Saved Shows',
        type   => 'GET',
        method => 'get_users_saved_shows',
        params => [ 'limit', 'offset' ]
    },

    {
        path   => '/v1/chapters/{id}',
        info   => 'Get a Chapter',
        type   => 'GET',
        method => 'get_chapter',
        params => [ 'id', 'market' ]
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
        path   => '/v1/shows/{id}/episodes',
        info   => 'Get Show Episodes',
        type   => 'GET',
        method => 'get_show_episodes',
        params => [ 'id', 'market', 'limit', 'offset' ]
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
        path   => '/v1/me/following',
        info   => 'Get Followed Artists',
        type   => 'GET',
        method => 'get_followed_artists',
        params => [ 'type', 'after', 'limit' ]
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
        path   => '/v1/artists/{id}/albums',
        info   => q{Get an artist's albums},
        type   => 'GET',
        method => 'artist_albums',
        params => [ 'limit', 'offset', 'country', 'album_type' ]
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
        path   => '/v1/me',
        info   => q{Get current user's profile},
        type   => 'GET',
        method => 'me'
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

my %method_to_uri = map { $_->{method} => $_->{path} } @api_call_options;

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
        my ( $path_part, $query_part ) = split /\?/, $path, 2;

        # Path-segment placeholders: fully escape the value.
        $path_part =~ s/\{([^}]+)\}/
            my $v = delete $unused{$1};
            defined $v ? uri_escape($v) : q{}
        /ge;

        if ( defined $query_part ) {

            # Query-string placeholders: substitute raw.  Callers are
            # responsible for any encoding needed (e.g. _uris_param pre-escapes
            # Spotify URIs; search() pre-escapes q and type).
            $query_part =~ s/\{([^}]+)\}/
                my $v = delete $unused{$1};
                defined $v ? $v : q{}
            /ge;
            $path = $path_part . '?' . $query_part;
        }
        else {
            $path = $path_part;
        }

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
#   $attributes  - original attributes hashref
#   $body        - optional request body (undef for GET)
#
# Returns the HTTP::Response.
sub _send_request {
    my ( $self, $verb, $url, $attributes, $body ) = @_;

    if ( $self->current_access_token() eq q{}
        || time() >= $self->token_expires_at() ) {
        warn "Needed to get access token\n" if $self->debug();
        $self->current_access_token(q{});
        $self->get_client_credentials();
    }

    my @headers
        = ( Authorization => 'Bearer ' . $self->current_access_token() );
    push @headers, 'Content-Type' => 'application/json', Content => $body
        if defined $body;

    my $res = $self->ua->$verb( $url, @headers );

    $self->response_headers( $res->headers->as_string )
        if $self->grab_response_header();
    $self->response_status( $res->code );
    $self->response_content_type( scalar $res->content_type );

    if ( $self->_has_custom_request_handler() ) {
        $self->_set_custom_request_handler_result(
            $self->custom_request_handler()->($res) );
    }

    return $res;
}

sub _finish_request {
    my ( $self, $res ) = @_;

    if ( $self->die_on_response_error() && $self->last_error ne '' ) {
        die $self->last_error();
    }

    return $self->format_results(
        $res->decoded_content( charset => 'none' ) );
}

# POST / PUT / DELETE: params not consumed by the URL path go in a JSON body.
sub _send_body_request {
    my ( $self, $verb, $attributes ) = @_;

    $self->last_error(q{});

    my ( $url, $body_params ) = $self->_build_url($attributes);
    my $body = %{$body_params} ? encode_json($body_params) : undef;
    my $res  = $self->_send_request( $verb, $url, $attributes, $body );

    if ( !is_success( $self->response_status() ) ) {
        warn "\u$verb request failed with status ",
            $self->response_status(), "\n"
            if $self->debug();
        $self->last_error( "\u$verb request failed, status("
                . $self->response_status()
                . ") examine last_result for details" );
    }

    return $self->_finish_request($res);
}

sub send_post_request   { $_[0]->_send_body_request( post   => $_[1] ) }
sub send_put_request    { $_[0]->_send_body_request( put    => $_[1] ) }
sub send_delete_request { $_[0]->_send_body_request( delete => $_[1] ) }

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
            push @tmp,
                "$key=" . uri_escape_utf8( $attributes->{extras}{$key} );
        }
        $uri_params = join( '&', @tmp );
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

            if ( $attributes->{params} ) {

                # Split on '?' so we only uri_escape values that appear in the
                # path segment.  Query-string placeholder values (comma-lists,
                # pre-escaped URIs, etc.) must be left as-is.
                my ( $path_part, $query_part ) = split /\?/, $path, 2;

                $path_part
                    =~ s/\{([^}]+)\}/uri_escape( $attributes->{params}{$1} )/ge;

                if ( defined $query_part ) {

                    # Substitute raw - callers pre-escape what needs escaping.
                    $query_part =~ s/\{([^}]+)\}/$attributes->{params}{$1}/ge;
                    $path = $path_part . '?' . $query_part;
                }
                else {
                    $path = $path_part;
                }
            }

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

    my $res = $self->_send_request( 'get', $url, $attributes, undef );

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

    return $self->_finish_request($res);
}

sub format_results {
    my $self    = shift;
    my $content = shift;

    # want to store the result in case
    # we want to interact with it via a helper method
    $self->last_result($content);

    if ( $self->auto_json_decode ) {
        my $decoded = eval { decode_json($content) };
        die "format_results: last_result is not valid JSON: $@\n" if $@;
        return $decoded;
    }

    # results are not altered in this case and would be
    # json instead of a perl data structure

    return $content;
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

    my $form = { grant_type => 'client_credentials' };
    $form->{scope} = $scope if $scope;

    $self->_request_token($form)
        or die "get_client_credentials: failed to obtain access token\n";
    warn "setting access token\n" if $self->debug();
    return $self->current_access_token();
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

sub _assert_token_url {
    my ($self) = @_;
    die "oauth_token_url '${\$self->oauth_token_url}' is not allowed - "
        . "only https://accounts.spotify.com/ URLs are permitted\n"
        unless $self->oauth_token_url
        =~ m{\Ahttps://accounts\.spotify\.com/}i;
}

sub _request_token {
    my ( $self, $form ) = @_;

    $self->_assert_token_url();

    my $encoded = encode_base64(
        $self->oauth_client_id() . ':' . $self->oauth_client_secret(), q{} );

    my $res = $self->ua->post(
        $self->oauth_token_url(), $form,
        Authorization => 'Basic ' . $encoded
    );

    my $result = eval { decode_json( $res->content ) };

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

    my @out;

    die "get(): no result available - make an API call first\n"
        unless length $self->last_result();

    my $result = eval { decode_json( $self->last_result() ) };
    die "get(): last_result is not valid JSON: $@\n" if $@;

    my $search_ref = $result;

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

sub query_full_url {
    my ( $self, $url ) = @_;

    # Prevent bearer-token leakage to off-origin hosts.  All Spotify API
    # responses that contain URLs (next/previous paging, href fields) point to
    # api.spotify.com; anything else is unexpected and potentially malicious.
    die "query_full_url: URL '$url' is not allowed - "
        . "only https://api.spotify.com/ URLs may be called with credentials\n"
        unless $url =~ m{\Ahttps://api\.spotify\.com/}i;

    return $self->send_get_request(
        { method => 'query_full_url', url => $url } );
}

#-- spotify specific methods

sub album {
    my $self = shift;
    my $id   = shift;

    die "album id is required\n" unless defined $id && length $id;

    return $self->send_get_request(
        {
            method => 'album',
            params => { 'id' => $id },
        }
    );
}

sub albums_tracks {
    my $self     = shift;
    my $album_id = shift;
    my $extras   = shift;

    die "album_id is required\n" unless defined $album_id && length $album_id;

    return $self->send_get_request(
        {
            method => 'albums_tracks',
            params => { 'id' => $album_id },
            extras => $extras,
        }
    );

}

sub artist {
    my $self = shift;
    my $id   = shift;

    die "artist id is required\n" unless defined $id && length $id;

    return $self->send_get_request(
        {
            method => 'artist',
            params => { 'id' => $id },
        }
    );

}

sub artist_albums {
    my $self      = shift;
    my $artist_id = shift;
    my $extras    = shift;

    die "artist_id is required\n"
        unless defined $artist_id && length $artist_id;

    return $self->send_get_request(
        {
            method => 'artist_albums',
            params => { 'id' => $artist_id },
            extras => $extras,
        }
    );

}

sub me {
    my $self = shift;
    return $self->send_get_request(
        {
            method => 'me',
        }
    );
}

sub next_result_set {
    my $self = shift;
    my $url  = $self->get('next');
    return unless defined $url && $url ne 'null' && $url ne q{};
    return $self->query_full_url($url);
}

sub previous_result_set {
    my $self = shift;
    my $url  = $self->get('previous');
    return unless defined $url && $url ne 'null' && $url ne q{};
    return $self->query_full_url($url);
}

sub search {
    my $self   = shift;
    my $q      = shift;
    my $type   = shift;
    my $extras = shift;

    die "search query (q) is required\n" unless defined $q    && length $q;
    die "search type is required\n"      unless defined $type && length $type;

    my $response = $self->send_get_request(
        {
            method => 'search',
            params => {
                q    => uri_escape_utf8($q),
                type => uri_escape_utf8($type),
            },
            extras => $extras,
        }
    );

    return $response;
}

sub track {
    my $self = shift;
    my $id   = shift;

    die "track id is required\n" unless defined $id && length $id;

    return $self->send_get_request(
        {
            method => 'track',
            params => { 'id' => $id }
        }
    );
}

sub get_playlist {
    my ( $self, $playlist_id ) = @_;

    die "playlist_id is required\n"
        unless defined $playlist_id && length $playlist_id;

    return $self->send_get_request(
        {
            method => 'get_playlist',
            params => { 'playlist_id' => $playlist_id },
        }
    );
}

sub get_playlist_items {
    my ( $self, $playlist_id, $extras ) = @_;

    die "playlist_id is required\n"
        unless defined $playlist_id && length $playlist_id;

    return $self->send_get_request(
        {
            method => 'get_playlist_items',
            params => { 'playlist_id' => $playlist_id },
            extras => $extras
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
            method => 'create_playlist',
            params => \%params
        }
    );
}

sub get_current_user_playlists {
    my ( $self, $extras ) = @_;
    return $self->send_get_request(
        {
            method => 'get_current_user_playlists',
            extras => $extras
        }
    );
}

sub add_items_to_playlist {
    my ( $self, $playlist_id, $uris, $position ) = @_;

    die "playlist_id is required\n"
        unless defined $playlist_id && length $playlist_id;

    my %params = (
        'playlist_id' => $playlist_id,
        'uris'        => ref $uris eq 'ARRAY' ? $uris : [$uris],
    );
    $params{position} = $position if defined $position;

    return $self->send_post_request(
        {
            method => 'add_items_to_playlist',
            params => \%params
        }
    );
}

sub unfollow_playlist {
    my ( $self, $playlist_id ) = @_;

    die "playlist_id is required\n"
        unless defined $playlist_id && length $playlist_id;

    return $self->send_delete_request(
        {
            method => 'unfollow_playlist',
            params => { 'playlist_id' => $playlist_id }
        }
    );
}

sub get_followed_artists {
    my ( $self, %params ) = @_;

    # Ensure 'type' is set to 'artist' as it's the only supported value
    $params{type} = 'artist';

    return $self->send_get_request(
        {
            method => 'get_followed_artists',
            params => \%params,
        }
    );
}

# Spotify URIs contain ':' and commas separate multiple items; both must be
# percent-encoded before being spliced into a query string by _build_url /
# send_get_request (which perform a raw substitution on the query part).
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
            method => 'save_library_items',
            params => { uris => _uris_param($uris) },
        }
    );
}

sub remove_library_items {
    my ( $self, $uris ) = @_;

    die "Spotify URIs are required" unless $uris;

    return $self->send_delete_request(
        {
            method => 'remove_library_items',
            params => { uris => _uris_param($uris) },
        }
    );
}

sub check_library_items {
    my ( $self, $uris ) = @_;

    die "Spotify URIs are required" unless $uris;

    return $self->send_get_request(
        {
            method => 'check_library_items',
            params => { uris => _uris_param($uris) },
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
            method => 'get_audiobook',
            params => $params,
        }
    );
}

sub get_audiobook_chapters {
    my ( $self, $id, %params ) = @_;

    die "Audiobook ID is required" unless $id;

    $params{id} = $id;

    return $self->send_get_request(
        {
            method => 'get_audiobook_chapters',
            params => \%params,
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
            method => 'get_users_saved_audiobooks',
            params => $params,
        }
    );
}

sub get_users_saved_shows {
    my ( $self, %params ) = @_;

    return $self->send_get_request(
        {
            method => 'get_users_saved_shows',
            params => \%params,
        }
    );
}

sub get_chapter {
    my ( $self, $id, %params ) = @_;

    die "Chapter ID is required" unless $id;

    $params{id} = $id;

    return $self->send_get_request(
        {
            method => 'get_chapter',
            params => \%params,
        }
    );
}

sub get_available_markets {
    my ($self) = @_;

    return $self->send_get_request(
        {
            method => 'get_available_markets',
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
            method => 'get_show',
            params => $params,
        }
    );
}

sub get_show_episodes {
    my ( $self, $id, %params ) = @_;

    die "Show ID is required" unless $id;

    $params{id} = $id;

    return $self->send_get_request(
        {
            method => 'get_show_episodes',
            params => \%params,
        }
    );
}

1;

=pod

=encoding UTF-8

=head1 SYNOPSIS

    use WWW::Spotify ();

    # client id and secret default to $ENV{SPOTIFY_CLIENT_ID} and
    # $ENV{SPOTIFY_CLIENT_SECRET}; every request sends a bearer token
    my $spotify = WWW::Spotify->new();

    my $result;

    $result = $spotify->album('0sNOF9WDwhWunNAHPD3Baj');

    # $result is a json structure, you can operate on it directly
    # or you can use the "get" method see below

    $result = $spotify->albums_tracks( '6akEvsycLGftJxYudPjmqK',
    {
        limit => 1,
        offset => 1

    }
    );

    $result = $spotify->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

    $result = $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

    $result = $spotify->track( '0eGsygTp906u18L0Oimnem' );

    $result = $spotify->search(
                        'tania bowra' ,
                        'artist' ,
                        { limit => 15 , offset => 0 }
    );

    my $names = $spotify->get('artists.items[*].name');

    # $names is an arrayref of every artist name in the search result

    # user-authorized (OAuth authorization code) flow: send the user to
    # authorize_url, exchange the returned code, then call /v1/me endpoints

    my $url = $spotify->authorize_url( { scope => 'playlist-read-private' } );
    my $code = 'CODE';    # the ?code= value Spotify appends to the redirect
    $spotify->get_access_token($code);

    $result = $spotify->get_current_user_playlists();

    my $link = $spotify->get('items[*].href');

    foreach my $playlist (@{$link}) {
        $spotify->query_full_url($playlist);
        my $pl_name = $spotify->get('name');
        print "$pl_name\n";
    }

=head1 DESCRIPTION

Wrapper for the Spotify Web API.

https://developer.spotify.com/web-api/

Have access to a JSON viewer to help develop and debug. The Chrome JSON viewer is
very good and provides the exact path of the item within the JSON in the lower left
of the screen as you mouse over an element.

=head1 UPGRADING FROM 0.017 OR EARLIER

Version 1.000 is a breaking release.  Besides removing the methods for
endpoints Spotify deleted in November 2024 and February 2026 (the full
list with replacements is in the Changes file), three things changed
that affect code calling the endpoints that survived:

=over 4

=item * force_client_auth, result_format, get_oauth_authorize

Removed.  Every request now sends a bearer token, so there is nothing
to force.  Passing C<force_client_auth> to C<new()> is silently ignored
by Moo; calling it as a method dies.  Use L</authorize_url> instead of
C<get_oauth_authorize>.

=item * custom_request_handler receives an HTTP::Response

The callback used to get the WWW::Mechanize object.  It now gets the
L<HTTP::Response>, so C<< $m->status() >> becomes C<< $res->code >>
and C<< $m->content() >> becomes C<< $res->decoded_content >>.

=item * last_result holds UTF-8 bytes

It was previously a character string.  Decode it with
L<JSON::MaybeXS/decode_json> (or set L</auto_json_decode>) rather than
printing it to a C<:utf8> handle.

=back

=head1 CONSTRUCTOR ARGS

=head2 ua

You may provide your own user agent object to the constructor.  This should be
a L<LWP::UserAgent> or a subclass of it.  To get extra debugging
information, you can do something like this:

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use LWP::UserAgent ();
    use WWW::Spotify ();

    my $ua = LWP::UserAgent->new;
    debug_ua( $ua );
    my $spotify = WWW::Spotify->new( ua => $ua )

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

=head2 artist_albums

equivalent to /v1/artists/{id}/albums

    $spotify->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                        { album_type => 'single',
                          # country => 'US',
                          limit   => 2,
                          offset  => 0
                        }  );

=head2 search

equivalent to /v1/search?type=album (etc)

The query and any extras are UTF-8 encoded before escaping, so pass
character strings (decoded text), not UTF-8 bytes.

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

=head2 get_followed_artists

equivalent to /v1/me/following

    $spotify->get_followed_artists(
        limit => 20,
        after => '0I2XqVXqHScXjHhk6AYYRe'
    );

Note: This method always sets the 'type' parameter to 'artist' as it's the only supported value.

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

=head2 get_audiobook

equivalent to GET /v1/audiobooks/{id}

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe');

or with market parameter:

    $spotify->get_audiobook('7iHfbu1YPACw6oZPAFJtqe', 'US');

=head2 get_users_saved_audiobooks

equivalent to GET /v1/me/audiobooks

    $spotify->get_users_saved_audiobooks(20, 0);

=head2 get_available_markets

equivalent to GET /v1/markets

    $spotify->get_available_markets();

This method retrieves the list of markets where Spotify is available.

=head2 get_show

equivalent to GET /v1/shows/{id}

    $spotify->get_show('38bS44xjbVVZ3No3ByF1dJ', 'US');

This method retrieves Spotify catalog information for a single show identified by its unique Spotify ID.

=head2 get_show_episodes

equivalent to GET /v1/shows/{id}/episodes

    $spotify->get_show_episodes('38bS44xjbVVZ3No3ByF1dJ', market => 'US', limit => 10, offset => 5);

This method retrieves Spotify catalog information about a show's episodes. Optional parameters can be used to limit the number of episodes returned.

=head2 get_audiobook_chapters

equivalent to GET /v1/audiobooks/{id}/chapters

    $spotify->get_audiobook_chapters('3ZXb8FKZGU0EHALYX6uCzU', market => 'US', limit => 50, offset => 0);

This method retrieves the chapters of an audiobook.

=head2 send_delete_request

Internal method used to send DELETE requests to the Spotify API.

=head2 send_put_request

Internal method used to send PUT requests to the Spotify API.

=head2 get_users_saved_shows

equivalent to GET /v1/me/shows

    $spotify->get_users_saved_shows(limit => 20, offset => 0);

This method retrieves a list of shows saved in the current Spotify user's library. Optional parameters can be used to limit the number of shows returned.

=head2 get_chapter

equivalent to GET /v1/chapters/{id}

    $spotify->get_chapter('0D5wENdkdwbqlrHoaJ9g29', market => 'US');

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

    # $res is the HTTP::Response object
    $spotify->custom_request_handler(
        sub { my $res = shift;
            if ($res->code == 401) {
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
