//
//  VideoDecompressor.swift
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

import Foundation
import AVFoundation

import CoreFoundation
import CoreVideo
import CoreMedia
import VideoToolbox

class VideoDecompressor : NSObject {
    /* ======================================================================================== */
    // MARK: - internal variables
    /* ======================================================================================== */
    
    // For callback
    internal var writeDecompressed: ((CMSampleBuffer) -> Void)? = nil
    
    /* ======================================================================================== */
    // MARK: - private variables
    /* ======================================================================================== */
    
    private var session: VTDecompressionSession? = nil
    private var ready: Bool = false
    private var temporalProcessing: Bool = false
    
    /* ======================================================================================== */
    // MARK: - public init/deinit
    /* ======================================================================================== */
    
    init(source sampleBuffer: CMSampleBuffer, deinterlace doDeinterlace: Bool) {
        super.init()
        
        // print("decompressor.init")
        
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
    internal func prepare(source sampleBuffer: CMSampleBuffer, deinterlace doDeinterlace: Bool) -> Bool {
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
                kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_422YpCbCr8),
                kCVPixelBufferWidthKey: Int(dimensions.width),
                kCVPixelBufferHeightKey: Int(dimensions.height)
                //, kCVPixelBufferIOSurfacePropertiesKey: [:]
                , kCVPixelBufferOpenGLCompatibilityKey: true
                //, kCVPixelBufferMetalCompatibilityKey: true // __MAC_10_11
                //, kCVPixelBufferOpenGLTextureCacheCompatibilityKey: true // __MAC_10_11
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
                if doDeinterlace == true, let session = session {
                    // Query available supported property keys of the decoder
                    var support: CFDictionary? = nil
                    let result0: OSStatus = VTSessionCopySupportedPropertyDictionary(session, supportedPropertyDictionaryOut: &support)
                    
                    if result0 == noErr, let support = support {
                        // FieldMode_DeinterlaceFields
                        if CFDictionaryContainsKey(support, Unmanaged.passUnretained(kVTDecompressionPropertyKey_FieldMode).toOpaque()) {
                            // Ready to deinterlace fields
                            let result1 = VTSessionSetProperty(session,
                                                               key: kVTDecompressionPropertyKey_FieldMode,
                                                               value: kVTDecompressionProperty_FieldMode_DeinterlaceFields)
                            if result1 == noErr {
                                // Decoder supports deinterlace fields feature.
                                // Deinterlaced decodring is enabled now.
                            } else {
                                // Ignore error
                                print("ERROR: Failed to enable FieldMode_DeinterlaceFields. (\(result1))")
                            }
                        } else {
                            // print("NOTE: The decoder do not support FieldMode_DeinterlaceFields.")
                        }
                        
                        // DeinterlaceMode_Temporal
                        if CFDictionaryContainsKey(support, Unmanaged.passUnretained(kVTDecompressionPropertyKey_DeinterlaceMode).toOpaque()) {
                            // Ready to deinterlaceMode
                            let result2 = VTSessionSetProperty(session,
                                                               key: kVTDecompressionPropertyKey_DeinterlaceMode,
                                                               value: kVTDecompressionProperty_DeinterlaceMode_Temporal)
                            if result2 == noErr {
                                // Decoder supports temporal processing for deinterlaceMode.
                                // Try temporal processing on decoding.
                                temporalProcessing = doDeinterlace
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
