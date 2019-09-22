## AVCaptureManager.framework

Simple but powerful wrapper for AVCapture.framework, etc.

- __Requirement__: MacOS X 10.11 or later.
- __Capture Device__: Any AV devices compatible with AVCapture.framework,
including A/V mixed connection like DV.
- __Restriction__: Video-only or Audio-only recording are not supported.
- __Dependency__: AVFoundation/AVCapture/VideoToolbox/CoreVideo/CoreMedia

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

    TODO: Current version does not fill videoSize if usePreset = true.

###### 3. Set parameters for recording then start recording

    // Set before startRecording(to:) - when usePreset==false
    open var encodeVideo : Bool = true
    open var encodeAudio : Bool = true
    open var encodeDeinterlace : Bool = true
    open var encodeProRes422 : Bool = true
    open var videoStyle : VideoStyle = .SD_720_480_16_9 // SD - DV-NTSC Wide screen
    open var clapHOffset : Int = 0
    open var clapVOffset : Int = 0
    open var sampleTimescaleVideo : CMTimeScale = 0
    open var timeCodeFormatType: CMTimeCodeFormatType? = nil // Only 'tmcd' or 'tc64' are supported

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
- MacOS X 10.14.6 Mojave
- Xcode 10.3
- Swift 5.0.1

#### License
- 3-clause BSD license

Copyright © 2016-2019年 MyCometG3. All rights reserved.
