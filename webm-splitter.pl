#!/usr/bin/perl

use strict;
use warnings;

use feature 'say';

use Path::Tiny;
use Data::Printer;
use JSON::MaybeXS;
use Syntax::Keyword::Try;
use Capture::Tiny 'capture';
use Getopt::Long qw(GetOptions GetOptionsFromString);

my @warn = qw(ss t to);

my ($input, $cliplen, $offset, $duration, $bitrate, $crf, $vf, $audio, $two_pass);

# Set defaults
$cliplen = 30;
$offset = 0;

# Handle command line args
Getopt::Long::Configure('pass_through');

GetOptions(
  'input|i=s' => \$input,
  'cliplength|clipduration|l=i' => \$cliplen,
  'offset|startat|o=i' => \$offset,
  'duration|stopat|d=i' => \$duration,
  #'audio|a=s' => \$audio,
  '2pass|2p:s' => \$two_pass
);

die 'No input file provided.' unless $input;
die 'Input file not found.' unless -e $input;

my ($ret, $ffmpegargs) = GetOptionsFromString(join(' ', @ARGV));

$two_pass ||= '/dev/null'
  if defined $two_pass;

# Get clean filename, path, etc.
my $file = path($input);

# Get video duration
my ($stdout, $stderr, $exit) = capture {
  system(qw(ffprobe -v quiet -print_format json -show_format -show_streams), $file)
};

die "$exit: $stderr" if $stderr;

my $ffprobe_out;

try {
  $ffprobe_out = decode_json($stdout)
}
catch {
  die "$@:\n$ffprobe_out"
}

my $length = $duration || int($ffprobe_out->{format}{duration});

# Split and encode
for (my $i = $offset; $i < $length; $i += $cliplen) {
  $cliplen = $length - $i if $length - $i < $cliplen;

  my $outfile = path("$file\_$i.webm");
  my @args_start = (qw(ffmpeg -ss), $i, '-i', $file, '-t', $cliplen);

  # Not sure if $ffmpegargs will work as expected this way
  my @args_end = qw(-c:v libvpx -f webm);

  push @args_end, @$ffmpegargs
    if ref $ffmpegargs eq 'ARRAY' && scalar @$ffmpegargs;

  if($two_pass) {
    system(@args_start, qw(-y -pass 1), @args_end, '-an', $two_pass); # Maybe I do need to store audio stuff in a variable
                                                                      # IDK if putting '-an' at the end overrides earlier audio options

    system(@args_start, qw(-y -pass 2), @args_end, $outfile)
  }
  else {
    system(@args_start, $audio, @args_end, $outfile)
  }
}
