#
# server_time.pl
# Implements the IRCv3 "server-time" capability
#
#
#   Copyright (C) 2016 Adrian Keet
#
#   Permission is hereby granted, free of charge, to any person obtaining a
#   copy of this software and associated documentation files (the "Software"),
#   to deal in the Software without restriction, including without limitation
#   the rights to use, copy, modify, merge, publish, distribute, sublicense,
#   and/or sell copies of the Software, and to permit persons to whom the
#   Software is furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#   DEALINGS IN THE SOFTWARE.
#
#
# Instructions
# ------------
#
# This script is intended to be loaded before connecting to a server; then it
# will request the server-time capability upon connecting.
#
# Changelog
# ---------
#
# 0.1
#   - Initial release
#

use strict;
use Irssi;

our $VERSION = '0.1';
our %IRSSI = (
    authors     => 'Adrian Keet',
    contact     => 'arkeet@gmail.com',
    name        => 'server_time',
    description => 'Implements the IRCv3 "server-time" capability',
    license     => 'MIT',
    url         => 'https://github.com/arkeet/irssi-server-time',
);

use DateTime;
use DateTime::TimeZone;
use DateTime::Format::ISO8601;

# Parse the @time tag on a server message
sub server_incoming {
    my ($server, $line) = @_;

    if ($line =~ /^\@time=([\S]*)\s+(.*)$/) {
        my $servertime = $1;
        $line = $2;

        my $tz = DateTime::TimeZone->new(name => 'local');

        my $ts = DateTime::Format::ISO8601->parse_datetime($servertime);
        $ts->set_time_zone($tz);

        my $orig_format = Irssi::settings_get_str('timestamp_format');
        my $format = $orig_format;

        # Prepend the date if it differs from the current date.
        my $now = DateTime->now();
        $now->set_time_zone($tz);
        if ($ts->ymd() ne $now->ymd()) {
            $format = '[%F] ' . $format;
        }

        my $timestamp = $ts->strftime($format);

        Irssi::settings_set_str('timestamp_format', $timestamp);
        Irssi::signal_emit('setup changed');

        Irssi::signal_continue($server, $line);

        Irssi::settings_set_str('timestamp_format', $orig_format);
        Irssi::signal_emit('setup changed');
    }
}

# Request the server-time capability during capability negotiation
sub event_cap {
    my ($server, $args, $nick, $address) = @_;

    if ($args =~ /^\S+ (\S+) :(.*)$/) {
        my $subcmd = uc $1;
        if ($subcmd eq 'LS') {
            my @servercaps = split(/\s+/, $2);
            my @caps = grep {$_ eq 'server-time' or $_ eq 'znc.in/server-time-iso'} @servercaps;
            my $capstr = join(' ', @caps);
            if (!$server->{connected}) {
                $server->send_raw_now("CAP REQ :$capstr");
            }
        }
    }
}

Irssi::signal_add_first('server incoming', \&server_incoming);
Irssi::signal_add('event cap', \&event_cap);
