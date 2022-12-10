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
    // MARK: - internal variables
    /* ======================================================================================== */
    
    internal var captureSession : AVCaptureSession? = nil
    
    internal var captureDeviceVideo : AVCaptureDevice? = nil
    internal var captureDeviceAudio : AVCaptureDevice? = nil
    
    internal var captureDeviceInputAudio : AVCaptureDeviceInput? = nil
    internal var captureDeviceInputVideo : AVCaptureDeviceInput? = nil
    
    internal var captureMovieFileOutput : AVCaptureMovieFileOutput? = nil
    internal var captureVideoDataOutput : AVCaptureVideoDataOutput? = nil
    internal var captureAudioDataOutput : AVCaptureAudioDataOutput? = nil
    
    internal var previewAudioOutput : AVCaptureAudioPreviewOutput? = nil
    internal var previewVideoLayer : AVCaptureVideoPreviewLayer? = nil
    internal var previewVideoConnection : AVCaptureConnection? = nil
    
    internal var avAssetWriter : AVAssetWriter? = nil
    internal var avAssetWriterInputVideo : AVAssetWriterInput? = nil
    internal var avAssetWriterInputAudio : AVAssetWriterInput? = nil
    internal var avAssetWriterInputTimeCodeVideo : AVAssetWriterInput? = nil
    
    internal var decompressor : VideoDecompressor? = nil
    
    //
    internal var startTime : CMTime = CMTime.zero
    internal var endTime : CMTime = CMTime.zero
    internal var isInitialTSReady : Bool = false
    internal var _duration  : Float64 = 0.0
    
    //
    internal var _volume : Float = 1.0
    
    //
    internal var uniqueIDmuxed : String? = nil
    internal var uniqueIDvideo : String? = nil
    internal var uniqueIDaudio : String? = nil
    
    internal var smpteReadyVideo : Bool = false
    
    internal var isWriting : Bool = false
    
    internal var audioDeviceDecompressedFormat : [String:Any] = [:]
    internal var audioDeviceCompressedFormat : [String:Any] = [:]
    
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
        avAssetWriterInputTimeCodeVideo = nil
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
        smpteReadyVideo = false
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
    
    /* ======================================================================================== */
    // MARK: - private support func
    /* ======================================================================================== */
    
    internal func descriptionForStatus(_ status :AVAssetWriter.Status) -> String {
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
    
    internal func fourCharString(_ type :OSType) -> String {
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
    
}
