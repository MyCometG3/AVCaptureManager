//
//  AVCaptureManager+CodecSupport.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/26.
//  Copyright © 2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation
import VideoToolbox

extension AVCaptureManager {
    
    /* ======================================================================================== */
    // MARK: - Debug - query codec property support
    /* ======================================================================================== */
    
    internal func checkVTSupportedProperties(encoder codec:CMVideoCodecType,
                                             accelerator enableHW:Bool,
                                             key:String?) -> CFDictionary?
    {
        let session:VTCompressionSession? = createDummySession(encoder: codec,
                                                               accelerator: enableHW)
        if let session = session {
            let dict:CFDictionary? = getSupportedDictionary(session)
            if let dict = dict {
                guard let key = key else {
                    print("NOTICE:Supported Dictionary(\(fourCC(uint32: codec))):", dict)
                    return dict
                }
                return evaluateDictionary(dict, key)
            }
        }
        return nil
    }
    
    internal func checkVTSupportedProperties(decoder codec:CMVideoCodecType,
                                             formatDescription srcFD:CMVideoFormatDescription,
                                             accelerator enableHW:Bool,
                                             key:String?) -> CFDictionary?
    {
        let session:VTDecompressionSession? = createDummySession(decoder: codec,
                                                                 formatDescription: srcFD,
                                                                 accelerater: enableHW)
        if let session = session {
            let dict:CFDictionary? = getSupportedDictionary(session)
            if let dict = dict {
                guard let key = key else {
                    print("NOTICE:Supported Dictionary(\(fourCC(uint32: codec))):", dict)
                    return dict
                }
                return evaluateDictionary(dict, key)
            }
        }
        return nil
    }
    
    private func createDummySession(encoder codec:CMVideoCodecType,
                                    accelerator enableHW:Bool) -> VTCompressionSession?
    {
        var session:VTCompressionSession? = nil
        var specification:NSDictionary = [
            kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder:false
        ]
        if enableHW {
            specification = [
                kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder:true,
                kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder:true
            ]
        }
        let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                width: 640, height: 480, codecType: codec,
                                                encoderSpecification: specification,
                                                imageBufferAttributes: nil,
                                                compressedDataAllocator: kCFAllocatorDefault,
                                                outputCallback: nil,
                                                refcon: nil,
                                                compressionSessionOut: &session)
        return (status == noErr ? session : nil)
    }
    
    private func createDummySession(decoder codec:CMVideoCodecType,
                                    formatDescription srcFD:CMVideoFormatDescription,
                                    accelerater enableHW:Bool) -> VTDecompressionSession?
    {
        var session:VTDecompressionSession? = nil
        var specification:NSDictionary = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder:false
        ]
        if enableHW {
            specification = [
                kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder:true,
                kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder:true
            ]
        }
        let status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                  formatDescription: srcFD,
                                                  decoderSpecification: specification,
                                                  imageBufferAttributes: nil,
                                                  outputCallback: nil,
                                                  decompressionSessionOut: &session)
        return (status == noErr ? session : nil)
    }
    
    private func getSupportedDictionary(_ session:VTSession) -> CFDictionary? {
        //
        var dict:CFDictionary? = nil
        let status = VTSessionCopySupportedPropertyDictionary(session,
                                                              supportedPropertyDictionaryOut: &dict)
        return (status == noErr ? dict : nil)
    }
    
    private func evaluateDictionary(_ dict: CFDictionary, _ key: String) -> CFDictionary? {
        let _key = key as NSString
        let _dict = dict as NSDictionary
        let _value = _dict[_key]
        
        if let _value = _value {
            return (_value as! CFDictionary)
        } else {
            return nil
        }
    }
    
    /* ======================================================================================== */
    // MARK: - Debug - FourCC conversion utilities
    /* ======================================================================================== */
    
    //
    internal func fourCC(avVideoCodecType codec: AVVideoCodecType) -> CMVideoCodecType {
        let src: String = codec.rawValue
        let fourCC: UInt32 = fourCC(str: src)
        return CMVideoCodecType(fourCC)
    }
    
    internal func fourCC(str src: String) -> UInt32 {
        var fourCC: UInt32 = 0
        if (src.count == 4 && src.utf8.count == 4) {
            for char: UInt8 in src.utf8 {
                fourCC = (fourCC << 8) | UInt32(char)
            }
        }
        return fourCC
    }
    
    //
    internal func fourCC(cmVideoCodecType codec: CMVideoCodecType) -> AVVideoCodecType {
        let src: UInt32 = UInt32(codec)
        let fourCC :String = fourCC(uint32: src)
        return AVVideoCodecType(rawValue: fourCC)
    }
    
    internal func fourCC(uint32 src: UInt32) -> String {
        let c1 : UInt32 = (src >> 24) & 0xFF
        let c2 : UInt32 = (src >> 16) & 0xFF
        let c3 : UInt32 = (src >>  8) & 0xFF
        let c4 : UInt32 = (src      ) & 0xFF
        let bytes: [CChar] = [
            printable(uint32: c1, 0x20),
            printable(uint32: c2, 0x20),
            printable(uint32: c3, 0x20),
            printable(uint32: c4, 0x20),
            CChar(0x00)
        ]
        let fourCC: String = String(cString: bytes)
        return fourCC
    }
    
    private func printable(uint32 c: UInt32, _ placeholder: UInt32) -> CChar {
        let printable = (0x20 <= c && c <= 0x7e)
        return (printable ? CChar(c) : CChar(placeholder))
    }
    
}
