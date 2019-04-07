//
//  AVCaptureManager.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2016/08/07.
//  Copyright © 2016年 MyCometG3. All rights reserved.
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

import Cocoa
import AVFoundation
import VideoToolbox

open class AVCaptureManager : NSObject, AVCaptureFileOutputRecordingDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    /* ======================================================================================== */
    // MARK: - public variables
    /* ======================================================================================== */
    
    // preview video : CALayer
    open var previewLayer : AVCaptureVideoPreviewLayer? {
        get {
            return previewVideoLayer
        }
    }
    
    // preview audio : Volume in 0.0 - 1.0 : Float.
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
    
    // recording duration in second : Float64.
    open var duration : Float64 {
        get {
            return _duration
        }
    }
    
    // query current video deviceID
    open var currentDeviceIDVideo : String? {
        get {
            var deviceID : String? = nil
            if let device = captureDeviceVideo {
                deviceID = device.uniqueID
            }
            return deviceID
        }
    }
    
    // query current audio deviceID
    open var currentDeviceIDAudio : String? {
        get {
            var deviceID : String? = nil
            if let device = captureDeviceAudio {
                deviceID = device.uniqueID
            }
            return deviceID
        }
    }
    
    // Set before openSession()
    open var useMuxed : Bool = false
    open var usePreset : Bool = false
    open var exportPreset : AVCaptureSession.Preset = .high
    
    // Set before openSession() - usePreset=false
    open var sampleDurationVideo : CMTime? = nil
    
    // Set before startRecording(to:) - usePreset=false
    open var encodeVideo : Bool = true
    open var encodeAudio : Bool = true
    open var encodeDeinterlace : Bool = true
    open var encodeProRes422 : Bool = true
    open var videoStyle : VideoStyle = .SD_720_480_16_9 // SD - DV-NTSC Wide screen
    open var clapHOffset : Int = 0
    open var clapVOffset : Int = 0
    open var videoSize : CGSize? = nil
    open var sampleTimescaleVideo : CMTimeScale = 0
    open var timeCodeFormatType: CMTimeCodeFormatType? = nil // Only 'tmcd' or 'tc64' are supported

    // Called before AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
    open var updateVideoSettings : (([String:Any]) -> [String:Any])? = nil
    // Called before AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
    open var updateAudioSettings : (([String:Any]) -> [String:Any])? = nil
    
    /* ======================================================================================== */
    // MARK: - private variables
    /* ======================================================================================== */
    
    private var captureSession : AVCaptureSession? = nil
    
    private var captureDeviceVideo : AVCaptureDevice? = nil
    private var captureDeviceAudio : AVCaptureDevice? = nil
    
    private var captureDeviceInputAudio : AVCaptureDeviceInput? = nil
    private var captureDeviceInputVideo : AVCaptureDeviceInput? = nil
    
    private var captureMovieFileOutput : AVCaptureMovieFileOutput? = nil
    private var captureVideoDataOutput : AVCaptureVideoDataOutput? = nil
    private var captureAudioDataOutput : AVCaptureAudioDataOutput? = nil
    
    private var previewAudioOutput : AVCaptureAudioPreviewOutput? = nil
    private var previewVideoLayer : AVCaptureVideoPreviewLayer? = nil
    private var previewVideoConnection : AVCaptureConnection? = nil
    
    private var avAssetWriter : AVAssetWriter? = nil
    private var avAssetWriterInputVideo : AVAssetWriterInput? = nil
    private var avAssetWriterInputAudio : AVAssetWriterInput? = nil
    private var avAssetWriterInputTimeCode : AVAssetWriterInput? = nil
    
    private var decompressor : VideoDecompressor? = nil
    
    //
    private var startTime : CMTime = CMTime.zero
    private var endTime : CMTime = CMTime.zero
    private var isInitialTSReady : Bool = false
    private var _duration  : Float64 = 0.0
    
    //
    private var _volume : Float = 1.0
    
    //
    private var uniqueIDmuxed : String? = nil
    private var uniqueIDvideo : String? = nil
    private var uniqueIDaudio : String? = nil
    
    private let smpteTimeKey : String = "com.apple.cmio.buffer_attachment.core_audio_smpte_time"
    private var smpteReady : Bool = false
    
    private var isWriting : Bool = false
    
    private var audioDeviceDecompressedFormat : [String:Any] = [:]
    private var audioDeviceCompressedFormat : [String:Any] = [:]
    
    /* ======================================================================================== */
    // MARK: - public session API
    /* ======================================================================================== */
    
    open func isReady() -> Bool {
        if let captureSession = captureSession {
            return captureSession.isRunning
        }
        return false
    }
    
    open func openSession() -> Bool {
        return openSessionForUniqueID(muxed: nil, video: nil, audio: nil)
    }
    
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
            startSession()
            
            return true
        }
        
        print("ERROR: Failed to start session.")
        return false
    }
    
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
        stopSession()
        
        // unref AVAssetWriter
        avAssetWriterInputTimeCode = nil
        avAssetWriterInputVideo = nil
        avAssetWriterInputAudio = nil
        avAssetWriter = nil
        
        // unref AVCaptureXXXXXPreviewXXXX
        previewVideoConnection = nil
        previewVideoLayer = nil
        previewAudioOutput = nil
        
        // unref AVCaptureOutput
        captureMovieFileOutput = nil
        captureVideoDataOutput = nil
        captureAudioDataOutput = nil
        
        // unref AVCaptureDeviceInput
        captureDeviceInputVideo = nil
        captureDeviceInputAudio = nil
        
        // unref AVCaptureDevice
        captureDeviceVideo = nil
        captureDeviceAudio = nil
        
        // unref AVCaptureSession
        captureSession = nil
        
        // reset other private parameters
        startTime = CMTime.zero
        endTime = CMTime.zero
        isInitialTSReady = false
        _volume = 1.0
        _duration = 0.0
        uniqueIDmuxed = nil
        uniqueIDvideo = nil
        uniqueIDaudio = nil
        smpteReady = false
        isWriting = false
        audioDeviceCompressedFormat = [:]
        audioDeviceDecompressedFormat = [:]
        
        // reset public parameters (a few)
        videoSize = nil
    }
    
    open func setVideoPreviewConnection(enabled state: Bool) {
        // NOTE: This func seems heavy operation for previewVideo - previewAudio could got stuttering
        #if true
            if let connection = previewVideoConnection {
                if connection.isEnabled != state {
                    connection.isEnabled = state
                }
            }
        #else
            if  let session = captureSession,
                let layer = previewVideoLayer,
                let connection = previewVideoConnection
            {
                if state && layer.connection == nil {
                    session.beginConfiguration()
                    session.addConnection(connection)
                    session.commitConfiguration()
                }
                if !state && layer.connection != nil {
                    session.beginConfiguration()
                    session.removeConnection(connection)
                    session.commitConfiguration()
                }
            }
        #endif
    }
    
    /* ======================================================================================== */
    // MARK: - public recording API
    /* ======================================================================================== */
    
    open func isRecording() -> Bool {
        return isWriting
    }
    
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
    
    /* ======================================================================================== */
    // MARK: - private session control
    /* ======================================================================================== */
    
    private func prepareSession() -> Bool {
        var inputReady = false
        var outputReady = false
        
        captureSession = AVCaptureSession()
        
        if let captureSession = captureSession {
            captureSession.beginConfiguration()
            
            /* ============================================ */
            
            // Define Capture Device
            if useMuxed {
                //
                if let uniqueIDmuxed = uniqueIDmuxed {
                    let captureDevice : AVCaptureDevice? = AVCaptureDevice(uniqueID: uniqueIDmuxed)
                    captureDeviceVideo = captureDevice
                    captureDeviceAudio = nil
                } else {
                    let captureDevice : AVCaptureDevice? = AVCaptureDevice.default(for: AVMediaType.muxed)
                    captureDeviceVideo = captureDevice
                    captureDeviceAudio = nil
                }
            } else {
                //
                if let uniqueIDvideo = uniqueIDvideo {
                    captureDeviceVideo = AVCaptureDevice(uniqueID: uniqueIDvideo)
                } else {
                    captureDeviceVideo = AVCaptureDevice.default(for: AVMediaType.video)
                }
                if let uniqueIDaudio = uniqueIDaudio {
                    captureDeviceAudio = AVCaptureDevice(uniqueID: uniqueIDaudio)
                } else {
                    captureDeviceAudio = AVCaptureDevice.default(for: AVMediaType.audio)
                }
            }
            
            /* ============================================ */
            
            // For video; Choose larger format, and fixed sample duration if requested
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
            
            // Add preview video (CAlayer)
            _ = addPreviewVideoLayer() // Ignore any error
            
            // Add preview audio (AVCaptureDataOutput)
            _ = addPreviewAudioOutput() // Ignore any error
            
            /* ============================================ */
            
            captureSession.commitConfiguration()
            
            if inputReady && outputReady {
                return true
            }
        }
        
        print("ERROR: Failed to prepare Capture session.")
        return false
    }
    
    private func startSession() {
        if let captureSession = captureSession {
            if (captureSession.isRunning == false) {
                // Reset video encoded size
                videoSize = nil
                
                //
                captureSession.startRunning()
                
                return
            }
            // print("ERROR: Capture session is already running.")
            return
        }
        
        print("ERROR: Capture session is not ready.")
    }
    
    private func stopSession() {
        if let captureSession = captureSession {
            if captureSession.isRunning {
                //
                captureSession.stopRunning()
                
                // Reset video encoded size
                videoSize = nil
                
                return
            }
            // print("ERROR: Capture session is not running.")
            return
        }
        
        print("ERROR: Capture session is not ready.")
    }
    
    /* ======================================================================================== */
    // MARK: - private session configuration
    /* ======================================================================================== */
    
    private func chooseVideoDeviceFormat() -> Bool {
        // For video; Choose larger format, and fixed sample duration if requested
        if let captureDeviceVideo = captureDeviceVideo {
            var bestPixels: Int32 = 0
            var bestFormat: AVCaptureDevice.Format? = nil
            
            let deviceFormats = captureDeviceVideo.formats 
            for format in deviceFormats {
                var betterOrSame = false
                
                do {
                    let formatDescription = format.formatDescription
                    let dimmensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                    let pixels = dimmensions.width * dimmensions.height
                    if pixels >= bestPixels {
                        betterOrSame = true
                        bestPixels = pixels
                    }
                }
                
                if let sampleDurationVideo = sampleDurationVideo {
                    var supported = false
                    
                    let rangeArray = format.videoSupportedFrameRateRanges
                    for range in rangeArray {
                        let requested = CMTimeGetSeconds(sampleDurationVideo)
                        let max = CMTimeGetSeconds(range.maxFrameDuration)
                        let min = CMTimeGetSeconds(range.minFrameDuration)
                        if max >= requested && requested >= min {
                            supported = true
                            break
                        }
                    }
                    
                    if betterOrSame && supported {
                        bestFormat = format
                    }
                } else {
                    if betterOrSame {
                        bestFormat = format
                    }
                }
            }
            
            /* ============================================ */
            
            // Update video device with best format
            if let bestFormat = bestFormat {
                do {
                    try captureDeviceVideo.lockForConfiguration()
                    captureDeviceVideo.activeFormat = bestFormat
                    if let sampleDurationVideo = sampleDurationVideo {
                        captureDeviceVideo.activeVideoMinFrameDuration = sampleDurationVideo
                        captureDeviceVideo.activeVideoMaxFrameDuration = sampleDurationVideo
                    }
                    captureDeviceVideo.unlockForConfiguration()
                    
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
    
    private func chooseAudioDeviceFormat() -> Bool {
        // For audio; Choose higher sample rate and multi channel
        if let captureDeviceAudio = captureDeviceAudio {
            var bestFormat: AVCaptureDevice.Format? = nil
            var bestRate: Double = 0.0
            var bestChannelCount: AVAudioChannelCount = 0
            var bestChannelLayoutData: NSData? = nil
            var bestBitsPerChannel: UInt32 = 0
            
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
                if let avaf = avaf, let asbd = asbd {
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
                audioDeviceDecompressedFormat = [AVFormatIDKey: Int(kAudioFormatLinearPCM),
                                                 AVSampleRateKey: Float(bestRate),
                                                 AVNumberOfChannelsKey: Int(bestChannelCount),
                                                 AVLinearPCMBitDepthKey: Int(bestBitsPerChannel),
                                                 AVLinearPCMIsBigEndianKey: false,
                                                 AVLinearPCMIsFloatKey: false,
                                                 AVLinearPCMIsNonInterleaved: false]
                if let bestChannelLayoutData = bestChannelLayoutData {
                    audioDeviceDecompressedFormat[AVChannelLayoutKey] = bestChannelLayoutData
                }
                
                return true
            } else {
                print("ERROR: No such audio format is available.")
            }
        }
        
        return false
    }
    
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
    
    private func addPreviewVideoLayer() -> Bool {
        if let captureSession = captureSession {
            //
            previewVideoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewVideoConnection = previewVideoLayer?.connection
            
            if previewVideoLayer != nil && previewVideoConnection != nil {
                return true
            }
        }
        
        print("ERROR: Failed to addPreviewVideoLayer().")
        return false
    }
    
    private func addMovieFileOutput(_ preset: AVCaptureSession.Preset) -> Bool {
        if let captureSession = captureSession {
            if captureSession.canSetSessionPreset(preset) {
                //
                captureSession.sessionPreset = preset
            } else {
                print("ERROR: Failed to set SessionPreset \(preset).")
            }
            
            captureMovieFileOutput = AVCaptureMovieFileOutput()
            if let captureMovieFileOutput = captureMovieFileOutput {
                //
                captureSession.addOutput(captureMovieFileOutput)
                
                return true
            }
        }
        
        print("ERROR: Failed to addMovieFileOutput().")
        return false
    }
    
    private func addVideoDataOutput(decode decompress: Bool) -> Bool {
        // Define Captured Video Data format (device native or decompressed format)
        
        captureVideoDataOutput = AVCaptureVideoDataOutput()
        if let captureVideoDataOutput = captureVideoDataOutput, let captureSession = captureSession {
            // Register video setting
            if decompress == false {
                // No transcode required (device native format)
                captureVideoDataOutput.videoSettings = [:]
            } else {
                // Transcode required (default decompressed format)
                captureVideoDataOutput.videoSettings = nil
            }
            
            // Register dispatch queue for video
            let queue : DispatchQueue = DispatchQueue(label: "my video queue", attributes: [])
            captureVideoDataOutput.setSampleBufferDelegate(self, queue: queue)
            
            // Define Captured Video Data Output
            let valid = captureSession.canAddOutput(captureVideoDataOutput)
            if valid {
                //
                captureSession.addOutput(captureVideoDataOutput)
                return true
            }
        }
        
        print("ERROR: Failed to addVideoDataOutput().")
        return false
    }
    
    private func addAudioDataOutput(decode decompress: Bool) -> Bool {
        // Define Captured Audio Data format (device native or decompressed format)
        
        captureAudioDataOutput = AVCaptureAudioDataOutput()
        if let captureAudioDataOutput = captureAudioDataOutput, let captureSession = captureSession {
            // Register audio setting
            if decompress == false || audioDeviceDecompressedFormat.count == 0 {
                // No transcode required (device native format)
                captureAudioDataOutput.audioSettings = nil
            } else {
                // Transcode required (default decompressed format)
                captureAudioDataOutput.audioSettings = audioDeviceDecompressedFormat
            }
            
            // Register dispatch queue for audio
            let queue : DispatchQueue = DispatchQueue(label: "my audio queue", attributes: [])
            captureAudioDataOutput.setSampleBufferDelegate(self, queue: queue)
            
            // Define Captured Audio Data Output
            let valid = captureSession.canAddOutput(captureAudioDataOutput)
            if valid {
                //
                captureSession.addOutput(captureAudioDataOutput)
                return true
            }
        }
        
        print("ERROR: Failed to addAudioDataOutput().")
        return false
    }
    
    /* ======================================================================================== */
    // MARK: - private recording control
    /* ======================================================================================== */
    
    private func startRecordingToOutputFileURL(_ fileUrl : URL) -> Bool {
        // unref previous AVAssetWriter and decompressor
        avAssetWriterInputVideo = nil
        avAssetWriterInputAudio = nil
        avAssetWriterInputTimeCode = nil
        avAssetWriter = nil
        decompressor = nil
        
        // reset TS variables and duration
        isInitialTSReady = false
        startTime = CMTime.zero
        endTime = CMTime.zero
        _duration = 0.0
        
        // Create AVAssetWriter for QuickTime Movie
        avAssetWriter = try? AVAssetWriter.init(outputURL: fileUrl, fileType: AVFileType.mov)
        
        /* ============================================ */
        
        if let avAssetWriter = avAssetWriter {
            if encodeVideo == false {
                // Create AVAssetWriterInput for Video (Passthru)
                avAssetWriterInputVideo = AVAssetWriterInput(mediaType: AVMediaType.video,
                                                             outputSettings: nil)
            } else {
                // Create OutputSettings for Video (Compress)
                let videoOutputSettings : [String:Any] = createOutputSettingsVideo()
                
                // Validate settings for Video
                if avAssetWriter.canApply(outputSettings: videoOutputSettings, forMediaType: AVMediaType.video) {
                    // Create AVAssetWriterInput for Video (Compress)
                    avAssetWriterInputVideo = AVAssetWriterInput(mediaType: AVMediaType.video,
                                                                 outputSettings: videoOutputSettings)
                } else {
                    print("ERROR: videoOutputSettings is not OK")
                    return false
                }
            }
            
            // Apply preferred video media timescale
            if sampleTimescaleVideo > 0, let avAssetWriterInputVideo = avAssetWriterInputVideo {
                avAssetWriterInputVideo.mediaTimeScale = sampleTimescaleVideo
            }
            
            /* ============================================ */
            
            if encodeAudio == false {
                // Create AVAssetWriterInput for Audio (Passthru)
                avAssetWriterInputAudio = AVAssetWriterInput(mediaType: AVMediaType.audio,
                                                             outputSettings: nil)
            } else {
                // Create OutputSettings for Audio (Compress)
                let audioOutputSettings : [String:Any] = createOutputSettingsAudio()
                
                // Validate settings for Audio
                if avAssetWriter.canApply(outputSettings: audioOutputSettings, forMediaType: AVMediaType.audio) {
                    // Create AVAssetWriterInput for Audio (Compress)
                    avAssetWriterInputAudio = AVAssetWriterInput(mediaType: AVMediaType.audio,
                                                                 outputSettings: audioOutputSettings)
                } else {
                    print("ERROR: audioOutputSettings is not OK")
                    return false
                }
            }
            
            /* ============================================ */
            
            if timeCodeFormatType != nil && smpteReady {
                // Create AVAssetWriterInput for Timecode (SMPTE)
                avAssetWriterInputTimeCode = AVAssetWriterInput(mediaType: AVMediaType.timecode,
                                                                outputSettings: nil)
                
                if let inputVideo = avAssetWriterInputVideo, let inputTimeCode = avAssetWriterInputTimeCode {
                    inputVideo.addTrackAssociation(withTrackOf: inputTimeCode,
                                                   type: AVAssetTrack.AssociationType.timecode.rawValue)
                }
            }
            
            /* ============================================ */
            
            // Register AVAssetWriterInput(s) to AVAssetWriter
            var videoReady = false
            var audioReady = false
            if let avAssetWriterInputVideo = avAssetWriterInputVideo {
                if avAssetWriter.canAdd(avAssetWriterInputVideo) {
                    avAssetWriterInputVideo.expectsMediaDataInRealTime = true
                    avAssetWriter.add(avAssetWriterInputVideo)
                    videoReady = true
                } else {
                    print("ERROR: avAssetWriter.addInput(avAssetWriterInputVideo)")
                }
            }
            if let avAssetWriterInputAudio = avAssetWriterInputAudio {
                if avAssetWriter.canAdd(avAssetWriterInputAudio) {
                    avAssetWriterInputAudio.expectsMediaDataInRealTime = true
                    avAssetWriter.add(avAssetWriterInputAudio)
                    audioReady = true
                } else {
                    print("ERROR: avAssetWriter.addInput(avAssetWriterInputAudio)")
                }
            }
            if timeCodeFormatType != nil && smpteReady {
                if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCode {
                    if avAssetWriter.canAdd(avAssetWriterInputTimeCode) {
                        avAssetWriterInputTimeCode.expectsMediaDataInRealTime = true
                        avAssetWriter.add(avAssetWriterInputTimeCode)
                    } else {
                        print("ERROR: avAssetWriter.add(avAssetWriterInputTimeCode)")
                    }
                }
            }
            
            /* ============================================ */
            
            if videoReady || audioReady {
                let valid = avAssetWriter.startWriting()
                return valid
            }
        }
        
        print("ERROR: Failed to init AVAssetWriter.")
        return false
    }
    
    private func stopRecordingToOutputFile() {
        if let avAssetWriter = avAssetWriter {
            // Finish writing
            if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCode {
                avAssetWriterInputTimeCode.markAsFinished()
            }
            if let avAssetWriterInputVideo = avAssetWriterInputVideo {
                avAssetWriterInputVideo.markAsFinished()
            }
            if let avAssetWriterInputAudio = avAssetWriterInputAudio {
                avAssetWriterInputAudio.markAsFinished()
            }
            
            avAssetWriter.endSession(atSourceTime: endTime)
            avAssetWriter.finishWriting(
                completionHandler: { [unowned self] () -> Void in
                    if let decompressor = self.decompressor {
                        // Clean up
                        decompressor.flush()
                        decompressor.invalidate()
                        
                        // unref decompressor
                        self.decompressor = nil
                    }
                    
                    if let avAssetWriter = self.avAssetWriter {
                        // Check if completed
                        if avAssetWriter.status != .completed {
                            // In case of faulty state
                            let statusStr = self.descriptionForStatus(avAssetWriter.status)
                            print("ERROR: AVAssetWriter.finishWritingWithCompletionHandler() = \(statusStr)")
                            print("ERROR: \(avAssetWriter.error as Optional)")
                        }
                        
                        // Reset CMTime values
                        if self.isInitialTSReady == true {
                            //print("### Reset InitialTS for session")
                            self._duration = CMTimeGetSeconds(CMTimeSubtract(self.endTime, self.startTime))
                            self.isInitialTSReady = false
                            self.startTime = CMTime.zero
                            self.endTime = CMTime.zero
                        }
                        
                        // unref AVAssetWriter
                        self.avAssetWriterInputTimeCode = nil
                        self.avAssetWriterInputVideo = nil
                        self.avAssetWriterInputAudio = nil
                        self.avAssetWriter = nil
                    }
                }
            )
        }
    }
    
    private func createOutputSettingsVideo() -> [String:Any] {
        // Create OutputSettings for Video (Compress)
        var videoOutputSettings : [String:Any] = [:]
        
        // VidoStyle string and clap:hOffset value
        videoOutputSettings = videoStyle.settings(hOffset: clapHOffset, vOffset: clapVOffset)
        
        // video hardware encoder
        let encoderSpecification: [NSString: Any] = [
            kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder : kCFBooleanTrue!,
            kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder : kCFBooleanFalse!
        ]
        videoOutputSettings[AVVideoEncoderSpecificationKey] = encoderSpecification
        
        // video output codec
        if encodeProRes422 {
            videoOutputSettings[AVVideoCodecKey] = AVVideoCodecAppleProRes422
            
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422HQ)
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422)
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422LT)
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422Proxy)
        } else {
            videoOutputSettings[AVVideoCodecKey] = AVVideoCodecH264
            
            #if false
                // For H264 encoder (using Main 3.1 maximum bitrate)
                videoOutputSettings[AVVideoCompressionPropertiesKey] = [
                    AVVideoAverageBitRateKey : 14*1000*1000,
                    AVVideoMaxKeyFrameIntervalKey : 29,
                    AVVideoMaxKeyFrameIntervalDurationKey : 1.0,
                    AVVideoAllowFrameReorderingKey : true,
                    AVVideoProfileLevelKey : AVVideoProfileLevelH264Main31,
                    AVVideoH264EntropyModeKey : AVVideoH264EntropyModeCABAC,
                    AVVideoExpectedSourceFrameRateKey : 30,
                    //AVVideoAverageNonDroppableFrameRateKey : 10,
                ]
            #endif
        }
        
        // Check if user want to customize settings
        if let updateVideoSettings = updateVideoSettings {
            // Call optional updateVideoSettings block
            videoOutputSettings = updateVideoSettings(videoOutputSettings)
        }
        
        return videoOutputSettings
    }
    
    private func createOutputSettingsAudio() -> [String:Any] {
        // Create OutputSettings for Audio (Compress)
        var audioOutputSettings : [String:Any] = [:]
        
        if audioDeviceCompressedFormat.count == 0 {
            audioOutputSettings[AVFormatIDKey] = NSNumber.init(value: kAudioFormatMPEG4AAC as UInt32)
            audioOutputSettings[AVSampleRateKey] = 48000
            audioOutputSettings[AVNumberOfChannelsKey] = 2
            audioOutputSettings[AVEncoderBitRateKey] = 256*1024
            //audioOutputSettings[AVEncoderAudioQualityKey] = AVAudioQuality.Max
            audioOutputSettings[AVEncoderBitRateStrategyKey] = AVAudioBitRateStrategy_Constant
            //audioOutputSettings[AVSampleRateConverterAlgorithmKey] = AVSampleRateConverterAlgorithm_Mastering
        } else {
            audioOutputSettings = audioDeviceCompressedFormat
        }
        
        // Check if user want to customize settings
        if let updateAudioSettings = updateAudioSettings {
            // Call optional updateAudioSettings block
            audioOutputSettings = updateAudioSettings(audioOutputSettings)
        }
        
        // Clipping for kAudioFormatMPEG4AAC
        if (audioOutputSettings[AVSampleRateKey] as! Float) > 48000.0 {
            // kAudioFormatMPEG4AAC runs up to 48KHz
            audioOutputSettings[AVSampleRateKey] = 48000
        }
        if (audioOutputSettings[AVEncoderBitRateKey] as! Int) > 320*1024 {
            // kAudioFormatMPEG4AAC runs up to 320Kbps
            audioOutputSettings[AVSampleRateKey] = 320*1024
        }
        
        return audioOutputSettings
    }
    
    /* ======================================================================================== */
    // MARK: - capture delegate protocol
    /* ======================================================================================== */
    
    // AVCaptureFileOutputRecordingDelegate Protocol
    open func fileOutput(_ captureOutput: AVCaptureFileOutput,
                      didStartRecordingTo fileURL: URL,
                      from connections: [AVCaptureConnection]) {
        // print("NOTICE: Capture started.")
    }
    
    // AVCaptureFileOutputRecordingDelegate Protocol
    open func fileOutput(_ captureOutput: AVCaptureFileOutput,
                      didFinishRecordingTo outputFileURL: URL,
                      from connections: [AVCaptureConnection], error: Error?) {
        // print("NOTICE: Capture stopped.")
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate Protocol
    // AVCaptureAudioDataOutputSampleBufferDelegate Protocol
    open func captureOutput(_ captureOutput: AVCaptureOutput,
                            didOutput sampleBuffer: CMSampleBuffer,
                            from connection: AVCaptureConnection) {
        //
        let recording = self.isWriting
        let forAudio = (captureOutput == self.captureAudioDataOutput)
        let forVideo = (captureOutput == self.captureVideoDataOutput)
        
        // Query SampleBuffer Information
        let bufferReady = CMSampleBufferDataIsReady(sampleBuffer)
        
        /* ============================================ */
        
        if forAudio && audioDeviceCompressedFormat.count == 0 {
            // Extract AudioFormatDescription and create compressed format settings
            if  let audioFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
                let asbd_p = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
            {
                //let asbd = asbd_p.pointee
                var avaf: AVAudioFormat? = nil
                var aclData: NSData? = nil
                var layoutSize: Int = 0
                if let acl_p = CMAudioFormatDescriptionGetChannelLayout(audioFormatDescription,
                                                                        sizeOut: &layoutSize) {
                    let avacl = AVAudioChannelLayout.init(layout: acl_p)
                    avaf = AVAudioFormat.init(streamDescription:asbd_p,
                                              channelLayout: avacl)
                    aclData = NSData.init(bytes: UnsafeRawPointer(acl_p),
                                          length: layoutSize)
                } else {
                    avaf = AVAudioFormat.init(streamDescription:asbd_p)
                    aclData = nil
                }
                
                // Create default compressed format
                if let avaf = avaf {
                    audioDeviceCompressedFormat = [
                        AVFormatIDKey: NSNumber.init(value: kAudioFormatMPEG4AAC as UInt32),
                        AVSampleRateKey: Float(avaf.sampleRate),
                        AVNumberOfChannelsKey: Int(avaf.channelCount),
                        AVEncoderBitRateKey: Int(256*1024),
                        AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Constant
                    ]
                    if let aclData = aclData {
                        audioDeviceCompressedFormat[AVChannelLayoutKey] = aclData
                    }
                }
            }
        }
        
        /* ============================================ */
        
        if forVideo {
            // Update raw width/height
            if videoSize == nil {
                videoSize = encodedSizeOfSampleBuffer(sampleBuffer)
            }
            
            // Extract sampleBuffer attachment for SMPTETime
            let smpteTimeData = CMGetAttachment(sampleBuffer,
                                                key: smpteTimeKey as CFString,
                                                attachmentModeOut: nil)
            if smpteTimeData != nil {
                smpteReady = true
            } else {
                smpteReady = false
            }
        }
        
        /* ============================================ */
        
        // Handle Audio SampleBuffer
        if forAudio, let _ = avAssetWriterInputAudio {
            // printDescriptionAudioBuffer(sampleBuffer)
            
            // Check AssetWriter is ready
            if recording && bufferReady {
                // Write sampleBuffer out
                writeAudioSampleBuffer(sampleBuffer)
                return
            }
            
            // On start/stop, some sample buffer will be dropped.
            // print("ERROR: Dropped a Audio SampleBuffer. - Not Ready.")
        }
        
        /* ============================================ */
        
        // Handle Video SampleBuffer
        if forVideo, let _ = avAssetWriterInputVideo {
            // printDescritionImageBuffer(sampleBuffer)
            
            // Check AssetWriter is ready
            if recording && bufferReady {
                var needDecompressor = false
                if encodeVideo {
                    // Transcode is requested.
                    
                    // Check if sampleBuffer has decompressed image
                    if let _ = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        // Decompressed imageBuffer - no decompressor is needed.
                        needDecompressor = false
                    } else {
                        // Compressed dataBuffer - decompressor is needed.
                        needDecompressor = true
                        
                        // Check decompressor is ready
                        if checkdecompressor(sampleBuffer) == false {
                            print("ERROR: Internal error - No decompressor is ready.")
                            return
                        }
                    }
                } else {
                    // No transcode is required - Keep native format for video
                }
                
                // Write sampleBuffer out
                if needDecompressor {
                    if let decompressor = decompressor {
                        _ = decompressor.decode(sampleBuffer)
                    } else {
                        print("ERROR: Internal error - No decompressor is ready.")
                    }
                } else {
                    writeVideoSampleBuffer(sampleBuffer)
                }
                
                // Timecode track support
                if timeCodeFormatType != nil && smpteReady {
                    if let sampleBufferTimeCode = createTimeCodeSampleBuffer(from: sampleBuffer) {
                        writeTimecodeSampleBuffer(sampleBufferTimeCode)
                    }
                }
                
                return
            }
            
            // On start/stop, some sample buffer will be dropped.
            // print("ERROR: Dropped a Video SampleBuffer. - Not Ready.")
        }
    }
    
    internal func writeAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputAudio = avAssetWriterInputAudio {
            if avAssetWriterInputAudio.isReadyForMoreMediaData {
                //
                updateTimeStamp(sampleBuffer)
                let result = avAssetWriterInputAudio.append(sampleBuffer)
                
                if result == false {
                    let statusStr : String = descriptionForStatus(avAssetWriter!.status)
                    print("ERROR: Could not write audio sample buffer.(\(statusStr))")
                    //print("ERROR: \(avAssetWriter!.error)")
                }
            } else {
                //print("ERROR: AVAssetWriterInputAudio is not ready to append.")
            }
        }
    }
    
    internal func writeVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputVideo = avAssetWriterInputVideo {
            if avAssetWriterInputVideo.isReadyForMoreMediaData {
                //
                updateTimeStamp(sampleBuffer)
                let result = avAssetWriterInputVideo.append(sampleBuffer)
                
                if result == false {
                    let statusStr : String = descriptionForStatus(avAssetWriter!.status)
                    print("ERROR: Could not write video sample buffer.(\(statusStr))")
                    //print("ERROR: \(avAssetWriter!.error)")
                }
            } else {
                //print("ERROR: AVAssetWriterInputVideo is not ready to append.")
            }
        }
    }
    
    internal func writeTimecodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCode {
            if avAssetWriterInputTimeCode.isReadyForMoreMediaData {
                //
                updateTimeStamp(sampleBuffer)
                let result = avAssetWriterInputTimeCode.append(sampleBuffer)
                
                if result == false {
                    let statusStr : String = descriptionForStatus(avAssetWriter!.status)
                    print("ERROR: Could not write timecode sample buffer.(\(statusStr))")
                    //print("ERROR: \(avAssetWriter!.error)")
                }
            } else {
                //print("ERROR: AVAssetWriterInputTimecode is not ready to append.")
            }
        }
    }
    
    /* ======================================================================================== */
    // MARK: - private Timecode support func
    /* ======================================================================================== */
    
    private func createTimeCodeSampleBuffer(from videoSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        // Extract SMPTETime from video sample
        guard let smpteTime = extractCVSMPTETime(from: videoSampleBuffer)
            else { return nil }
        
        // Check CMTimeCodeFormatType
        var sizes: Int = 0
        if let timeCodeFormatType = timeCodeFormatType {
            switch timeCodeFormatType {
            case kCMTimeCodeFormatType_TimeCode32: sizes = MemoryLayout<Int32>.size // tmcd 32bit
            case kCMTimeCodeFormatType_TimeCode64: sizes = MemoryLayout<Int64>.size // tc64 64bit
            default:
                print("ERROR: Unsupported CMTimeCodeFormatType detected.")
                return nil
            }
        } else {
            return nil
        }
        
        // Evaluate TimeCode Quanta
        var quanta: UInt32 = 30
        switch smpteTime.type {
        case 0:          quanta = 24
        case 1:          quanta = 25
        case 2..<6:      quanta = 30
        case 6..<10:     quanta = 60
        case 10:         quanta = 50
        case 11:         quanta = 24
        default:         break
        }
        
        // Evaluate TimeCode type
        var tcType: UInt32 = kCMTimeCodeFlag_24HourMax // | kCMTimeCodeFlag_NegTimesOK
        switch smpteTime.type {
        case 2,5,8,9:    tcType |= kCMTimeCodeFlag_DropFrame
        default:         break
        }
        
        // Prepare Data Buffer for new SampleBuffer
        guard let dataBuffer = prepareTimeCodeDataBuffer(smpteTime, sizes, quanta, tcType)
            else { return nil }
        
        /* ============================================ */
        
        // Prepare TimeCode SampleBuffer
        var sampleBuffer: CMSampleBuffer? = nil
        if let timeCodeFormatType = timeCodeFormatType {
            var status: OSStatus = noErr
            
            // Extract duration from video sample
            let duration = CMSampleBufferGetDuration(videoSampleBuffer)
            
            // Extract timingInfo from video sample
            var timingInfo = CMSampleTimingInfo()
            CMSampleBufferGetSampleTimingInfo(videoSampleBuffer, at: 0, timingInfoOut: &timingInfo)
            
            // Prepare CMTimeCodeFormatDescription
            var description : CMTimeCodeFormatDescription? = nil
            status = CMTimeCodeFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                       timeCodeFormatType: timeCodeFormatType,
                                                       frameDuration: duration,
                                                       frameQuanta: quanta,
                                                       flags: tcType,
                                                       extensions: nil,
                                                       formatDescriptionOut: &description)
            if status != noErr || description == nil {
                print("ERROR: Could not create format description.")
                return nil
            }
            
            // Create new SampleBuffer
            var timingInfoTMP = timingInfo
            status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                          dataBuffer: dataBuffer,
                                          dataReady: true,
                                          makeDataReadyCallback: nil,
                                          refcon: nil,
                                          formatDescription: description,
                                          sampleCount: 1,
                                          sampleTimingEntryCount: 1,
                                          sampleTimingArray: &timingInfoTMP,
                                          sampleSizeEntryCount: 1,
                                          sampleSizeArray: &sizes,
                                          sampleBufferOut: &sampleBuffer)
            if status != noErr || sampleBuffer == nil {
                print("ERROR: Could not create sample buffer.")
                return nil
            }
        }
        
        return sampleBuffer
    }
    
    private func extractCVSMPTETime(from sampleBuffer: CMSampleBuffer) -> CVSMPTETime? {
        // Extract sampleBuffer attachment for SMPTETime
        let smpteTimeData = CMGetAttachment(sampleBuffer,
                                            key: smpteTimeKey as CFString,
                                            attachmentModeOut: nil)
        
        // Create SMPTETime struct from sampleBuffer attachment
        var smpteTime: CVSMPTETime? = nil
        if let smpteTimeData = smpteTimeData as? Data {
            let data = (smpteTimeData as NSData).bytes.bindMemory(to: CVSMPTETime.self,
                                                                  capacity: smpteTimeData.count).pointee
            smpteTime = CVSMPTETime(subframes: data.subframes,
                                    subframeDivisor: data.subframeDivisor,
                                    counter: data.counter,
                                    type: data.type,
                                    flags: data.flags,
                                    hours: data.hours,
                                    minutes: data.minutes,
                                    seconds: data.seconds,
                                    frames: data.frames)
        }
        
        return smpteTime
    }
    
    private func prepareTimeCodeDataBuffer(_ smpteTime: CVSMPTETime,
                                           _ sizes: Int,
                                           _ quanta: UInt32,
                                           _ tcType: UInt32) -> CMBlockBuffer?  {
        var dataBuffer: CMBlockBuffer? = nil
        var status: OSStatus = noErr
        
        // Caluculate frameNumber for specific SMPTETime
        var frameNumber64: Int64 = 0
        let tcNegativeFlag = Int16(0x80)
        frameNumber64 = Int64(smpteTime.frames)
        frameNumber64 += Int64(smpteTime.seconds) * Int64(quanta)
        frameNumber64 += Int64(smpteTime.minutes & ~tcNegativeFlag) * Int64(quanta) * 60
        frameNumber64 += Int64(smpteTime.hours) * Int64(quanta) * 60 * 60
        
        let fpm: Int64 = Int64(quanta) * 60
        if (tcType & kCMTimeCodeFlag_DropFrame) != 0 {
            let fpm10 = fpm * 10
            let num10s = frameNumber64 / fpm10
            var frameAdjust = -num10s * (9*2)
            var numFramesLeft = frameNumber64 % fpm10
            
            if numFramesLeft > 1 {
                let num1s = numFramesLeft / fpm
                if num1s > 0 {
                    frameAdjust -= (num1s - 1) * 2
                    numFramesLeft = numFramesLeft % fpm
                    if numFramesLeft > 1 {
                        frameAdjust -= 2
                    } else {
                        frameAdjust -= (numFramesLeft + 1)
                    }
                }
            }
            frameNumber64 += frameAdjust
        }
        
        if (smpteTime.minutes & tcNegativeFlag) != 0 {
            frameNumber64 = -frameNumber64
        }
        
        // TODO
        let frameNumber32: Int32 = Int32(frameNumber64)
        
        /* ============================================ */
        
        // Allocate BlockBuffer
        status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                    memoryBlock: nil,
                                                    blockLength: sizes,
                                                    blockAllocator: kCFAllocatorDefault,
                                                    customBlockSource: nil,
                                                    offsetToData: 0,
                                                    dataLength: sizes,
                                                    flags: kCMBlockBufferAssureMemoryNowFlag,
                                                    blockBufferOut: &dataBuffer)
        if status != noErr || dataBuffer == nil {
            print("ERROR: Could not create block buffer.")
            return nil
        }
        
        // Write FrameNumfer into BlockBuffer
        if let dataBuffer = dataBuffer {
            switch sizes {
            case MemoryLayout<Int32>.size:
                var frameNumber32BE = frameNumber32.bigEndian
                status = CMBlockBufferReplaceDataBytes(with: &frameNumber32BE,
                                                       blockBuffer: dataBuffer,
                                                       offsetIntoDestination: 0,
                                                       dataLength: sizes)
            case MemoryLayout<Int64>.size:
                var frameNumber64BE = frameNumber64.bigEndian
                status = CMBlockBufferReplaceDataBytes(with: &frameNumber64BE,
                                                       blockBuffer: dataBuffer,
                                                       offsetIntoDestination: 0,
                                                       dataLength: sizes)
            default:
                status = -1
            }
            if status != kCMBlockBufferNoErr {
                print("ERROR: Could not write into block buffer.")
                return nil
            }
        }
        
        return dataBuffer
    }
    
    /* ======================================================================================== */
    // MARK: - private support func
    /* ======================================================================================== */
    
    private func updateTimeStamp(_ sampleBuffer: CMSampleBuffer) {
        // Update InitialTimeStamp and EndTimeStamp
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        
        objc_sync_enter(self)
        do {
            // Set startTime CMTime value
            if self.isInitialTSReady == false {
                // Set initial SourceTime value for AVAssetWriter
                avAssetWriter!.startSession(atSourceTime: presentation)
                
                // Set initial time stamp for session
                self.isInitialTSReady = true
                self.startTime = presentation
            }
            
            // Update endTime/duration CMTime value
            self.endTime = CMTimeAdd(presentation, duration)
            self._duration = CMTimeGetSeconds(CMTimeSubtract(self.endTime, self.startTime))
        }
        objc_sync_exit(self)
    }
    
    private func checkdecompressor(_ sampleBuffer: CMSampleBuffer) -> Bool {
        if let decompressor = decompressor, decompressor.isReady() {
            return true
        }
        
        // Prepare decompressor (format transcode : device native => decompressed)
        decompressor = VideoDecompressor.init(source: sampleBuffer, deinterlace: encodeDeinterlace)
        
        if let decompressor = decompressor {
            if decompressor.isReady() {
                decompressor.manager = self
                return true
            } else {
                print("ERROR: Failed to init decompressor. Not ready.")
            }
        } else {
            print("ERROR: Failed to init decompressor.")
        }
        
        decompressor = nil
        return false
    }
    
    private func encodedSizeOfSampleBuffer(_ sampleBuffer : CMSampleBuffer) -> CGSize? {
        var cgSize : CGSize? = nil
        if let format : CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format)
            cgSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        }
        
        return cgSize
    }
    
    private func printDescritionImageBuffer(_ sampleBuffer : CMSampleBuffer) {
        // Descriptioon For Video Sample Buffer
        let count = CMSampleBufferGetNumSamples(sampleBuffer)
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        print("### video; count=\(count); presentation=\(presentation.value)/\(presentation.timescale); duration=\(duration.value)/\(duration.timescale);")
        
        if let imageBuffer : CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
            
            print("### \(imageBuffer)")
            
            let width :size_t = CVPixelBufferGetWidth(imageBuffer)
            let height : size_t = CVPixelBufferGetHeight(imageBuffer)
            let bytesPerRow : size_t = CVPixelBufferGetBytesPerRow(imageBuffer)
            let bufferSize : size_t = CVPixelBufferGetDataSize(imageBuffer)
            
            let cleanRect = CVImageBufferGetCleanRect(imageBuffer)
            let displaySize = CVImageBufferGetDisplaySize(imageBuffer)
            let encodedSize = CVImageBufferGetEncodedSize(imageBuffer)
            
            print("### (\(width), \(height)), (\(bytesPerRow), \(bufferSize)), \(cleanRect), \(displaySize), \(encodedSize) ")
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        }
        
        //print("### \(sampleBuffer)\n")
    }
    
    private func printDescriptionAudioBuffer(_ sampleBuffer : CMSampleBuffer) {
        // Descriptioon For Audio Sample Buffer
        
        let count = CMSampleBufferGetNumSamples(sampleBuffer)
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        print("### audio; count=\(count); presentation=\(presentation.value)/\(presentation.timescale); duration=\(duration.value)/\(duration.timescale);")
        
        if let dataBuffer : CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            // TODO
            let length = CMBlockBufferGetDataLength(dataBuffer)
            let contiguous = CMBlockBufferIsRangeContiguous(dataBuffer, atOffset: 0, length: length)
            
            print("### length: \(length), contiguous: \(contiguous)")
        }
        
        //print("### \(sampleBuffer)\n")
    }
    
    private func descriptionForStatus(_ status :AVAssetWriter.Status) -> String {
        // In case of faulty state
        let statusArray : [AVAssetWriter.Status : String] = [
            .unknown    : "AVAssetWriter.Status.Unknown",
            .writing    : "AVAssetWriter.Status.Writing",
            .completed  : "AVAssetWriter.Status.Completed",
            .failed     : "AVAssetWriter.Status.Failed",
            .cancelled  : "AVAssetWriter.Status.Cancelled"
        ]
        let statusStr :String = statusArray[status]!
        
        return statusStr
    }
    
    private func fourCharString(_ type :OSType) -> String {
        let c1 : UInt32 = (type >> 24) & 0xFF
        let c2 : UInt32 = (type >> 16) & 0xFF
        let c3 : UInt32 = (type >>  8) & 0xFF
        let c4 : UInt32 = (type      ) & 0xFF
        let bytes: [CChar] = [
            CChar( c1 == 0x00 ? 0x20 : c1),
            CChar( c2 == 0x00 ? 0x20 : c2),
            CChar( c3 == 0x00 ? 0x20 : c3),
            CChar( c4 == 0x00 ? 0x20 : c4),
            CChar(0x00)
        ]
        
        return String(cString: bytes)
    }
    
    private func deviceInfoArray(mediaType type: AVMediaType) -> [Any] {
        let deviceArray = AVCaptureDevice.devices(for: type)
        
        var deviceInfoArray = [Any]()
        for device in deviceArray {
            let deviceInfo: [String:Any] = [
                "uniqueID" : device.uniqueID,
                "modelID" : device.modelID,
                "localizedName" : device.localizedName,
                "manufacturer" : device.manufacturer,
                "transportType" : fourCharString(UInt32.init(device.transportType)),
                "connected" : device.isConnected,
                "inUseByAnotherApplication" : device.isInUseByAnotherApplication,
                "suspended" : device.isSuspended,
                ]
            deviceInfoArray.append(deviceInfo)
        }
        
        return deviceInfoArray
    }
    
    /* ======================================================================================== */
    // MARK: - public print description API
    /* ======================================================================================== */
    
    open func listDevice() {
        let deviceInfoMuxed = devicesMuxed()
        print("AVMediaTypeMuxed : count = \(deviceInfoMuxed?.count as Optional)")
        print(": \"\(deviceInfoMuxed as Optional))")
        
        let deviceInfoVideo = devicesVideo()
        print("AVMediaTypeVideo : count = \(deviceInfoVideo?.count as Optional)")
        print(": \"\(deviceInfoVideo as Optional))")
        
        let deviceInfoAudio = devicesAudio()
        print("AVMediaTypeAudio : count = \(deviceInfoAudio?.count as Optional)")
        print(": \"\(deviceInfoAudio as Optional))")
        
        print("")
    }
    
    open func devicesMuxed() -> [Any]! {
        let deviceArrayInfoMuxed = deviceInfoArray(mediaType: AVMediaType.muxed)
        return deviceArrayInfoMuxed
    }
    
    open func devicesVideo() -> [Any]! {
        let deviceArrayInfoVideo = deviceInfoArray(mediaType: AVMediaType.video)
        return deviceArrayInfoVideo
    }
    
    open func devicesAudio() -> [Any]! {
        let deviceArrayInfoAudio = deviceInfoArray(mediaType: AVMediaType.audio)
        return deviceArrayInfoAudio
    }
    
    open func deviceInfoForUniqueID(_ uniqueID: String) -> [String:Any]? {
        guard let device = AVCaptureDevice.init(uniqueID: uniqueID) else { return nil }
        let deviceInfo: [String:Any] = [
            "uniqueID" : device.uniqueID,
            "modelID" : device.modelID,
            "localizedName" : device.localizedName,
            "manufacturer" : device.manufacturer,
            "transportType" : fourCharString(UInt32.init(device.transportType)),
            "connected" : device.isConnected,
            "inUseByAnotherApplication" : device.isInUseByAnotherApplication,
            "suspended" : device.isSuspended,
        ]
        return deviceInfo
    }
    
    open func printSessionDiag() {
        print("")
        
        /* ============================================ */
        
        if let captureDeviceVideo = captureDeviceVideo {
            print("captureDeviceVideo")
            
            if let captureDeviceInputVideo = captureDeviceInputVideo {
                for item in (captureDeviceInputVideo.ports) {
                    print(": port = \(item)")
                }
            }
            
            for format in captureDeviceVideo.formats {
                let supportPresetHigh = captureDeviceVideo.supportsSessionPreset(AVCaptureSession.Preset.high)
                print(": supportPresetHigh = \(supportPresetHigh)")
                
                let mediaType = format.mediaType
                print(": mediaType = \((mediaType))")
                let videoSupportedFrameRateRanges = (format as AnyObject).videoSupportedFrameRateRanges
                print(": videoSupportedFrameRateRanges = \(videoSupportedFrameRateRanges as Optional)")
                let description : CMFormatDescription = (format as AnyObject).formatDescription
                print(": description = \(description)")
                
                let mediaTypeString = fourCharString(CMFormatDescriptionGetMediaType(description))
                let mediaSubTypeString = fourCharString(CMFormatDescriptionGetMediaSubType(description))
                print(": \"\(mediaTypeString)\", \"\(mediaSubTypeString)\"")
                
                let extensions = CMFormatDescriptionGetExtensions(description)
                print(": \(extensions as Optional)")
                
                //var size = 0
                //let rect = CMVideoFormatDescriptionGetCleanAperture(description, true)
                //let dimensions = CMVideoFormatDescriptionGetDimensions(description)
                // CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers()
                //let sizeWithoutAspectAndAperture = CMVideoFormatDescriptionGetPresentationDimensions(description, false, false)
                //let sizeWithAspectAndAperture = CMVideoFormatDescriptionGetPresentationDimensions(description, true, true)
            }
            print("")
        } else {
            print("captureDeviceVideo is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureDeviceAudio = captureDeviceAudio {
            print("captureDeviceAudio")
            
            if let captureDeviceInputAudio = captureDeviceInputAudio {
                for item in (captureDeviceInputAudio.ports) {
                    print(": port = \(item)")
                }
            }
            
            for format in captureDeviceAudio.formats {
                let supportPresetHigh = captureDeviceAudio.supportsSessionPreset(AVCaptureSession.Preset.high)
                print(": supportPresetHigh = \(supportPresetHigh)")
                
                let mediaType = format.mediaType
                print(": mediaType = \((mediaType))")
                let description : CMFormatDescription = (format as AnyObject).formatDescription
                print(": description = \(description)")
                
                let mediaTypeString = fourCharString(CMFormatDescriptionGetMediaType(description))
                let mediaSubTypeString = fourCharString(CMFormatDescriptionGetMediaSubType(description))
                print(": \"\(mediaTypeString)\", \"\(mediaSubTypeString)\"")
                
                let extensions = CMFormatDescriptionGetExtensions(description)
                print(": \(extensions as Optional)")
                
                //var size = 0
                //let audioChannelLayout = CMAudioFormatDescriptionGetChannelLayout(description, &size)
                //let formatList = CMAudioFormatDescriptionGetFormatList(description, &size)
                //let magicCookie = CMAudioFormatDescriptionGetMagicCookie(description, &size)
                //let mostCompatibleFormat = CMAudioFormatDescriptionGetMostCompatibleFormat(description)
                //let richestDecodableFormat = CMAudioFormatDescriptionGetRichestDecodableFormat(description)
                //let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)
            }
            print("")
        } else {
            print("captureDeviceAudio is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureMovieFileOutput = captureMovieFileOutput {
            print("captureMovieFileOutput")
            
            for connection in captureMovieFileOutput.connections {
                print(": connection = \(connection)")
            }
            
            print("")
        } else {
            print("captureMovieFileOutput is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureVideoDataOutput = captureVideoDataOutput {
            print("captureVideoDataOutput")
            print(": videoSettings = \(String(describing: captureVideoDataOutput.videoSettings))")
            
            #if true
                // : availableCodecTypes = [avc1, jpeg]
                let codecTypes = captureVideoDataOutput.availableVideoCodecTypes
                print(": availableCodecTypes = \(codecTypes as Optional)") // String array
                
                // : availableVideoCVPixelFormatTypes = [846624121, 2037741171, 875704438, 875704422, 32, 1111970369]
                let pixfmtTypes = captureVideoDataOutput.availableVideoCVPixelFormatTypes
                print(": availableVideoCVPixelFormatTypes = \(pixfmtTypes as Optional) in UInt32 array") // UInt32 array
                
                // : availableVideoCVPixelFormatTypes = ["2vuy", "yuvs", "420v", "420f", "    ", "BGRA"]
                var pixfmtTypesStr :[String] = []
                for value in pixfmtTypes! {
                    let fourcc = fourCharString((value as AnyObject).uint32Value)
                    pixfmtTypesStr.append(fourcc)
                }
                print(": availableVideoCVPixelFormatTypes = \(pixfmtTypesStr) in FourCharCode Array")
            #endif
            
            print("")
        } else {
            print("captureVideoDataOutput is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureAudioDataOutput = captureAudioDataOutput {
            print("captureAudioDataOutput")
            print(": audioSettings = \(String(describing: captureAudioDataOutput.audioSettings))")
            print("")
        } else {
            print("captureAudioDataOutput is not ready.")
            print("")
        }
    }
}

extension AVCaptureVideoDataOutput {
    // Swift header bug?
    // https://github.com/apple/swift/blob/master/stdlib/public/SDK/AVFoundation/AVCaptureVideoDataOutput.swift
    
    @nonobjc
    public var availableVideoCVPixelFormatTypes :[Any]! {
        return __availableVideoCVPixelFormatTypes
    }
    
    @nonobjc
    public var availableVideoPixelFormatTypes: [OSType] {
        return __availableVideoCVPixelFormatTypes.map { $0.uint32Value } as [OSType]
    }
}
