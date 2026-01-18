package WWW::Spotify::Endpoint;

use Moo::Role;

use JSON::MaybeXS     qw( encode_json );
use HTTP::Status      qw( HTTP_OK HTTP_NO_CONTENT HTTP_CREATED HTTP_ACCEPTED );
use URI::Escape       qw( uri_escape );

#--------------------------------------------------------------------------
# Generic HTTP verb helpers extracted from the main module.  They rely on
# a number of attributes and helper methods that are provided by
# WWW::Spotify (the consuming class), such as _mech(), uri_scheme(),
# force_client_auth(), etc.
#--------------------------------------------------------------------------

# Helper to check if HTTP status code indicates success (2xx range)
sub _is_success_status {
    my ( $self, $status ) = @_;
    return $status >= 200 && $status < 300;
}

# Helper to URI-encode a value for use in URL paths
sub _uri_encode_param {
    my ( $self, $value ) = @_;
    return defined $value ? uri_escape($value) : '';
}

sub send_post_request {
    my $self       = shift;
    my $attributes = shift;

    $self->last_error(q{});

    my $url  = $self->uri_scheme() . '://' . $self->uri_hostname();
    my $path = $self->_method_to_uri->{ $attributes->{method} };

    if ($path) {
        $path =~ s/\{([^}]+)\}/$self->_uri_encode_param($attributes->{params}{$1})/ge;
        $url .= $path;
    }

    warn "$url\n" if $self->debug;

    my $mech = $self->_mech;

    if (   $attributes->{client_auth_required}
        || $self->force_client_auth() != 0 )
    {
        if ( $self->current_access_token() eq q{} ) {
            warn "Needed to get access token\n" if $self->debug();
            $self->get_client_credentials();
        }
        $mech->add_header(
            'Authorization' => 'Bearer ' . $self->current_access_token() );
    }

    my $content =
      $attributes->{params} ? encode_json( $attributes->{params} ) : '';
    $mech->add_header( 'Content-Type' => 'application/json' );
    $mech->post( $url, Content => $content );

    if ( $self->grab_response_header() == 1 ) {
        $self->_set_response_headers($mech);
    }

    $self->response_status( $mech->status() );
    $self->response_content_type( $mech->content_type() );

    if ( $self->_has_custom_request_handler() ) {
        $self->_set_custom_request_handler_result(
            $self->custom_request_handler()->($mech) );
    }

    if (   $self->response_content_type() =~ /application\/json/i
        && !$self->_is_success_status( $self->response_status() ) )
    {
        warn "content type is ", $self->response_content_type(), "\n"
          if $self->debug();
        $self->last_error( "POST request failed, status("
              . $self->response_status()
              . ") examine last_result for details" );
    }

    die $self->last_error()
      if $self->die_on_response_error() && $self->last_error ne '';

    return $self->format_results( $mech->content, $mech->ct(),
        $mech->status() );
}

sub send_delete_request {
    my $self       = shift;
    my $attributes = shift;

    $self->last_error(q{});

    my $url  = $self->uri_scheme() . '://' . $self->uri_hostname();
    my $path = $self->_method_to_uri->{ $attributes->{method} };

    if ($path) {
        $path =~ s/\{([^}]+)\}/$self->_uri_encode_param($attributes->{params}{$1})/ge;
        $url .= $path;
    }

    warn "$url\n" if $self->debug;

    my $mech = $self->_mech;

    if (   $attributes->{client_auth_required}
        || $self->force_client_auth() != 0 )
    {
        if ( $self->current_access_token() eq q{} ) {
            warn "Needed to get access token\n" if $self->debug();
            $self->get_client_credentials();
        }
        $mech->add_header(
            'Authorization' => 'Bearer ' . $self->current_access_token() );
    }

    my $content =
      $attributes->{params} ? encode_json( $attributes->{params} ) : '';
    $mech->add_header( 'Content-Type' => 'application/json' );
    $mech->delete( $url, Content => $content );

    if ( $self->grab_response_header() == 1 ) {
        $self->_set_response_headers($mech);
    }

    $self->response_status( $mech->status() );
    $self->response_content_type( $mech->content_type() );

    if ( $self->_has_custom_request_handler() ) {
        $self->_set_custom_request_handler_result(
            $self->custom_request_handler()->($mech) );
    }

    if ( !$self->_is_success_status( $self->response_status() ) ) {
        warn "DELETE request failed with status ", $self->response_status(),
          "\n" if $self->debug();
        $self->last_error( "DELETE request failed, status("
              . $self->response_status()
              . ") examine last_result for details" );
    }

    die $self->last_error()
      if $self->die_on_response_error() && $self->last_error ne '';

    return $self->format_results( $mech->content, $mech->ct(),
        $mech->status() );
}

sub send_put_request {
    my $self       = shift;
    my $attributes = shift;

    $self->last_error(q{});

    my $url  = $self->uri_scheme() . '://' . $self->uri_hostname();
    my $path = $self->_method_to_uri->{ $attributes->{method} };

    if ($path) {
        $path =~ s/\{([^}]+)\}/$self->_uri_encode_param($attributes->{params}{$1})/ge;
        $url .= $path;
    }

    warn "$url\n" if $self->debug;

    my $mech = $self->_mech;

    if (   $attributes->{client_auth_required}
        || $self->force_client_auth() != 0 )
    {
        if ( $self->current_access_token() eq q{} ) {
            warn "Needed to get access token\n" if $self->debug();
            $self->get_client_credentials();
        }
        $mech->add_header(
            'Authorization' => 'Bearer ' . $self->current_access_token() );
    }

    my $content =
      $attributes->{params} ? encode_json( $attributes->{params} ) : '';
    $mech->add_header( 'Content-Type' => 'application/json' );
    $mech->put( $url, Content => $content );

    if ( $self->grab_response_header() == 1 ) {
        $self->_set_response_headers($mech);
    }

    $self->response_status( $mech->status() );
    $self->response_content_type( $mech->content_type() );

    if ( $self->_has_custom_request_handler() ) {
        $self->_set_custom_request_handler_result(
            $self->custom_request_handler()->($mech) );
    }

    if ( !$self->_is_success_status( $self->response_status() ) ) {
        warn "PUT request failed with status ", $self->response_status(), "\n"
          if $self->debug();
        $self->last_error( "PUT request failed, status("
              . $self->response_status()
              . ") examine last_result for details" );
    }

    die $self->last_error()
      if $self->die_on_response_error() && $self->last_error ne '';

    return $self->format_results( $mech->content, $mech->ct(),
        $mech->status() );
}

sub send_get_request {
    my $self       = shift;
    my $attributes = shift;

    my $uri_params = q{};
    warn "attributes: " . (defined $attributes ? 'defined' : 'undef') . "\n"
      if $self->debug();

    $self->last_error(q{});

    if ( defined $attributes->{extras} && ref $attributes->{extras} eq 'HASH' ) {
        my @tmp;
        foreach my $key ( keys %{ $attributes->{extras} } ) {
            push @tmp, "$key=$attributes->{extras}{$key}";
        }
        $uri_params = join( '&', @tmp );
        warn "uri_params: $uri_params\n" if $self->debug();
    }

    if ( exists $attributes->{format} && $attributes->{format} =~ /json|jsonp/ ) {
        $self->result_format( $attributes->{format} );
        delete $attributes->{format};
    }

    my $url;
    if ( $attributes->{method} eq 'query_full_url' ) {
        $url = $attributes->{url};
    }
    else {
        $url = $self->uri_scheme() . '://' . $self->uri_hostname();

        my $path = $self->_method_to_uri->{ $attributes->{method} };
        if ($path) {
            warn "raw: $path" if $self->debug();

            if ( $path =~ /search/ && $attributes->{method} eq 'search' ) {
                my $q    = $self->_uri_encode_param( $attributes->{q} );
                my $type = $self->_uri_encode_param( $attributes->{type} );
                $path =~ s/\{q\}/$q/;
                $path =~ s/\{type\}/$type/;
            }
            elsif ( $path =~ m/\{id\}/ && exists $attributes->{params}{id} ) {
                my $id = $self->_uri_encode_param( $attributes->{params}{id} );
                $path =~ s/\{id\}/$id/;
            }
            elsif ( $path =~ m/\{ids\}/ && exists $attributes->{params}{ids} ) {
                my $ids = $self->_uri_encode_param( $attributes->{params}{ids} );
                $path =~ s/\{ids\}/$ids/;
            }

            if ( $path =~ m/\{country\}/ ) {
                my $country = $self->_uri_encode_param( $attributes->{params}{country} );
                $path =~ s/\{country\}/$country/;
            }

            if ( $path =~ m/\{user_id\}/ && exists $attributes->{params}{user_id} ) {
                my $user_id = $self->_uri_encode_param( $attributes->{params}{user_id} );
                $path =~ s/\{user_id\}/$user_id/;
            }

            if ( $path =~ m/\{playlist_id\}/ && exists $attributes->{params}{playlist_id} ) {
                my $playlist_id = $self->_uri_encode_param( $attributes->{params}{playlist_id} );
                $path =~ s/\{playlist_id\}/$playlist_id/;
            }

            if ( $path =~ m/\{category_id\}/ && exists $attributes->{params}{category_id} ) {
                my $category_id = $self->_uri_encode_param( $attributes->{params}{category_id} );
                $path =~ s/\{category_id\}/$category_id/;
            }

            warn "modified: $path\n" if $self->debug();
            $url .= $path;
        }
    }

    if ($uri_params) {
        my $start_with = $url =~ /\?/ ? '&' : '?';
        $url .= $start_with . $uri_params;
    }

    warn "$url\n" if $self->debug;

    my $mech = $self->_mech;

    if (   $attributes->{client_auth_required}
        || $self->force_client_auth() != 0 )
    {
        if ( $self->current_access_token() eq q{} ) {
            warn "Needed to get access token\n" if $self->debug();
            $self->get_client_credentials();
        }
        $mech->add_header( 'Authorization' => 'Bearer ' . $self->current_access_token() );
    }

    $mech->get($url);

    if ( $self->grab_response_header() == 1 ) {
        $self->_set_response_headers($mech);
    }

    $self->response_status( $mech->status() );
    $self->response_content_type( $mech->content_type() );

    if ( $self->_has_custom_request_handler() ) {
        $self->_set_custom_request_handler_result( $self->custom_request_handler()->($mech) );
    }

    if (   $self->response_content_type() =~ /application\/json/i
        && !$self->_is_success_status( $self->response_status() ) )
    {
        warn "content type is " . $self->response_content_type() . "\n" if $self->debug();
        $self->last_error( "GET request failed, status(" . $self->response_status() . ") examine last_result for details" );
    }

    die $self->last_error()
      if $self->die_on_response_error() && $self->last_error ne '';

    return $self->format_results( $mech->content, $mech->ct(), $mech->status() );
}

# --------------------------------------------------------------
# Convenience wrapper so callers may use a full URL directly.
# --------------------------------------------------------------

sub query_full_url {
    my $self                 = shift;
    my $url                  = shift;
    my $client_auth_required = shift || 0;

    return $self->send_get_request({
        method               => 'query_full_url',
        url                  => $url,
        client_auth_required => $client_auth_required,
    });
}

# A tiny helper that gives us access to the private %method_to_uri mapping
# stored in WWW::Spotify.  We expose it via a method so the hashref can be
# reused rather than duplicated.

sub _method_to_uri {
    no strict 'refs'; ## no critic
    return \%{ 'WWW::Spotify::' . 'method_to_uri' };
}

1;

# ABSTRACT: Generic HTTP helpers extracted into a role

# vim: ts=4 sts=4 sw=4 et
