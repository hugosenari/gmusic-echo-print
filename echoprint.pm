# Base code of this plugins came from nowplaying.pm and mpris2.pm plugins from gmusicbrowser
# This plugin is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=gmbplugin ECHOPRINT
name	Echo Print
title	Echo print
desc	Get fingerprint using echoprint-codegen
=cut

package GMB::Plugin::ECHOPRINT;
use warnings;
use constant
{
    OPT	=> 'PLUGIN_ECHOPRINT_',
};

use IO::CaptureOutput qw( qxx);
 
my $Log=Gtk2::ListStore->new('Glib::String');

my $handle;
my $musicID = -1;

sub Start
{
    $handle={};
    ::Watch($handle, PlayingSong => \&Changed);
}
sub Stop
{
    ::UnWatch($handle,'PlayingSong');
}

sub Log
{
    my $text=$_[0];
    $Log->set( $Log->prepend,0, localtime().'  '.$text );
    warn "$text\n";# if $::debug;
    if (my $iter=$Log->iter_nth_child(undef,50)) { $Log->remove($iter); }
}

sub prefbox 
{
    my $vbox=Gtk2::VBox->new(::FALSE, 2);
    $vbox->add( ::LogView($Log) );
    return $vbox;
}

sub Changed
{
    return 1 if ($musicID == $::SongID);
    $musicID = $::SongID;

    eval {
        SetFingerPrint();
    } or do {
        Log("$@");
        return 0;
    };
    return 1;
}

sub SetFingerPrint
{
    my $echoprint = FileTag::GetLyrics($musicID) or 0;
    Log("old echoprint $echoprint");
    
    unless ($echoprint)
    {
        $echoprint = GetFingerPrint();

        Log("new echoprint $echoprint");
        FileTag::WriteLyrics($musicID, $echoprint) if $echoprint;
    }
    return 1;
}

sub GetFingerPrint
{
    my $fullfilename = Songs::GetFullFilename($musicID);
    my ( $stdout , $stderr , $success ) = qxx( 'echoprint-codegen' , $fullfilename, 1, 10 );
    if ($stdout =~ /"code"/) {
        $stdout =~ s/\R//g;
        $stdout =~ s/^.*"code"\w*:\w*"([^"]+)".*/$1/gi;
        return $stdout;
    }

    $stderr = $stdout unless $stderr;
    $stderr =~ s/\R//g;
    $stderr =~ s/^.*"error"\w*:\w*"([^"]+)".*/$1/gi;

    die "Cannot get fingerprint, Error: $stderr";
}