## AVCaptureManager.framework

Simple but powerful wrapper for AVCapture.framework, etc.

- __Requirement__: MacOS X 10.14.6 or later.
- __Capture Device__: Any AV devices compatible with AVCapture.framework,
including A/V mixed connection like DV.
- __Restriction__: Video-only or Audio-only recording are not supported.
- __Dependency__: AVFoundation/VideoToolbox/CoreMediaIO
- __Architecture__: Universal binary (x86_64 + arm64)

#### Basic Usage

###### 1. Instance AVCaptureManager

    import Cocoa
    import AVFoundation
    import AVCaptureManager

    manager = AVCaptureManager()

###### 2. Set parameters for session then start session

    // Set before openSession() or openSessionForUniqueID()
    open var useMuxed : Bool = false
    open var usePreset : Bool = false
    open var exportPreset : AVCaptureSession.Preset = .high

    // Start session
    open func openSession() -> Bool {...}
    open func openSessionForUniqueID(muxed muxedID:String?,
                                     video videoID:String?,
                                     audio audioID:String?) -> Bool {...}
    // Check readiness
    open func isReady() -> Bool {...}

    // Wait Source encoded pixel size is ready to proceed
    open var videoSize : CGSize? = nil

###### 3. Set parameters for recording then start recording

    // Set before startRecording(to:) - when usePreset==false
    open var encodeVideo : Bool = true
    open var encodeAudio : Bool = true
    open var encodeDeinterlace : Bool = true
    open var encodeProRes : Bool = true
    private (set) public var videoStyle : VideoStyle = .SD_720_480_16_9 // SD - DV-NTSC Wide screen
    private (set) public var clapHOffset : Int = 0
    private (set) public var clapVOffset : Int = 0
    open var sampleDurationVideo : CMTime? = nil
    open var sampleTimescaleVideo : CMTimeScale = 0
    open var timeCodeFormatType: CMTimeCodeFormatType? = nil // Only 'tmcd' or 'tc64' are supported

    // Apply new recording parameters using one of followings:
    open func resetVideoStyle(_ newStyle:VideoStyle) {...}
    open func resetVideoStyle(_ newStyle:VideoStyle, hOffset newHOffset:Int, vOffset newVOffset:Int) {...}
    open func resetCompressionSettings() {

    // Specify URL to record
    open func startRecording(to url: URL) {...}

    // Check if recording is running
    open func isRecording() -> Bool {...}

###### 4. Stop recording

    // Finish writing
    open func stopRecording() {...}

    // Query recording duration
    open var duration : Float64 {...}

###### 5. Close session

    // Shutdown session
    open func closeSession() {...}

###### 6. Dealloc AVCaptureManager

    manager = nil

#### Query Capture Devices (r/o)

    // Device's uniqueID for current session
    open var currentDeviceIDVideo : String? {...}
    open var currentDeviceIDAudio : String? {...}

    // All connected devices info
    open func devicesMuxed() -> [Any]! {...}
    open func devicesVideo() -> [Any]! {...}
    open func devicesAudio() -> [Any]! {...}
    open func deviceInfoForUniqueID(_ uniqueID: String) -> [String:Any]? {..}

#### Restriction

You have to restart session always in the following scenario:
- To change b/w muxed input and separated A-V inputs
- To change devices for inputs

#### Development environment
- macOS 12.6.2 Monterey
- Xcode 14.2
- Swift 5.7.2

#### License
- MIT license

Copyright © 2016-2022年 MyCometG3. All rights reserved.
