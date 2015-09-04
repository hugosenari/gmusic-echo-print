# Base code of this plugins came from nowplaying.pm and mpris2.pm plugins from gmusicbrowser
# This plugin is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=gmbplugin GSTCHROMAPRINT
name	Gstreamer chromaprint
title	Gstreamer chromaprint
desc	Get fingerprint using gst-launch-1.0 chromaprint
=cut

package GMB::Plugin::GSTCHROMAPRINT;
use warnings;
use constant
{
    OPT	=> 'PLUGIN_GSTCHROMAPRINT_'
};

use IPC::Open2;
 
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
    warn "$text\n";
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
        FingerPrint($musicID);
    } or do {
        Log("$@");
        return 0;
    };
    return 1;
}

sub FingerPrint
{   my $mID = shift;
    my $file = Songs::GetFullFilename($mID);
    
    WriteFingerPrint($mID, CreateFingerPrint($file)) unless GetFingerPrint($file);
    
    return 1;
}

sub GetFingerPrint
{   my $file = shift;
    my ($h) = FileTag::Read($file, 0, 'embedded_lyrics');
    return $h->{embedded_lyrics} if $h and $h->{embedded_lyrics};
}

sub WriteFingerPrint
{   my ($mID,$val) = @_;
    FileTag::Write($mID, [ embedded_lyrics => $val ], sub
    {my ($syserr ,$details) = FileTag::Error_Message(@_);
        return ::Retry_Dialog($syserr, "Error writing fingerprint", details => $details, ID => $mID);
    });
    return $val;
}

sub CreateFingerPrint
{   my $file = shift;
    $file =~ s/'/\'\\'\'/g;
    my $result = `gst-launch-1.0 -t \\
                 filesrc location='$file' ! \\
                 decodebin ! \\
                 audioconvert ! \\
                 chromaprint duration=30 ! \\
                 fakesink sync=0\\
    2>&1`;

    $result =~ s/\R/@/g;
    if ($result =~ /chromaprint fingerprint/) {
        $result =~ s/^.*chromaprint fingerprint: ([^@]+)@+.*/$1/gi;
        return $result;
    }

    die "Cannot get chromaprint, Error: $result";
}
