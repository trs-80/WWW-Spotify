#!perl

use strict;
use warnings;

use Test::More;
use LWP::UserAgent ();
use WWW::Spotify   ();

{
    my $ua = LWP::UserAgent->new;
    $ua->agent('foo');
    is(
        WWW::Spotify->new( ua => $ua )->ua->agent,
        'foo',
        'uses custom LWP::UserAgent ua'
    );
}

done_testing();
