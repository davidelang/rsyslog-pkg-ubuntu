#!/bin/bash
# Build daily snapshot package
# ***current working directory must be project dir (e.g. rsyslog)***

# Note: Launchpad does not work with the git hash inside the version
# number, because it checks if the version number as whole is larger
# than what exists. This obviously is not always the case with hashes.
# As such, we rename the version to todays date and time. It looks like
# this works sufficiently good, even when the source code has the
# "right" (hash-based) version number.

#set -o xtrace  # useful for debugging

echo package build for `pwd` $1/$2/$3
date

# params
szPlatform=$1  # trusty, vivid, ...
UPLOAD_PPA=$2  # path of the ppa (e.g. v8-devel)
szBranch=$3    # branch to use (e.g. master)
	       # Note: this must match the tarball branch

rm -fv *.orig.tar.gz # clean up if left over, temporary work file!
# only a single .tar.gz must exist at any time
ls -l *.tar.gz # debug output
szSourceFile=`ls *.tar.gz`
szSourceBase=`basename $szSourceFile .tar.gz`
VERSION=`echo $szSourceBase|cut -d- -f2`
LAUNCHPAD_VERSION=`echo $VERSION|cut -d. -f1-3`.'0aa'.`date +%Y%m%d%H%M%S`
PROJECT=`echo $szSourceBase | cut -d- -f1`
szReplaceFile="${PROJECT}_$LAUNCHPAD_VERSION"
VERSION_FILE="LAST_VERSION.$szBranch.$szPlatform"

echo PROJECT $PROJECT
echo VERSION $VERSION
echo Platform $szPlatform

# $VERSION_FILE must not exist. If it does not exist, an
# error message is emitted (this is OK) and the build is
# done. So you can delete it to trigger a new build.
if [ "$VERSION" == "`cat $VERSION_FILE`" ]; then
	echo "version $VERSION already built, exiting"
	rm *.tar.gz
	exit 0
fi

# clean up any old cruft (if it exists)
rm -f $PROJECT_*.changes
rm -f $PROJECT_*.dsc
rm -f $PROJECT_*.build
rm -f $PROJECT_*.debian.tar.gz
rm -f $PROJECT_*.orig.tar.gz

# BEGIN ACTUAL BUILD PROCESS

tar xfz $szSourceFile
mv $szSourceFile $szReplaceFile.orig.tar.gz

mv $szSourceBase $LAUNCHPAD_VERSION
cd $LAUNCHPAD_VERSION
#cp -r ../common/$szBranch/debian .
# now overwrite with platform-specific stuff (if any)
cp -r ../$szPlatform/$szBranch/debian .

# create dummy changelog entry
echo "$PROJECT ($LAUNCHPAD_VERSION-0adiscon1$szPlatform) $szPlatform; urgency=low" > debian/changelog
echo "" >> debian/changelog
echo "  * daily build" >> debian/changelog
echo "" >> debian/changelog
echo " -- Adiscon package maintainers <adiscon-pkg-maintainers@adiscon.com>  `date -R`" >> debian/changelog 

# Build Source package now!
debuild -S -sa -rfakeroot -k"$PACKAGE_SIGNING_KEY_ID"
if [ $? -ne 0 ]; then
	echo "fail in debuild for $PROJECT $VERSION on $szPlatform" | mutt -s "$PROJECT daily build failed!" $RS_NOTIFY_EMAIL
        exit 1
fi

# we now need to climb out of the working tree, all distributable
# files are generated in the home directory.
cd ..

# Upload changes to PPA now!
dput -f ppa:adiscon/$UPLOAD_PPA `ls *.changes`
if [ $? -ne 0 ]; then
	 echo "fail in dput, PPA upload to Launchpad failed" | mutt -s "$PROJECT daily build failed!" $RS_NOTIFY_EMAIL
        exit 1
fi
#cleanup
echo $VERSION >$VERSION_FILE
#exit # do this for testing
rm -rf $LAUNCHPAD_VERSION
rm -v $szReplaceFile*.dsc $szReplaceFile*.build $szReplaceFile*.changes $szReplaceFile*.upload *.tar.gz
