#!/usr/bin/perl

use strict;
use warnings;

my $paramInputFile = "";		#
my $paramOutputFile = "";		#
my $paramSubstitution = "-";	# Substitution of unallowed characters
my $paramN = 0; 				# Do not generate XML header
my $paramRootElement = "";		# Name of root elementy
my $paramArrayName = "";		#
my $paramItemName = "";			#
my $paramS = 0; 				# Transformace typu string na text elementy
my $paramI = 0; 				# Transformace typu number na text elementy
my $paramL = 0; 				# Transformace literalu na elementy
my $paramC = 0;					#
my $paramArraySize = 0;			#
my $paramIndexItems = 0;		#
my $paramIndexItemsStart = -1;	#

# Parse arguments 
parseArguments(@ARGV);

#############################################################################
# parseArguments()
#############################################################################
sub parseArguments{
	my @argv = @_;
	
	if(@argv == 0){
		printError("Invalid arguments", 1);
	}
	
	my $argvString = join(" ", @argv) . " ";	

	# Help
  	if($argvString =~ /^--help$/){
		printHelp();
	}
	
	# Option --input
	if($argvString =~ /--input/){
		if($argvString =~ s/--input=([\S]*) //){
			$paramInputFile = $1;
			
			printError("Input file does not exists", 1) if (! -f $paramInputFile);		
		}
		else{
			printError("Invalid usage of argument --input", 1);
		}
	}
	
	# Option --output
	if($argvString =~ /--output/){
		if($argvString =~ s/--output=([\S]*) //){
			$paramOutputFile = $1;
			
			printError("Invalid name of output file", 1) if($paramOutputFile eq "");
			printError("Output file is existing directory", 1) if (-d $paramOutputFile);		
		}
		else{
			printError("Invalid usage of argument --output", 1);
		}
	}

	# Option -h=subst
	if($argvString =~ /-h/){
		if($argvString =~ s/-h=([\S]) //){
			$paramSubstitution = $?;
		}
		else{
			printError("Invalid usage of argument -h", 1);
		}
	}
	
	# Option -n
	$paramN = 1 if($argvString =~ s/-n //);
	
	# Option -r=root-element
	if($argvString =~ /-r/){
		if($argvString =~ s/-r=([\S]+) //){
			$paramRootElement = $?;
		}
		else{
			printError("Invalid usage of argument -r", 1);
		}
	}

	# Option --array-name=array-element
	if($argvString =~ /--array-name/){
		if($argvString =~ s/--array-name=([\S]+) //){
			$paramArrayName = $?;
		}
		else{
			printError("Invalid usage of argument --array-name", 1);
		}
	}
	
	# Option --item-name=item-element
	if($argvString =~ /--item-name/){
		if($argvString =~ s/--item-name=([\S]+) //){
			$paramItemName = $?;
		}
		else{
			printError("Invalid usage of argument --item-name", 1);
		}
	}	
	
	
	# Options -s -i -l -c
	$paramS = 1 if($argvString =~ s/-s //);
	$paramI = 1 if($argvString =~ s/-i //);
	$paramL = 1 if($argvString =~ s/-l //);
	$paramC = 1 if($argvString =~ s/-c //);

	# Options -a --array-size
	$paramArraySize = 1 if($argvString =~ s/--array-size //);
	$paramArraySize = 1 if($argvString =~ s/-a //);
	
	# Options -t --index-items
	$paramIndexItems = 1 if($argvString =~ s/--index-items //);
	$paramIndexItems = 1 if($argvString =~ s/-t //);
	
	# Option --start
	if($argvString =~ /--start/){
		if($argvString =~ s/--start=([0-9]+) //){
			$paramIndexItemsStart = $?;
		}
		else{
			printError("Invalid usage of argument --start", 1);
		}
	}
	
	printError("Input file must be specified", 1) if($paramInputFile eq "");
	printError("Output file must be specified", 1) if($paramOutputFile eq "");
	printError("Argument --start needs option Index items enabled", 1) if($paramIndexItemsStart >= 0 && $paramIndexItems == 0);
	printError("Invalid arguments", 1) unless($argvString =~ /^[\ ]*$/);
	
	if($paramIndexItemsStart < 0){
		$paramIndexItemsStart = 1;
	}
}
# /parseArguments()

#############################################################################
# printHelp()
#############################################################################
sub printHelp{
	print "Program json2xml\n\n";
	
	print "Usage:\n";
	print "\tjsn.pl --help\n";
	print "\tjsn.pl --input=file --output=file [OPTIONS]\n";
	print "Options:\n";
	print "\t-n\t\tNot generate XML header\n";
 	print "\t-s\t\tTransform strings to element\n";
 	print "\t-i\t\tTransform numbers to element\n";
 	print "\t-l\t\tTransform literals to element\n";
 	print "\t-r=root-element\tSet name of root element\n";
 	print "\t-h=subst\tSet substitution of unallowed characters\n";

	exit 0;
}
# /PrintHelp()

# printError()
sub printError{
	if(@_ > 0){
		print "$_[0]\n";
	
		if(@_ == 2){
			exit $_[1];
		}
		else{
			exit 100;
		}
	}
}
# /printError()
