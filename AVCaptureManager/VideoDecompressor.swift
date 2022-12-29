//
//  VideoDecompressor.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2016/08/07.
//  Copyright © 2016-2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation
import VideoToolbox

class VideoDecompressor : NSObject {
    
    /* ======================================================================================== */
    // MARK: - internal variables
    /* ======================================================================================== */
    
    // For callback
    internal var writeDecompressed: ((CMSampleBuffer) -> Void)? = nil
    
    // For decompressed pixelformat
    internal var pixelFormatType : CMPixelFormatType = kCMPixelFormat_422YpCbCr8
    
    /* ======================================================================================== */
    // MARK: - private variables
    /* ======================================================================================== */
    
    private var session: VTDecompressionSession? = nil
    private var ready: Bool = false
    private var fieldProcessing: Bool = false
    private var temporalProcessing: Bool = false
    
    /* ======================================================================================== */
    // MARK: - public init/deinit
    /* ======================================================================================== */
    
    init(source sampleBuffer: CMSampleBuffer, deinterlace doDeinterlace: Bool, pixelFormat format:CMPixelFormatType?) {
        super.init()
        
        // print("decompressor.init")
        
        if let format = format {
            pixelFormatType = format
        }
        _ = prepare(source: sampleBuffer, deinterlace: doDeinterlace)
    }
    
    deinit {
        // print("decompressor.deinit")
        
        invalidate()
    }
    
    /* ======================================================================================== */
    // MARK: - internal decompressor API
    /* ======================================================================================== */
    
    /// Verify if decompressor is prepared
    /// - Returns: true if ready
    internal func isReady() -> Bool {
        return ready
    }
    
    /// Prepare VTDecompressionSession
    /// - Parameters:
    ///   - sampleBuffer: source CMSampleBuffer to decode (or decompress)
    ///   - doDeinterlace: deinterlace flag (depends on decoder implementation)
    /// - Returns: true if no error
    internal func prepare(source sampleBuffer: CMSampleBuffer, deinterlace tryDeinterlace: Bool) -> Bool {
        // print("decompressor.prepare")
        
        ready = false
        
        // Extract FormatDescription
        let formatDescription: CMFormatDescription? = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        if let formatDescription = formatDescription {
            // VTVideoDecoderSpecification
            let decoderSpecification: [NSString: Any] = [
                kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: kCFBooleanTrue!,
                kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder: kCFBooleanFalse!
            ]
            
            // Prepare default attributes
            let dimensions: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            let defaultAttr: [NSString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: Int(pixelFormatType),
                kCVPixelBufferWidthKey: Int(dimensions.width),
                kCVPixelBufferHeightKey: Int(dimensions.height)
            ]
            
            // Create VTDecompressionSession
            var valid: OSStatus = noErr
            valid = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                 formatDescription: formatDescription,
                                                 decoderSpecification: decoderSpecification as CFDictionary?,
                                                 imageBufferAttributes: defaultAttr as CFDictionary?,
                                                 outputCallback: nil,
                                                 decompressionSessionOut: &session)
            if valid == noErr {
                // Ready to use
                ready = true
                
                // When requested:  Try deinterlace when decompressed
                if tryDeinterlace == true, let session = session {
                    verifyDeinterlaceSupport(session)
                }
            } else {
                print("ERROR: Failed to VTDecompressionSessionCreate(). error = \(valid)")
            }
        } else {
            print("ERROR: Failed to CMSampleBufferGetFormatDescription().")
        }
        return ready
    }
    
    /// Release VTDecompressionSession
    internal func invalidate() {
        // print("decompressor.invalidate")
        
        if let session = session {
            //
            VTDecompressionSessionInvalidate(session)
        }
        session = nil
        ready = false
    }
    
    /// Enqueue source CMSampleBuffer to decode (or decompress)
    /// - Parameter sampleBuffer: CMSampleBuffer to decompress
    /// - Returns: true if no error
    internal func decode(_ sampleBuffer: CMSampleBuffer) -> Bool {
        if isReady(), let session = session {
            //print("decompressor.decode")
            
            // Check sampleBuffer is ready to decompress
            let sampleBufferIsValid = CMSampleBufferIsValid(sampleBuffer)
            let sampleBufferDataIsReady = CMSampleBufferDataIsReady(sampleBuffer)
            if sampleBufferIsValid && sampleBufferDataIsReady == true {
                // Prepare parameters
                let decodeFlags: VTDecodeFrameFlags = (
                    temporalProcessing
                        ? [._EnableAsynchronousDecompression, ._EnableTemporalProcessing]
                        : [._EnableAsynchronousDecompression])
                var infoFlagsOut: VTDecodeInfoFlags = VTDecodeInfoFlags(rawValue: 0)
                
                // Extract attachment from source SampleBuffer
                let propagate = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                              target: sampleBuffer,
                                                              attachmentMode: kCMAttachmentMode_ShouldPropagate)
                
                // Prepare output handler using source attachments
                let outputHandler = handler(propagate)
                
                // Decompress sampleBuffer
                let valid: OSStatus = VTDecompressionSessionDecodeFrame(session,
                                                                        sampleBuffer: sampleBuffer,
                                                                        flags: decodeFlags,
                                                                        infoFlagsOut: &infoFlagsOut,
                                                                        outputHandler: outputHandler)
                if valid == noErr {
                    // Queued sampleBuffer to decode
                    return true
                } else {
                    print("ERROR: Failed to VTDecompressionSessionDecodeFrame(). error = \(valid)")
                }
            } else {
                print("ERROR: Failed to decode sampleBuffer - invalid sampleBuffer detected.")
            }
        } else {
            print("ERROR: Failed to decode sampleBuffer - Not ready.")
        }
        return false
    }
    
    /// Flush decompressionSession queue
    internal func flush() {
        if isReady(), let session = session {
            //print("decompressor.flush")
            
            let result1: OSStatus = VTDecompressionSessionFinishDelayedFrames(session)
            if result1 != noErr {
                print("ERROR: VTDecompressionSessionFinishDelayedFrames(). error = \(result1)")
            }
            
            let result2: OSStatus = VTDecompressionSessionWaitForAsynchronousFrames(session)
            if result2 != noErr {
                print("ERROR: VTDecompressionSessionWaitForAsynchronousFrames(). error = \(result2)")
            }
        } else {
            print("ERROR: Failed to decode sampleBuffer - Not ready.")
        }
    }
    
    /// Test/Enable if decoder supports deinterlacing video
    /// - Parameter session: VTDecompressionSession
    private func verifyDeinterlaceSupport(_ session: VTDecompressionSession) {
        // Query available supported property keys of the decoder
        var support: CFDictionary? = nil
        let result0: OSStatus = VTSessionCopySupportedPropertyDictionary(session, supportedPropertyDictionaryOut: &support)
        
        if result0 == noErr, let support = support {
            // FieldMode_DeinterlaceFields
            fieldProcessing = false
            if CFDictionaryContainsKey(support, ptr(kVTDecompressionPropertyKey_FieldMode)) {
                // Ready to deinterlace fields
                let result1 = VTSessionSetProperty(session,
                                                   key: kVTDecompressionPropertyKey_FieldMode,
                                                   value: kVTDecompressionProperty_FieldMode_DeinterlaceFields)
                if result1 == noErr {
                    // Decoder supports deinterlace fields feature.
                    // Deinterlaced decodring is enabled now.
                    fieldProcessing = true
                } else {
                    // Ignore error
                    print("ERROR: Failed to enable FieldMode_DeinterlaceFields. (\(result1))")
                }
            } else {
                // print("NOTE: The decoder do not support FieldMode_DeinterlaceFields.")
            }
            
            // DeinterlaceMode_Temporal
            temporalProcessing = false
            if CFDictionaryContainsKey(support, ptr(kVTDecompressionPropertyKey_DeinterlaceMode)) {
                // Ready to deinterlaceMode
                let result2 = VTSessionSetProperty(session,
                                                   key: kVTDecompressionPropertyKey_DeinterlaceMode,
                                                   value: kVTDecompressionProperty_DeinterlaceMode_Temporal)
                if result2 == noErr {
                    // Decoder supports temporal processing for deinterlaceMode.
                    // Try temporal processing on decoding.
                    temporalProcessing = true
                    return
                } else {
                    // Ignore error
                    print("ERROR: Failed to enable DeinterlaceMode_Temporal. (\(result2))")
                }
            } else {
                // print("NOTE: The decoder do not support DeinterlaceMode_Temporal.")
            }
        } else {
            print("ERROR: Failed to query VTSessionCopySupportedPropertyDictionary().")
        }
    }
    
    /// Translate any CFTypeRef to UnsafeRawPointer
    /// - Parameter cfType: CFTypeRef
    /// - Returns: UnsafeRawPointer
    private func ptr(_ cfType :CFTypeRef) -> UnsafeRawPointer {
        let ptr = Unmanaged.passUnretained(cfType).toOpaque()
        return UnsafeRawPointer(ptr)
    }
    
    /* ======================================================================================== */
    // MARK: - private VTDecompressionOutputHandler builder
    /* ======================================================================================== */
    
    /// Decompression Output Handler
    /// - Parameter propagate: Dictionary for propagate CMAttachments
    /// - Returns: VTDecompressionOutputHandler
    private func handler(_ propagate: CFDictionary?) -> VTDecompressionOutputHandler {
        return { [unowned self] (
            status: OSStatus,
            infoFlags: VTDecodeInfoFlags,
            imageBuffer: CVImageBuffer?,
            presentationTimeStamp: CMTime,
            presentationDuration: CMTime
            ) in
            
            // Check if CVImageBuffer is ready
            if status == noErr, let imageBuffer = imageBuffer {
                var valid: OSStatus = noErr
                
                // Create format description for imageBuffer
                var formatDescription: CMVideoFormatDescription? = nil
                valid = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: imageBuffer, formatDescriptionOut: &formatDescription)
                
                if valid == noErr, let formatDescription = formatDescription {
                    // Create CMSampleTimingInfo struct
                    let decodeTimeStamp = CMTime.invalid
                    var sampleTiming = CMSampleTimingInfo(duration: presentationDuration,
                                                          presentationTimeStamp: presentationTimeStamp,
                                                          decodeTimeStamp: decodeTimeStamp)
                    
                    // Create CMSampleBuffer from imageBuffer
                    var sampleBuffer: CMSampleBuffer? = nil
                    valid = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                               imageBuffer: imageBuffer,
                                                               dataReady: true,
                                                               makeDataReadyCallback: nil,
                                                               refcon: nil,
                                                               formatDescription: formatDescription,
                                                               sampleTiming: &sampleTiming,
                                                               sampleBufferOut: &sampleBuffer)
                    
                    // Copy all attachments propagated
                    if valid == noErr, let sampleBuffer = sampleBuffer, let propagate = propagate {
                        CMSetAttachments(sampleBuffer, attachments: propagate, attachmentMode: kCMAttachmentMode_ShouldPropagate)
                    }
                    
                    // Callback AVCaptureManager to write decompressed sample buffer
                    if valid == noErr, let sampleBuffer = sampleBuffer, let writeDecompressed = writeDecompressed {
                        writeDecompressed(sampleBuffer)
                    } else {
                        print("ERROR: Failed to CMSampleBufferCreateForImageBuffer(). error = \(valid)")
                    }
                } else {
                    print("ERROR: Failed to CMVideoFormatDescriptionCreateForImageBuffer(). error = \(valid)")
                }
            } else {
                print("ERROR: No imageBuffer is decoded. error = \(status)")
            }
        }
    }
    
}
