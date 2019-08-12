#!/usr/bin/perl

use strict;
use warnings;

use feature 'say';

use Getopt::Long;
use Data::Printer;
use JSON::MaybeXS;
use File::Basename;
use Syntax::Keyword::Try;

my ($input, $cliplen, $offset, $stopat, $bitrate, $crf, $vf, $audio, $two_pass, $ffmpegargs);

# set defaults
$cliplen = 30;
$offset = 0;
$bitrate = "1M";
$crf = 10;

# handle command line args
GetOptions(
  'input|i=s' => \$input,
  'cliplength|l=i' => \$cliplen,
  'offset|startat|o=i' => \$offset,
  'stopat|roffset|s=i' => \$stopat,
  'bitrate|b=s' => \$bitrate,
  'crf|q=i' => \$crf,
  'vfoptions|vf=s' => \$vf,
  'audio|a=s' => \$audio,
  '2pass|2p:s' => \$two_pass,
  'additionalargs|ffmpegargs|cl|opts=s' => \$ffmpegargs
);

die 'No input provided.' unless $input;

$vf = $vf ? "-vf $vf" : '';
$audio //= '-an';

if(defined($two_pass)) {
  $two_pass ||= '/dev/null';
  $crf = ''
}
else {
  $crf = "-crf $crf"
}

# get clean filename, path, etc.
my ($filename, $path, $suffix) = fileparse($input);
my $input_clean = $path . $filename;

my $ffprobe_out = `ffprobe -v quiet -print_format json -show_format -show_streams '$input_clean'`;

# get video duration
try {
  $ffprobe_out = decode_json($ffprobe_out)
}
catch {
  die "$@:\n$ffprobe_out"
}

my $length = $stopat || int($$ffprobe_out{format}->{duration});

# split and encode
for(my $i = $offset; $i < $length; $i += $cliplen) {
  $cliplen = $length - $i if $length - $i < $cliplen;

  my $filename = "'" . $filename . "_$i.webm'";

  my $ffmpeg_cmd_start = "ffmpeg -ss $i -i '$input_clean' -t $cliplen";
  my $ffmpeg_cmd_end = "-c:v libvpx $crf -b:v $bitrate -f webm $vf $ffmpegargs";

  if($two_pass) {
    `$ffmpeg_cmd_start -y -pass 1 -an $ffmpeg_cmd_end $two_pass`;
    `$ffmpeg_cmd_start -pass 2 $audio $ffmpeg_cmd_end $filename`
  }
  else {
    `$ffmpeg_cmd_start $audio $ffmpeg_cmd_end $filename`
  }
}
