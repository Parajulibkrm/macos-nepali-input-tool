
killall -9 GoogleInputTools

rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
rm -rf ~/Library/Containers/com.lennylxx.inputmethod.GoogleInputTools/
rm -rf ~/Library/Developer/Xcode/DerivedData/GoogleInputTools-*/
rm -rf ./build

xcodebuild -scheme GoogleInputTools build CONFIGURATION_BUILD_DIR=/Users/$(id -un)/Library/Input\ Methods/

ls -al ~/Library/Input\ Methods
