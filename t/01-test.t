use strict;

use Data::Dumper;

use Test::More qw/no_plan/;

use lib '..';

BEGIN {
    use_ok('WWW::Spotify');
    }

my $obj = WWW::Spotify->new();

ok( $obj->debug(1) , "set debug" );

sub show_and_pause {
    my $show = shift;
    print Dumper($show);
    sleep 5;
};

my $result;

=pod

$result = $obj->album('0sNOF9WDwhWunNAHPD3Baj');

show_and_pause($result);

$result = $obj->albums( '41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4,6UXCm6bOO4gFlDQZV5yL37' );

show_and_pause($result);

$result = $obj->album_tracks( '6akEvsycLGftJxYudPjmqK',
{
    limit => 0,
    offset => 1
    
}
); 
$result = $obj->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

show_and_pause($result);

$result = $obj->artists( '0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin' );

show_and_pause($result);

print "ARTIST ALBUMS\n";

$result = $obj->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                    { album_type => 'single',
                      # country => 'US',
                      limit   => 2,
                      offset  => 0
                    }  );

show_and_pause($result);

=cut

$result = $obj->track( '0eGsygTp906u18L0Oimnem' );

ok( $obj->is_valid_json($result) , "track returned valid json" );

show_and_pause($result);



$result = $obj->tracks( '0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G' );

ok( $obj->is_valid_json($result) , "tracks returned valid json" );

show_and_pause($result);
                    
=pod

$result = $obj->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE' , {
country => 'SE'
}
);

$result = $obj->search( { q => '' , type => 'album' , limit => 15 , offset => 0 } );


# need a test user?
$result = $obj->user( 'user' );

$result = $obj->me(  );
$result = $obj->next(  );
$result = $obj->previous(  );



$result = $obj->user_playlist(  );
$result = $obj->user_playlist_add_tracks(  );
$result = $obj->user_playlist_create(  );
$result = $obj->user_playlists(  );

=cut

# test me
