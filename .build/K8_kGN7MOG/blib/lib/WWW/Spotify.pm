use strict;
use warnings;
use Data::Dumper;
package WWW::Spotify;


# ABSTRACT: turns baubles into trinkets

use Moose;

BEGIN {
    $WWW::Spotify::VERSION = "0.001";
}

use Data::Dumper;
use URI;
use URI::Escape;
use WWW::Mechanize;
use JSON::XS;
use JSON::Path;
use XML::Simple;
use HTTP::Headers;
use Scalar::Util;
use File::Basename;
use IO::CaptureOutput qw( capture qxx qxy );
#use Digest::MD5::File qw( file_md5_hex url_md5_hex );

has 'result_format' => (
    is       => 'rw',
    isa      => 'Str',
    default  => 'json',
);

has 'results' => (
    is       => 'rw',
    isa      => 'Int',
    default  => '15'
);

has 'debug' => (
    is       => 'rw',
    isa      => 'Int',
    default  => 0,
);

has 'uri_scheme' => (
    is       => 'rw',
    isa      => 'Str',
    default  => 'https',
);

has uri_hostname => (
    is       => 'rw',
    isa      => 'Str',
    default  => 'api.spotify.com'
);

has uri_domain_path => (
    is       => 'rw',
    isa      => 'Str',
    default  => 'api',
);

has call_type => (
    is       => 'rw',
    isa      => 'Str',
);

has auto_json_decode => (
    is       => 'rw',
    isa      => 'Int',
    default  => 0
);

has auto_xml_decode => (
    is       => 'rw',
    isa      => 'Int',
    default  => 0
);

has last_result => (
    is        => 'rw',
    isa       => 'Str',
    default   => q{}
);

has last_error => (
    is        => 'rw',
    isa       => 'Str',
    default   => q{}
);

has response_headers => (
    is        => 'rw',
    isa       => 'Str',
    default   => q{}
);

has problem => (
    is        => 'rw',
    isa       => 'Str',
    default   => q{}
);

my %api_call_options = (

        '/v1/albums/{id}' => {
            info => 'Get an album' ,
            type => 'GET',
            method => 'album'
        },

        '/v1/albums?ids={ids}' => {
            info => 'Get several albums' ,
            type => 'GET',
            method => 'albums',
            params => [ 'limit' , 'offset' ]
        },

        '/v1/albums/{id}/tracks' => {
            info => "Get an album's tracks" ,
            type => 'GET',
            method => 'album_tracks'
        },

        '/v1/artists/{id}' => {
            info => "Get an artist",
            type => 'GET',
            method => 'artist'
        },

	'/v1/artists?ids={ids}' => {
            info => "Get several artists",
            type => 'GET',
            method => 'artists'
        },
        
	'/v1/artists/{id}/albums' => {
            info => "Get an artist's albums",
            type => 'GET',
            method => 'artist_albums',
            params => [ 'limit' , 'offset' , 'country' , 'album_type' ]
        },
        
        '/v1/artists/{id}/top-tracks' => {
            info => "Get an artist's top tracks",
            type => 'GET',
            method => 'artist_top_tracks',
            params => [ 'country' ]
        },

	'/v1/search' => {
            info => "Search for an item",
            type => 'GET',
            method => 'search',
            params => [ 'limit' , 'offset' , 'q' , 'type' ]
        },
        
	'/v1/tracks/{id}' => {
            info => "Get a track",
            type => 'GET',
            method => 'track'
        },
        
	'/v1/tracks?ids={ids}' => {
            info =>  "Get several tracks",
            type => 'GET',
            method => 'tracks'
        },

	'/v1/users/{user_id}' => {
            info => "Get a user's profile",
            type => 'GET',
            method => 'user'
        },

        '/v1/me' => {

            info => "Get current user's profile",
            type => 'GET',
            method => 'me'
        },
        
	'/v1/users/{user_id}/playlists' => {
            info => "Get a list of a user's playlists",
            type => 'GET',
            method => 'user_playlist'
        },
        
	'/v1/users/{user_id}/playlists/{playlist_id}' => {
            info => "Get a playlist",
            type => 'GET',
            method => ''
        },

        '/v1/users/{user_id}/playlists/{playlist_id}/tracks' => {
            info => "Get a playlist's tracks",
            type => 'POST',
            method => ''
        },
        

        '/v1/users/{user_id}/playlists'	=> {
            info => 'Create a playlist',
            type => 'POST',
            method => ''
        },

        '/v1/users/{user_id}/playlists/{playlist_id}/tracks' => {
            info => 'Add tracks to a playlist',
            type => 'POST',
            method => ''
        }
                        );

my %method_to_uri = ();

foreach my $key (keys %api_call_options) {
    next if $api_call_options{$key}->{method} eq '';
    $method_to_uri{$api_call_options{$key}->{method}} = $key;
}

print Dumper(\%method_to_uri);

sub is_valid_json {
    my ($self,$json,$caller) = @_;
    eval {
        decode_json $json;    
    };
    
    if ($@) {
        $self->last_error("invalid josn passed into $caller");
        return 0;
    } else {
        return 1;
    }
}

sub send_get_request {
    # need to build the URL here
    my $self = shift;
    
    my $attributes = shift;
    
    my $uri_params = '';
    
    if (defined $attributes->{extras} and ref $attributes->{extras} eq 'HASH') {
        my @tmp = ();
        
        foreach my $key (keys %{$attributes->{extras}}) {
            push @tmp , "$key=$attributes->{extras}{$key}";
        }
        $uri_params = join('&',@tmp);
    }
    
    
    if (exists $attributes->{format} && $attributes->{format} =~ /json|xml|xspf|jsonp/) {
        $self->result_format($attributes->{format});
        delete $attributes->{format};
    }
    
    my $call_type = $self->call_type();
    
    # my $url = $self->build_url_base($call_type);
    
    my $url = $self->uri_scheme();
    
    # the ://
    $url .= "://";
    
    # the domain
    $url .= $self->uri_hostname();
    
    my $path = $method_to_uri{$attributes->{method}};
    if ($path) {
        warn "raw: $path" if $self->debug();
        if ($path =~ m/\{id\}/ && exists $attributes->{params}{id}) {
            $path =~ s/\{id\}/$attributes->{params}{id}/;   
        } elsif ($path =~ m/\{ids\}/ && exists $attributes->{params}{ids}) {
            $path =~ s/\{ids\}/$attributes->{params}{ids}/;
        }
        warn "modified: $path" if $self->debug();
    }
    
    $url .= $path;
    
    # now we need to address the "extra" attributes if any
    if ($uri_params) {
        my $start_with = '?';
        if ($url =~ /\?/) {
            $start_with = '&';
        }
        $url .= $start_with . $uri_params;
    }
    
    
    my $need_auth = 0;
    if ($need_auth) {
        #code
        # ensure we have a semi valid api key stashed away
        if ($self->_have_valid_api_key() == 0) {
            return "won't send requests without a valid api key";
        }
        # since it is a GET we can ? it
        $url .= "?";
    
        # add the api key since it should always be sent
        $url .= "api_key=" . $self->api_key();
    
        # add the format
    
        $url .= "&format=" . $self->result_format();
    }
    
    warn "'$call_type'\n" if $self->debug();
    
    warn "$url\n" if $self->debug;
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    my $mech = WWW::Mechanize->new( autocheck => 0 );
    $mech->get( $url );
    
    #my $hd;
    #capture { $mech->dump_headers(); } \$hd;

    #$self->response_headers($hd);
    $self->_set_response_headers($mech);
    return $self->format_results($mech->content);
    
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
    my $self = shift;
    my $content = shift;
    
    # want to store the result in case
    # we want to interact with it via a helper method
    $self->last_result($content);
    
    # FIX ME / TEST ME
    # vefify both of these work and return the *same* perl hash
    
    # when / how should we check the status? Do we need to?
    # if so then we need to create another method that will
    # manage a Sucess vs. Fail request
    
    if ($self->auto_json_decode && $self->result_format eq 'json' ) {
        return decode_json $content;
    }

    if ($self->auto_xml_decode && $self->result_format eq 'xml' ) {
        # FIX ME
        my $xs = XML::Simple->new();
        return $xs->XMLin($content);
    }
    
    # results are not altered in this cass and would be either
    # json or xml instead of a perl data structure
    
    return $content;
}

sub build_url_base {
    # first the uri type
    my $self = shift;
    my $call_type = shift || $self->call_type();    
  
    my $url = $self->uri_scheme();
    
    # the ://
    $url .= "://";
    
    # the domain
    $url .= $self->uri_hostname();
    
    # the path
    if ( $self->uri_domain_path() ) {
        $url .= "/" . $self->uri_domain_path();
    }
 
 
    # $url 
    return $url;
}

sub is_valid_json {
    my ($self,$json,$caller) = @_;
    eval {
        decode_json $json;    
    };
    
    if ($@) {
        $self->last_error("invalid josn passed into $caller");
        return 0;
    } else {
        return 1;
    }
}


sub album {
    my $self = shift;
    my $id = shift;
    $self->send_get_request(
        { method => 'album',
          params => { 'id' => $id }
        }
    );
}

sub albums {
    my $self = shift;
    my $ids = shift;
    $self->send_get_request(
        { method => 'albums',
          params => { 'ids' => $ids }
        }
    );
}

sub album_tracks {
    my $self = shift;
    my $ablbum_id = shift;
                   
}



sub artist {
    my $self = shift;
    my $id = shift;
    $self->send_get_request(
        { method => 'artist',
          params => { 'id' => $id }
        }
    );            
}

sub artists {
    my $self = shift;
    my $artists = shift;
    $self->send_get_request(
        { method => 'artists',
          params => { 'ids' => $artists }
        }
    );
}

sub artist_albums {
    my $self = shift;
    my $artist_id = shift;
    my $extras = shift;
    $self->send_get_request(
        { method => 'artist_albums',
          params => { 'id' => $artist_id },
          extras => $extras  
        }
    ); 
}

sub artist_top_tracks {
    my $self = shift;
    my $artist_id = shift;
    my $extras = shift;
    $self->send_get_request(
        { method => 'artists',
          params => { 'ids' => $artist_id },
          extras => $extras  
        }
    );    
}



sub me {
    my $self = shift;
    
}

sub next {
    my $self = shift;
    my $result = shift;
}

sub previous {
    my $self = shift;
    my $result = shift;
}

sub search {
    my $self = shift;
    my $attrib = shift;
    
}

sub track {
    my $self = shift;
    my $id = shift;
    $self->send_get_request(
        { method => 'track',
          params => { 'id' => $id }
        }
    ); 
}

sub tracks {
    my $self = shift;
    my $tracks = shift;
    $self->send_get_request(
        { method => 'tracks',
          params => { 'ids' => $tracks }
        }
    );
}

sub user {
    my $self = shift;
}

sub user_playlist {
    my $self = shift;
}

sub user_playlist_add_tracks {
    my $self = shift;
}

sub user_playlist_create {
    my $self = shift;
}

sub user_playlists {
    my $self = shift;
}


1;

__END__

=pod

=head1 NAME

WWW::Spotify - turns baubles into trinkets

=head1 VERSION

version 0.001

        # the path
    if ( $call_type ) {
        $url .= "/" . $call_type;
    }

=head1 AUTHOR

Aaron Johnson <aaronjjohnson@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Aaron Johnson.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
