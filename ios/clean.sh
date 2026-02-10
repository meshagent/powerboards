rm -rf ~/.cocoapods
rm -rf ~/Library/Developer/Xcode/DerivedData/*

rm -rf build
rm -rf Pods
rm Podfile.lock

pod cache clean --all
pod repo update
pod deintegrate
pod install --repo-update