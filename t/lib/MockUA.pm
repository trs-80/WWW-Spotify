package MockUA;

# Minimal LWP::UserAgent stand-in for the mocked tests: records the last
# request (verb, URL, headers, form, body) and returns a canned HTTP::Response.

use strict;
use warnings;

use HTTP::Response ();
use parent 'LWP::UserAgent';    # satisfies WWW::Spotify's ua type check

sub new {
    my ( $class, %args ) = @_;
    return bless {
        status       => $args{status}       // 200,
        content      => $args{content}      // '{}',
        content_type => $args{content_type} // 'application/json',

        # optional body returned by post() only (simulates the token endpoint)
        token_response => $args{token_response},
        headers        => {},
        last_verb      => undef,
        last_url       => undef,
        last_content   => undef,
        last_form      => undef,
        post_calls     => 0,
    }, $class;
}

sub _request {
    my ( $self, $verb, $url, @args ) = @_;
    my $form    = ref $args[0] ? shift @args : undef;
    my %headers = @args;

    $self->{last_verb}    = $verb;
    $self->{last_url}     = $url;
    $self->{last_form}    = $form;
    $self->{last_content} = delete $headers{Content};
    $self->{headers}      = \%headers;
    $self->{post_calls}++ if $verb eq 'post';

    my $body
        = $verb eq 'post' && $self->{token_response}
        ? $self->{token_response}
        : $self->{content};

    return HTTP::Response->new(
        $self->{status},                             undef,
        [ 'Content-Type' => $self->{content_type} ], $body
    );
}

sub get    { shift->_request( get    => @_ ) }
sub post   { shift->_request( post   => @_ ) }
sub put    { shift->_request( put    => @_ ) }
sub delete { shift->_request( delete => @_ ) }

1;
