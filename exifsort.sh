#!/bin/bash
#
#
# The following are the only settings you should need to change:
#
# TS_AS_FILENAME: This can help eliminate duplicate images during sorting.
# TRUE: File will be renamed to timestamp ( %Y-%m-%d_%H:%M:%S )and its extension.
# FALSE (any non-TRUE value): Filename is unchanged.
TS_AS_FILENAME=TRUE
# 
# PRESERVE_ORIGINAL_FILENAME: If this is TRUE, the original filename will be added after 
# the timestamp.
PRESERVE_ORIGINAL_FILENAME=TRUE
#
# DIRFORMAT: Directory name format (as used in the date command) used in the file move 
DIRFORMAT="+%Y/%m/%Y%m%d"
#
# USE_LMDATE: If this is TRUE, images without EXIF data will have their Last Modified file
# timestamp used as a fallback. If FALSE, images without EXIF data are put in noexif/ for
# manual sorting.
# Valid options are "TRUE" or anything else (assumes FALSE). FIXME: Restrict to TRUE/FALSE
USE_LMDATE=FALSE
#
# USE_FILE_EXT: The following option is here as a compatibility option as well as a bugfix.
# If this is set to TRUE, files are identified using FILE's magic, and the extension
# is set accordingly. If FALSE (or any other value), file extension is left as-is.
# CAUTION: If set to TRUE, extensions may be changed to values you do not expect.
# See the manual page for file(1) to understand how this works.
# NOTE: This option is only honored if TS_AS_FILENAME is TRUE.
USE_FILE_EXT=TRUE
#
# JPEG_TO_JPG: The following option is here for personal preference. If TRUE, this will
# cause .jpg to be used instead of .jpeg as the file extension. If FALSE (or any other
# value) .jpeg is used instead. This is only used if USE_FILE_EXT is TRUE and used.
JPEG_TO_JPG=TRUE
#
#
# The following is an array of filetypes that we intend to locate using find.
# Any graphicsmagick-supported filetype can be used, but EXIF data is only present in
# jpeg and tiff. Script will optionally use the last-modified time for sorting (see above)
# Extensions are matched case-insensitive. *.jpg is treated the same as *.JPG, etc.
# Can handle any file type; not just EXIF-enabled file types. See USE_LMDATE above.
#
FILETYPES=("*.jpg" "*.jpeg" "*.png" "*.tif" "*.tiff" "*.gif" "*.xcf")
#
# Optional: Prefix of new top-level directory to move sorted photos to.
# if you use MOVETO, it MUST have a trailing slash! Can be a relative pathspec, but an
# absolute pathspec is recommended.
# FIXME: Gracefully handle unavailable destinations, non-trailing slash, etc.
#
MOVETO=""
#
# Use this as filename for a directory protection marker
# If this file is present, we skip the directory and don't process the files in it
PROTECTED_DIR_MARKER=".exifsort_dont_delete_this"
#
# The following option decides whether to honour the PROTECTED_DIR_MARKER or not
USE_PROTECTED_DIR_MARKER=TRUE
#
###############################################################################
# End of settings. If you feel the need to modify anything below here, please share
# your edits at the URL above so that improvements can be made to the script. Thanks!
#
#
# Assume find, grep, stat, awk, sed, tr, etc.. are already here, valid, and working.
# This may be an issue for environments which use gawk instead of awk, etc.
# Please report your environment and adjustments at the URL above.
#
###############################################################################
# Nested execution (action) call
# This is invoked when the programs calls itself with
# $1 = "doAction"
# $2 = <file to handle>
# This is NOT expected to be run by the user in this matter, but can be for single image
# sorting. Minor output issue when run in this manner. Related to find -print0 below.
#
# Are we supposed to run an action? If not, skip this entire section.
if [[ "$1" == "doAction" && "$2" != "" ]]; then

  # First we check if a file with name of $PROTECTED_DIR exists
  if [ "$USE_PROTECTED_DIR_MARKER" == "TRUE" ]; then
    # get directory of current file and find out whether the marker file exists
    CURRENT_DIR=`dirname "$2"`
    # now we check whether the marker file exists
    if [[ -e "$CURRENT_DIR/$PROTECTED_DIR_MARKER" ]]; then
      exit
    fi
  fi

  # Check for EXIF and process it
  echo -n ": Checking EXIF... "
  DATETIME=`exiftool -v0 -createdate "$2" | grep "Create Date" | awk -F' ' '{print $4" "$5}'`

  if [[ "$DATETIME" == "" ]]; then
    echo -n "Create Date not found. Let's try GPS Date/Time... "
	DATETIME=`exiftool -v0 -gpsdatetime "$2" | grep "GPS Date/Time" | awk -F' ' '{print $4" "$5}'`

    if [[ "$DATETIME" == "" ]]; then
       echo -n " GPS Date/Time also not found."
          
	   if [[ $USE_LMDATE == "TRUE" ]]; then
          # I am deliberately not using %Y here because of the desire to display the date/time
          # to the user, though I could avoid a lot of post-processing by using it.
          DATETIME=`stat --printf='%y' "$2" | awk -F. '{print $1}' | sed y/-/:/`
          echo " Using LMDATE: $DATETIME"
       else
          echo " Moving to ./noexif/"
          mkdir -p "${MOVETO}noexif" && mv --backup=numbered -f "$2" "${MOVETO}noexif"
	  touch "${MOVETO}noexif/${PROTECTED_DIR_MARKER}"
          exit
       fi;
	else
	  echo "found: $DATETIME"
	fi;	  
  else
    echo "found: $DATETIME"
  fi;


  # Evaluate the file extension
  if [ "$USE_FILE_EXT" == "TRUE" ]; then
    # Get the FILE type and lowercase it for use as the extension
    EXT=`file -b "$2" | awk -F' ' '{print $1}' | tr '[:upper:]' '[:lower:]'`
    
	if [[ "${EXT}" == "jpeg" && "${JPEG_TO_JPG}" == "TRUE" ]]; then 
	   EXT="jpg"
	fi;

  else
    # Lowercase and use the current extension as-is
    EXT=`echo "$2" | awk -F. '{print $NF}' | tr '[:upper:]' '[:lower:]'`
  fi;
  
  # Evaluate the file name
  if [ "$TS_AS_FILENAME" == "TRUE" ]; then
    # Get date and times from EXIF stamp
    EDATE=`echo $DATETIME | awk -F' ' '{print $1}'`
    ETIME=`echo $DATETIME | awk -F' ' '{print $2}'`

	# If time is from GPS it is UTC time, marked with a Z at the end
	# Here we convert it to local time.
    LOCAL_TIME=`date -d "$ETIME" "+%H:%M:%S"`

    # Unix Formatted DATE and TIME - For feeding to date()
    UFDATE=`echo $EDATE | sed y/:/-/`

    # Unix DateSTAMP
#    UDSTAMP=`date -d "$UFDATE $LOCAL_TIME" +%s`
#    echo " Will rename to $UDSTAMP.$EXT"
#    MVCMD="/$UDSTAMP.$EXT"

    if [ "$PRESERVE_ORIGINAL_FILENAME" == "TRUE" ]; then
      EXTENSION=${2##*.}
	  FILENAME=`basename "$2" .$EXTENSION`
      MVCMD="/${UFDATE}_${LOCAL_TIME}_$FILENAME.${EXT}"
	else  
      MVCMD="/${UFDATE}_${LOCAL_TIME}.${EXT}"
    fi;
  fi;

  # DIRectory NAME for the file move
  # sed issue for y command fix provided by thomas
#  DIRNAME=`echo $EDATE | sed y-:-/-`
  DIRNAME=`date -d $UFDATE $DIRFORMAT`

  echo -n " Moving to ${MOVETO}${DIRNAME}${MVCMD} ... "
  mkdir -p "${MOVETO}${DIRNAME}" && mv --backup=numbered -f "$2" "${MOVETO}${DIRNAME}${MVCMD}"
  touch "${MOVETO}${DIRNAME}/${PROTECTED_DIR_MARKER}"
  echo "done."
  echo ""
  exit
fi;
#
###############################################################################
# Scanning (find) loop
# This is the normal loop that is run when the program is executed by the user.
# This runs find for the recursive searching, then find invokes this program with the two
# parameters required to trigger the above loop to do the heavy lifting of the sorting.
# Could probably be optimized into a function instead, but I don't think there's an
# advantage performance-wise. Suggestions are welcome at the URL at the top.
for x in "${FILETYPES[@]}"; do
  # Check for the presence of exiftool command.
  # Assuming its valid and working if found.
  I=`which exiftool`
  if [ "$I" == "" ]; then
    echo "The 'exiftool' command is missing or not available."
    echo "Is exiftool installed?"
    exit 1
  fi;

  echo -e "Scanning for $x..."
  # FIXME: Eliminate problems with unusual characters in filenames.
  # Currently the exec call will fail and they will be skipped.
  find . -type f -iname "$x" -print0 -exec sh -c "$0 doAction '{}'" \;
  echo -e "\n... end of $x\n"
done;

# clean up empty directories. Find can do this easily.
# Remove Thumbs.db first because of thumbnail caching

echo -n "Removing Thumbs.db files ... "
find . -type f -name Thumbs.db -delete
echo "done."

echo -n "Cleaning up empty directories ... "
find . -type d -empty -delete
echo "done."

