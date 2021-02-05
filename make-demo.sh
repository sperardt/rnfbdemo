#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native current + react-native-firebase current + Firebase SDKs current"

npx react-native init rnfbdemo
cd rnfbdemo

# This is the most basic integration
echo "Adding react-native-firebase core app package"
yarn add "@react-native-firebase/app"
echo "Adding basic iOS integration - AppDelegate import and config call"
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n@import Firebase;/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/if ([FIRApp defaultApp] == nil) { [FIRApp configure]; }\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
echo "Adding basic java integration - gradle plugin dependency and call"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.3.4"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/apply plugin: "com.android.application"/apply plugin: "com.android.application"\\\napply plugin: "com.google.gms.google-services"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials
echo "Adding upstream SDK overrides for precise version control"
echo "project.ext{set('react-native',[versions:[firebase:[bom:'26.4.0'],],])}" >> android/build.gradle
sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseSDKVersion = \'7.5.0\'\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
rm -f ios/Podfile??

# Copy the Firebase config files in - you must supply them
echo "Copying in Firebase android json and iOS plist app definition files downloaded from console"
if [ "$(uname)" == "Darwin" ]; then
  cp ../GoogleService-Info.plist ios/rnfbdemo/
fi
cp ../google-services.json android/app/

# Copy in a project file that is pre-constructed - no way to patch it cleanly that I've found
# There is already a pre-constructed project file here. 
# Normal users may skip these steps unless you are maintaining this repository and need to generate a new project
# To build it do this:
# 1.  stop this script here (by uncommenting the exit line)
# 2.  open the .xcworkspace created by running the script to this point
# 3.  alter the bundleID to com.rnfbdemo
# 4.  alter the target to iPhone and iPad instead of iPhone only (Mac is not supported yet, but feel free to try...)
# 5.  right-click on rnfbdemo, "add files to rnfbdemo" select rnfbdemo/GoogleService-Info.plist for rnfbdemo and rnfbdemo-tvOS
# 6.  copy the rnfbdemo.xcodeproj and rnfbdemo.xcworkspace folders over the existing ones saved in the root directory
#exit 1
rm -rf ios/rnfbdemo.xcodeproj ios/rnfbdemo.xcworkspace
cp -r ../rnfbdemo.xcodeproj ios/
cp -r ../rnfbdemo.xcworkspace ios/

# From this point on we are adding optional modules
# First set up all the modules that need no further config for the demo 
echo "Adding packages: Auth, Database, Storage"
yarn add \
  @react-native-firebase/auth \
  @react-native-firebase/database \
  @react-native-firebase/storage

# Copy in our demonstrator App.js
echo "Copying demonstrator App.js"
rm ./App.js && cp ../App.js ./App.js


# Another Java build tweak - or gradle runs out of memory during the build
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# In case we have any patches
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npx patch-package

# Run it for Android (assumes you have an android emulator running)
echo "Running android app"
npx react-native run-android
