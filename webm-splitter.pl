#!/usr/bin/perl

use strict;

use JSON;
use File::Basename;

# get input and args
my $input = $ARGV[0] or die "No input video.\n";
my $cliplen = $ARGV[1] || 30;
my $offset = $ARGV[2] || 0;
my $bitrate = $ARGV[3] || "1M";
my $crf = $ARG[4] || 10;

# get clean filename, path, etc.
my ($filename, $path, $suffix) = fileparse($input);
my $input_clean = $path . $filename;

# get video duration
my $ffprobe_out = decode_json(`ffprobe -v quiet -print_format json -show_format -show_streams '$input_clean'`);
my $length = int($$ffprobe_out{format}->{duration});

# split and encode
for(my $i = $offset; $i < $length; $i += $cliplen) {
  my $ffmpegcmd = "ffmpeg -ss $i -i '$input_clean' -t $cliplen -c:v libvpx -crf $crf -b:v $bitrate -an '" . $filename . "_$i.webm'";
  my $ffmpegout = `$ffmpegcmd`;
}
