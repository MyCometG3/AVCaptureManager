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
                        if self.isInitialTSReady == true {
                            //print("### Reset InitialTS for session")
                            self._duration = CMTimeGetSeconds(CMTimeSubtract(self.endTime, self.startTime))
                            self.isInitialTSReady = false
                            self.startTime = CMTime.zero
                            self.endTime = CMTime.zero
                        }
                        
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
                    writeVideoSampleBuffer(sampleBuffer)
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
    
    /* ======================================================================================== */
    // MARK: - private Timecode support func
    /* ======================================================================================== */
    
    private func createTimeCodeSampleBuffer(from srcSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        // Extract SMPTETime from source sample buffer
        guard let smpteTime = extractCVSMPTETime(from: srcSampleBuffer)
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
            let duration = CMSampleBufferGetDuration(srcSampleBuffer)
            
            // Extract timingInfo from video sample
            var timingInfo = CMSampleTimingInfo()
            CMSampleBufferGetSampleTimingInfo(srcSampleBuffer, at: 0, timingInfoOut: &timingInfo)
            
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
        /*
         NOTE: SMPTETime in CoreAudioBaseTypes.h == CVSMPTETime in CVBase.h

         kCMIOSampleBufferAttachmentKey_CAAudioTimeStamp:
             = com.apple.cmio.buffer_attachment.audio.core_audio_audio_time_stamp
         kCMIOSampleBufferAttachmentKey_SMPTETime:
             = com.apple.cmio.buffer_attachment.core_audio_smpte_time
         */
        
        var cvSmpteTime :CVSMPTETime? = nil
        
        // Test SampleBufferAttachment "CAAudioTimeStamp" as AudioTimeStamp
        let audioTimeStampKey = kCMIOSampleBufferAttachmentKey_CAAudioTimeStamp.takeUnretainedValue()
        let audioTimeStampData = CMGetAttachment(sampleBuffer, key: audioTimeStampKey, attachmentModeOut: nil)
        if let audioTimeStampData = audioTimeStampData as? NSData {
            let ats = audioTimeStampData.bytes.bindMemory(to: AudioTimeStamp.self,
                                                          capacity: audioTimeStampData.length).pointee
            if ats.mFlags.contains(.smpteTimeValid) {
                let smpteTime = ats.mSMPTETime
                cvSmpteTime = dupSMPTEtoCV(smpteTime)
            }
        }
        if cvSmpteTime == nil {
            // Test SampleBufferAttachment "SMPTETime"
            let smpteTimeKey = kCMIOSampleBufferAttachmentKey_SMPTETime.takeUnretainedValue()
            let smpteTimeData = CMGetAttachment(sampleBuffer, key: smpteTimeKey, attachmentModeOut: nil)
            if let smpteTimeData = smpteTimeData as? NSData {
                let smpteTime = smpteTimeData.bytes.bindMemory(to: SMPTETime.self,
                                                               capacity: smpteTimeData.count).pointee
                cvSmpteTime = dupSMPTEtoCV(smpteTime)
            }
        }
        
        return cvSmpteTime
    }
    
    private func dupSMPTEtoCV(_ smpteTime:SMPTETime) -> CVSMPTETime {
        // Create new copy of SMPTETime as CVSMPTETime,
        // as the original SMPTETime struct is backed by CFDataRef CMAttachment
        let cvSmpteTime = CVSMPTETime(subframes: smpteTime.mSubframes,
                                      subframeDivisor: smpteTime.mSubframeDivisor,
                                      counter: smpteTime.mCounter,
                                      type: smpteTime.mType.rawValue,
                                      flags: smpteTime.mFlags.rawValue,
                                      hours: smpteTime.mHours,
                                      minutes: smpteTime.mMinutes,
                                      seconds: smpteTime.mSeconds,
                                      frames: smpteTime.mFrames)
        return cvSmpteTime
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
                    self.writeVideoSampleBuffer(sampleBuffer)
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
    
}
