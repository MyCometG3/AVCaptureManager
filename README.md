## AVCaptureManager.framework

Simple but powerful wrapper for AVCapture.framework, etc.

- __Requirement__: MacOS X 10.14.6 or later.
- __Capture Device__: Any AV devices compatible with AVCapture.framework,
including A/V mixed connection like DV.
- __UVC/UAC Devices__: Generall UVC/UAC devices are supported.
- __Restriction__: Only QuickTime movie (.mov) is supported.
- __Restriction__: Video-only or Audio-only source may not work.
- __Restriction__: Progressive/Frame based video is supported but Field based video is not supported.
- __Dependency__: AVFoundation/VideoToolbox/CoreMediaIO
- __Architecture__: Universal binary (x86_64 + arm64)

#### Basic Usage:

###### 1. Instanciate AVCaptureManager

    import Cocoa
    import AVFoundation
    import AVCaptureManager

    manager = AVCaptureManager()

###### 2. Set parameters for session then start session

    // Set session parameters
    public var useMuxed : Bool = false
    public var usePreset : Bool = false
    public var exportPreset : AVCaptureSession.Preset = .high

    // Start session using one of followings
    public func openSession() -> Bool {...}
    public func openSessionForUniqueID(muxed muxedID:String?,
                                     video videoID:String?,
                                     audio audioID:String?) -> Bool {...}
    // Check readiness
    public func isReady() -> Bool {...}

    // Wait till Source encoded pixel size is detected
    public var videoSize : CGSize? = nil

###### 3. Set parameters for recording then start recording

    // Set some parameters before start recording - when usePreset==false
    public var encodeVideo : Bool = true
    public var encodeAudio : Bool = true
    public var encodeDeinterlace : Bool = true
    public var encodeProRes : Bool = true
    public var sampleDurationVideo : CMTime? = nil
    public var sampleTimescaleVideo : CMTimeScale = 0
    public var timeCodeFormatType: CMTimeCodeFormatType? = nil // Only 'tmcd' or 'tc64' are supported

    // Re-generate new recording parameters using one of followings
    public func resetVideoStyle(_ newStyle:VideoStyle) {...}
    public func resetVideoStyle(_ newStyle:VideoStyle, hOffset newHOffset:Int, vOffset newVOffset:Int) {...}
    public func resetCompressionSettings() {...}

    // Specify URL to record
    public func startRecording(to url: URL) {...}

    // Check if recording is running
    public func isRecording() -> Bool {...}

###### 4. Stop recording

    // Finish writing
    public func stopRecording() {...}

###### 5. Close session

    // Shutdown session
    public func closeSession() {...}

###### 6. Dealloc AVCaptureManager

    manager = nil

###### Check if recording detects any error

    internal (set) public var lastAVAssetWriterStatus:String? = nil
    internal (set) public var lastAVAssetWriterError:String? = nil

###### Query Capture Devices (r/o)

    // Device's uniqueID for current session
    public var currentDeviceIDVideo : String? {...}
    public var currentDeviceIDAudio : String? {...}

    // All connected devices info
    public func devicesMuxed() -> [Any]! {...}
    public func devicesVideo() -> [Any]! {...}
    public func devicesAudio() -> [Any]! {...}
    public func deviceInfoForUniqueID(_ uniqueID: String) -> [String:Any]? {..}

#### NOTE:

This framework produces QuickTime movie (.mov) only.

You must restart session in the following scenario:
- To toggle "using AVAssetWriter preset" and "using custom compression"
- To switch between "muxed device" and "separated AV devices"
- To change devices for inputs (e.g. internal mic to external audio I/F)

QuickTime movie capture will create tracks as following:
- Muxed capture works with combination of followings.
- Video capture works with video track of 1)Device Native or 2)Encoded format.
- Audio capture works with audio track of 1)Decompressed or 2)Encoded format.

#### Development environment:
- macOS 12.6.2 Monterey
- Xcode 14.2
- Swift 5.7.2

#### License
- MIT license

Copyright © 2016-2023年 MyCometG3. All rights reserved.
