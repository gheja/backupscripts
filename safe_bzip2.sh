#!/bin/bash

# http://github.com/gheja/backupscripts

if [ $# != 2 ]; then
	echo "Usage: $0 <file or directory> <output filename>"
	exit 1
fi

file=$1
output=$2
tmp=$output.tmp

echo "$file" | grep -Eq '^/$'
if [ $? == 0 ]; then
	echo "Cannot operate on / - exiting."
	exit 2
fi

echo "$file" | grep -Eq '(/\.\.|\.\./)'
if [ $? == 0 ]; then
	echo "Cannot operate on .. - exiting."
	exit 3
fi

if [ ! -e "$file" ]; then
	echo "Input file/directory ($file) does not exist - exiting."
	exit 4
fi

if [ -e "$output" ]; then
	echo "Output file ($output) exists - exiting."
	exit 5
fi

if [ -e "$tmp" ]; then
	echo "Temp file ($tmp) exists - exiting."
	exit 6
fi

echo -n "Creating $output ... "

md5sum_orig=`tar -c --numeric-owner $file | md5sum | awk '{ print $1; }'`
tar -c --numeric-owner $file | bzip2 -c9 > $tmp

result=$?
if [ $result != 0 ]; then
	echo "Bzip2 returned an error - exiting."
	rm $tmp
	exit 7
fi

md5sum_bzip2=`cat $tmp | bzip2 -d | md5sum | awk '{ print $1; }'`

if [ "$md5sum_bzip2" != "$md5sum_orig" ]; then
	echo "Bzip2'd checksum differs from original - exiting."
	rm $tmp
	exit 8
fi

md5sum_after=`tar -c --numeric-owner $file | md5sum | awk '{ print $1; }'`
if [ "$md5sum_after" != "$md5sum_orig" ]; then
	echo "Files changed while we read them - exiting."
	rm $tmp
	exit 9
fi

mv $tmp $output

echo "Done."

exit 0
