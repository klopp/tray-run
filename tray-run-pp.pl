#!/usr/bin/perl

# ------------------------------------------------------------------------------
use strict;
use warnings;
use utf8::all;
use open qw/:std :utf8/;

use Config::General qw/ParseConfig/;
use Const::Fast;
use English qw/-no_match_vars/;
use File::Basename qw/dirname basename/;
use Gtk3 qw/-init/;
use IPC::Run qw/run/;
use POSIX qw/:sys_wait_h/;
use Proc::Killfam;
use Text::ParseWords qw/quotewords/;
use Try::Catch;

# ------------------------------------------------------------------------------
const my $DEF_KILL  => 'TERM';
const my $SELF_PATH => dirname($PROGRAM_NAME);

# ------------------------------------------------------------------------------
our $VERSION = '1.0';

# ------------------------------------------------------------------------------
my $pid;
my $cfg;
my $self_name = basename($PROGRAM_NAME);
$self_name =~ s/^(.+)[.][^.]+$/$1/gsm;
my $cfile = $ARGV[0] || "$SELF_PATH/$self_name.conf" || "$SELF_PATH/$self_name.rc";
%{$cfg} = ParseConfig(
    -ConfigFile     => $cfile,
    -LowerCaseNames => 1,
    -UTF8           => 1,
);
my $exec      = _cget('Exec');
my $real_exec = _parse_path($exec);
my $kill      = $cfg->{kill};
my $on        = _icon('On');
my $off       = _icon('Off');
my $state     = $cfg->{active} ? 0 : 1;

-x $real_exec or Carp::croak sprintf '"%s" is not executable file', $exec;
if ( !$kill ) {
    $kill = $DEF_KILL;
    Carp::carp sprintf 'CONFIG :: no "Kill", set to "%s"', $DEF_KILL;
}
exists $SIG{$kill} or Carp::croak 'CONFIG :: invalid "Kill" value';

my $trayicon = Gtk3::StatusIcon->new;
_switch_state();
$trayicon->set_tooltip_text( sprintf "Left click: execute/stop\n[%s]\nRight click: stop and exit", $exec );
$trayicon->signal_connect(
    'button_press_event' => sub {
        my ( undef, $event ) = @_;

        if ( $event->button == 3 ) {
            _stop();
            Gtk3->main_quit;
        }
        elsif ( $event->button == 1 ) {
            _switch_state();
        }
        1;
    }
);

Gtk3->main;

# ------------------------------------------------------------------------------
sub _parse_path
{
    my ($path) = @_;
    if ( $path =~ /^~(.*)/ ) {
        $path = $ENV{HOME} . $1;
    }
    elsif ( $path !~ /^\// ) {
        $path = sprintf '%s/%s', dirname($PROGRAM_NAME), $path;
    }
    return $path;
}

# ------------------------------------------------------------------------------
sub _cget
{
    my ($name) = @_;
    my $val = $cfg->{ lc $name };
    $val or Carp::croak sprintf 'CONFIG :: no "%s" value', $name;
    return $val;
}

# ------------------------------------------------------------------------------
sub _icon
{
    my ($name) = @_;
    my ( $file, $ico ) = ( _cget($name) );

    try {
        $file = _parse_path($file);
        $ico  = Gtk3::Gdk::Pixbuf->new_from_file($file);
    }
    catch {
        Carp::croak sprintf 'Can not create icon from file "%s" (%s)', $file, $_;
    };
    return $ico;
}

# ------------------------------------------------------------------------------
sub _stop
{
    $pid and killfam $kill, $pid;
}

# ------------------------------------------------------------------------------
sub _start
{
    $pid = fork;
    if ( !defined $pid ) {
        Carp::croak sprintf 'Fork error :: %s', $ERRNO;
    }
    elsif ( !$pid ) {
        try {
            run [ quotewords( '\s+', 1, $real_exec ) ], sub { }, sub { }, sub { };
        }
        catch {
            Carp::carp sprintf '[%s] :: %s', $exec, $_;
        };
    }
    else {
        local $SIG{CHLD} = sub {
            1 while waitpid( $pid, WNOHANG ) > 0;
            undef $pid;
        }
    }
    return;
}

# ------------------------------------------------------------------------------
sub _switch_state
{
    if ($state) {
        $trayicon->set_from_pixbuf($off);
        _stop();
    }
    else {
        $trayicon->set_from_pixbuf($on);
        _start();
    }
    $state ^= 1;
    return;
}

# ------------------------------------------------------------------------------
END {
    _stop();
}

# ------------------------------------------------------------------------------
__END__
