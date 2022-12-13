//
//  AVCaptureManager+Custom.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/10.
//  Copyright © 2022 Takashi Mochizuki. All rights reserved.
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
import CoreMediaIO.CMIOSampleBuffer
import CoreAudioTypes

extension AVCaptureManager : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    /* ======================================================================================== */
    // MARK: - private session configuration
    /* ======================================================================================== */
    
    internal func addVideoDataOutput(decode decompress: Bool) -> Bool {
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
    
    internal func addAudioDataOutput(decode decompress: Bool) -> Bool {
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
    
    internal func addMovieFileOutput(_ preset: AVCaptureSession.Preset) -> Bool {
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
    
    /* ======================================================================================== */
    // MARK: - internal/private recording control
    /* ======================================================================================== */
    
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
            
            if timeCodeFormatType != nil && smpteReadyVideo {
                // Create AVAssetWriterInput for Timecode (SMPTE)
                avAssetWriterInputTimeCodeVideo = AVAssetWriterInput(mediaType: AVMediaType.timecode,
                                                                outputSettings: nil)
                
                if let inputVideo = avAssetWriterInputVideo, let inputTimeCode = avAssetWriterInputTimeCodeVideo {
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
                let valid = avAssetWriter.startWriting()
                return valid
            }
        }
        
        print("ERROR: Failed to init AVAssetWriter.")
        return false
    }
    
    internal func stopRecordingToOutputFile() {
        if let avAssetWriter = avAssetWriter {
            // Finish writing
            if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCodeVideo {
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
                            print("ERROR: \(avAssetWriter.error.debugDescription)")
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
            videoOutputSettings[AVVideoCodecKey] = AVVideoCodecType.proRes422
            
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422HQ)
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422)
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422LT)
            //videoOutputSettings[AVVideoCodecKey] = fourCharString(kCMVideoCodecType_AppleProRes422Proxy)
        } else {
            videoOutputSettings[AVVideoCodecKey] = AVVideoCodecType.h264
            
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
        if (audioOutputSettings[AVSampleRateKey] as! Float) > 96000 {
            // runs up to 96KHz
            audioOutputSettings[AVSampleRateKey] = 96000
        }
        if (audioOutputSettings[AVEncoderBitRateKey] as! Int) > 320*1024 {
            // runs up to 320Kbps
            audioOutputSettings[AVEncoderBitRateKey] = 320*1024
        }
        
        return audioOutputSettings
    }
    
    /* ======================================================================================== */
    // MARK: - capture delegate protocol
    /* ======================================================================================== */
    
    open func captureOutput(_ output: AVCaptureOutput,
                            didDrop sampleBuffer: CMSampleBuffer,
                            from connection: AVCaptureConnection) {
        let reason = CMGetAttachment(sampleBuffer,
                                     key: kCMSampleBufferAttachmentKey_DroppedFrameReason,
                                     attachmentModeOut: nil) as? String
        print("NOTICE: Dropped reason =", reason ?? "n/a")
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
        
        // Check discontinuity
        _ = checkDiscontinuity(sampleBuffer) // Ignore any error
        
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
            let cvSmpteTime = extractCVSMPTETime(from: sampleBuffer)
            if cvSmpteTime != nil {
                smpteReadyVideo = true
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
                    writeVideoSampleBufferResampled(sampleBuffer)
                }
                
                // Timecode track support
                if timeCodeFormatType != nil && smpteReadyVideo {
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
    
    private func writeAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
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
    
    private func writeVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
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
    
    private func writeTimecodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let avAssetWriterInputTimeCode = avAssetWriterInputTimeCodeVideo {
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
    
    private func writeVideoSampleBufferResampled(_ srcSampleBuffer: CMSampleBuffer) {
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
    
    private func checkdecompressor(_ sampleBuffer: CMSampleBuffer) -> Bool {
        if let decompressor = decompressor, decompressor.isReady() {
            return true
        }
        
        // Prepare decompressor (format transcode : device native => decompressed)
        decompressor = VideoDecompressor.init(source: sampleBuffer, deinterlace: encodeDeinterlace)
        
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
    
    private func encodedSizeOfSampleBuffer(_ sampleBuffer : CMSampleBuffer) -> CGSize? {
        var cgSize : CGSize? = nil
        if let format : CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format)
            cgSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        }
        
        return cgSize
    }
    
    private func checkDiscontinuity(_ sampleBuffer: CMSampleBuffer) -> Bool {
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
}
