#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Daemon;
use HTTP::Response;
use URI;
use URI::QueryParam;
use LWP::UserAgent;
use JSON::MaybeXS qw( decode_json );
use MIME::Base64 qw( encode_base64 );

# =============================================================================
# Spotify OAuth User Token Helper
# =============================================================================
#
# This script automates the OAuth Authorization Code flow to get a user
# access token for testing endpoints that require user authorization.
#
# Usage:
#   SPOTIFY_CLIENT_ID=xxx SPOTIFY_CLIENT_SECRET=yyy perl scripts/get-user-token.pl
#
# Or set the environment variables in your shell first.
#
# The script will:
#   1. Start a local web server on port 8888
#   2. Open your browser to Spotify's authorization page
#   3. Wait for you to authorize the app
#   4. Capture the authorization code from the callback
#   5. Exchange it for an access token
#   6. Print the token and example usage
#
# =============================================================================

my $CLIENT_ID     = $ENV{SPOTIFY_CLIENT_ID}     || die "Set SPOTIFY_CLIENT_ID\n";
my $CLIENT_SECRET = $ENV{SPOTIFY_CLIENT_SECRET} || die "Set SPOTIFY_CLIENT_SECRET\n";
my $PORT          = $ENV{SPOTIFY_CALLBACK_PORT} || 8888;
my $REDIRECT_URI  = $ENV{SPOTIFY_REDIRECT_URI}  || "http://localhost:$PORT/callback";
my $MANUAL_MODE   = $ENV{SPOTIFY_MANUAL_MODE}   || 0;

# Scopes needed for the user auth tests
my @SCOPES = qw(
    playlist-read-private
    playlist-read-collaborative
    user-library-read
    user-follow-read
    user-read-private
    user-read-email
);

# Build the authorization URL
my $auth_url = URI->new('https://accounts.spotify.com/authorize');
$auth_url->query_form(
    client_id     => $CLIENT_ID,
    response_type => 'code',
    redirect_uri  => $REDIRECT_URI,
    scope         => join( ' ', @SCOPES ),
    show_dialog   => 'true',
);

print "=" x 70, "\n";
print "Spotify OAuth User Token Helper\n";
print "=" x 70, "\n\n";

print "Redirect URI: $REDIRECT_URI\n\n";

my $code;

if ($MANUAL_MODE) {
    # Manual mode: user copies the code from the redirect URL
    print "MANUAL MODE: No callback server needed.\n\n";

    # Try to open browser automatically
    my $browser_opened = open_browser($auth_url->as_string);

    if ($browser_opened) {
        print "Browser opened. Please authorize the application.\n\n";
    } else {
        print "Please visit this URL to authorize:\n\n";
        print "  $auth_url\n\n";
    }

    print "After authorizing, you'll be redirected to a URL like:\n";
    print "  $REDIRECT_URI?code=AQXXXXX...\n\n";
    print "(The page may not load - that's OK, we just need the URL)\n\n";
    print "Paste the FULL redirect URL or just the code value:\n> ";

    my $input = <STDIN>;
    chomp($input);

    if ($input =~ /code=([^&\s]+)/) {
        $code = $1;
    } else {
        $code = $input;  # Assume they pasted just the code
    }

    die "No authorization code provided\n" unless $code;
}
else {
    # Automatic mode: start callback server
    my $daemon = HTTP::Daemon->new(
        LocalPort => $PORT,
        ReuseAddr => 1,
    ) or die "Could not start server on port $PORT: $!\n";

    print "Starting callback server on http://localhost:$PORT\n\n";

    # Try to open browser automatically
    my $browser_opened = open_browser($auth_url->as_string);

    if ($browser_opened) {
        print "Browser opened. Please authorize the application.\n\n";
    } else {
        print "Could not open browser automatically.\n";
        print "Please visit this URL to authorize:\n\n";
        print "  $auth_url\n\n";
    }

    print "Waiting for callback...\n\n";
    print "(If the redirect fails, restart with SPOTIFY_MANUAL_MODE=1)\n\n";

    # Wait for the callback
    while ( my $conn = $daemon->accept ) {
        while ( my $req = $conn->get_request ) {
            my $uri  = URI->new( $req->uri );
            my $path = $uri->path;

            if ( $path eq '/callback' ) {
                $code = $uri->query_param('code');
                my $error = $uri->query_param('error');

                my $response;
                if ($error) {
                    $response = HTTP::Response->new(400);
                    $response->content_type('text/html');
                    $response->content(<<"HTML");
<!DOCTYPE html>
<html>
<head><title>Authorization Failed</title></head>
<body>
<h1>Authorization Failed</h1>
<p>Error: $error</p>
<p>You can close this window.</p>
</body>
</html>
HTML
                    $conn->send_response($response);
                    $conn->close;
                    die "Authorization failed: $error\n";
                }

                $response = HTTP::Response->new(200);
                $response->content_type('text/html');
                $response->content(<<"HTML");
<!DOCTYPE html>
<html>
<head><title>Authorization Successful</title></head>
<body>
<h1>Authorization Successful!</h1>
<p>You can close this window and return to the terminal.</p>
</body>
</html>
HTML
                $conn->send_response($response);
                $conn->close;
                last;
            }
            else {
                my $response = HTTP::Response->new(404);
                $response->content('Not Found');
                $conn->send_response($response);
            }
        }
        last if $code;
    }
}

die "No authorization code received\n" unless $code;

print "Authorization code received!\n\n";
print "Exchanging code for access token...\n\n";

# Exchange the code for an access token
my $token_data = exchange_code_for_token($code);

print "=" x 70, "\n";
print "SUCCESS! Access token obtained.\n";
print "=" x 70, "\n\n";

print "Access Token:\n";
print "  $token_data->{access_token}\n\n";

if ( $token_data->{refresh_token} ) {
    print "Refresh Token:\n";
    print "  $token_data->{refresh_token}\n\n";
}

print "Expires In: $token_data->{expires_in} seconds\n\n";

print "To run the user auth tests:\n\n";
print "  SPOTIFY_CLIENT_ID=$CLIENT_ID \\\n";
print "  SPOTIFY_CLIENT_SECRET=$CLIENT_SECRET \\\n";
print "  SPOTIFY_USER_TOKEN=$token_data->{access_token} \\\n";
print "  prove -l t/04-live-user-auth.t\n\n";

print "Or export the token:\n\n";
print "  export SPOTIFY_USER_TOKEN='$token_data->{access_token}'\n\n";

# =============================================================================
# Helper Functions
# =============================================================================

sub exchange_code_for_token {
    my ($code) = @_;

    my $ua = LWP::UserAgent->new();

    my $credentials = encode_base64( "$CLIENT_ID:$CLIENT_SECRET", '' );

    my $response = $ua->post(
        'https://accounts.spotify.com/api/token',
        [
            grant_type   => 'authorization_code',
            code         => $code,
            redirect_uri => $REDIRECT_URI,
        ],
        'Authorization' => "Basic $credentials",
        'Content-Type'  => 'application/x-www-form-urlencoded',
    );

    if ( !$response->is_success ) {
        die "Token exchange failed: " . $response->status_line . "\n"
          . $response->decoded_content . "\n";
    }

    return decode_json( $response->decoded_content );
}

sub open_browser {
    my ($url) = @_;

    my $cmd;
    if ( $^O eq 'darwin' ) {
        $cmd = qq{open "$url"};
    }
    elsif ( $^O eq 'linux' ) {
        $cmd = qq{xdg-open "$url" 2>/dev/null || sensible-browser "$url"};
    }
    elsif ( $^O eq 'MSWin32' ) {
        $cmd = qq{start "" "$url"};
    }
    else {
        return 0;
    }

    system($cmd) == 0;
}

__END__

=head1 NAME

get-user-token.pl - Obtain a Spotify user access token for testing

=head1 SYNOPSIS

    # Set your credentials
    export SPOTIFY_CLIENT_ID='your_client_id'
    export SPOTIFY_CLIENT_SECRET='your_client_secret'

    # Run the script
    perl scripts/get-user-token.pl

=head1 DESCRIPTION

This script helps you obtain a Spotify user access token using the OAuth
Authorization Code flow. This is required for testing API endpoints that
access user-specific data (playlists, saved tracks, followed artists, etc.).

The script will:

=over 4

=item 1. Start a local web server on port 8888

=item 2. Open your browser to Spotify's authorization page

=item 3. Wait for you to log in and authorize

=item 4. Capture the callback with the authorization code

=item 5. Exchange the code for an access token

=item 6. Print the token and usage instructions

=back

=head1 ENVIRONMENT

=over 4

=item SPOTIFY_CLIENT_ID (required)

Your Spotify application's client ID.

=item SPOTIFY_CLIENT_SECRET (required)

Your Spotify application's client secret.

=item SPOTIFY_CALLBACK_PORT (optional, default: 8888)

Port for the local callback server.

=back

=head1 SPOTIFY APP SETUP

Make sure your Spotify app has C<http://localhost:8888/callback> added
as a Redirect URI in the app settings at:

L<https://developer.spotify.com/dashboard>

=head1 AUTHOR

WWW::Spotify contributors

=cut
