package WWW::Spotify::Response;

use 5.010;
use strict;
use warnings;

# A lightweight wrapper around an individual Spotify Web API HTTP
# response.  It stores the raw content as returned by LWP::UserAgent and
# provides helpers for JSON decoding and JSON::Path extraction - logic
# that previously lived in the monolithic WWW::Spotify module.

use Moo;
use JSON::MaybeXS qw( decode_json );
use JSON::Path    ();

#--------------------------------------------------------------------------
# Attributes
#--------------------------------------------------------------------------

has raw => (
    is       => 'ro',
    required => 1,
);

has status => (
    is        => 'ro',
    isa       => sub { },        # int-ish; keep simple
    predicate => 'has_status',
);

has content_type => (
    is        => 'ro',
    isa       => sub { },
    predicate => 'has_content_type',
);

#--------------------------------------------------------------------------
# Public methods
#--------------------------------------------------------------------------

# Decode JSON once and memoise it (most callers will need it).

has _decoded_json => (
    is       => 'lazy',
    init_arg => undef,
);

sub _build__decoded_json {
    my $self = shift;
    return decode_json( $self->raw );
}

# get( path1, path2, … ) – returns value(s) from the JSON structure
# using JSON::Path syntax.  Mirrors the behaviour that existed in
# WWW::Spotify->get so that callers can migrate gradually.

sub get {
    my ( $self, @paths ) = @_;

    my @out;
    my $json = $self->_decoded_json;

    foreach my $key (@paths) {
        my $type  = ( $key =~ /\*\]/ ) ? 'values' : 'value';
        my $jpath = JSON::Path->new("\$.$key");
        my @vals  = $jpath->$type($json);

        push @out,
            ( $type eq 'value' ? $vals[0] : \@vals );
    }

    return wantarray ? @out : $out[0];
}

# Convenience alias so we can call $resp->json directly.

sub json {
    return shift->_decoded_json;
}

1;

# ABSTRACT: Object wrapper around a single Spotify API response

# vim: ts=4 sts=4 sw=4 et
