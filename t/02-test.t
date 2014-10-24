use strict;

use Data::Dumper;

use Test::More qw/no_plan/;

use lib '..';

BEGIN {
    use_ok('WWW::Spotify');
    use_ok('Net::Ping'); # need basic network connection to test module
    }

my $obj = WWW::Spotify->new();

#------------------#

# $obj->debug(1);

#------------------#

# ok( $obj->debug(0) == 0 , 'turn debug off' );

sub show_and_pause {
    if ($obj->debug()) {
        my $show = shift;
        print Dumper($show);
        sleep 5;
    }
};

my $result;

my $p = Net::Ping->new('syn');
# lets see if we can ping google
my $host = 'www.google.com';

my $have_internet = 0;

if ($p->ping($host)) {
    $have_internet = 1
}

$p->close();

if ($have_internet) {

    if ($ENV{SPOTIFY_CLIENT_ID}) {
        
    
        ok( $obj->oauth_client_id($ENV{SPOTIFY_CLIENT_ID}) , 'set client id' );
        
        ok( $obj->oauth_client_secret($ENV{SPOTIFY_CLIENT_SECRET}), 'set client secret' );
    
        
        ok( $obj->get_client_credentials() , 'get client credentials' );
        
        $result = $obj->browse_featured_playlists();
        
        ok( $result =~ /total/ , 'result string for browse_featured_playlists contains the word total' ); 
        
        $result = $obj->browse_new_releases( { country => 'US' , limit => 5 , offset => 2 } );
        
        ok( $result =~ /total/ , 'result string for browse_new_releases contains the word total' );
        
        # print $result;
    
    }
}
exit;