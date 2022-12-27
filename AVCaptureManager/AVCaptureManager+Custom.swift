//
//  AVCaptureManager+Custom.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/10.
//  Copyright © 2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation
import CoreMediaIO.CMIOSampleBuffer
import VideoToolbox

extension AVCaptureManager : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    /* ======================================================================================== */
    // MARK: - private session configuration
    /* ======================================================================================== */
    
    /// Attach Captured Video Data Output (either device native or decompressed format)
    /// - Parameter decompress: true for decompressed format
    /// - Returns: true if no error
    internal func addVideoDataOutput(decode decompress: Bool) -> Bool {
        if let captureSession = captureSession {
            captureVideoDataOutput = AVCaptureVideoDataOutput()
            if let captureVideoDataOutput = captureVideoDataOutput {
                // Register video setting
                if decompress == false || videoDeviceDecompressedFormat.count == 0 {
                    // No transcode required (device native format)
                    captureVideoDataOutput.videoSettings = [:]
                } else {
                    // Transcode required (default decompressed format)
                    captureVideoDataOutput.videoSettings = videoDeviceDecompressedFormat
                }
                
                // Register dispatch queue for video
                let queue : DispatchQueue = DispatchQueue(label: "my video queue", attributes: [])
                captureVideoDataOutput.setSampleBufferDelegate(self, queue: queue)
                
                // Define Captured Video Data Output
                if captureSession.canAddOutput(captureVideoDataOutput) {
                    captureSession.addOutput(captureVideoDataOutput)
                    return true
                }
            }
        }
        
        print("ERROR: Failed to addVideoDataOutput().")
        return false
    }
    
    /// Attach Captured Audio Data Output (either device native or decompressed format)
    /// - Parameter decompress: true for decompressed format
    /// - Returns: true if no error
    internal func addAudioDataOutput(decode decompress: Bool) -> Bool {
        // Define Captured Audio Data format (device native or decompressed format)
        
        if let captureSession = captureSession {
            captureAudioDataOutput = AVCaptureAudioDataOutput()
            if let captureAudioDataOutput = captureAudioDataOutput {
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
                if captureSession.canAddOutput(captureAudioDataOutput) {
                    captureSession.addOutput(captureAudioDataOutput)
                    return true
                }
            }
        }
        
        print("ERROR: Failed to addAudioDataOutput().")
        return false
    }
    
    /* ======================================================================================== */
    // MARK: - internal/private recording control
    /* ======================================================================================== */
    
    /// Start movie file writing using AVAssetWriter (not AVCaptureMovieFileOutput)
    /// - Parameter fileUrl: movie file URL to write
    /// - Returns: true if no error
    internal func startRecordingToOutputFileURL(_ fileUrl : URL) -> Bool {
        // unref previous AVAssetWriter and decompressor
        avAssetWriterInputVideo = nil
        avAssetWriterInputAudio = nil
        avAssetWriterInputTimeCodeVideo = nil
        avAssetWriter = nil
        
        decompressor = nil
        
        // reset TS variables and duration
        _duration = 0.0
        startTime = CMTime.zero
        endTime = CMTime.zero
        isInitialTSReady = false
        
        // Reset Resampling values
        resampleDuration = nil
        resampleCurrentPTS = nil
        resampleNextPTS = nil
        resampleCaptured = nil
        
        // Apply resampling values
        if let sampleDurationVideo = sampleDurationVideo {
            resampleDuration = sampleDurationVideo
        }
        
        // Reset last AVAssetWriter status/error
        lastAVAssetWriterStatus = nil
        lastAVAssetWriterError = nil
        
        /* ============================================ */
        
        // Create AVAssetWriter for QuickTime Movie
        avAssetWriter = try? AVAssetWriter.init(outputURL: fileUrl, fileType: .mov)
        if let avAssetWriter = avAssetWriter {
            //
            if encodeVideo == false {
                // Create AVAssetWriterInput for Video (Passthru)
                avAssetWriterInputVideo = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
            } else {
                // Prepare OutputSettings for Video (Compress)
                if videoDeviceCompressedFormat.count == 0 {
                    videoDeviceCompressedFormat = prepareOutputSettingsVideo(nil)
                }
                
                // Validate settings for Video
                let settings = videoDeviceCompressedFormat
                if avAssetWriter.canApply(outputSettings: settings, forMediaType: .video) {
                    // Create AVAssetWriterInput for Video (Compress)
                    avAssetWriterInputVideo = AVAssetWriterInput(mediaType: .video,
                                                                 outputSettings: settings)
                } else {
                    print("ERROR: videoOutputSettings is not OK")
                    return false
                }
            }
            if sampleTimescaleVideo > 0, let avAssetWriterInputVideo = avAssetWriterInputVideo {
                // Apply preferred video media timescale
                avAssetWriterInputVideo.mediaTimeScale = sampleTimescaleVideo
            }
            
            //
            if encodeAudio == false {
                // Create AVAssetWriterInput for Audio (Passthru)
                avAssetWriterInputAudio = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            } else {
                // Prepare OutputSettings for Audio (Compress)
                if audioDeviceCompressedFormat.count == 0 {
                    audioDeviceCompressedFormat = prepareOutputSettingsAudio(nil)
                }
                
                // Validate settings for Audio
                let settings = audioDeviceCompressedFormat
                if avAssetWriter.canApply(outputSettings: settings, forMediaType: .audio) {
                    // Create AVAssetWriterInput for Audio (Compress)
                    avAssetWriterInputAudio = AVAssetWriterInput(mediaType: .audio,
                                                                 outputSettings: settings)
                } else {
                    print("ERROR: audioOutputSettings is not OK")
                    return false
                }
            }
            
            //
            if timeCodeFormatType != nil && smpteReadyVideo {
                // Create AVAssetWriterInput for Timecode (SMPTE)
                avAssetWriterInputTimeCodeVideo = AVAssetWriterInput(mediaType: .timecode,
                                                                     outputSettings: nil)
                
                // Add track association b/w video/timeCode track
                let inputVideo = avAssetWriterInputVideo
                let inputTimeCode = avAssetWriterInputTimeCodeVideo
                if let inputVideo = inputVideo, let inputTimeCode = inputTimeCode {
                    let trackAssociationType = AVAssetTrack.AssociationType.timecode.rawValue
                    if inputVideo.canAddTrackAssociation(withTrackOf: inputTimeCode,
                                                         type: trackAssociationType){
                        inputVideo.addTrackAssociation(withTrackOf: inputTimeCode,
                                                       type: trackAssociationType)
                    }
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
            if timeCodeFormatType != nil && smpteReadyVideo {
                if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCodeVideo {
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
                if avAssetWriter.startWriting() {
                    return true
                }
                
                let statusStr : String = parseAVAssetWriterStatus() ?? "n/a"
                let errorStr : String = parseAVAssetWriterError() ?? "n/a"
                print("ERROR: AVAssetWriter.startWriting() = \(statusStr)")
                print("ERROR: \(errorStr)")
                return false
            }
        }
        
        print("ERROR: Failed to init AVAssetWriter.")
        return false
    }
    
    /// Stop movie file writing using AVAssetWriter (not AVCaptureMovieFileOutput)
    internal func stopRecordingToOutputFile() {
        if let avAssetWriter = avAssetWriter {
            let outputURL = avAssetWriter.outputURL
            
            // Finish writing
            if let avAssetWriterInputTimeCodeVideo = avAssetWriterInputTimeCodeVideo {
                avAssetWriterInputTimeCodeVideo.markAsFinished()
            }
            if let avAssetWriterInputVideo = avAssetWriterInputVideo {
                avAssetWriterInputVideo.markAsFinished()
            }
            if let avAssetWriterInputAudio = avAssetWriterInputAudio {
                avAssetWriterInputAudio.markAsFinished()
            }
            
            avAssetWriter.endSession(atSourceTime: endTime)
            avAssetWriter.finishWriting{ [unowned self] in
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
                        let statusStr : String = self.parseAVAssetWriterStatus() ?? "n/a"
                        let errorStr : String = self.parseAVAssetWriterError() ?? "n/a"
                        print("ERROR: AVAssetWriter.finishWritingWithCompletionHandler() = \(statusStr)")
                        print("ERROR: \(errorStr)")
                    }
                    
                    // Reset CMTime values
                    self._duration = CMTimeGetSeconds(CMTimeSubtract(self.endTime, self.startTime))
                    self.startTime = CMTime.zero
                    self.endTime = CMTime.zero
                    self.isInitialTSReady = false
                    
                    // Reset Resampling values
                    self.resampleDuration = nil
                    self.resampleCurrentPTS = nil
                    self.resampleNextPTS = nil
                    self.resampleCaptured = nil
                    
                    // unref AVAssetWriter
                    self.avAssetWriterInputTimeCodeVideo = nil
                    self.avAssetWriterInputVideo = nil
                    self.avAssetWriterInputAudio = nil
                    self.avAssetWriter = nil
                }
                
                DispatchQueue.main.async {
                    if self.trimMovie(outputURL) == false {
                        print("ERROR: Failed to trim the output on:", outputURL)
                    }
                }
            }
        }
    }
    
    /// Generate video compression setting
    /// - Parameter sampleBuffer: source CMSampleBuffer if available
    /// - Returns: compression setting dictionary
    private func prepareOutputSettingsVideo(_ sampleBuffer: CMSampleBuffer?) -> [String:Any] {
        // Create OutputSettings for Video (Compress)
        var videoOutputSettings : [String:Any] = [:]
        
        // VidoStyle settings with clean aperture offset
        videoOutputSettings = videoStyle.settings(hOffset: clapHOffset, vOffset: clapVOffset)
        
        // video hardware encoder
        let encoderSpecification: [NSString: Any] = [
            kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder : kCFBooleanTrue!,
            kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder : kCFBooleanFalse!
        ]
        videoOutputSettings[AVVideoEncoderSpecificationKey] = encoderSpecification
        
        // video output codec
        if encodeProRes {
            let codec :AVVideoCodecType = proresEncoderType
            videoOutputSettings[AVVideoCodecKey] = codec
            
        } else {
            let codec :AVVideoCodecType = videoEncoderType
            videoOutputSettings[AVVideoCodecKey] = codec
            
            if debugDumpSupportedPropertiesVideo {
                // debug - verify compressor supported properties
                let key:String? = nil // AVVideoAllowFrameReorderingKey, etc.
                let encoder:CMVideoCodecType = fourCC(avVideoCodecType: codec)
                if let key = key {
                    let result:CFDictionary? = checkVTSupportedProperties(encoder: encoder,
                                                                          accelerator: true,
                                                                          key: key)
                    print(key, ":", result ?? "n/a")
                } else {
                    _ = checkVTSupportedProperties(encoder: encoder, accelerator: true, key: nil)
                }
            }
            
            var compressionProperties :[String:Any] = [:]
            do {
                // Calculate value for AVVideoExpectedSourceFrameRateKey
                var srcFPS:Double = 30.0
                if let duration = sampleDurationVideo { // Using sampleDurationVideo instead of resampleDuration here
                    assert(CMTIME_IS_NUMERIC(duration) && duration.seconds > 0)
                    srcFPS = (1.0/duration.seconds)
                } else if let sb = sampleBuffer {
                    let duration = CMSampleBufferGetDuration(sb)
                    assert(CMTIME_IS_NUMERIC(duration) && duration.seconds > 0)
                    srcFPS = (1.0/duration.seconds)
                }
                
                // Calculate value for AVVideoMaxKeyFrameIntervalKey
                let maxKeyFrameIntervalFrames:Int = min(1, Int(srcFPS * maxKeyFrameIntervalSeconds))
                
                // Prepare value for AVVideoCompressionPropertiesKey
                compressionProperties = [
                    AVVideoAverageBitRateKey : videoEncoderBitRate,
                    AVVideoMaxKeyFrameIntervalKey : maxKeyFrameIntervalFrames,
                    AVVideoMaxKeyFrameIntervalDurationKey : maxKeyFrameIntervalSeconds,
                    AVVideoAllowFrameReorderingKey : true,
                    AVVideoProfileLevelKey : videoEncoderProfile,
                    AVVideoH264EntropyModeKey : AVVideoH264EntropyModeCABAC,
                    AVVideoExpectedSourceFrameRateKey : srcFPS,
                ]
                
                if maxKeyFrameIntervalFrames == 1 { // key frame only stream
                    compressionProperties.removeValue(forKey: AVVideoMaxKeyFrameIntervalDurationKey)
                }
                if videoEncoderBitRate == 0 { // let compressor to decide bit rate
                    compressionProperties.removeValue(forKey: AVVideoAverageBitRateKey)
                }
                if codec != .h264 { // AVVideoH264EntropyModeKey is h264 only
                    compressionProperties.removeValue(forKey: AVVideoH264EntropyModeKey)
                }
                
                /*
                // AVVideoAverageNonDroppableFrameRateKey is not supported by h264/HEVC Hardware encoder...
                let nonDropRatio = 0.5 // The ratio of NonDroppable per total frames (0 < ratio <= 1.0)
                if 0 < nonDropRatio, nonDropRatio <= 1.0 {
                    let nonDropFPS:Double = (srcFPS * nonDropRatio)
                    compressionProperties[AVVideoAverageNonDroppableFrameRateKey] = NSNumber(value:nonDropFPS)
                }
                 */
            }
            
            //
            if compressionProperties.count > 0 {
                videoOutputSettings[AVVideoCompressionPropertiesKey] = compressionProperties
            }
        }
        
        // Check if user want to customize settings
        if let updateVideoSettings = updateVideoSettings {
            // Call optional updateVideoSettings block
            videoOutputSettings = updateVideoSettings(videoOutputSettings)
        }
        assert(videoOutputSettings.count > 0)
        
        return videoOutputSettings
    }
    
    /// Generate audio compression setting
    /// - Parameter sampleBuffer: source CMSampleBuffer if available
    /// - Returns: compression setting dictionary
    private func prepareOutputSettingsAudio(_ sampleBuffer: CMSampleBuffer?) -> [String:Any] {
        // Prepare OutputSettings for Audio (Compress)
        var audioOutputSettings : [String:Any] = [:]
        
        //
        let audioFormat = audioEncodeType
        let bitRate = UInt32(audioEncoderBitRate)
        let strategy = audioEncoderStrategy
        
        // Extract AudioFormatDescription and create compressed format settings
        if  let sampleBuffer = sampleBuffer,
            let audioFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbd_p = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
        {
            var avaf: AVAudioFormat? = nil
            var aclData: NSData? = nil
            var layoutSize: Int = 0
            let acl_p = CMAudioFormatDescriptionGetChannelLayout(audioFormatDescription, sizeOut: &layoutSize)
            if let acl_p = acl_p {
                let avacl = AVAudioChannelLayout(layout: acl_p)
                avaf = AVAudioFormat(streamDescription:asbd_p, channelLayout: avacl)
                aclData = NSData(bytes: UnsafeRawPointer(acl_p), length: layoutSize)
            } else {
                avaf = AVAudioFormat.init(streamDescription:asbd_p)
                aclData = nil
            }
            
            // Create default compressed format
            if let avaf = avaf {
                audioOutputSettings = [
                    AVFormatIDKey: audioFormat,                 // UInt32
                    AVSampleRateKey: avaf.sampleRate,           // Double
                    AVNumberOfChannelsKey: avaf.channelCount,   // UInt32
                    AVEncoderBitRateKey: bitRate,               // UInt32
                    AVEncoderBitRateStrategyKey: strategy       // String
                ]
                if let aclData = aclData {
                    audioOutputSettings[AVChannelLayoutKey] = aclData // NSData
                }
            }
        }
        if audioOutputSettings.count == 0 {
            // Derive some parameters from De-compressed setting
            let srcSampleRate = audioDeviceDecompressedFormat[AVSampleRateKey] as? Double
            let srcNumChannels = audioDeviceDecompressedFormat[AVNumberOfChannelsKey] as? AVAudioChannelCount
            let srcAclData = audioDeviceDecompressedFormat[AVChannelLayoutKey] as? NSData
            if let srcSampleRate = srcSampleRate, let srcNumChannels = srcNumChannels {
                audioOutputSettings = [
                    AVFormatIDKey: audioFormat,                 // UInt32
                    AVSampleRateKey: srcSampleRate ,            // Double
                    AVNumberOfChannelsKey: srcNumChannels,      // UInt32
                    AVEncoderBitRateKey: bitRate,               // UInt32
                    AVEncoderBitRateStrategyKey: strategy       // String
                ]
                if let srcAclData = srcAclData {
                    audioOutputSettings[AVChannelLayoutKey] = srcAclData // NSData
                }
            }
        }
        
        // Check if user want to customize settings
        if let updateAudioSettings = updateAudioSettings {
            // Call optional updateAudioSettings block
            audioOutputSettings = updateAudioSettings(audioOutputSettings)
        }
        
        // Adjust parameters per audioFormat requirement
        if audioFormat == kAudioFormatAppleLossless {
            let srcBitDepth = (audioDeviceDecompressedFormat[AVLinearPCMBitDepthKey] as! UInt32)
            audioOutputSettings[AVEncoderBitDepthHintKey] = srcBitDepth
            
            audioOutputSettings.removeValue(forKey: AVEncoderBitRateKey)
            audioOutputSettings.removeValue(forKey: AVEncoderBitRateStrategyKey)
        }
        if audioFormat == kAudioFormatFLAC {
            audioOutputSettings.removeValue(forKey: AVEncoderBitRateKey)
            audioOutputSettings.removeValue(forKey: AVEncoderBitRateStrategyKey)
        }
        if audioFormat == kAudioFormatMPEG4AAC {
            var bitRateAAC = audioOutputSettings[AVEncoderBitRateKey] as! UInt32
            bitRateAAC = min(max(bitRateAAC,64000),320000)
            audioOutputSettings[AVEncoderBitRateKey] = bitRateAAC
        }
        if audioFormat == kAudioFormatMPEG4AAC_HE {
            var bitRateAACHE = audioOutputSettings[AVEncoderBitRateKey] as! UInt32
            bitRateAACHE = min(max(bitRateAACHE,32000),80000)
            audioOutputSettings[AVEncoderBitRateKey] = bitRateAACHE
        }
        if audioFormat == kAudioFormatMPEG4AAC_HE_V2 {
            var bitRateAACHEv2 = audioOutputSettings[AVEncoderBitRateKey] as! UInt32
            bitRateAACHEv2 = min(max(bitRateAACHEv2,20000),48000)
            audioOutputSettings[AVEncoderBitRateKey] = bitRateAACHEv2
        }
        if audioFormat == kAudioFormatOpus {
            // AFAIK, no parameter restriction
        }
        
        return audioOutputSettings
    }
    
    /* ======================================================================================== */
    // MARK: - capture delegate protocol
    /* ======================================================================================== */
    
    /// AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
    /// - Parameters:
    ///   - output: The capture output object.
    ///   - sampleBuffer: A CMSampleBuffer object containing information about the dropped frame,
    ///   such as its format and presentation time. This sample buffer contains none of the original video data.
    ///   - connection: The connection from which the video was received.
    open func captureOutput(_ output: AVCaptureOutput,
                            didDrop sampleBuffer: CMSampleBuffer,
                            from connection: AVCaptureConnection) {
        //
        let reason = CMGetAttachment(sampleBuffer,
                                     key: kCMSampleBufferAttachmentKey_DroppedFrameReason,
                                     attachmentModeOut: nil) as? String
        print("NOTICE: Dropped reason =", reason ?? "n/a")
    }
    
    /// AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
    /// - Parameters:
    ///   - output: The capture output object.
    ///   - sampleBuffer: The sample buffer that was output.
    ///   - connection: The connection.
    open func captureOutput(_ captureOutput: AVCaptureOutput,
                            didOutput sampleBuffer: CMSampleBuffer,
                            from connection: AVCaptureConnection) {
        //
        let recording = self.isWriting
        let forAudio = (captureOutput == self.captureAudioDataOutput)
        let forVideo = (captureOutput == self.captureVideoDataOutput)
        var smpteTime :CVSMPTETime? = nil
        
        // Query SampleBuffer Information
        let bufferReady = CMSampleBufferDataIsReady(sampleBuffer)
        
        // Check discontinuity
        _ = detectDiscontinuity(sampleBuffer) // Ignore any error
        
        /* ============================================ */
        
        // Create default compression setting using input sample properties
        if forVideo && encodeVideo && videoDeviceCompressedFormat.count == 0 {
            videoDeviceCompressedFormat = prepareOutputSettingsVideo(sampleBuffer)
        }
        if forAudio && encodeAudio && audioDeviceCompressedFormat.count == 0 {
            audioDeviceCompressedFormat = prepareOutputSettingsAudio(sampleBuffer)
        }
        
        /* ============================================ */
        
        if forVideo {
            // Update raw width/height
            if videoSize == nil {
                videoSize = encodedSizeOfSampleBuffer(sampleBuffer)
            }
            
            // Verify sampleBuffer attachment for SMPTETime
            if timeCodeFormatType != nil {
                smpteTime = extractCVSMPTETime(from: sampleBuffer)
                if smpteTime != nil {
                    smpteReadyVideo = true
                }
            } else {
                smpteReadyVideo = false
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
                //
                var needDecompressor = false
                if encodeVideo {
                    // Transcode is requested.
                    
                    // Check if sampleBuffer has decompressed image
                    if let _ = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        // Decompressed imageBuffer - no decompressor is needed.
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
                    writeVideoSampleBufferResampled(sampleBuffer)
                }
                
                // Timecode track support
                if smpteTime != nil  {
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
    
    /// Write Audio SampleBuffer
    /// - Parameter sampleBuffer: CMSampleBuffer to write
    private func writeAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputAudio = avAssetWriterInputAudio {
            if avAssetWriterInputAudio.isReadyForMoreMediaData {
                updateTimeStamp(sampleBuffer)
                if avAssetWriterInputAudio.append(sampleBuffer) {
                    return
                } else {
                    let statusStr : String = parseAVAssetWriterStatus() ?? "n/a"
                    let errorStr : String = parseAVAssetWriterError() ?? "n/a"
                    print("ERROR: Could not write audio sample buffer.(\(statusStr))")
                    print("ERROR: \(errorStr)")
                }
            } else {
                //print("ERROR: AVAssetWriterInputAudio is not ready to append.")
            }
        }
    }
    
    /// Write Video SampleBuffer
    /// - Parameter sampleBuffer: CMSampleBuffer to write
    private func writeVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputVideo = avAssetWriterInputVideo {
            if avAssetWriterInputVideo.isReadyForMoreMediaData {
                updateTimeStamp(sampleBuffer)
                if avAssetWriterInputVideo.append(sampleBuffer) {
                    return
                } else {
                    let statusStr : String = parseAVAssetWriterStatus() ?? "n/a"
                    let errorStr : String = parseAVAssetWriterError() ?? "n/a"
                    print("ERROR: Could not write video sample buffer.(\(statusStr))")
                    print("ERROR: \(errorStr)")
                }
            } else {
                //print("ERROR: AVAssetWriterInputVideo is not ready to append.")
            }
        }
    }
    
    /// Write Timecode SampleBuffer
    /// - Parameter sampleBuffer: CMSampleBuffer to write
    private func writeTimecodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCodeVideo {
            if avAssetWriterInputTimeCode.isReadyForMoreMediaData {
                updateTimeStamp(sampleBuffer)
                if avAssetWriterInputTimeCode.append(sampleBuffer) {
                    return
                } else {
                    let statusStr : String = parseAVAssetWriterStatus() ?? "n/a"
                    let errorStr : String = parseAVAssetWriterError() ?? "n/a"
                    print("ERROR: Could not write timecode sample buffer.(\(statusStr))")
                    print("ERROR: \(errorStr)")
                }
            } else {
                //print("ERROR: AVAssetWriterInputTimecode is not ready to append.")
            }
        }
    }
    
    /// Write Video SampleBuffer using sampleDurationVideo (Fixed FPS)
    /// - Parameter srcSampleBuffer: Source CMSsampleBuffer to write
    private func writeVideoSampleBufferResampled(_ srcSampleBuffer: CMSampleBuffer) {
        // NOTE: sampleDurationVideo is captured as resampleDuration
        
        // Check if ready to resample
        let flag = (resampleDuration != nil &&
                    CMTIME_IS_NUMERIC(resampleDuration!) &&
                    resampleDuration!.seconds > 0)
        if flag == false {
            writeVideoSampleBuffer(srcSampleBuffer)
            return
        }
        
        // Set initial Current/Next PTS
        let duration = resampleDuration!
        let srcStart = CMSampleBufferGetPresentationTimeStamp(srcSampleBuffer)
        let srcEnd = srcStart + CMSampleBufferGetDuration(srcSampleBuffer)
        if resampleCurrentPTS == nil {
            // use PTS from source sampleBuffer as start point of new PTS
            resampleCurrentPTS = srcStart
            resampleNextPTS = srcStart + duration
        }
        
        // read resample properties
        var current = resampleCurrentPTS!
        var next = resampleNextPTS!
        
        while current < srcEnd {
            if next <= srcEnd {
                // current < next < srcEnd
                // Emit: write sample using either last source or current source samplebuffer.
                
                var newSampleBuffer :CMSampleBuffer? = nil
                newSampleBuffer = resample((resampleCaptured ?? srcSampleBuffer), current, duration)
                if let newSampleBuffer = newSampleBuffer {
                    writeVideoSampleBuffer(newSampleBuffer)
                } else {
                    print("ERROR: Failed to resample using new TimeingInfo")
                }
                
                // Relase resampleSourceBuffer (set nil)
                resampleCaptured = nil
                
                // recalculate resample PTS
                current = next
                next = current + duration
            } else {
                // current < srcEnd < next
                // Capture: update last sample with current source samplebuffer

                if resampleCaptured == nil {
                    var captured :CMSampleBuffer? = nil
                    let err = CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault,
                                                       sampleBuffer: srcSampleBuffer,
                                                       sampleBufferOut: &captured)
                    if let captured = captured {
                        resampleCaptured = captured
                    } else {
                        print("ERROR: Failed to create copy of CMSampleBuffer(\(err)")
                    }
                }
                break
            }
        }
        
        // update resample properties
        resampleCurrentPTS = current
        resampleNextPTS = next
    }
    
    /// Create a copy of source CMSampleBuffer using new TimingInfo
    /// - Parameters:
    ///   - source: source CMSampleBuffer to copy
    ///   - start: new presentation time stamp
    ///   - duration: new duration (as Fixed FPS)
    /// - Returns: resampled sampleBuffer
    private func resample( _ source: CMSampleBuffer, _ start: CMTime, _ duration: CMTime) -> CMSampleBuffer? {
        var newSampleBuffer :CMSampleBuffer? = nil
        var newTimingInfo = CMSampleTimingInfo(duration: duration,
                                               presentationTimeStamp: start,
                                               decodeTimeStamp: CMTime.invalid)
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
                                              sampleBuffer: source,
                                              sampleTimingEntryCount: 1,
                                              sampleTimingArray: &newTimingInfo,
                                              sampleBufferOut: &newSampleBuffer)
        return newSampleBuffer
    }
    
    /* ======================================================================================== */
    // MARK: - private support func
    /* ======================================================================================== */
    
    /// Track presentation timestamp and duration of each sampleBuffer
    /// - Parameter sampleBuffer: CMSampleBuffer to inspect
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
            let newEndTime = CMTimeAdd(presentation, duration)
            let currentEndTime = self.endTime
            self.endTime = CMTimeMaximum(currentEndTime, newEndTime)
            self._duration = CMTimeGetSeconds(CMTimeSubtract(self.endTime, self.startTime))
        }
        objc_sync_exit(self)
    }
    
    /// Check video decompressor is ready and prepare if required
    /// - Parameter sampleBuffer: CMSampleBuffer to decode
    /// - Returns: true if no error
    private func checkdecompressor(_ sampleBuffer: CMSampleBuffer) -> Bool {
        if let decompressor = decompressor, decompressor.isReady() {
            return true
        }
        
        // Prepare decompressor (format transcode : device native => decompressed)
        decompressor = VideoDecompressor.init(source: sampleBuffer,
                                              deinterlace: encodeDeinterlace,
                                              pixelFormat: pixelFormatType)
        
        if let decompressor = decompressor {
            if decompressor.isReady() {
                decompressor.writeDecompressed = { [unowned self] (sampleBuffer) in
                    self.writeVideoSampleBufferResampled(sampleBuffer)
                }
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
    
    /// Get dimension of video sampleBuffer in CGSize
    /// - Parameter sampleBuffer: CMSampleBuffer to inspect
    /// - Returns: dimension in CGSize
    private func encodedSizeOfSampleBuffer(_ sampleBuffer : CMSampleBuffer) -> CGSize? {
        var cgSize : CGSize? = nil
        if let format : CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format)
            cgSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        }
        
        return cgSize
    }
    
    /// Check discontinuity of video/audio sampleBuffer
    /// - Parameter sampleBuffer: CMSampleBuffer to inspect
    /// - Returns: true if any gap is detected, false if no issue
    private func detectDiscontinuity(_ sampleBuffer: CMSampleBuffer) -> Bool {
        var gapDetected = false
        if let fd = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let sequence = CMIOSampleBufferGetSequenceNumber(sampleBuffer)
            let discontinuity = CMIOSampleBufferGetDiscontinuityFlags(sampleBuffer)
            
            let mediaType = CMFormatDescriptionGetMediaType(fd)
            switch mediaType {
            case kCMMediaType_Video:
                let expected = CMIOGetNextSequenceNumber(lastSeqVideo)
                if discontinuity != kCMIOSampleBufferNoDiscontinuities || sequence != expected {
                    gapDetected = true
                    print("ERROR:AVCaptureVideoDataOutput:",
                          "discontinuity:\(discontinuity), expected:\(expected), actual:\(sequence)")
                }
                lastSeqVideo = sequence
            case kCMMediaType_Audio:
                let expected = CMIOGetNextSequenceNumber(lastSeqAudio)
                if discontinuity != kCMIOSampleBufferNoDiscontinuities || sequence != expected {
                    gapDetected = true
                    print("ERROR:AVCaptureAudioDataOutput:",
                          "discontinuity:\(discontinuity), expected:\(expected), actual:\(sequence)")
                }
                lastSeqAudio = sequence
            default:
                break
            }
        }
        return gapDetected
    }
    
    /// Parse AVAssetWriter.status and return description string.
    /// - Returns: status description
    private func parseAVAssetWriterStatus() -> String? {
        var statusDescription:String? = nil
        if let avAssetWriter = avAssetWriter {
            // In case of faulty state
            let statusArray : [AVAssetWriter.Status : String] = [
                .unknown    : "AVAssetWriter.Status.Unknown",
                .writing    : "AVAssetWriter.Status.Writing",
                .completed  : "AVAssetWriter.Status.Completed",
                .failed     : "AVAssetWriter.Status.Failed",
                .cancelled  : "AVAssetWriter.Status.Cancelled"
            ]
            let status = avAssetWriter.status
            statusDescription = statusArray[status]
        }
        lastAVAssetWriterStatus = statusDescription
        return statusDescription
    }
    
    /// Parse AVAssetWriter.error and return description string.
    /// - Returns: error description
    private func parseAVAssetWriterError() -> String? {
        var errorDescription:String? = nil
        if let avAssetWriter = avAssetWriter, let err = avAssetWriter.error {
            if let err = err as NSError? {
                let domain:String = err.domain
                let code:String = String(err.code)
                let description:String = err.localizedDescription
                let reason:String = err.localizedFailureReason ?? "Unknown error reason."
                errorDescription = "\(domain):\(code):\(description):\(reason)"
            } else {
                errorDescription = err.localizedDescription
            }
        }
        lastAVAssetWriterError = errorDescription
        return errorDescription
    }
}
