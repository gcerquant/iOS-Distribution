#!/usr/bin/env sh
#
# MacMation - http://www.macmation.com
# Guillaume Cerquant - contact at domainnameabove
# 
# Version 1.2: Now generate an IPA file, with a label showing info version on the artwork iTunes icon
# Version 1.1: Include the Mobile Provisioning file inside the generated zip

# TODO:
# 	Explain what this script does
#	Automatically detect sdk version to use
#	Refactor this code to:
#	  - allow an easier configuration of the sources repo
#	  - clean it
#	Output multiple ipas, resigned with a different certificate
#   Remove the dependancy to ImageMagick by embeding a custom command line tool that would do something nice using CoreImage
# 
# 




## configuration
# Project info
PROJECT_NAME="YourAwesomeProject"
TARGET_NAME="YourAwesomeProject"
SDK="iphoneos4.2"
CONFIGURATION_NAME="AdHoc"  # "AppStore" # ou AdHoc
CONFIGURATION="Distribution-${CONFIGURATION_NAME}"


FINAL_DIRECTORY="/Users/your_user_name/Desktop"



# TODO: RENAME THIS OPTION
IMAGE_MAGICK_ENABLED="1";

IMAGE_MAGICK_CONVERT="/usr/local/bin/convert"
IMAGE_MAGICK_COMPOSITE="/usr/local/bin/composite"


# End of configuration

set -o errexit





XCODEBUILD="/Developer/usr/bin/xcodebuild"
BZR="/usr/local/bin/bzr"

TEMP_DIRECTORY=`/usr/bin/mktemp -dq /tmp/${PROJECT_NAME}_XXXXXXXXXXXX`
if [ $? -ne 0 ]; then
	echo "$0: Can't create temp file, exiting..."
    exit 1
fi

SRC_DIRECTORY="${TEMP_DIRECTORY}/bzr"
BUILD_DIRECTORY="${TEMP_DIRECTORY}/build"


echo "Building $PROJECT_NAME (Target: $TARGET_NAME; SDK: $SDK; Configuration: $CONFIGURATION)"
echo "Temp: $TEMP_DIRECTORY"

$BZR export $SRC_DIRECTORY

BZR_REVNO=`/usr/local/bin/bzr revno`
# echo "Revno: $BZR_REVNO"


cd "${SRC_DIRECTORY}"
echo cd "${SRC_DIRECTORY}"

# Building project
echo ${XCODEBUILD} -target "$TARGET_NAME" -sdk "$SDK" -configuration "$CONFIGURATION" SYMROOT="${BUILD_DIRECTORY}"
${XCODEBUILD} -target "$TARGET_NAME" -sdk "$SDK" -configuration "$CONFIGURATION" SYMROOT="${BUILD_DIRECTORY}"


#############################################
# Getting Mobile Provisioning file
PATH_TO_EMBED_MOBILE_PROVISION_FILE="${BUILD_DIRECTORY}/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.app/embedded.mobileprovision";
NAME_OF_MOBILE_PROVISION_FILE=`strings "${PATH_TO_EMBED_MOBILE_PROVISION_FILE}" | grep -A1 '<key>Name</key>' | tail -n1 | awk -F'<string>' '{print $2}' | awk -F'</string>' '{print $1}'`



echo "Mobile Provisioning Certificate used: ${NAME_OF_MOBILE_PROVISION_FILE}"

cp "${PATH_TO_EMBED_MOBILE_PROVISION_FILE}" "${BUILD_DIRECTORY}/${CONFIGURATION}-iphoneos/${NAME_OF_MOBILE_PROVISION_FILE}.mobileprovision"

#############################################




################################################

PRODUCT_VERSION_NUMBER=`cat ${PROJECT_NAME}-Info.plist | grep -A1 CFBundleVersion | tail -n1 | cut -d'>' -f2 | cut -d'<' -f1`
# echo "Product version: ${PRODUCT_VERSION_NUMBER}"

DATE=`date '+%Y%m%d_%H'h'%M'`


BASEFILENAME="${PROJECT_NAME}_v${PRODUCT_VERSION_NUMBER}_(rev_${BZR_REVNO}-$DATE)_${CONFIGURATION_NAME}.zip" 

cd "${BUILD_DIRECTORY}/${CONFIGURATION}-iphoneos"


# Generate IPA

/bin/mkdir Payload

mv "${PROJECT_NAME}.app" "Payload"

/bin/cp "${SRC_DIRECTORY}/resources/images/Icon_iTunes.png" "iTunesArtwork"

# Add a text label to the image


if [ ${IMAGE_MAGICK_ENABLED} -eq "1" ]; then
	if [ ! -x "${IMAGE_MAGICK_CONVERT}" ]; then
	 	echo "Please Install ImageMagick (http://www.imagemagick.org/script/install-source.php)\nor disable iTunes icon version tagging";
		exit 3;
	else

		# Create the text info label on a white semi transparent background
		${IMAGE_MAGICK_CONVERT} -size 512x -background '#FFFD'  -fill black  -font Monaco  -gravity South label:"     Version ${PRODUCT_VERSION_NUMBER} (beta)     \n     ${DATE}     " label.png

		# Composite the label and the original iTunes artwork
		${IMAGE_MAGICK_COMPOSITE} -gravity South label.png iTunesArtwork iTunesArtwork_labeled
	
		mv "iTunesArtwork_labeled" "iTunesArtwork"
	
	fi
fi


/usr/bin/zip -r -T -y "${PROJECT_NAME}.ipa" "Payload" "iTunesArtwork"


################################################

#############################################

# Create final archive


echo "Creating file: $BASEFILENAME"




zip -r -T -y "${BASEFILENAME}" "${PROJECT_NAME}.ipa" "${NAME_OF_MOBILE_PROVISION_FILE}.mobileprovision"


echo "${BUILD_DIRECTORY}/${CONFIGURATION}-iphoneos"
mv "./${BASEFILENAME}" "${FINAL_DIRECTORY}"



open "${FINAL_DIRECTORY}"


# Cleaning up:
rm -rf ${TEMP_DIRECTORY}
