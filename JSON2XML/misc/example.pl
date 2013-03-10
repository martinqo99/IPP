#!/usr/bin/perl
 
use strict;
 
# used modules
use Data::Dumper; # stringified perl data structures
use JSON::XS;     # JSON serialising/deserialising
use XML::Writer;  # writing XML documents
use IO::File;     # supply object methods for filehandles
 
# available options of this program
my $n=0;  # not to generate XML header
my $r=''; # name of the root element to wrap result
my $s=0;  # string transform
my $i=0;  # integer transform
my $l=0;  # literals transform
my $e=0;  # root array recovery
 
my $infile = ''; my $outfile = ''; # input and output filenames
 
#########################################################################
# start
#########################################################################
 
parseOpts(@ARGV); # parsing program arguments
 
# file input
my $jshash; # declare json hash reference
 
local $/=undef; # unset $/ for whole file read at once
 
if ($infile) { # reading from file
    open JSFILE, "<", $infile or die $infile.': problem with file!';
    $jshash = JSON::XS->new->utf8->decode(<JSFILE>); # json parsing
    close JSFILE;
}
else { # reading from STDIN
  $jshash = JSON::XS->new->utf8->decode(<STDIN>); # json parsing
}
# explicit check of input JSON and options
die("Invalid JSON input\n") if (ref $jshash eq 'ARRAY' and !($r and $e));
 
# set output handler
my $output = $outfile ? new IO::File(">$outfile") : <STDOUT>;
# create xml writer
my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 1);
 
$writer->xmlDecl("UTF-8") unless $n; # xml header if such option
$writer->startTag($r) if $r; # root element if such option
 
json2xml($jshash); # JSON2XML
 
$writer->endTag($r) if $r; # end root element if such option
 
$writer->end(); # destroy xml writer
$output->close() if $outfile; # close file if opened
 
#########################################################################
# finish
#########################################################################
 
 
##########################################################################
# subroutine for transforming JSON::XS hash into XML text 
sub json2xml {
  my ($jr) = @_;
  if (ref $jr eq 'ARRAY') {
      $writer->startTag('array');
      foreach (@$jr) { # loop items in array
        if (ref $_ eq '' or ref $_ eq 'JSON::XS::Boolean') { # value
          value2xml('item', $_); # use 'item' as a key
        }
        else { # reference
          $writer->startTag('item');
          json2xml($_); # recursive call for each item
          $writer->endTag('item');  
        }
      }
      $writer->endTag('array');   
    return;    
  }
  #value2xml('item', $jr) if (ref $jr eq '');
  while ( my ($key, $value) = each (%$jr) ) 
  { # main loop of writing XML    
    if (ref $value eq 'HASH')
    { # HASH
      $writer->startTag($key);
      json2xml($value); # recursive call for this hash
      $writer->endTag($key);
    } 
    elsif (ref $value eq 'ARRAY')
    { # ARRAY
      $writer->startTag($key);
      json2xml($value); # process it at the begin of next call
      $writer->endTag($key);
    }
    else 
    { # VALUE
      value2xml($key, $value);
    }
  } # end of WHILE
} # end of json2xml
 
 
##########################################################################
# subroutine for transforming value into XML text 
sub value2xml {
  my ($key, $value) = @_;
  # BOOLEAN LITERAL
  if (ref $value eq 'JSON::XS::Boolean') {
    unless ($l) { # make attribute
      $writer->emptyTag($key,'value' => $value ? 'true':'false');
    }
    else { # make element
      $writer->startTag($key);
      $writer->emptyTag($value ? 'true':'false');
      $writer->endTag($key);
    }
  }
  # NULL
  elsif (! defined $value) {
    unless ($l) { # make attribute
      $writer->emptyTag($key, 'value' => $value ? $value : 'null');
    }
    else { # make element
      $writer->startTag($key);
      $writer->emptyTag('null');
      $writer->endTag($key);
    }
  }       
  # STRING or NUMERIC value
  else {
    my $novalue = 0;
    if (Dumper($value) =~ /^.*= '.*'.*/
    or  Dumper($value) =~ /^.*= ".*".*/) { # true if string
      $novalue = 1 if $s;
    }
    else { # true if number
      $novalue = 1 if $i;
    }       
    unless ($novalue) { # make attribute
      $writer->emptyTag($key,'value' => $value);
    }
    else { # make element
      $writer->startTag($key);
      $writer->characters($value);
      $writer->endTag($key);
    }
  }    
}
 
##########################################################################
# parsing of program arguments subroutine
sub parseOpts {
  my $astr = join(' ',@_); # join all arguments into one string
  return if ($astr =~ /^\s*$/); # ERROR - no arguments
  if ($astr =~ s/--help//) {
    die("--help must be only given argument\n") unless ($astr =~ /^\s*$/);  
    help(); # print help message and exit
    exit 0;
  }
  else { # parse arguments
    if ($astr =~ s/--input=([\S]*)//) {
      $infile = $1;
      die("this input file cannot be used\n") if (-d $infile);
      die("input file not exists\n") if (! -f $infile);
    }
    if ($astr =~ s/--output=([\S]*)//) {
      $outfile = $1;
      die("this output file cannot be used\n") if (-d $outfile);
    }
    unless ($astr =~ /^\s*$/) { # OPTIONS given
      $n = 1 if ($astr =~ s/[\-]n//);
      $r = $1 if ($astr =~ s/[\-]r=([\S]*)//);
      $s = 1 if ($astr =~ s/[\-]s//);
      $i = 1 if ($astr =~ s/[\-]i//);
      $l = 1 if ($astr =~ s/[\-]l//);
      $e = 1 if ($astr =~ s/[\-]e//);      
    }
    die("-e can not be without -r.\nSee json2xml.pl --help\n") if ($e and !$r);
    die("Wrong arguments are given\n") unless ($astr =~ /^\s*$/);
  }
} # end of parseOpts
 
 
##########################################################################
# HELP PRINT subroutine
sub help {
    print "Program json2xml\n\n";
    print "Usage: jsn.pl [OPTIONS]\n";
    print "\nAvailable options:\n";
    print "\n--input=file1.ext\tInput JSON file\n";
    print "--output=file2.ext\tName of output XML file\n";
    print "-n\t\t\tNot to generate XML header\n";
    print "-r=root-element\t\tName of the element to wrap result\n";
    print "-s\t\t\tTransform strings to element instead attribute\n";
    print "-i\t\t\tTransform integers to element instead attribute\n";
    print "-l\t\t\tTransform other JSON literals to element\n";
    print "-e\t\t\tWrong root array recovery\n";
    print "\nOther controls:\n--help\t\t\tThis message\n\n";
} # end of help
 
# end of script