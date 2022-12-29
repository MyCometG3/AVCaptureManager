//
//  AVCaptureManager.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2016/08/07.
//  Copyright © 2016-2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation

public class AVCaptureManager : NSObject, AVCaptureFileOutputRecordingDelegate {
    
    /* ======================================================================================== */
    // MARK: - public variables
    /* ======================================================================================== */
    
    /// preview video : CALayer
    public var previewLayer : AVCaptureVideoPreviewLayer? {
        get {
            return previewVideoLayer
        }
    }
    
    /// preview audio : Volume in 0.0 - 1.0 : Float.
    public var volume : Float {
        get {
            return _volume
        }
        set (value) {
            _volume = value
            _volume = _volume > 1.0 ? 1.0 : _volume
            _volume = _volume < 0.0 ? 0.0 : _volume
            if let previewAudioOutput = previewAudioOutput {
                previewAudioOutput.volume = _volume
            }
        }
    }
    
    /// recording duration in second : Float64.
    public var duration : Float64 {
        get {
            return _duration
        }
    }
    
    /// query current video deviceID
    public var currentDeviceIDVideo : String? {
        get {
            var deviceID : String? = nil
            if let device = captureDeviceVideo {
                deviceID = device.uniqueID
            }
            return deviceID
        }
    }
    
    /// query current audio deviceID
    public var currentDeviceIDAudio : String? {
        get {
            var deviceID : String? = nil
            if let device = captureDeviceAudio {
                deviceID = device.uniqueID
            }
            return deviceID
        }
    }
    
    // MARK: - status parameters
    
    /// Video dimension received from input device
    internal (set) public var videoSize : CGSize? = nil
    /// Status description returned from AVAssetWriter
    internal (set) public var lastAVAssetWriterStatus:String? = nil
    /// Error description returned from AVAssetWriter
    internal (set) public var lastAVAssetWriterError:String? = nil
    
    // MARK: - session parameters
    /*
     * Followings are session settings.
     * Use closeSession()/openSession() to reflect any changes.
     */
    /// Special flag for muxed stream (Video/Audio muxed). e.g. DV devices
    public var useMuxed : Bool = false
    /// Choose either "AVFoundation's session preset" or "custom compression".
    public var usePreset : Bool = false
    /// Preset for capture session
    public var exportPreset : AVCaptureSession.Preset = .high
    
    /// Debug support - notification
    public var debugObserver : Bool = false
    /// Debug support - trim movie
    public var debugTrimMovie : Bool = false
    /// Debug support - decode video; false allows device native format. Default is false.
    public var debugDecodeVideo : Bool = false
    /// Debug support - decode audio; false allows device native format. Default is true.
    public var debugDecodeAudio : Bool = true
    /// Debug support - dump video encoder supported properties
    public var debugDumpSupportedPropertiesVideo : Bool = false
    /// Debug support - Adjust settings for Video
    public var debugAdjustSettingsVideo : Bool = true
    /// Debug support - Adjust settings for Audio
    public var debugAdjustSettingsAudio : Bool = true
    
    /// Decompressed pixel format; either 8bit or 10bit, 422 or 444 is recommended. Default is kCMPixelFormat_422YpCbCr8.
    public var pixelFormatType : CMPixelFormatType = kCMPixelFormat_422YpCbCr8
    
    // MARK: - custom compression parameters
    /*
     * Following are custom settings, effective when usePreset=false.
     * Use resetCompressionSettings() to reflect any changes.
     */
    /// Enable VideoTranscode or not
    public var encodeVideo : Bool = true
    /// Enable AudioTranscode or not
    public var encodeAudio : Bool = true
    /// Request deinterlace of input video (depends on decoder feature)
    public var encodeDeinterlace : Bool = true
    /// Choose ProRes or H.264 for VideoTranscode
    public var encodeProRes : Bool = true
    
    /// VideoStyle for encodeVideo==true; use resetVideoStyle() to set.
    private (set) public var videoStyle : VideoStyle = .SD_720_480_16_9 // SD - DV-NTSC Wide screen
    /// Clean aperture offset - Horizontal; use resetVideoStyle() to set.
    private (set) public var clapHOffset : Int = 0
    /// Clean aperture offset - Vertical; use resetVideoStyle() to set.
    private (set) public var clapVOffset : Int = 0
    
    /// Video resampling support
    public var sampleDurationVideo : CMTime? = nil
    /// Video track timeScale like 30000, 50000, 60000 (per sec)
    public var sampleTimescaleVideo : CMTimeScale = 0
    /// TimeCode track support
    public var timeCodeFormatType: CMTimeCodeFormatType? = nil // Only 'tmcd' or 'tc64' are supported
    
    /// Callback support to verify/modify for video compression setting
    public var updateVideoSettings : ((inout [String:Any]) -> Void)? = nil
    /// Callback support to verify/modify for audio compression setting
    public var updateAudioSettings : ((inout [String:Any]) -> Void)? = nil
    
    /// ProRes VideoEncoder. Default is AVVideoCodecType.proRes422.
    public var proresEncoderType : AVVideoCodecType = .proRes422
    /// VideoEncoder. Default is AVVideoCodecType.h264. Use updateVideoSettings() to modify detailed parameters.
    public var videoEncoderType : AVVideoCodecType = .h264
    /// VideoEncoder profile. Default is AVVideoProfileLevelH264MainAutoLevel.
    public var videoEncoderProfile : String = AVVideoProfileLevelH264MainAutoLevel
    /// VideoEncoder bitRate. Default is H264ProfileLevel.MP_40.maxRate.
    public var videoEncoderBitRate : Int = H264ProfileLevel.MP_40.maxRate
    /// VideoEncoder key frame interval limit in seconds. Set 0.0 to make key frame only stream.
    public var maxKeyFrameIntervalSeconds : Double = 3.0
    
    /// AudioEncoder. Default is kAudioFormatMPEG4AAC. Use updateAudioSettings() to modify detailed parameters.
    public var audioEncodeType : AudioFormatID = kAudioFormatMPEG4AAC
    /// AudioEncoder bitRate. Default is 256Kbps.
    public var audioEncoderBitRate : Int = 256*1000
    /// AudioEncoder bitRate Strategy. Default is AVAudioBitRateStrategy_Constant.
    public var audioEncoderStrategy : String = AVAudioBitRateStrategy_Constant
    
    /* ======================================================================================== */
    // MARK: - internal variables - session
    /* ======================================================================================== */
    
    internal var captureSession : AVCaptureSession? = nil
    
    internal var captureDeviceVideo : AVCaptureDevice? = nil
    internal var captureDeviceAudio : AVCaptureDevice? = nil
    
    internal var captureDeviceInputAudio : AVCaptureDeviceInput? = nil
    internal var captureDeviceInputVideo : AVCaptureDeviceInput? = nil
    
    internal var previewAudioOutput : AVCaptureAudioPreviewOutput? = nil
    internal var previewVideoLayer : AVCaptureVideoPreviewLayer? = nil
    
    internal var _volume : Float = 1.0
    
    internal var uniqueIDmuxed : String? = nil
    internal var uniqueIDvideo : String? = nil
    internal var uniqueIDaudio : String? = nil
    
    internal var smpteReadyVideo : Bool = false                             // Custom
    
    internal var lastSeqVideo : UInt64 = kCMIOInvalidSequenceNumber         // Custom
    internal var lastSeqAudio : UInt64 = kCMIOInvalidSequenceNumber         // Custom
    
    internal var observers:[NSObjectProtocol] = []
    
    /* ======================================================================================== */
    // MARK: - internal variables - recording
    /* ======================================================================================== */
    
    internal var captureMovieFileOutput : AVCaptureMovieFileOutput? = nil
    internal var captureVideoDataOutput : AVCaptureVideoDataOutput? = nil   // Custom
    internal var captureAudioDataOutput : AVCaptureAudioDataOutput? = nil   // Custom
    
    internal var avAssetWriter : AVAssetWriter? = nil
    internal var avAssetWriterInputVideo : AVAssetWriterInput? = nil        // Custom
    internal var avAssetWriterInputAudio : AVAssetWriterInput? = nil        // Custom
    internal var avAssetWriterInputTimeCodeVideo : AVAssetWriterInput? = nil // Custom
    
    internal var decompressor : VideoDecompressor? = nil                    // Custom
    
    internal var _duration  : Float64 = 0.0                                 // Custom
    internal var startTime : CMTime = CMTime.zero                           // Custom
    internal var endTime : CMTime = CMTime.zero                             // Custom
    internal var isInitialTSReady : Bool = false                            // Custom
    
    internal var isWriting : Bool = false
    
    internal var videoDeviceDecompressedFormat : [String:Any] = [:]
    internal var videoDeviceCompressedFormat : [String:Any] = [:]           // Custom
    
    internal var audioDeviceDecompressedFormat : [String:Any] = [:]
    internal var audioDeviceCompressedFormat : [String:Any] = [:]           // Custom
    
    internal var resampleDuration : CMTime? = nil                           // Custom
    internal var resampleCurrentPTS : CMTime? = nil                         // Custom
    internal var resampleNextPTS : CMTime? = nil                            // Custom
    internal var resampleCaptured : CMSampleBuffer? = nil                   // Custom
    
    /* ======================================================================================== */
    // MARK: - public session API
    /* ======================================================================================== */
    
    /// Verify if capture session is ready (ready to capture)
    /// - Returns: true if ready
    public func isReady() -> Bool {
        if let captureSession = captureSession {
            return captureSession.isRunning
        }
        return false
    }
    
    /// Open capture session using default video/audio devices
    /// - Returns: true if no error
    public func openSession() -> Bool {
        return openSessionForUniqueID(muxed: nil, video: nil, audio: nil)
    }
    
    /// Open capture session using specified uniqueID devices.
    /// If device is not available default device will be used instead.
    /// - Parameters:
    ///   - muxedID: muxed device uniqueID
    ///   - videoID: video device uniqueID
    ///   - audioID: audio device uniqueID
    /// - Returns: true if no error
    public func openSessionForUniqueID(muxed muxedID:String?,
                                     video videoID:String?,
                                     audio audioID:String?) -> Bool {
        // Close current session first
        if isReady() {
            closeSession()
        }
        
        // Update uniqueID as requested
        uniqueIDmuxed = muxedID
        uniqueIDvideo = videoID
        uniqueIDaudio = audioID
        
        // Initialize session
        if prepareSession() {
            // Start Capture session
            if startSession() {
                return true
            } else {
                print("ERROR: startSession() failed.")
            }
        } else {
            print("ERROR: prepareSession() failed.")
        }
        return false
    }
    
    /// Close capture session completely
    public func closeSession() {
        // Stop recording session
        if isRecording() {
            stopRecording()
        }
        
        // Stop decompressor
        if let decompressor = decompressor {
            decompressor.invalidate()
            self.decompressor = nil
        }
        
        // Stop Capture session
        _ = stopSession() // Ignore any error
        
        // Release objects (recording)
        avAssetWriterInputTimeCodeVideo = nil
        avAssetWriterInputVideo = nil
        avAssetWriterInputAudio = nil
        avAssetWriter = nil
        
        captureMovieFileOutput = nil
        captureVideoDataOutput = nil
        captureAudioDataOutput = nil
        
        // Release objects (session)
        previewVideoLayer = nil
        previewAudioOutput = nil
        
        captureDeviceInputVideo = nil
        captureDeviceInputAudio = nil
        
        captureDeviceVideo = nil
        captureDeviceAudio = nil
        
        captureSession = nil
        
        // Unregister Notification Observers
        unregisterObserver()
        
        // Reset other private parameters (recording)
        _duration = 0.0
        startTime = CMTime.zero
        endTime = CMTime.zero
        isInitialTSReady = false
        
        isWriting = false
        
        videoDeviceCompressedFormat = [:]
        videoDeviceDecompressedFormat = [:]
        
        audioDeviceCompressedFormat = [:]
        audioDeviceDecompressedFormat = [:]
        
        resampleDuration = nil
        resampleCurrentPTS = nil
        resampleNextPTS = nil
        resampleCaptured = nil
        
        // Reset other private parameters (session)
        _volume = 1.0
        
        uniqueIDmuxed = nil
        uniqueIDvideo = nil
        uniqueIDaudio = nil
        
        smpteReadyVideo = false
        
        lastSeqVideo = kCMIOInvalidSequenceNumber
        lastSeqAudio = kCMIOInvalidSequenceNumber
        
        // reset status parameters
        lastAVAssetWriterStatus = nil
        lastAVAssetWriterError = nil
        videoSize = nil
    }
    
    /// Toggle video preview connection
    /// - Parameter state: Enabled/Disabled state
    public func setVideoPreviewConnection(enabled state: Bool) {
        // NOTE: This func seems heavy operation for previewVideo - previewAudio could got stuttering
        if let previewVideoLayer = previewVideoLayer {
            let previewVideoConnection = previewVideoLayer.connection
            if let connection = previewVideoConnection {
                if connection.isEnabled != state {
                    connection.isEnabled = state
                }
            }
        }
    }
    
    /* ======================================================================================== */
    // MARK: - public recording API
    /* ======================================================================================== */
    
    /// Verify if recording is running
    /// - Returns: true if recording, false if not
    public func isRecording() -> Bool {
        return isWriting
    }
    
    /// Start recording on current capture session
    /// - Parameter url: file URL to write movie
    public func startRecording(to url: URL) {
        // check if session is running
        if isReady() == false {
            return
        }
        
        // check if recording is running
        if isWriting == true {
            return
        }
        
        // remove existing file for the url
        do {
            let path = url.path
            // clean up existing file anyway
            do {
                let fileManager = FileManager()
                try fileManager.removeItem(atPath: path)
            } catch {
                // Ignore any error
            }
        }
        
        /* ============================================ */
        
        // start recording
        if let captureMovieFileOutput = captureMovieFileOutput {
            // Using AVCaptureMovieFileOutput
            // Start writing
            captureMovieFileOutput.startRecording(to: url, recordingDelegate: self)
            
            // mark as Recording
            isWriting = true
        } else {
            // Using AVAssetWriter
            // Start writing
            if startRecordingToOutputFileURL(url) == false {
                print("ERROR: Start recording failed.")
                return
            }
            
            // mark as Recording
            isWriting = true
        }
    }
    
    /// Stop recording on current capture session
    public func stopRecording() {
        // check if session is running
        if isReady() == false {
            return
        }
        
        // check if recording is running
        if isWriting == false {
            return
        }
        
        // stop recording
        if let captureMovieFileOutput = captureMovieFileOutput {
            // Using AVCaptureMovieFileOutput
            // Stop writing
            captureMovieFileOutput.stopRecording()
        } else {
            // Using AVAssetWriter
            // Stop writing
            stopRecordingToOutputFile()
        }
        
        // mark as Not Recording
        isWriting = false
    }
    
    /// Regenerate video compression settings using new VideoStyle.
    /// - Parameter newStyle: new VideoStyle
    public func resetVideoStyle(_ newStyle:VideoStyle) {
        resetVideoStyle(newStyle, hOffset:0, vOffset:0)
    }
    
    /// Regenerate video compression settings using new VideoStyle.
    /// Optionally specify clean aperture offset for overscaned SD source.
    /// - Parameters:
    ///   - newStyle: new VideoStyle
    ///   - newHOffset: new clapHOffset (clean aperture offset H)
    ///   - newVOffset: new clapVOffset (clean aperture offset V)
    public func resetVideoStyle(_ newStyle:VideoStyle, hOffset newHOffset:Int, vOffset newVOffset:Int) {
        videoStyle = newStyle
        clapHOffset = newHOffset
        clapVOffset = newVOffset

        resetCompressionSettings()
    }
    
    /// Regenerate compression settins.
    public func resetCompressionSettings() {
        if isRecording() == false {
            // clear autogenerated video/audio compression settings
            videoDeviceCompressedFormat = [:]
            audioDeviceCompressedFormat = [:]
        } else {
            print("ERROR: Compression settings cannot be reset while recording.")
        }
    }
    
    /* ======================================================================================== */
    // MARK: - private session control
    /* ======================================================================================== */
    
    /// Prepare capture session
    /// - Returns: true if no error
    private func prepareSession() -> Bool {
        var inputReady = false
        var outputReady = false
        
        // Verify readiness
        guard captureDeviceVideo == nil && captureDeviceAudio == nil && captureSession == nil
        else {
            print("ERROR: Unexpected session state detected.")
            return false
        }
        
        // Define Capture Device
        if useMuxed {
            //
            if let captureDevice = availableDevice(for: .muxed, uniqueID: uniqueIDmuxed) {
                captureDeviceVideo = captureDevice
                captureDeviceAudio = nil
            } else {
                print("NOTICE: No Muxed device is found.")
            }
        } else {
            //
            if let captureDevice = availableDevice(for: .video, uniqueID: uniqueIDvideo) {
                captureDeviceVideo = captureDevice
            } else {
                print("NOTICE: No Video device is found.")
            }
            //
            if let captureDevice = availableDevice(for: .audio, uniqueID: uniqueIDaudio) {
                captureDeviceAudio = captureDevice
            } else {
                print("NOTICE: No Audio device is found.")
            }
        }
        
        // Verify device availability
        let deviceReadyVideo = (captureDeviceVideo != nil &&
                                captureDeviceVideo!.isInUseByAnotherApplication == false)
        let deviceReadyAudio = (captureDeviceAudio != nil &&
                                captureDeviceAudio!.isInUseByAnotherApplication == false)
        guard (deviceReadyVideo || deviceReadyAudio) else {
            print("ERROR: No AVCaptureDevice is ready.")
            return false
        }
                
        // Init AVCaptureSession
        captureSession = AVCaptureSession()
        if let captureSession = captureSession {
            registerObserver()
            
            captureSession.beginConfiguration()
            
            /* ============================================ */
            
            // For video; Choose larger format
            _ = chooseVideoDeviceFormat() // Ignore any error
            
            // For audio; Choose higher sample rate and multi channel
            _ = chooseAudioDeviceFormat() // Ignore any error
            
            // Add input device
            inputReady = addCaptureDeviceInput()
            
            /* ============================================ */
            
            // Add output procedure
            if usePreset {
                // Using MovieFileOutput
                // NOTE: Use SessionPreset - No fine control is available
                outputReady = addMovieFileOutput(exportPreset)
            } else {
                // Using AVAssetWriter
                // NOTE: For video, we use device native format for extra control
                outputReady = (addVideoDataOutput(decode: debugDecodeVideo) &&
                               addAudioDataOutput(decode: debugDecodeAudio))
            }
            
            /* ============================================ */
            
            // Add preview video (CAlayer)
            _ = addPreviewVideoLayer() // Ignore any error
            
            // Add preview audio (AVCaptureDataOutput)
            _ = addPreviewAudioOutput() // Ignore any error
            
            /* ============================================ */
            
            captureSession.commitConfiguration()
        }
        
        if inputReady && outputReady {
            return true
        } else {
            print("ERROR: Failed to prepare Capture session.")
            return false
        }
    }
    
    /// Start capture session
    /// - Returns: true if no error
    private func startSession() -> Bool {
        if let captureSession = captureSession {
            if (captureSession.isRunning == false) {
                //
                captureSession.startRunning()
            } else {
                // print("NOTICE: Capture session is already running.")
            }
            return true
        }
        
        print("ERROR: Capture session is not ready.")
        return false
    }
    
    /// Stop capture session
    /// - Returns: true if no error
    private func stopSession() -> Bool {
        if let captureSession = captureSession {
            if captureSession.isRunning {
                //
                captureSession.stopRunning()
            } else {
                // print("ERROR: Capture session is not running.")
            }
            return true
        }
        
        print("ERROR: Capture session is not ready.")
        return false
    }
    
    /* ======================================================================================== */
    // MARK: - private session configuration
    /* ======================================================================================== */
    
    /// Prepare decompressed settings for Video Input
    /// - Returns: true if no error
    private func chooseVideoDeviceFormat() -> Bool {
        // For video; Choose larger format, and fixed sample duration if requested
        if let captureDeviceVideo = captureDeviceVideo {
            var bestPixels: Int32 = 0
            var bestFormat: AVCaptureDevice.Format? = nil
            
            let deviceFormats = captureDeviceVideo.formats 
            for format in deviceFormats {
                let formatDescription = format.formatDescription
                let dimmensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                let pixels = dimmensions.width * dimmensions.height
                if pixels >= bestPixels {
                    bestFormat = format
                    bestPixels = pixels
                }
            }
            
            /* ============================================ */
            
            // Update video device with best format
            if let bestFormat = bestFormat {
                do {
                    try captureDeviceVideo.lockForConfiguration()
                    captureDeviceVideo.activeFormat = bestFormat
                    captureDeviceVideo.unlockForConfiguration()
                    
                    // Specify width/height, pixelformat
                    let pixelFormat = pixelFormatType
                    let formatDescription = bestFormat.formatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                    videoDeviceDecompressedFormat = [
                        kCVPixelBufferPixelFormatTypeKey as String:pixelFormat,
                        kCVPixelBufferWidthKey as String:dimensions.width,
                        kCVPixelBufferHeightKey as String:dimensions.height,
                    ]
                    
                    // extract and merge common extensions like colorspace, aspect ratio, cleanaperture, etc.
                    let fdExtensions = CMFormatDescriptionGetExtensions(formatDescription)
                    let commonKeys = CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers() as NSArray
                    if let fdExtensions = fdExtensions as NSDictionary?, let keys = commonKeys as? [String] {
                        for key in keys {
                            if let value = fdExtensions[key] {
                                videoDeviceDecompressedFormat[key] = value
                            }
                        }
                    }
                    videoDeviceDecompressedFormat = convertExtensionsAsVideoSettings(videoDeviceDecompressedFormat)
                    
                    videoSize = CGSize(width: Double(dimensions.width),
                                       height: Double(dimensions.height))
                    return true
                } catch {
                    captureDeviceVideo.unlockForConfiguration()
                }
            } else {
                print("ERROR: No such video format is available.")
            }
        }
        
        return false
    }
    
    /// Prepare decompressed settings for Audio Input
    /// - Returns: true if no error
    private func chooseAudioDeviceFormat() -> Bool {
        // For audio; Choose higher sample rate and multi channel
        if let captureDeviceAudio = captureDeviceAudio {
            var bestFormat: AVCaptureDevice.Format? = nil
            var bestRate: Double = 0.0
            var bestChannelCount: AVAudioChannelCount = 0
            var bestChannelLayoutData: NSData? = nil
            var bestBitsPerChannel: UInt32 = 0
            
            let sampleRateUpper = Double(48000<<3) // 384 kHz
            let sampleRateLower = Double(48000>>3) //   6 kHz
            let sampleRateRange:ClosedRange<Double> = sampleRateLower...sampleRateUpper
            
            let deviceFormats = captureDeviceAudio.formats 
            for deviceFormat in deviceFormats {
                // Get AudioStreamBasicDescription,  and AVAudioFormat/AudioChannelLayout
                var avaf: AVAudioFormat? = nil
                var aclData: NSData? = nil
                var asbd: AudioStreamBasicDescription? = nil
                let audioFormatDescription = deviceFormat.formatDescription
                if let asbd_p = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
                {
                    asbd = asbd_p.pointee
                    
                    var layoutSize: Int = 0
                    if let acl_p = CMAudioFormatDescriptionGetChannelLayout(audioFormatDescription,
                                                                            sizeOut: &layoutSize) {
                        let avacl = AVAudioChannelLayout.init(layout: acl_p)
                        
                        aclData = NSData.init(bytes: UnsafeRawPointer(acl_p),
                                              length: layoutSize)
                        avaf = AVAudioFormat.init(streamDescription:asbd_p,
                                                  channelLayout: avacl)
                    } else {
                        aclData = nil
                        avaf = AVAudioFormat.init(streamDescription:asbd_p)
                    }
                }
                
                // Choose better format
                if let avaf = avaf, let asbd = asbd, sampleRateRange.contains(avaf.sampleRate) {
                    var better = false
                    
                    if avaf.sampleRate > bestRate {
                        better = true
                    } else if avaf.sampleRate == bestRate && avaf.channelCount > bestChannelCount {
                        better = true
                    }
                    
                    if better {
                        bestFormat = deviceFormat
                        
                        bestRate = avaf.sampleRate
                        bestChannelCount = avaf.channelCount
                        bestChannelLayoutData = aclData // can be nil
                        bestBitsPerChannel = asbd.mBitsPerChannel
                    }
                }
            }
            
            /* ============================================ */
            
            // Update audio device with best format
            if let bestFormat = bestFormat {
                do {
                    try captureDeviceAudio.lockForConfiguration()
                    captureDeviceAudio.activeFormat = bestFormat
                    captureDeviceAudio.unlockForConfiguration()
                } catch {
                    captureDeviceAudio.unlockForConfiguration()
                }
                
                // Specify SameRate, SignedInteger, interleaved format when decompressed
                audioDeviceDecompressedFormat = [AVFormatIDKey: kAudioFormatLinearPCM,          // UInt32
                                                 AVSampleRateKey: bestRate,                     // Double
                                                 AVNumberOfChannelsKey: bestChannelCount,       // UInt32
                                                 AVLinearPCMBitDepthKey: bestBitsPerChannel,    // UInt32
                                                 AVLinearPCMIsBigEndianKey: false,              // Bool
                                                 AVLinearPCMIsFloatKey: false,                  // Bool
                                                 AVLinearPCMIsNonInterleaved: false]            // Bool
                if let bestChannelLayoutData = bestChannelLayoutData {
                    audioDeviceDecompressedFormat[AVChannelLayoutKey] = bestChannelLayoutData   // NSData
                }
                
                return true
            } else {
                print("ERROR: No such audio format is available.")
            }
        }
        
        return false
    }
    
    /// Attach Audio/Video input device to capture session
    /// - Returns: true if no error
    private func addCaptureDeviceInput() -> Bool {
        if let captureSession = captureSession {
            if let captureDeviceAudio = captureDeviceAudio {
                //
                captureDeviceInputAudio = try? AVCaptureDeviceInput.init(device: captureDeviceAudio)
                
                if let captureDeviceInputAudio = captureDeviceInputAudio {
                    if captureSession.canAddInput(captureDeviceInputAudio) {
                        //
                        captureSession.addInput(captureDeviceInputAudio)
                    } else {
                        print("ERROR: Failed to captureSession.addInput(captureDeviceInputAudio).")
                        return false
                    }
                }
            }
            if let captureDeviceVideo = captureDeviceVideo {
                //
                captureDeviceInputVideo = try? AVCaptureDeviceInput.init(device: captureDeviceVideo)
                
                if let captureDeviceInputVideo = captureDeviceInputVideo {
                    if captureSession.canAddInput(captureDeviceInputVideo) {
                        //
                        captureSession.addInput(captureDeviceInputVideo)
                    } else {
                        print("ERROR: Failed to captureSession.addInput(captureDeviceInputVideo).")
                        return false
                    }
                }
            }
            if captureSession.inputs.count > 0 {
                return true
            }
        }
        
        print("ERROR: Failed to addCaptureDeviceInput().")
        return false
    }
    
    /// Attach Audio Preview to capture session
    /// - Returns: true if no error
    private func addPreviewAudioOutput() -> Bool {
        if let captureSession = captureSession {
            previewAudioOutput = AVCaptureAudioPreviewOutput()
            if let previewAudioOutput = previewAudioOutput {
                if captureSession.canAddOutput(previewAudioOutput) {
                    //
                    previewAudioOutput.volume = _volume
                    captureSession.addOutput(previewAudioOutput)
                    
                    return true
                }
            }
        }
        
        print("ERROR: Failed to addPreviewAudioOutput().")
        return false
    }
    
    /// Attach Video Preview to capture session
    /// - Returns: true if no error
    private func addPreviewVideoLayer() -> Bool {
        if let captureSession = captureSession {
            //
            previewVideoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            if let layer = previewVideoLayer, layer.connection != nil {
                return true
            }
        }
        
        print("ERROR: Failed to addPreviewVideoLayer().")
        return false
    }
    
    /// Attach Captured Movie File Output using session preset
    /// - Parameter preset: session preset
    /// - Returns: true if no error
    private func addMovieFileOutput(_ preset: AVCaptureSession.Preset) -> Bool {
        if let captureSession = captureSession {
            captureMovieFileOutput = AVCaptureMovieFileOutput()
            if let captureMovieFileOutput = captureMovieFileOutput {
                // Define Captured Movie File Output
                if captureSession.canAddOutput(captureMovieFileOutput) {
                    captureSession.addOutput(captureMovieFileOutput)
                    
                    // Apply session preset
                    if captureSession.canSetSessionPreset(preset) {
                        captureSession.sessionPreset = preset
                        return true
                    } else {
                        print("ERROR: Failed to set SessionPreset \(preset).")
                        return false
                    }
                }
            }
        }
        
        print("ERROR: Failed to addMovieFileOutput().")
        return false
    }
    
    /* ======================================================================================== */
    // MARK: - capture delegate protocol
    /* ======================================================================================== */
    
    /// AVCaptureFileOutputRecordingDelegate Protocol
    /// - Parameters:
    ///   - captureOutput: AVCaptureFileOutput
    ///   - fileURL: output fileURL
    ///   - connections: AVCaptureConnection
    open func fileOutput(_ captureOutput: AVCaptureFileOutput,
                      didStartRecordingTo fileURL: URL,
                      from connections: [AVCaptureConnection]) {
        // print("NOTICE: Capture started.")
    }
    
    /// AVCaptureFileOutputRecordingDelegate Protocol
    /// - Parameters:
    ///   - captureOutput: AVCaptureFileOutput
    ///   - outputFileURL: output fileURL
    ///   - connections: AVCaptureConnection
    ///   - error: Error result if available
    open func fileOutput(_ captureOutput: AVCaptureFileOutput,
                      didFinishRecordingTo outputFileURL: URL,
                      from connections: [AVCaptureConnection], error: Error?) {
        // print("NOTICE: Capture stopped.")
    }
    
    /* ======================================================================================== */
    // MARK: - private support func
    /* ======================================================================================== */
    
    /// Register Notification Observer
    private func registerObserver() {
        guard debugObserver else { return }
        
        print("registerObserver()")
        if let captureSession = captureSession {
            let center = NotificationCenter.default
            let queue = OperationQueue.main
            let handler:(Notification) -> Void = { (notification) in
                let log = notification.debugDescription
                NSLog("Notification: %@", log)
            }
            
            let notificationNames:[Notification.Name] = [
                .AVCaptureSessionRuntimeError,
                .AVCaptureSessionDidStopRunning,
                .AVCaptureSessionDidStartRunning,
                .AVCaptureSessionWasInterrupted,
                .AVCaptureSessionInterruptionEnded,
                .AVCaptureDeviceWasConnected,
                .AVCaptureDeviceWasDisconnected,
            ]
            observers = []
            notificationNames.forEach {
                let observer = center.addObserver(forName: $0, object: captureSession,
                                                  queue: queue, using: handler)
                observers.append(observer)
            }
        }
    }
    
    /// Unregister Notification Observer
    private func unregisterObserver() {
        guard observers.count > 0 else { return }
        
        print("unregisterObserver()")
        let center = NotificationCenter.default
        observers.forEach {
            center.removeObserver($0)
        }
        observers = []
    }
    
    /// Verify the device with specified uniqueID is available and fallback to default
    /// - Parameters:
    ///   - type: AVMediaType to query
    ///   - uniqueID: uniqueID for search
    /// - Returns: Available AVCaptureDevice
    private func availableDevice(for type:AVMediaType, uniqueID: String?) -> AVCaptureDevice? {
        if let uniqueID = uniqueID, let device = AVCaptureDevice(uniqueID: uniqueID) {
            return device
        } else {
            return AVCaptureDevice.default(for: type)
        }
    }
    
    /// Convert some CMFormatDescriptionExtension(s) into AVVideoSettings (Ref: AVVideoSettings.h)
    ///
    /// CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers() returns kCMFormatDescriptionExtension_* keys;
    /// They are alias of kCVImageBuffer*. We need to convert "pasp/clap/colr" using AVVideo*Keys.
    /// - Parameter srcSettings: settings with incompatible Extensions
    /// - Returns: resulted settings
    private func convertExtensionsAsVideoSettings(_ srcSettings:[String:Any] ) -> [String:Any] {
        var settings = srcSettings
        
        // pasp: Convert as AVVideoPixelAspectRatioKey (Ref: AVVideoSettings.h)
        let paspExt = settings[kCMFormatDescriptionExtension_PixelAspectRatio as String]
        if let cfType = paspExt as CFTypeRef?, let paspExt = cfType as? NSDictionary {
            let paspH = paspExt[kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing]
            let paspV = paspExt[kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing]
            if let paspH = paspH, let paspV = paspV {
                //
                let pasp : NSDictionary = [
                    AVVideoPixelAspectRatioHorizontalSpacingKey : paspH,
                    AVVideoPixelAspectRatioVerticalSpacingKey : paspV,
                ]
                settings[AVVideoPixelAspectRatioKey] = pasp
            }
            
            settings.removeValue(forKey: kCMFormatDescriptionExtension_PixelAspectRatio as String)
        }

        // clap: Convert as AVVideoCleanApertureKey (Ref: AVVideoSettings.h)
        // NOTE: clap without offset is ignored
        let clapExt = settings[kCMFormatDescriptionExtension_CleanAperture as String]
        if let cfType = clapExt as CFTypeRef?, let clapExt = cfType as? NSDictionary {
            let clapWidth = clapExt[kCMFormatDescriptionKey_CleanApertureWidth]
            let clapHeight = clapExt[kCMFormatDescriptionKey_CleanApertureHeight]
            let clapOffsetH = clapExt[kCMFormatDescriptionKey_CleanApertureHorizontalOffset]
            let clapOffsetV = clapExt[kCMFormatDescriptionKey_CleanApertureVerticalOffset]
            if let clapWidth = clapWidth, let clapHeight = clapHeight,
               let clapOffsetH = clapOffsetH, let clapOffsetV = clapOffsetV {
                //
                let clap : NSDictionary = [
                    AVVideoCleanApertureWidthKey : clapWidth ,
                    AVVideoCleanApertureHeightKey : clapHeight ,
                    AVVideoCleanApertureHorizontalOffsetKey : clapOffsetH ,
                    AVVideoCleanApertureVerticalOffsetKey : clapOffsetV ,
                ]
                settings[AVVideoCleanApertureKey] = clap
            }
            
            settings.removeValue(forKey: kCMFormatDescriptionExtension_CleanAperture as String)
        }

        // colr: Encapsulate as AVVideoColorPropertiesKey (Ref: AVVideoSettings.h)
        let colrMatrix = settings[kCMFormatDescriptionExtension_YCbCrMatrix as String]
        let colrTransfer = settings[kCMFormatDescriptionExtension_TransferFunction as String]
        let colrPrimaries = settings[kCMFormatDescriptionExtension_ColorPrimaries as String]
        if let colrMatrix = colrMatrix, let colrTransfer = colrTransfer, let colrPrimaries = colrPrimaries {
            //
            let colr : NSDictionary = [
                AVVideoYCbCrMatrixKey:colrMatrix,
                AVVideoTransferFunctionKey:colrTransfer,
                AVVideoColorPrimariesKey:colrPrimaries,
            ]
            settings[AVVideoColorPropertiesKey] = colr
            
            settings.removeValue(forKey: kCMFormatDescriptionExtension_YCbCrMatrix as String)
            settings.removeValue(forKey: kCMFormatDescriptionExtension_TransferFunction as String)
            settings.removeValue(forKey: kCMFormatDescriptionExtension_ColorPrimaries as String)
        }
        
        return settings
    }
    
}
