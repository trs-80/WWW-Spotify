use strict;
use warnings;

use Data::Dumper  qw( Dumper );
use JSON::MaybeXS qw( decode_json );
use Test::More;
use Test::RequiresInternet (
    'accounts.spotify.com' => 443,
    'api.spotify.com'      => 443,
    'www.spotify.com'      => 80,
);
use Try::Tiny    qw( catch try );
use WWW::Spotify ();

my $obj = WWW::Spotify->new();

sub show_and_pause {
    if ( $obj->debug() == 1 ) {
        my $show = shift;
        print Dumper($show);
        sleep 5;
    }
}

my $result;

#SKIP: {

#    skip 'No SPOTIFY_CLIENT_ID', 5 unless $ENV{SPOTIFY_CLIENT_ID};
$obj->force_client_auth(1);

ok( $obj->force_client_auth() == 1 );

#------------------#

$obj->force_client_auth(0);

ok( $obj->force_client_auth() == 0 );

#------------------#

=pod
$result = $obj->search(
    'tania bowra',
    'artist',
    { limit => 15, offset => 0 }
);

show_and_pause($result);

ok( is_valid_json($result), 'search' );
=cut

#------------------#

my $crh_check = 0;

eval { $obj->custom_request_handler('string'); };

if ($@) {
    $crh_check = 1;
}

ok( $crh_check == 1, 'customer_request_handler requires code ref' );

# return a sentinel regardless of response status: this asserts the
# handler ran and its result was stored, not what the API returned
$obj->custom_request_handler(
    sub {
        my $m = shift;
        return 2;
    }
);

$result = $obj->album('0sNOF9WDwhWunNAHPD3Baj');

ok( is_valid_json( $result, 'album' ), 'album' );

ok(
    $obj->custom_request_handler_result() == 2,
    'custom_request_handler_result'
);

show_and_pause($result);

#------------------#

$obj->die_on_response_error(1);

eval { $result = $obj->album('0sNOF9WDwhWunNAHPD3Baj'); };

if ($@) {
    ok( 1, 'die_on_response_error' );
}

show_and_pause($result);

$obj->die_on_response_error(0);

#------------------#

$result = $obj->albums(
    '41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4,6UXCm6bOO4gFlDQZV5yL37');

ok( is_valid_json( $result, 'albums' ), 'albums (multiple ids)' );

show_and_pause($result);

#------------------#

# The long =pod block of live catalog tests that used to sit here was
# converted to mocked tests in t/06-methods-mocked.t.

sub is_valid_json {
    my $json = shift;
    my $decoded;
    try {
        $decoded = decode_json($json);
    }
    catch {
        diag 'could not decode JSON';
        diag $json;
        diag $_;
    };

    return defined $decoded;
}

done_testing();
