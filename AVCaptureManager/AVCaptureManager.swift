//
//  AVCaptureManager.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2016/08/07.
//  Copyright © 2016-2022 MyCometG3. All rights reserved.
//
/*
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 * Neither the name of the <MyCometG3> nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <MyCometG3> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import AVFoundation
import VideoToolbox

open class AVCaptureManager : NSObject, AVCaptureFileOutputRecordingDelegate {
    
    /* ======================================================================================== */
    // MARK: - public variables
    /* ======================================================================================== */
    
    /// preview video : CALayer
    open var previewLayer : AVCaptureVideoPreviewLayer? {
        get {
            return previewVideoLayer
        }
    }
    
    /// preview audio : Volume in 0.0 - 1.0 : Float.
    open var volume : Float {
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
    open var duration : Float64 {
        get {
            return _duration
        }
    }
    
    /// query current video deviceID
    open var currentDeviceIDVideo : String? {
        get {
            var deviceID : String? = nil
            if let device = captureDeviceVideo {
                deviceID = device.uniqueID
            }
            return deviceID
        }
    }
    
    /// query current audio deviceID
    open var currentDeviceIDAudio : String? {
        get {
            var deviceID : String? = nil
            if let device = captureDeviceAudio {
                deviceID = device.uniqueID
            }
            return deviceID
        }
    }
    
    // MARK: -
    /*
     * Set before openSession()
     * NOTE: Use closeSession()/openSession() to reflect changes of following
     */
    /// Special flag for muxed stream (Video/Audio muxed). e.g. DV devices
    open var useMuxed : Bool = false
    /// Choose either "AVFoundation's session preset" or "custom compression".
    open var usePreset : Bool = false
    /// Preset for capture session
    open var exportPreset : AVCaptureSession.Preset = .high
    
    /// Debug support - notification
    open var debugObserver : Bool = false
    /// Debug support - trim movie
    open var debugTrimMovie : Bool = false
    
    // MARK: -
    /*
     * Set before startRecording(to:)
     * Set usePreset=false
     * NOTE: Use resetCompressionSettings() to reflect changes of following
     */
    /// Enable VideoTranscode or not
    open var encodeVideo : Bool = true
    /// Enable AudioTranscode or not
    open var encodeAudio : Bool = true
    /// Request deinterlace of input video (depends on decoder feature)
    open var encodeDeinterlace : Bool = true
    /// Choose ProRes or H.264 for VideoTranscode
    open var encodeProRes422 : Bool = true
    /// VideoStyle for encodeVideo==true
    private (set) public var videoStyle : VideoStyle = .SD_720_480_16_9 // SD - DV-NTSC Wide screen
    /// Clean aperture offset - Horizontal
    private (set) public var clapHOffset : Int = 0
    /// Clean aperture offset - Vertical
    private (set) public var clapVOffset : Int = 0
    /// video dimension from input device
    internal (set) public var videoSize : CGSize? = nil
    /// Video resampling support
    open var sampleDurationVideo : CMTime? = nil
    /// Video track timeScale like 30000, 50000, 60000 (per sec)
    open var sampleTimescaleVideo : CMTimeScale = 0
    /// TimeCode track support
    open var timeCodeFormatType: CMTimeCodeFormatType? = nil // Only 'tmcd' or 'tc64' are supported
    /// Callback support to verify/modify for video compression setting
    open var updateVideoSettings : (([String:Any]) -> [String:Any])? = nil
    /// Callback support to verify/modify for audio compression setting
    open var updateAudioSettings : (([String:Any]) -> [String:Any])? = nil
    
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
    open func isReady() -> Bool {
        if let captureSession = captureSession {
            return captureSession.isRunning
        }
        return false
    }
    
    /// Open capture session using default video/audio devices
    /// - Returns: true if no error
    open func openSession() -> Bool {
        return openSessionForUniqueID(muxed: nil, video: nil, audio: nil)
    }
    
    /// Open capture session using specified uniqueID devices.
    /// If device is not available default device will be used instead.
    /// - Parameters:
    ///   - muxedID: muxed device uniqueID
    ///   - videoID: video device uniqueID
    ///   - audioID: audio device uniqueID
    /// - Returns: true if no error
    open func openSessionForUniqueID(muxed muxedID:String?,
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
    open func closeSession() {
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
        
        // reset public parameters (a few)
        videoSize = nil
    }
    
    /// Toggle video preview connection
    /// - Parameter state: Enabled/Disabled state
    open func setVideoPreviewConnection(enabled state: Bool) {
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
    open func isRecording() -> Bool {
        return isWriting
    }
    
    /// Start recording on current capture session
    /// - Parameter url: file URL to write movie
    open func startRecording(to url: URL) {
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
    open func stopRecording() {
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
    open func resetVideoStyle(_ newStyle:VideoStyle) {
        resetVideoStyle(newStyle, hOffset:0, vOffset:0)
    }
    
    /// Regenerate video compression settings using new VideoStyle.
    /// Optionally specify clean aperture offset for overscaned SD source.
    /// - Parameters:
    ///   - newStyle: new VideoStyle
    ///   - newHOffset: new clapHOffset (clean aperture offset H)
    ///   - newVOffset: new clapVOffset (clean aperture offset V)
    open func resetVideoStyle(_ newStyle:VideoStyle, hOffset newHOffset:Int, vOffset newVOffset:Int) {
        videoStyle = newStyle
        clapHOffset = newHOffset
        clapVOffset = newVOffset

        resetCompressionSettings()
    }
    
    /// Regenerate compression settins.
    open func resetCompressionSettings() {
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
                outputReady = addVideoDataOutput(decode: false) && addAudioDataOutput(decode: true)
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
                    let pixelFormat = kCMPixelFormat_422YpCbCr8 // TODO:
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
    
}
