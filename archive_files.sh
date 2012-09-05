#!/bin/bash

# http://github.com/gheja/backupscripts

original_parameters="$@"

archive="no"
verbose="no"
dry_run="no"
exif_ok="no"
timestamps="yes"

_help()
{
	echo "archive_files.sh -- http://github.com/gheja/backupscripts"
	echo ""
	echo "Valid options and switches:"
	echo "  -s, --source DIR     required, set DIR as the source directory"
	echo "  -t, --target DIR     required, set DIR as the target directory (files will be copied here)"
	echo "  -a, --archive DIR    move files after backup to this directory"
	echo "  -n, --dry-run        do not do any real work"
	echo "  -T, --no-timestamps  do not put \"Ymd_HMS_\" in target file names"
	echo "  -v, --verbose        be verbose (for debugging)"
	echo "  -h, --help           this text"
	echo ""
	echo "Usage examples:"
	echo "  archive_files.sh --source /mnt/sdb1/DCIM/Camera --target /home/user/backup/camera --verbose"
	echo "  archive_files.sh -s /mnt/sdb1/images -t /home/user/images -a /mnt/sdb1/images_archived"
	echo ""
	echo "TODO: write some helpful help..."
}

while [ "$1" != "" ]; do
	case "$1" in
		--no-timestamps|-T)
			timestamps="no"
		;;
		
		--source|-s)
			shift
			source_dir="$1"
		;;
		
		--target|-t)
			shift
			target_dir="$1"
		;;
		
		--archive|-a)
			shift
			archive="yes"
			archive_dir="$1"
		;;
		
		--dry-run|-n)
			dry_run="yes"
		;;
		
		--verbose|-v)
			verbose="yes"
		;;
		
		--help|-h)
			_help
			exit 0
		;;
		
		*)
			echo "Unknown parameter \"$1\"." >&2
			_help
			exit 1
		;;
	esac
	shift
done

if [ "$source_dir" == "" ]; then
	echo "ERROR: Source dir not supplied, use --source /path/to/source"
	echo ""
	_help
	exit 1
fi

if [ "$target_dir" == "" ]; then
	echo "ERROR: Target dir not supplied, use --target /path/to/target"
	echo ""
	_help
	exit 1
fi

exif=`which exif 2>/dev/null`
if [ "$exif" != "" ]; then
	exif_ok="yes"
fi

if [ "$verbose" == "yes" ]; then
	echo "archive_files.sh"
	echo "  Command line: $0 $original_parameters"
	echo "  Source dir: $source_dir"
	echo "  Target dir: $target_dir"
	echo "  Archiving files: $archive"
	echo "  Archive dir: $archive_dir"
	echo "  Dry run: $dry_run"
	echo "  EXIF supported on OS: $exif_ok"
fi

echo "$source_dir" | grep -q ' '
if [ $? == 0 ]; then
	echo "Source directory name contains spaces - this is not supported at the moment!"
# 	exit 2
fi

ls -1 "$source_dir"/* | grep -q ' '
if [ $? == 0 ]; then
	echo "Source filenames contain spaces - this is not supported at the moment!"
# 	exit 2
fi

IFS_OLD="$IFS"
IFS="
"

ls -1 "$source_dir"/* | while read file; do
	IFS="$IFS_OLD"
	
	time_found="no"
	
	source_basename=`basename "$file"`
	
	if [ "$verbose" == "yes" ]; then
		echo -n "$source_basename... "
	else
		echo "$source_basename"
	fi
	
	# find out time of capture from EXIF (if available)
	if [ "$exif_ok" == "yes" ]; then
		time_tag=`$exif -t 0x9003 "$file" 2>/dev/null | grep 'Value: ' | awk '{ print $2, $3; }' | sed -e 's/:/ /g'`
		echo "$time_tag" | grep -Eq '^[0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}'
		if [ $? == 0 ]; then
			time_found="yes"
			[ "$verbose" == "yes" ] && echo -n "EXIF: "
		fi
	fi
	
	# fall back to file modification time (if could not be found in EXIF)
	if [ "$time_found" == "no" ]; then
		time_tag=`stat --format %y "$file" 2>/dev/null | cut -d . -f 1 | sed -e 's/\-/ /g' -e 's/:/ /g'`
		[ "$verbose" == "yes" ] && echo -n "stat: "
	fi
	
	# parse the date and time
	year=`echo "$time_tag" | awk '{ print $1; }'`
	month=`echo "$time_tag" | awk '{ print $2; }'`
	day=`echo "$time_tag" | awk '{ print $3; }'`
	hour=`echo "$time_tag" | awk '{ print $4; }'`
	minute=`echo "$time_tag" | awk '{ print $5; }'`
	second=`echo "$time_tag" | awk '{ print $6; }'`
	
	[ "$verbose" == "yes" ] && echo -n "$year-$month-$day $hour:$minute:$second "
	
	if [ "$timestamps" == "yes" ]; then
		target_x="${year}${month}${day}_${hour}${minute}${second}_${source_basename}"
	else
		target_x="${source_basename}"
	fi
	
	target_file="$target_dir/$target_x"
	
	[ "$verbose" == "yes" ] && echo -n "-> $target_x... "
	
	# create base directory (if it does not exist)
	target_basedir=`dirname "$target_file"`
	if [ ! -d "$target_basedir" ]; then
		[ "$verbose" == "yes" ] && echo -n "creating target dir... "
		if [ "$dry_run" != "yes" ]; then
			mkdir -p "$target_basedir"
			if [ $? != 0 ]; then
				echo "creating the target dir failed, exiting."
				exit 3
			fi
		fi
	fi
	
	# copy file
	if [ "$dry_run" != "yes" ]; then
		cp -a "$file" "$target_file"
		if [ $? != 0 ]; then
			echo "copy failed, exiting."
			exit 4
		fi
		
		# check the copied file
		source_md5=`md5sum "$file" | awk '{ print $1; }'`
		target_md5=`md5sum "$target_file" | awk '{ print $1; }'`
		if [ "$source_md5" != "$target_md5" ]; then
			echo "checksum missmatch, removing target file and exiting."
			rm "$target_file"
			exit 5
		fi
	fi
	
	[ "$verbose" == "yes" ] && echo -n "copied... "
	
	# move the file to archive directory (if enabled)
	if [ "$archive" == "yes" ]; then
		archive_file="$archive_dir/${source_basename}"
		basedir=`dirname "$archive_file"`
		if [ ! -d "$basedir" ]; then
			[ "$verbose" == "yes" ] && echo -n "creating archive dir... "
			if [ "$dry_run" != "yes" ]; then
				mkdir -p "$basedir"
				if [ $? != 0 ]; then
					echo "creating the archive directory failed, exiting."
					exit 7
				fi
			fi
		fi
		
		if [ -e "$archive_file" ]; then
			echo "archive file exists, exiting."
			exit 8
		fi
		
		if [ "$dry_run" != "yes" ]; then
			mv "$file" "$archive_file"
			if [ $? != 0 ]; then
				echo "moving the file failed, exiting."
				exit 9
			fi
		fi
		
		[ "$verbose" == "yes" ] && echo -n "moved... "
	else
		# delete the file
		if [ "$dry_run" != "yes" ]; then
			rm "$file"
			if [ $? != 0 ]; then
				echo "deletion failed, exiting."
				exit 10
			fi
			[ "$verbose" == "yes" ] && echo -n "deleted... "
		fi
	fi
	
	[ "$verbose" == "yes" ] && echo "done."
done
