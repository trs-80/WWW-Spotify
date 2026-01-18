package WWW::Spotify::Client;

use 5.010;
use strict;
use warnings;

use Moo::Role;

use MIME::Base64      qw( encode_base64 );
use JSON::MaybeXS     qw( decode_json );

#--------------------------------------------------------------------------
# Requirements – attributes/methods that must be supplied by the consuming
# class (WWW::Spotify).
#--------------------------------------------------------------------------

requires qw(
  oauth_client_id
  oauth_client_secret
  oauth_authorize_url
  oauth_token_url
  oauth_redirect_uri
  current_oauth_code
  current_access_token
  ua
  _mech
  debug
);

#--------------------------------------------------------------------------
# Authentication helpers migrated from the original monolithic module.
#--------------------------------------------------------------------------

sub get_oauth_authorize {
    my $self = shift;

    if ( $self->current_oauth_code() ) {
        return $self->current_oauth_code();
    }

    my $grant_type = 'authorization_code';
    my $client_and_secret =
      $self->oauth_client_id() . ':' . $self->oauth_client_secret();
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
    my $mech = $self->_mech;
    my $client_and_secret =
      $self->oauth_client_id() . ':' . $self->oauth_client_secret();
    my $encoded = encode_base64($client_and_secret);
    my $url     = $self->oauth_token_url();

    my $extra = {
        grant_type => $grant_type
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
        }
    }
}

sub get_access_token {
    my $self       = shift;
    my $grant_type = 'authorization_code';
    my $scope      = shift;

    my @scopes = (
        'playlist-modify',       'playlist-modify-private',
        'playlist-read-private', 'streaming',
        'user-read-private',     'user-read-email'
    );

    if ($scope) {
        my $good_scope = 0;
        foreach my $s (@scopes) {
            if ( $scope eq $s ) {
                $good_scope = 1;
                last;
            }
        }
        if ( $good_scope == 0 ) {
            $scope = q{};
        }
    }

    $grant_type ||= 'authorization_code';

    my $client_and_secret =
      $self->oauth_client_id() . ':' . $self->oauth_client_secret();

    my $encoded = encode_base64($client_and_secret);
    chomp($encoded);
    $encoded =~ s/\n//g;

    my $url = $self->oauth_token_url;

    my $extra = {
        grant_type   => $grant_type,
        code         => $self->current_oauth_code(),
        redirect_uri => $self->oauth_redirect_uri
    };
    if ($scope) {
        $extra->{scope} = $scope;
    }

    my $mech = $self->_mech;
    $mech->add_header( 'Authorization' => 'Basic ' . $encoded );

    $mech->post( $url, [$extra] );

    my $content = $mech->content();
    warn "get_access_token response: $content\n" if $self->debug();

    if ( $content =~ /access_token/ ) {
        my $result = decode_json($content);
        if ( $result->{'access_token'} ) {
            $self->current_access_token( $result->{'access_token'} );
        }
        return $result;
    }

    return;
}

1;

# ABSTRACT: Spotify authentication logic (extracted into a role)

# vim: ts=4 sts=4 sw=4 et
