package Media::Info::Mplayer;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use Capture::Tiny qw(capture);
use Log::Any::For::Builtins qw(system);
use Perinci::Sub::Util qw(err);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       get_media_info
               );

our %SPEC;

$SPEC{get_media_info} = {
    v => 1.1,
    summary => 'Return information on media file/URL, using mplayer',
    args => {
        media => {
            summary => 'Media file/URL',
            schema  => 'str*',
            pos     => 0,
            req     => 1,
        },
        audio_info => {
            schema => 'bool',
            default => 1,
        },
    },
    deps => {
        prog => 'mplayer',
    },
};
sub get_media_info {
    require File::Which;

    my %args = @_;
    my $audio_info = $args{audio_info} // 1;

    File::Which::which("mplayer")
          or return err(412, "Can't find mplayer in PATH");
    my $media = $args{media} or return err(400, "Please specify media");

    # make sure user can't sneak in cmdline options to mplayer
    $media = "./$media" if $media =~ /\A-/;

    my ($stdout, $stderr, $exit) = capture {
        local $ENV{LANG} = "C";
        system("mplayer", "-identify", $media,
               "-quiet",
               ("-nosound") x ($audio_info ? 0:1),
               "-msglevel", "all=0", "-frames", "0");
    };

    return err(500, "Can't execute mplayer ($exit)") if $exit;
    #mplayer always emits that message?
    #return err(404, "Media file not found")
    #    if $stderr =~ /^mplayer: No such file/m;

    my $info = {};
    $info->{duration} = $1      if $stdout =~ /^ID_LENGTH=(.+)/m;
    $info->{num_channels} = $1  if $stdout =~ /^ID_AUDIO_NCH=(.+)/m;
    $info->{num_chapters} = $1  if $stdout =~ /^ID_CHAPTERS=(.+)/m;
    #$info->{_audio_format} = $1 if $stdout =~ /^ID_AUDIO_FORMAT=(.+)/m;
    for (qw/
               AUDIO_FORMAT
               AUDIO_BITRATE
               AUDIO_RATE
               VIDEO_FORMAT
               VIDEO_BITRATE
               VIDEO_WIDTH
               VIDEO_HEIGHT
               VIDEO_FPS
               VIDEO_ASPECT
           /) {
        $info->{lc($_)} = $1 if $stdout =~ /^ID_\Q$_\E=(.+)/m;
    }

    [200, "OK", $info, {"func.raw_output"=>$stdout}];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Use directly:

 use Media::Info::Mplayer qw(get_media_info);
 my $res = get_media_info(media => '/home/steven/celine.avi');

or use via L<Media::Info>.

Sample result:

 [
   200,
   "OK",
   {
     audio_bitrate => 128000,
     audio_format  => 85,
     audio_rate    => 44100,
     duration      => 2081.25,
     num_channels  => 2,
     num_chapters  => 0,
   },
   {
     "func.raw_output" => "ID_AUDIO_ID=0\n...",
   },
 ]


=head1 SEE ALSO

L<Media::Info>

=cut
