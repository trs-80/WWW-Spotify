#!perl

# Interactive, developer-only live test of user-authorized (OAuth
# authorization-code) endpoints. Never runs on install: it lives in xt/
# and additionally requires SPOTIFY_INTERACTIVE_TESTS=1.
#
# Setup (once):
#   1. In the Spotify developer dashboard, add
#      http://127.0.0.1:8888/callback as a redirect URI for your app.
#   2. export SPOTIFY_CLIENT_ID=... SPOTIFY_CLIENT_SECRET=...
#   3. SPOTIFY_INTERACTIVE_TESTS=1 prove -l xt/author/live-user.t
#
# First run opens a browser for Spotify login; the token (with refresh
# token) is cached in ~/.www-spotify-dev-token.json so later runs are
# non-interactive until the refresh token stops working.

use strict;
use warnings;

use JSON::MaybeXS qw( decode_json encode_json );
use Test::More;
use WWW::Spotify ();

plan skip_all => 'developer-only: set SPOTIFY_INTERACTIVE_TESTS=1 to run'
  unless $ENV{SPOTIFY_INTERACTIVE_TESTS};
plan skip_all => 'SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET required'
  unless $ENV{SPOTIFY_CLIENT_ID} && $ENV{SPOTIFY_CLIENT_SECRET};

my $REDIRECT_URI = 'http://127.0.0.1:8888/callback';
my $CACHE_FILE   = "$ENV{HOME}/.www-spotify-dev-token.json";
my $SCOPES       = join ' ', qw(
  user-read-private
  user-library-read
  user-library-modify
  playlist-read-private
  playlist-modify-public
  playlist-modify-private
);

my $spotify = WWW::Spotify->new(
    oauth_client_id     => $ENV{SPOTIFY_CLIENT_ID},
    oauth_client_secret => $ENV{SPOTIFY_CLIENT_SECRET},
    oauth_redirect_uri  => $REDIRECT_URI,
    force_client_auth   => 0,
);

ensure_user_token($spotify);

# ---------------------------------------------------------------------------
# Live user-endpoint assertions
# ---------------------------------------------------------------------------

# GET /v1/me
my $profile = decode_json( $spotify->me() );
ok( $profile->{id}, 'me() returns a profile with an id' )
  or diag explain $profile;
note "authenticated as $profile->{id}";

# GET /v1/me/playlists
my $playlists = decode_json( $spotify->get_current_user_playlists() );
ok( exists $playlists->{items}, 'get_current_user_playlists returns items' );

# Library save/check/remove cycle (self-cleaning)
my $track_uri = 'spotify:track:0eGsygTp906u18L0Oimnem';    # Mr. Brightside

$spotify->save_library_items( [$track_uri] );
my $contains = decode_json( $spotify->check_library_items( [$track_uri] ) );
ok( $contains->[0], 'saved track shows in library contains check' );

$spotify->remove_library_items( [$track_uri] );
$contains = decode_json( $spotify->check_library_items( [$track_uri] ) );
ok( !$contains->[0], 'removed track no longer in library' );

# Playlist create/add/verify/unfollow cycle (self-cleaning)
my $name     = 'WWW::Spotify live test ' . time();
my $playlist = decode_json(
    $spotify->create_playlist(
        $name, 0, 'temporary playlist created by xt/author/live-user.t'
    )
);
ok( $playlist->{id}, 'create_playlist returns a playlist id' )
  or diag explain $playlist;

my $added = decode_json(
    $spotify->add_items_to_playlist( $playlist->{id}, $track_uri ) );
ok( $added->{snapshot_id}, 'add_items_to_playlist returns a snapshot id' );

# /v1/playlists/{id}/items wraps each entry in an 'item' key (not 'track')
my $items = decode_json( $spotify->get_playlist_items( $playlist->{id} ) );
is( $items->{items}[0]{item}{uri},
    $track_uri, 'playlist contains the added track' );

$spotify->unfollow_playlist( $playlist->{id} );
pass('unfollow_playlist cleanup sent');

done_testing();

# ---------------------------------------------------------------------------
# Token plumbing: cache -> refresh -> interactive browser login
# ---------------------------------------------------------------------------

sub ensure_user_token {
    my $spotify = shift;

    if ( my $cache = load_cache() ) {
        $spotify->refresh_token( $cache->{refresh_token} // q{} );
        if (   $cache->{access_token}
            && $cache->{expires_at}
            && time() < $cache->{expires_at} - 60 ) {
            $spotify->current_access_token( $cache->{access_token} );
            $spotify->token_expires_at( $cache->{expires_at} );
            note 'using cached access token';
            return;
        }
        if ( $spotify->refresh_token() && $spotify->refresh_access_token() ) {
            note 'refreshed access token from cache';
            save_cache($spotify);
            return;
        }
        note 'cached token unusable; falling back to browser login';
    }

    interactive_login($spotify);
    save_cache($spotify);
}

sub load_cache {
    open my $fh, '<', $CACHE_FILE or return;
    local $/;
    my $cache = eval { decode_json(<$fh>) };
    close $fh;
    return $cache;
}

sub save_cache {
    my $spotify = shift;
    open my $fh, '>', $CACHE_FILE
      or die "cannot write $CACHE_FILE: $!";
    chmod 0600, $CACHE_FILE;
    print {$fh} encode_json(
        {
            access_token  => $spotify->current_access_token(),
            refresh_token => $spotify->refresh_token(),
            expires_at    => $spotify->token_expires_at(),
        }
    );
    close $fh;
}

sub interactive_login {
    my $spotify = shift;

    require HTTP::Daemon;
    require HTTP::Status;

    my $daemon = HTTP::Daemon->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 8888,
        ReuseAddr => 1,
    ) or die "cannot listen on 127.0.0.1:8888: $!\n"
      . "(is another test run still holding the port?)\n";

    my $state = sprintf '%08x%08x', rand(0xffffffff), rand(0xffffffff);
    my $url   = $spotify->authorize_url(
        { scope => $SCOPES, state => $state } );

    diag "\nOpening browser for Spotify login...\n$url\n";
    if ( $^O eq 'darwin' ) {
        system 'open', $url;
    }
    elsif ( $^O eq 'linux' ) {
        system 'xdg-open', $url;
    }
    else {
        diag 'Open the URL above in your browser.';
    }

    my $code;
    while ( my $conn = $daemon->accept ) {
        my $request = $conn->get_request or next;
        my $uri     = $request->uri;

        if ( $uri->path ne '/callback' ) {
            $conn->send_error( HTTP::Status::HTTP_NOT_FOUND() );
            $conn->close;
            next;
        }

        my %query = $uri->query_form;
        if ( ( $query{state} // q{} ) ne $state ) {
            $conn->send_error( HTTP::Status::HTTP_BAD_REQUEST(),
                'state mismatch' );
            $conn->close;
            die "OAuth state mismatch; aborting\n";
        }
        if ( $query{error} ) {
            $conn->send_error( HTTP::Status::HTTP_BAD_REQUEST(),
                $query{error} );
            $conn->close;
            die "authorization denied: $query{error}\n";
        }

        $code = $query{code};
        my $response = HTTP::Response->new( HTTP::Status::HTTP_OK() );
        $response->header( 'Content-Type' => 'text/html' );
        $response->content(
            '<html><body><h1>Login captured</h1>'
              . 'You can close this tab and return to the terminal.'
              . '</body></html>' );
        $conn->send_response($response);
        $conn->close;
        last;
    }
    $daemon->close;

    die "no authorization code received\n" unless $code;

    $spotify->get_access_token($code)
      or die "token exchange failed\n";
    note 'interactive login complete';
}
