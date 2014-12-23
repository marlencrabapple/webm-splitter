#!/usr/bin/perl

use strict;

use JSON;
use Getopt::Long;
use File::Basename;

my ($input, $cliplen, $offset, $stopat, $bitrate, $crf, $vf, $ffmpegargs);

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
  'additionalargs|ffmpegargs|cl|opts=s' => \$ffmpegargs
);

die "No input provided." unless $input;
$vf = "-vf $vf" if $vf;

# get clean filename, path, etc.
my ($filename, $path, $suffix) = fileparse($input);
my $input_clean = $path . $filename;

# get video duration
my $ffprobe_out = decode_json(`ffprobe -v quiet -print_format json -show_format -show_streams '$input_clean'`);
my $length = $stopat || int($$ffprobe_out{format}->{duration});

# split and encode
for(my $i = $offset; $i < $length; $i += $cliplen) {
  $cliplen = $length - $i if $length - $i < $cliplen;

  my $ffmpegcmd = "ffmpeg -ss $i -i '$input_clean' -t $cliplen -c:v libvpx -crf $crf -b:v $bitrate -an $vf $ffmpegargs '" . $filename . "_$i.webm'";
  print "$ffmpegcmd:\n\n";

  `$ffmpegcmd`;
}
