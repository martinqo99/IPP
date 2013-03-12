#!/usr/bin/perl

#JSN:xherma25

use strict;

#------------------- MODULES -------------------
use Getopt::Long qw(:config pass_through);
use JSON::XS;
use XML::Writer;
use IO::File;
#------------------- MODULES -------------------

#------------------- GLOBALS -------------------
my $input;		# input file
my $output;		# output file
my $h;			# substr
my $n;			# xmlheader
my $r;			# wrap result in
my $array_name;		# array name
my $item_name;		# item name
my $s;			# string transform
my $i;			# integer transform
my $l;			# literals transform
my $c;			# root array recovery
my $a;			# size
my $t;			# index
my $start;		# index from 

my @Stack;
my $StackCounter;
#------------------- GLOBALS -------------------

#-------------------- MAIN --------------------
parse_ops(@ARGV); 

  my $json;
  
  # we load json file into $json.   
  local $/=undef; 
  
  if($input eq "")
  {
    $json = JSON::XS->new->utf8(0)->decode(<STDIN>);
  }
  else
  {
    open FILE, "<", $input or my_die(2,"Cannot open file: ".$input."\n");
    $json = JSON::XS->new->utf8(0)->decode(<FILE>);
    close FILE;
  }
  
  # open output file and make XML writer.
  if($output eq "")
    {my $out = <STDOUT>;}
  else
    {my $out = new IO::File(">$output") or my_die(3,"Cannot open file: ".$output."\n");}
    
  my $out = new IO::File(">$output");
  my $writer = new XML::Writer(OUTPUT => $out, UNSAFE => 1, UNSAFE => 1, DATA_MODE => 'true', DATA_INDENT => 2);
  
  
  #lets write header and root tag if set.
  if(!$n) # HEADER
    {$writer->xmlDecl("UTF-8")}
  
  if($r) # ROOT TAG START
    {$writer->startTag($r);}
  
  #recursive implementation.
  if (ref $json eq 'ARRAY') 
    {subarray($json);}
  else
    {subdata($json);}
  
  if($r) # ROOT TAG END
    {$writer->endTag($r)}

  $writer->end();
  if($output ne "")
    {$out->close();}
#-------------------- MAIN --------------------

#------------------- MY_DIE --------------------
sub my_die
{
  my ($err, $msg) = @_;
  print STDERR $msg;
  exit $err;
}
#------------------- MY_DIE --------------------

#------------------ SUBARRAY -------------------
sub subarray
{
  my ($js) = @_;
  
  if($a)
    {$writer->startTag($array_name, "size" => scalar(@$js));}
  else
    {$writer->startTag($array_name);}
    
  push (@Stack, $StackCounter);
  $StackCounter = $start;
  
  # we found an array, so we need to analyze what is inside the array.
  foreach (@$js) 
  {
    my $row = $_;
    if (ref $row eq '' or ref $row eq 'JSON::XS::Boolean') 
    {
      # if its item, we write it.
      write_value($item_name, $row);
    }
    else
    {
      # if its an object or array, 
      # we place start and end tag, and we go deeper
      if($t)
      {
        $writer->startTag($item_name, 'index' => $StackCounter); ################
        $StackCounter++;
      }
      else
        {$writer->startTag($item_name);}
      subdata($row);
      $writer->endTag($item_name);  
    }
  }
  
  $StackCounter = pop @Stack;
  $writer->endTag($array_name);   
}
#------------------ SUBARRAY -------------------

#------------------- SUBDATA -------------------
sub subdata
{
  my ($js) = @_;
  
  if (ref $js eq 'ARRAY') 
    {subarray($js);
    return;}
  
  # lets read $first and $second from associative array.
  # if its value is array, we call subarray.
  # if its value is hash, we call subdata.
  # else we can safely write values.
  while(my ($first, $second) = each(%$js)) 
  { 
    if(ref $second eq 'ARRAY')
    {
      $writer->startTag($first);
      subarray($second);
      $writer->endTag($first);
    } 
    elsif(ref $second eq 'HASH')
    {
      $writer->startTag($first);
      subdata($second);
      $writer->endTag($first);
    }
    else 
    {
      write_value($first, $second);
    }
  }
}
#------------------- SUBDATA -------------------

#---------------- ISVALIDELEMENT -----------------
sub isvalidelement
{
  my ($pom) = @_;
  if($pom =~ /^[_:A-Za-z\ě\š\č\ř\ž\ý\á\í\é\ú\ů\ť\ň\ď\Ě\Š\Č\Ř\Ž\Ý\Á\Í\É\Ú\Ů\Ď\Ť\Ň\ó\Ó][-._:A-Za-z0-9\ě\š\č\ř\ž\ý\á\í\é\ú\ů\ť\ň\ď\Ě\Š\Č\Ř\Ž\Ý\Á\Í\É\Ú\Ů\Ď\Ť\Ň\ó\Ó]*$/)
    {return 1;}
  else
    {return 0;}
}
#---------------- ISVALIDELEMENT -----------------

#----------------- WRITE_VALUE ------------------
sub write_value
{
  my ($first, $second) = @_;
   
  # is $first valid element? Also replace those characters!
  $first =~ s/[^-._:A-Za-z0-9\ě\š\č\ř\ž\ý\á\í\é\ú\ů\ť\ň\ď\Ě\Š\Č\Ř\Ž\Ý\Á\Í\É\Ú\Ů\Ď\Ť\Ň\ó\Ó]/$h/g;
  # Ain't Nobody Got Time for That!
  if(!isvalidelement($first))
  {
    my_die(51,"invalid element name: ".$first."\n");
  }
  # first at all, we check if $second is defined.
  if($second eq undef )
  {  # ----- NULL -----
    # if not, we write it depending on $l param.
    if($l)
    {
      if($t and $first eq $item_name)
      {
	$writer->startTag($first, 'index' => $StackCounter); ################
	$StackCounter++;
      }
      else
	{$writer->startTag($first);}
	
      $writer->emptyTag('null');
      $writer->endTag($first);
    }
    else
    {
      if($t and $first eq $item_name)
      {
	if($second)
	  {$writer->emptyTag($first, 'value' => $second, 'index' => $StackCounter);$StackCounter++;} ###############
	else
	  {$writer->emptyTag($first, 'value' => 'null', 'index' => $StackCounter);$StackCounter++;} ###############
      }
      else
      {
	if($second)
	  {$writer->emptyTag($first, 'value' => $second);}
	else
	  {$writer->emptyTag($first, 'value' => 'null');}
      }
     
    }
  }
  # now we check if $second is a bool value.
  elsif(ref $second eq 'JSON::XS::Boolean')
  {  # ----- BOOL -----
    # if yes, we write it depending on $l param.
    if($l)
    {
      if($t and $first eq $item_name)
      {
	$writer->startTag($first, 'index' => $StackCounter); ################
	$StackCounter++;
      }
      else
	{$writer->startTag($first);}
      
      if($second)
	{$writer->emptyTag('true');}
      else
	{$writer->emptyTag('false');}
	
      $writer->endTag($first);
    }
    else
    {
      if($t and $first eq $item_name)
      {
	if($second)
	  {$writer->emptyTag($first, 'value' => 'true', 'index' => $StackCounter);$StackCounter++;} ############
	else
	  {$writer->emptyTag($first, 'value' => 'false', 'index' => $StackCounter);$StackCounter++;} ############
      }
      else
      {
	if($second)
	  {$writer->emptyTag($first, 'value' => 'true');}
	else
	  {$writer->emptyTag($first, 'value' => 'false');}
      }
    }
  }
  #else it must be number, or string.
  else
  {
    # so we check if it is a number.
    #if($second  =~ /^[+-]?\d+\.?\d*$/) # is a number?
    unless($second  ^ $second) # is a number?
    {  # ----- NUMBER -----
      # if the number is lesser then 0, we do this little magic.
      if($second < 0)
	{$second = $second - 1;}
      # now the int() will round as we need it.
      my $num = int($second);

      # now we cant write the number, depending on $i
      if($i)
      {
	if($t and $first eq $item_name)
	{
	  $writer->startTag($first, 'index' => $StackCounter); ##################
	  $StackCounter++;
	}
	else
	  {$writer->startTag($first);}
	
	$writer->characters($num);
	$writer->endTag($first);
      }
      else
      {
	if($t and $first eq $item_name)
	{
	  $writer->emptyTag($first, 'value' => $num, 'index' => $StackCounter); ###################
	  $StackCounter++;
	}
	else
	  {$writer->emptyTag($first, 'value' => $num);}
      }
    }
    else # ----- STRING -----
    {
      # there is no other options. We write string depending on $s and $c
      if($s)
      {
	if($t and $first eq $item_name)
	{
	  $writer->startTag($first, 'index' => $StackCounter); ####################
	  $StackCounter++;
	}
	else
	  {$writer->startTag($first);}
	  
	if($c)
	  {$writer->characters($second);}
	else
	  {$writer->raw($second);}
	$writer->endTag($first);
      }
      else	
      {
	if($c)
	{
	  if($t and $first eq $item_name)
	  {
	    $writer->emptyTag($first, 'value' => $second); ################
	    $StackCounter++;
	  }
	  else
	    {$writer->emptyTag($first, 'value' => $second);}  
	}
	else
	{
	  if($t and $first eq $item_name)
	  {
	    $writer->raw("<".$first." index=\"".$StackCounter."\"value=\""); ################
	    $StackCounter++;
	  }
	  else
	    {$writer->raw("<".$first." value=\"");}
	    
	  $writer->raw($second);
	  $writer->raw("\" />");
	}
      }
    }
  }
}
#----------------- WRITE_VALUE ------------------

#------------------ ARGUMENTS ------------------
sub parse_ops 
{
  my $pom = join(' ',@_);
  if ($pom =~ s/--help//)
  {
    help();
    exit 1;
  }

  GetOptions(
    'input:s'	=> sub { if( defined $input) {
		my_die(1, "Error: --input can be specified only once\n");
		} else {$input = $_[1];}},
    'output:s'	=> sub { if( defined $output) {
		my_die(1, "Error: --output can be specified only once\n");
		} else {$output = $_[1];}},
    'h:s'		=> sub { if( defined $h) {
		my_die(1, "Error: -h can be specified only once\n");
		} else {$h = $_[1];}},
    'n'		=> sub { if( defined $n) {
		my_die(1, "Error: -n can be specified only once\n");
		} else {$n = $_[1];}},
    'r:s'		=> sub { if( defined $r) {
		my_die(1, "Error: -r can be specified only once\n");
		} else {$r = $_[1];}},
    'array-name:s'	=> sub { if( defined $array_name) {
		my_die(1, "Error: --array_name can be specified only once\n");
		} else {$array_name = $_[1];}},
    'item-name:s'	=> sub { if( defined $item_name) {
		my_die(1, "Error: --item_name can be specified only once\n");
		} else {$item_name = $_[1];}},
    's'		=> sub { if( defined $s) {
		my_die(1, "Error: -s can be specified only once\n");
		} else {$s = $_[1];}},
    'i'		=> sub { if( defined $i) {
		my_die(1, "Error: -i can be specified only once\n");
		} else {$i = $_[1];}},
    'l'		=> sub { if( defined $l) {
		my_die(1, "Error: -l can be specified only once\n");
		} else {$l = $_[1];}},
    'c'		=> sub { if( defined $c) {
		my_die(1, "Error: -c can be specified only once\n");
		} else {$c = $_[1];}},
    'a'		=> sub { if( defined $a) {
		my_die(1, "Error: -a can be specified only once\n");
		} else {$a = $_[1];}},
    'array-size'	=> sub { if( defined $a) {
		my_die(1, "Error: -a can be specified only once\n");
		} else {$a = $_[1];}},
    't'		=> sub { if( defined $t) {
		my_die(1, "Error: -t can be specified only once\n");
		} else {$t = $_[1];}},
    'index-items'	=> sub { if( defined $t) {
		my_die(1, "Error: -t can be specified only once\n");
		} else {$t = $_[1];}},
    'start:i'	=> sub { if( defined $start) {
		my_die(1, "Error: --start can be specified only once\n");
		} else {$start = $_[1];}},
);
  
  if($h eq "")
    {$h = "-";}
    
  if($array_name eq "")
    {$array_name = "array";}
  
  if($item_name eq "")
    {$item_name = "item";}
  
  if(!$t and $start > 0)
  {
    my_die(1,"-t must be set if start is in use!\n");
  }
  
  if($r ne "")
  {
    if(!isvalidelement($r))
    {
      my_die(50,"root element is not valid XML element name!\n");
    }
  }
  if(!isvalidelement($array_name))
  {
    my_die(50,"array name is not valid!\n");
  }
  if(!isvalidelement($item_name))
  {
    my_die(50,"array name is not valid!\n");
  }
  
  
  if(@ARGV > 0)
  {
    my_die(1,"invalid arguments!\n");
  }
  
  if($start eq "")
  {
    $start = 1;
  }
  
  $StackCounter = $start;  
}
#------------------ ARGUMENTS ------------------

#-------------------- HELP --------------------
sub help {
    print "Usage: jsn.pl [OPTIONS]\n\n";
    print "options:\n";
    print "--help\t\t\t\tPrint this help.\n";
    print "--input=filename\t\tInput JSON file.\n";
    print "--output=filename\t\tOutput XML file.\n";
    print "-h=subst\t\t\tReplacing substring for invalid input.\n";
    print "-n\t\t\t\tDo not generate XML header.\n";
    print "-r=root-element\t\t\tName of pair element.\n";
    print "--array-name=array-element\tRename array to array-element.\n";
    print "--item-name=item-element\tRename element name.\n";
    print "-s\t\t\t\tTransform strings to elements.\n";
    print "-i\t\t\t\tTransform ints to elements.\n";
    print "-l\t\t\t\tTransform bools to elements.\n";
    print "-c\t\t\t\tConvert \< \> \& \n";
    print "-a, --array-size\t\tAdd size of array to each array element\n";
    print "-t, --index-items\t\tEach array item get index\n";
    print "--start=n\t\t\tIndex start from n\n";
}
#-------------------- HELP --------------------