use strict;

use Data::Dumper;

use Test::More qw/no_plan/;

use lib '..';

BEGIN {
    use_ok('WWW::Spotify');
    }

my $obj = WWW::Spotify->new();

#------------------#

ok( $obj->debug(1) , "turn debug on" );

#------------------#

ok( $obj->debug(0) == 0 , 'turn debug off' );

sub show_and_pause {
    if ($obj->debug()) {
        my $show = shift;
        print Dumper($show);
        sleep 5;
    }
};

my $result;

#------------------#

$result = $obj->album('0sNOF9WDwhWunNAHPD3Baj');

ok( $obj->is_valid_json($result , 'album') , "album" );

show_and_pause($result);

#------------------#

$result = $obj->albums( '41MnTivkwTO3UUJ8DrqEJJ,6JWc4iAiJ9FjyK0B59ABb4,6UXCm6bOO4gFlDQZV5yL37' );

ok( $obj->is_valid_json($result , 'ablums') , "albums (multiple ids)" );

show_and_pause($result);

#------------------#

$result = $obj->album_tracks( '6akEvsycLGftJxYudPjmqK',
{
    limit => 0,
    offset => 1
    
}
); 

ok( $obj->is_valid_json($result , 'album_tracks') , "album_tracks" );

show_and_pause($result);

#------------------#

$result = $obj->artist( '0LcJLqbBmaGUft1e9Mm8HV' );

ok( $obj->is_valid_json($result , 'artist') , "artist" );

show_and_pause($result);

#------------------#

my $artists_multiple = '0oSGxfWSnnOXhD2fKuz2Gy,3dBVyJ7JuOMt4GE9607Qin';

$result = $obj->artists( $artists_multiple );

ok( $obj->is_valid_json($result , 'artists') , "artists ( $artists_multiple )" );

show_and_pause($result);

#------------------#

$result = $obj->artist_albums( '1vCWHaC5f2uS3yhpwWbIA6' ,
                    { album_type => 'single',
                      # country => 'US',
                      limit   => 2,
                      offset  => 0
                    }  );
ok( $obj->is_valid_json($result , 'artist_albums') , "artist_albums" );

show_and_pause($result);

#------------------#

$result = $obj->track( '0eGsygTp906u18L0Oimnem' );

ok( $obj->is_valid_json($result , 'track') , "track returned valid json" );

show_and_pause($result);

#------------------#

$result = $obj->tracks( '0eGsygTp906u18L0Oimnem,1lDWb6b6ieDQ2xT7ewTC3G' );

ok( $obj->is_valid_json($result , 'tracks') , "tracks returned valid json" );

show_and_pause($result);
                   
#------------------#

$result = $obj->artist_top_tracks( '43ZHCT0cAZBISjO8DG9PnE'
                                   , 'SE'

);

show_and_pause($result);

ok( $obj->is_valid_json($result, 'artist_top_tracks') , "artist_top_tracks call");

#------------------#

$result = $obj->search(
                    'tania bowra' ,
                    'artist' ,
                    { limit => 15 , offset => 0 }
);

show_and_pause($result);

ok( $obj->is_valid_json($result) , 'search');

#------------------#

# need a test user?
# spotify:user:elainelin
$result = $obj->user( 'glennpmcdonald' );

ok( $obj->is_valid_json($result , 'user') , "user (glennpmcdonald)" );

show_and_pause($result);

#------------------#

=pod

$result = $obj->me(  );
$result = $obj->next(  );
$result = $obj->previous(  );



$result = $obj->user_playlist(  );
$result = $obj->user_playlist_add_tracks(  );
$result = $obj->user_playlist_create(  );
$result = $obj->user_playlists(  );

=cut

# test me
