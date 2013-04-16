#!/usr/bin/env python3

#XTD:xkolac12

import argparse, sys, xml.etree.ElementTree as xmlParser, xml.dom.minidom as minidom, re
from pprint import pprint

#
def printError(errorMessage, errorCode):
	print(errorMessage, file=sys.stderr)
	exit(errorCode)

#
def typeOf(data, isAttribute = False):
	if re.match("^[0|1]$", data) or re.match("^True$", data) or re.match("^False$", data):
	#if re.match("^(True|False)$", data) or re.match("^[0|1]$", data):
		return "BIT"
	#elif re.match("[^[0-9]+$]", data):
	elif re.match("^\d+$", data):
		return "INT"
	#elif re.match("^[0-9]+\.[0-9]+$", data) or re.match("^[0-9]+e[+|-][0-9]+$", data) or re.match("^[0-9]+\.[0-9]+e[+|-][0-9]+$", data):
	elif re.match("^\d+\.\d+$", data) or re.match("^\d+e[+|-|]\d+$", data) or re.match("^\d+\.\d+e[+|-|]\d+$", data):
		return "FLOAT"
	# String
	else:
		return "NVARCHAR" if isAttribute else "NTEXT"

#
def typeWeightOf(dataType):	
	if dataType == "BIT":
		return 0
	elif dataType == "INT":
		return 1
	elif dataType == "FLOAT":
		return 2
	elif dataType == "NVARCHAR":
		return 3
	else:
		return 4 # NTEXT

#	
def typeCompare(data, dataType, isAttribute = False):
	tmp = typeOf(data, isAttribute)
	
	first = typeWeightOf(tmp)
	second = typeWeightOf(dataType)
	
	return tmp if first > second else dataType
	
#
def isRelation(field, table, tableRelation):
	
	for relationTo, relationType in field:
		if relationTo == table and relationType == tableRelation:
			return True # There is relation
			
	return False # There is no relation

#
def processXML(node, data, relations, args):
	
	for element in node.getchildren():
		elementName = element.tag.lower()
		elementText = element.text.strip() if element.text else None
		
		#
		if elementName not in data.keys():
			data[elementName] = { "PRK_" + elementName + "_ID": "INT PRIMARY KEY" }
	
		# Find out type
		if elementText:
			if "value" in data[elementName].keys():
				data[elementName]["value"] = typeCompare(elementText, data[elementName]["value"])
			else:
				data[elementName]["value"] = typeOf(elementText)
		
		# Generate columns from attributes
		if not args.a and element.attrib:
			for key in element.attrib.keys():
				if key in data[elementName].keys():
					data[elementName][key.lower()] = typeCompare(element.attrib[key], data[elementName][key.lower()], True)
				else:
					data[elementName][key.lower()] = typeOf(element.attrib[key], True)
	
		counter = {}
		
		for children in element.getchildren():
			childrenName = children.tag.lower()			
			
			if childrenName not in counter.keys():
				counter[childrenName] = 1
			else:
				counter[childrenName] += 1
				
		for keys in counter.keys():
			if not args.etc or counter[keys] <= int(args.etc):
				if args.b or counter[keys] == 1:
					data[elementName][keys.lower() + "_ID"] = "INT"
				else:
					while counter[keys] > 0:
						data[elementName][keys.lower() + str(counter[keys]) + "_ID"] = "INT"
						counter[keys] -= 1
			else:
				for match in element.findall(keys):
					if match.tag.lower() not in data.keys():
						data[match.tag.lower()] = { "PRK_" + match.tag.lower() + "_ID" : "INT PRIMARY KEY" }
						
					data[match.tag.lower()][elementName + "_ID"] = "INT"	
		
		return processXML(element, data, relations, args)
		
	return data

#
def printDDL(data, handler):
	
	for table in data.keys():
		handler.write("CREATE TABLE " + table + "(\n")
		
		columns = len(data[table])
		for column in data[table].keys():
			if columns == 1:
				handler.write("\t" + column + " " + data[table][column] + "\n")
			else:
				handler.write("\t" + column + " " + data[table][column] + ",\n")
				
			columns -= 1
		
		handler.write(");\n\n")	

#
def printXML(relations, handler):
	
	for table in relations.keys():
		for relationTo, relationType in relations[table]:			
			# Symetric relation
			if not isRelation(relations[relationTo], table, relationType[::-1]):
				relations[relationTo].append([table, relationType[::-1]])
			
			# Transitive relations
			for tranRelationTo, tranRelationType in relations[relationTo]:
				if isRelation(relations[table], relationTo, "N:1"):
					if isRelation(relations[relationTo], tranRelationTo, "N:1"):
						# Create transitive relation
						if not isRelation(relations[table], tranRelationTo, "N:1"):
							relations[table].append([tranRelationTo, "N:1"])
							
						# Create symetric relation
						if not isRelation(relations[tranRelationTo], table, "1:N"):
							relations[tranRelationTo].append([table, "1:N"])
					
				if isRelation(relations[table], relationTo, "1:N"):
					if isRelation(relations[relationTo], tranRelationTo, "1:N"):
						# Create transitive relation
						if not isRelation(relations[table], tranRelationTo, "1:N"):
							relations[table].append([tranRelationTo, "1:N"])
						
						# Create symetric relation
						if not isRelation(relations[tranRelationTo], table, "N:1"):
							relations[tranRelationTo].append([table, "N:1"])
							
	for table in relations.keys():
		for relationTo, relationType in relations[table]:		
			if isRelation(relations[table], relationTo, "1:N") and isRelation(relations[table], relationTo, "N:1"):
				# Cleaning relations
				relations[relationTo].remove([table, "N:1"])
				relations[relationTo].remove([table, "1:N"])				
				relations[table].remove([relationTo, "1:N"])
				relations[table].remove([relationTo, "N:1"])
				
				#
				relations[relationTo].append([table, "N:M"])
				relations[table].append([relationTo, "N:M"])
				
			for tranRelationTo, tranRelationType in relations[relationTo]:
				if table == tranRelationTo:
					continue
				
				if isRelation(relations[table], relationTo, "N:1"):
					# N-1-N
					if isRelation(relations[relationTo], tranRelationTo, "1:N"):
						if isRelation(relations[table], tranRelationTo, "1:N"):
							continue
						
						if isRelation(relations[table], tranRelationTo, "N:1"):
							continue
						
						# Added relation
						if not isRelation(relations[table], tranRelationTo, "N:M"):
							relations[table].append([tranRelationTo, "N:M"])
						
						# Added symetric relation
						if not isRelation(relations[tranRelationTo], table, "N:M"):
							relations[tranRelationTo].append([table, "N:M"])
							
				if isRelation(relations[table], relationTo, "1:N"):
					# 1-N-1
					if isRelation(relations[relationTo], tranRelationTo, "N:1"):
						if isRelation(relations[table], tranRelationTo, "1:N"):
							continue
						
						if isRelation(relations[table], tranRelationTo, "N:1"):
							continue
						
						# Added relation
						if not isRelation(relations[table], tranRelationTo, "N:M"):
							relations[table].append([tranRelationTo, "N:M"])
						
						# Added symetric relation
						if not isRelation(relations[tranRelationTo], table, "N:M"):
							relations[tranRelationTo].append([table, "N:M"])
							
	root = xmlParser.Element("tables")
	
	for table in relations.keys():
		tableTree = xmlParser.SubElement(root, "table", attrib={"name" : table})
		
		for relationTo, relationType in relations[table]:
			xmlParser.SubElement(tableTree, "relation", attrib = {"to" : relationTo, "relation_type" : relationType})
			
		handler.write((minidom.parseString(xmlParser.tostring(root))).toprettyxml())		

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
	printError("Parameters --etc and -b can not be defined at the same time", 1)

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
	

xmlDataRoot = xmlData.getroot()

relations = {}
data = {}

processXML(xmlDataRoot, data, relations, args)

#pprint(data)

if args.g:
	printXML(relations, outputFile)
else:
	printDDL(data, outputFile)

# Close input file
if inputFile:
	inputFile.close()

# Close output file
if outputFile:
	outputFile.close()

exit(0)
	