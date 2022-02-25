BINARY_NAME=sal-submit
CODE_SIGN_IDENTITY=""

clean:
	# remove old builds
	rm -rf build/
	rm -rf sal-scripts/.build/
	# remove binaries
	rm -f payload/usr/local/munki/report_broken_client
	rm -f payload/usr/local/sal/bin/${BINARY_NAME}

sign:
	codesign --force --sign ${CODE_SIGN_IDENTITY} --verbose --preserve-metadata= payload/usr/local/sal/bin/${BINARY_NAME}
	codesign --force --sign ${CODE_SIGN_IDENTITY} --verbose --preserve-metadata= payload/usr/local/munki/report_broken_client

build_pkg: build_report_broken_client
	mv "${GITHUB_WORKSPACE}"/report_broken_client/build/Release/report_broken_client "$GITHUB_WORKSPACE"/payload/usr/local/munki/report_broken_client
	mv "${GITHUB_WORKSPACE}"/sal-scripts/.build/apple/Products/Release/sal-scripts "$GITHUB_WORKSPACE"/payload/usr/local/sal/bin/${BINARY_NAME}

pkg: 
	munkipkg .	

build_report_broken_client: 
	xcodebuild -project report_broken_client/report_broken_client.xcodeproj -configuration Release
	
build_arm64_binary:
	cd sal-scripts; swift build -c release --arch arm64

arm64: build_arm64_binary build_pkg pkg

arm64_signed: build_arm64_binary build_pkg sign pkg

build_x86_binary:
	cd sal-scripts; swift build sal-scripts -c release --arch x86_64

x86: build_x86_binary build_pkg pkg

x86_signed: build_x86_binary build_pkg sign pkg

build_universal_binary: 
	cd sal-scripts; swift build -c release --arch arm64 --arch x86_64
	
universal: build_universal_binary build_pkg pkg

universal_signed: build_universal_binary build_pkg sign pkg
	

