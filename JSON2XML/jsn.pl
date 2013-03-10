#!/usr/bin/perl

#JSN:xkolac12

use strict;
use warnings;
use utf8;
use encoding 'utf-8';

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# Imported modules
use Data::Dumper;
use JSON::XS;
use IO::File;
use XML::Writer;

my $paramInputFile = "-";		#
my $paramOutputFile = "-";		#
my $paramSubstitution = "-";	# Substitution of unallowed characters
my $paramN = 0; 				# Do not generate XML header
my $paramRootElement = "";		# Name of root elementy
my $paramArrayName = "array";	#
my $paramItemName = "item";		#
my $paramS = 0; 				# Transformace typu string na text elementy
my $paramI = 0; 				# Transformace typu number na text elementy
my $paramL = 0; 				# Transformace literalu na elementy
my $paramC = 0;					#
my $paramArraySize = 0;			#
my $paramIndexItems = 0;		#
my $paramIndexItemsStart = -1;	#

# Create instance of IO::File
my $fileHandler = new IO::File();
# Create instance of JSON parser
my $jsonParser = new JSON::XS();
# Global instance of XML Writer
my $XML;

my @Stack;
my $StackCounter;

#############################################################################
# Main
#############################################################################

	# Parse arguments 
	parseArguments(@ARGV);
	
	local $/ = undef;
	
	# Open input file
	$fileHandler->open("< $paramInputFile") or printError("Cannot open input file", 2);
	
	# Read input file to buffer
	my $jsonDataRaw = <$fileHandler>;
	
	# Close input file
	$fileHandler->close();
	
	my $jsonData;
	
	# Simulate try catch block
	eval{	
		# Parse JSON file
		$jsonData = $jsonParser->utf8(0)->decode($jsonDataRaw);
	};
	# Catch
	if($@){
		printError("Invalid format of input data", 4);
	}
	
	# 
	#printError("Invalid format of input data", 4) if(ref $jsonData eq "ARRAY");
	
	# Free JSON parser & input buffer
	undef $jsonParser;
	undef $jsonDataRaw;	

	# This function does that dirty job
	createXML($jsonData, $paramOutputFile);
	
	exit 0;
# /Main

#############################################################################
# parseArguments()
#############################################################################
sub parseArguments{
	my @argv = @_;
	my $argvString = join(" ", @argv) . " ";	

	# Help
  	if($argvString =~ /^--help $/){
		printHelp();
	}
	
	# Option --input
	if($argvString =~ /--input/){
		printError("Multiple definition of --input", 1) if(substrCount($argvString, "--input") > 1);
	
		if($argvString =~ s/--input=([\S]*) //){
			$paramInputFile = $1;
			
			printError("Input file does not exists", 2) if (! -f $paramInputFile);		
		}
		else{
			printError("Invalid usage of argument --input", 1);
		}
	}
	
	# Option --output
	if($argvString =~ /--output/){
		printError("Multiple definition of --output", 1) if(substrCount($argvString, "--output") > 1);
	
		if($argvString =~ s/--output=([\S]*) //){
			$paramOutputFile = $1;
			
			printError("Invalid name of output file", 1) if($paramOutputFile eq "");
			printError("Output file is existing directory", 3) if (-d $paramOutputFile);		
		}
		else{
			printError("Invalid usage of argument --output", 1);
		}
	}

	# Option -h=subst
	if($argvString =~ /-h/){
		printError("Multiple definition of -h", 1) if(substrCount($argvString, "-h ") > 1);
	
		if($argvString =~ s/-h=([\S]) //){
			$paramSubstitution = $1;
		}
		else{
			printError("Invalid usage of argument -h", 1);
		}
	}
	
	# Option -n
	printError("Multiple definition of -n", 1) if(substrCount($argvString, "-n ") > 1);
	$paramN = 1 if($argvString =~ s/-n //);
	
	# Option -r=root-element
	if($argvString =~ /-r/){
		printError("Multiple definition of -r", 1) if(substrCount($argvString, "-r ") > 1);
		
		if($argvString =~ s/-r=([\S]+) //){
			$paramRootElement = $1;
			
			printError("Unallowed characters in root element", 50) unless isValidTagName($paramRootElement);
		}
		else{
			printError("Invalid usage of argument -r", 1);
		}
	}

	# Option --array-name=array-element
	if($argvString =~ /--array-name/){
		printError("Multiple definition of --array-name", 1) if(substrCount($argvString, "--array-name") > 1);
	
		if($argvString =~ s/--array-name=([\S]+) //){
			$paramArrayName = $1;
			
			printError("Unallowed characters in array name", 50) unless isValidTagName($paramArrayName);
		}
		else{
			printError("Invalid usage of argument --array-name", 1);
		}
	}
	
	# Option --item-name=item-element
	if($argvString =~ /--item-name/){
		printError("Multiple definition of --item-name", 1) if(substrCount($argvString, "--item-name") > 1);
	
		if($argvString =~ s/--item-name=([\S]+) //){
			$paramItemName = $1;
			
			printError("Unallowed characters in item name", 50) unless isValidTagName($paramItemName);
		}
		else{
			printError("Invalid usage of argument --item-name", 1);
		}
	}	
	
	# Options -s -i -l -c
	printError("Multiple definition of -s", 1) if(substrCount($argvString, "-s ") > 1);
	$paramS = 1 if($argvString =~ s/-s //);
	printError("Multiple definition of -i", 1) if(substrCount($argvString, "-i ") > 1);
	$paramI = 1 if($argvString =~ s/-i //);
	printError("Multiple definition of -l", 1) if(substrCount($argvString, "-l ") > 1);
	$paramL = 1 if($argvString =~ s/-l //);
	printError("Multiple definition of -c", 1) if(substrCount($argvString, "-c ") > 1);
	$paramC = 1 if($argvString =~ s/-c //);

	# Options -a --array-size
	printError("Multiple definition of --array-size / -a", 1) if(substrCount($argvString, "--array-size") + substrCount($argvString, "-a ") > 1);
	$paramArraySize = 1 if($argvString =~ s/--array-size //);
	$paramArraySize = 1 if($argvString =~ s/-a //);
	
	# Options -t --index-items
	printError("Multiple definition of --index-items / -t", 1) if(substrCount($argvString, "--index-items") + substrCount($argvString, "-t ") > 1);
	$paramIndexItems = 1 if($argvString =~ s/--index-items //);
	$paramIndexItems = 1 if($argvString =~ s/-t //);
	
	# Option --start
	if($argvString =~ /--start/){
		printError("Multiple definition of --start", 1) if(substrCount($argvString, "--start") > 1);
		if($argvString =~ s/--start=([0-9]+) //){
			$paramIndexItemsStart = $1;
		}
		else{
			printError("Invalid usage of argument --start", 1);
		}
	}
	
	#printError("Input file must be specified", 1) if($paramInputFile eq "");
	#printError("Output file must be specified", 1) if($paramOutputFile eq "");
	printError("Argument --start needs option Index items enabled", 1) if($paramIndexItemsStart >= 0 && $paramIndexItems == 0);
	printError("Invalid arguments", 1) unless($argvString =~ /^[\ ]*$/);
	
	if($paramIndexItemsStart < 0){
		$paramIndexItemsStart = 1;
	}
}
# /parseArguments()

#############################################################################
# createXML(jsonData, outputFile)
#############################################################################
sub createXML{
	my $data = $_[0];
	my $outputFile = $_[1];
	
	# Open output file
	$fileHandler->open("> $outputFile") or printError("Cannot open output file", 3);
	
	binmode $fileHandler, ":encoding(utf8)";
	
	# Create instance of XML Writer
	# ,,Error reporting can be turned off by providing an UNSAFE parameter"
	$XML = new XML::Writer(OUTPUT => $fileHandler, UNSAFE => 1);

	$XML->xmlDecl("UTF-8") unless $paramN;
	$XML->startTag($paramRootElement) unless $paramRootElement eq "";
	
	# Setup global counter
	$StackCounter = $paramIndexItemsStart;

	#print Dumper $data;
	processJSON($data);

	
	$XML->endTag($paramRootElement) unless $paramRootElement eq "";
	
	# Close XML Writer
	$XML->end();
	
	undef $XML;
	
	# Close output file
	$fileHandler->close();
}
# /createXML()

sub processJSON{
	my $json = $_[0];

	# Array
	if(ref $json eq 'ARRAY'){
		# Array size
		if($paramArraySize){
			$XML->startTag($paramArrayName, "size" => scalar(@$json));
		}
		else{
			$XML->startTag($paramArrayName);
		}	
		
		push (@Stack, $StackCounter);
		
		$StackCounter = $paramIndexItemsStart;
		
		foreach(@$json){
			
			if(ref $_ eq "" or ref $_ eq "JSON::XS::Boolean"){
				processData($paramItemName, $_);
			}
			else{
				if($paramIndexItems){
					$XML->startTag($paramItemName, "index" => $StackCounter);
				}
				else{
					$XML->startTag($paramItemName);
				}
				
				$StackCounter++;						
				
				processJSON($_);
				
				$XML->endTag($paramItemName);
			}			
		}
		
		$StackCounter = pop @Stack;
		
		$XML->endTag($paramArrayName);
		return;
	}
	else{
		while(my($key, $val) = each(%$json)){
			# Hash
			if(ref $val eq 'HASH'){
				$XML->startTag($key);
				
				processJSON($val);
				
				$XML->endTag($key);
			}
			# Array
			elsif(ref $val eq 'ARRAY'){
				# Array size
				if($paramArraySize){
					$XML->startTag($key, "size" => scalar(@$val));
				}
				else{
					$XML->startTag($key);
				}				

				processJSON($val);
				
				$XML->endTag($key);
			}
			# Value
			else{
				processData($key, $val);
			}
		}
	}
}

sub processData{
	my $key = $_[0];
	my $val = $_[1];
	
	$key =~ s/[\&\<\>\"\/]/$paramSubstitution/g;
	
	printError("Invalid tag name after replace", 51) unless isValidTagName($key);
	
	# Null
	unless(defined $val){
		if($paramL){
			$XML->startTag($key);
			$XML->emptyTag("null");
			$XML->endTag($key);
		}
		else{
			$XML->emptyTag($key, "value" => (($val)? $val : "null"));
		}		
	}	
	# Bool
	elsif(ref $val eq 'JSON::XS::Boolean'){
		if($paramL){
			$XML->startTag($key);
			$XML->emptyTag($val ? "true" : "false");
			$XML->endTag($key);
		}
		else{
			$XML->emptyTag($key, "value" => (($val)? "true" : "false"));
		}
	}
	# Number
	elsif($val =~ /[\d]+/){
		if($paramI){
			$XML->startTag($key);
			$XML->characters($val);
			$XML->endTag($key);			
		}
		else{
			$XML->emptyTag($key, "value" => $val);
		}
	}
	# String
	else{
		# Encode
		if($paramC){
			if($paramS){
				$XML->startTag($key);
				$XML->characters($val);
				$XML->endTag($key);
			}
			else{
				$XML->emptyTag($key, "value" => $val);
			}
		}
		# Raw
		else{
			if($paramS){
				$XML->startTag($key);
				$XML->raw($val);
				$XML->endTag($key);
			}
			else{
				$XML->raw("<". $key. " value=\"");
				$XML->raw($val);
				$XML->raw("\" />");
			}
		}
	}
}

sub isValidTagName{
	# \A - Match only at beginning of string
	# \S - non white space
	# \w - Match a "word" character (alphanumeric plus "_")
	#print $_[0].": ".(($_[0] =~ /\A(?!xml)[\p{L}][\p{L}\d\_\-]*$/i)? 1 : 0)."\n";
	return ($_[0] =~ /\A(?!xml)[\p{L}\_\:][\p{L}\d\_\-\.\:]*$/i)? 1 : 0;

	#return ($_[0] =~ /\A(?!XML)[\p{Letter}][\p{Letter}0-9-]*/i)? 1 : 0;
	#return ($_[0] =~ /^_?(?!(xml|[_\d\W]))([\w.-]+)$/)? 1 : 0;
}

sub substrCount(){
	my @count = $_[0] =~ /$_[1]/g;
	return scalar @count;
}

#############################################################################
# printHelp()
#############################################################################
sub printHelp{
	print "Program json2xml\n\n";
	
	print "Usage:\n";
	print "\tjsn.pl --help\n";
	print "\tjsn.pl --input=file --output=file [OPTIONS]\n";
	print "Options:\n";
 	print "\t-n\t\t\tDisable generating XML header\n";
 	print "\t-s\t\t\tTransform strings to element\n";
 	print "\t-i\t\t\tTransform numbers to element\n";
 	print "\t-l\t\t\tTransform literals to element\n";
 	print "\t-c\t\t\tK\n";
 	print "\t-r=<root-element>\tSet name of root element\n";
 	print "\t-h=<subst>\t\tSet substitution of unallowed characters\n";
 	print "\t--array-name=<element>\tK\n";
 	print "\t--item-name=<element>\tK\n";
 	print "\t--array-size / -a\tK\n";
 	print "\t--index-items\t\tK\n";
 	print "\t--start=<number>\tK\n";
 	print "Author:\n";
 	print "\txkolac12 <xkolac12\@stud.fit.vutbr.cz>\n";

	exit 0;
}
# /PrintHelp()

#############################################################################
# printError()
#############################################################################
sub printError{
	my @argv = @_;
	
	if(@argv > 0){
		print STDERR "[!] $argv[0]\n";
		
		exit ((@argv == 2)? $argv[1] : 255);
	}
	
	exit 255;
}
# /printError()
