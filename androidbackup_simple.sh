#!/bin/bash

# http://github.com/gheja/backupscripts

archiver_script="./archive_files.sh"

dry_run="no"
verbose="no"

while [ "$1" != "" ]; do
	case "$1" in
		--dry-run|-n)
			dry_run="yes"
		;;
		
		--verbose|-v)
			verbose="yes"
		;;
		
		*)
			echo "Unknown option \"$1\", exiting." >&2
			exit 1
		;;
	esac
	shift
done

source_root="/mnt/sdb1"
target_root="/mnt/nas0/milestone2"
archive_root="$source_root/archived"

# sudo mount ...

extra=""

[ "$dry_run" == "yes" ] && extra="$extra --dry-run"
[ "$verbose" == "yes" ] && extra="$extra --verbose"

$archiver_script $extra \
	--source $source_root/DCIM/Camera \
	--target $target_root/camera \
	--archive $archive_root/camera

$archiver_script $extra \
	--source $source_root/bluetooth \
	--target $target_root/bluetooth \
	--archive $archive_root/bluetooth

$archiver_script $extra \
	--source $source_root/Pictures/Screenshots \
	--target $target_root/screenshots \
	--archive $archive_root/screenshots

$archiver_script $extra \
	--source "$source_root/Draw Something" \
	--target $target_root/draw_something \
	--archive $archive_root/draw_something

# sudo umount ...
