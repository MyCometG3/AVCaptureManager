//
//  AVCaptureManager+Timecode.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/13.
//  Copyright © 2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation
import CoreMediaIO.CMIOSampleBuffer

extension AVCaptureManager {
    
    /* ======================================================================================== */
    // MARK: - private Timecode support func
    /* ======================================================================================== */
    
    /// Create TimeCode CMSampleBuffer from CMIOSampleBufferAttatchment with same timingInfo as source sampleBuffer
    /// - Parameter srcSampleBuffer: source SampleBuffer
    /// - Returns: TimeCode CMSampleBuffer
    internal func createTimeCodeSampleBuffer(from srcSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
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
    
    /// Extract CVSMPTETime CMIOSampleBufferAttachment if available
    /// - Parameter sampleBuffer: CMSampleBuffer to inspect
    /// - Returns: CVSMPTETime if available
    internal func extractCVSMPTETime(from sampleBuffer: CMSampleBuffer) -> CVSMPTETime? {
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
    
    /// Create a complete copy of SMPTETime as CVSMPTETime
    /// - Parameter smpteTime: SMPTETime in CoreAudioBaseTypes.h
    /// - Returns: CVSMPTETime
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
    
    /// Create TimeCode CMBlockBuffer
    /// - Parameters:
    ///   - smpteTime: CVSMPTETime
    ///   - sizes: size in byte for tmcd or tc64
    ///   - quanta: quanta
    ///   - tcType: tcType
    /// - Returns: TimeCode CMBlockBuffer
    private func prepareTimeCodeDataBuffer(_ smpteTime: CVSMPTETime,
                                           _ sizes: Int,
                                           _ quanta: UInt32,
                                           _ tcType: UInt32) -> CMBlockBuffer?  {
        //
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

}
