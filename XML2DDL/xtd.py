#!/usr/bin/env python3

#XTD:xkolac12

import argparse, sys, xml.etree.ElementTree as xmlParser

#
def printError(errorMessage, errorCode):
	print(errorMessage, file=sys.stderr)
	exit(errorCode)

#---------------------------------------------
# Main
#---------------------------------------------

# Create instance of arg parser
parser = argparse.ArgumentParser(description="XML2DDL - xkolac12@stud.fit.vutbr.cz", add_help=False)
parser.add_argument("--input", action="store", dest="input", help="Set input file")
parser.add_argument("--output", action="store", dest="output", help="Set output file")
parser.add_argument("--header", action="store", dest="header", help="Set custom header")
parser.add_argument("--etc", action="store", dest="etc", help="Set max column count")
parser.add_argument("--help", "-h", action="store_true", dest="help", help="Show this help", default=False)
parser.add_argument("-a", action="store_true", dest="a", help="")
parser.add_argument("-b", action="store_true", dest="b", help="")
parser.add_argument("-g", action="store_true", dest="g", help="")

# Check count of arguments
if len(sys.argv) == 1:
	printError("Invalid arguments", 1)

# Try to parse arguments
try:
	args = parser.parse_args()
except:
	printError("Invalid arguments", 1)
	
# Print help
if args.help:
	if len(sys.argv) != 2:
		printError("Help cannot be combinated", 100)
	
	parser.print_help()
	exit(0)
	
# Check invalid combination
if args.etc and args.b:
	print("Cannot combinate -b and --etc", 1)

# Opening input file
try:
	if args.input:
		inputFile = open(args.input, "rt", encoding="utf-8")
	else:
		inputFile = sys.stdin
except:
	printError("Cannot open input file", 2)
	
# Opening output file
try:
	if args.output:
		outputFile = open(args.output, "wt", encoding="utf-8")
	else:
		outputFile = sys.stdout
except:
	printError("Cannot open output file", 3)

# Try to parse input data
try:
	xmlData = xmlParser.parse(inputFile)
except:
	printError("Invalid XML in input file", 4)

# --header argument
if args.header:
	outputFile.write("--" + args.header + "\n\n")

# Close input file
if inputFile:
	inputFile.close()

# Close output file
if outputFile:
	outputFile.close()

exit(0)
	