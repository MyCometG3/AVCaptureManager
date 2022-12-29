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
    // MARK: - internal/private query video codec property support
    /* ======================================================================================== */
    
    /// Query video compressor supported properties dictionary
    /// - Parameters:
    ///   - codec: video encoder
    ///   - enableHW: use HW accelerator
    ///   - key: Property Key to query. Specify nil to get whole dictionary.
    /// - Returns: Resulted CFDictionary
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
    
    /// Query video decompressor supported properties dictionary
    /// - Parameters:
    ///   - codec: video decoder
    ///   - srcFD: source CMFormatDescription
    ///   - enableHW: use HW accelerator
    ///   - key: Property Key to query. Specify nil to get whole dictionary.
    /// - Returns: Resulted CFDictionary
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
    
    /// Create dummy compression session
    /// - Parameters:
    ///   - codec: video encoder
    ///   - enableHW: use HW accelerator
    /// - Returns: true if no error
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
    
    /// Create dummy decompression session
    /// - Parameters:
    ///   - codec: video decoder
    ///   - srcFD: source CMFormatDescription
    ///   - enableHW: use HW accelerator
    /// - Returns: true if no error
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
    
    /// Copy supported properties dictionary from VTSession
    /// - Parameter session: VTSession for decode or encode
    /// - Returns: Resulted CFDictionary
    private func getSupportedDictionary(_ session:VTSession) -> CFDictionary? {
        //
        var dict:CFDictionary? = nil
        let status = VTSessionCopySupportedPropertyDictionary(session,
                                                              supportedPropertyDictionaryOut: &dict)
        return (status == noErr ? dict : nil)
    }
    
    /// Extract CFDictionary value from parent CFDictionary
    /// - Parameters:
    ///   - dict: parent CFDictionary
    ///   - key: Key to test
    /// - Returns: Resulted CFDictionary
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
    // MARK: - internal/private FourCC conversion utilities
    /* ======================================================================================== */
    
    /// Translate AVVideoCodecType to CMVideoCodecType
    /// - Parameter codec: AVVideoCodecType
    /// - Returns: CMVideoCodecType
    internal func fourCC(avVideoCodecType codec: AVVideoCodecType) -> CMVideoCodecType {
        let src: String = codec.rawValue
        let fourCC: UInt32 = fourCC(str: src)
        return CMVideoCodecType(fourCC)
    }
    
    /// Translate String to FourCharCode
    /// - Parameter src: String
    /// - Returns: FourCharCode
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
    /// Translate CMVideoCodecType to AVVideoCodecType
    /// - Parameter codec: CMVideoCodecType
    /// - Returns: AVVideoCodecType
    internal func fourCC(cmVideoCodecType codec: CMVideoCodecType) -> AVVideoCodecType {
        let src: UInt32 = UInt32(codec)
        let fourCC :String = fourCC(uint32: src)
        return AVVideoCodecType(rawValue: fourCC)
    }
    
    /// Translate FourCharCode to String
    /// - Parameter src: FourCharCode
    /// - Returns: String
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
    
    /* ======================================================================================== */
    // MARK: - internal encoder specific support func
    /* ======================================================================================== */
    
    /// Adjust H264 Compression Properties
    /// - Parameter compressionProperties: AVVideoCompressionProperties (inout)
    internal func adjustCompressionPropertiesH264(_ compressionProperties:inout [String:Any]) {
        let bitRate = compressionProperties[AVVideoAverageBitRateKey] as? Int
        let profile = compressionProperties[AVVideoProfileLevelKey] as? CFTypeRef
        
        if let profile = profile, let bitRate = bitRate {
            let profile = profile as! CFString
            var vcl = bitRate
            
            switch profile {
            case kVTProfileLevel_H264_High_AutoLevel:   vcl = min(vcl, H264ProfileLevel.HiP_52.maxRate)
            case kVTProfileLevel_H264_High_5_2:         vcl = min(vcl, H264ProfileLevel.HiP_52.maxRate)
            case kVTProfileLevel_H264_High_5_1:         vcl = min(vcl, H264ProfileLevel.HiP_51.maxRate)
            case kVTProfileLevel_H264_High_5_0:         vcl = min(vcl, H264ProfileLevel.HiP_50.maxRate)
            case kVTProfileLevel_H264_High_4_2:         vcl = min(vcl, H264ProfileLevel.HiP_42.maxRate)
            case kVTProfileLevel_H264_High_4_1:         vcl = min(vcl, H264ProfileLevel.HiP_41.maxRate)
            case kVTProfileLevel_H264_High_4_0:         vcl = min(vcl, H264ProfileLevel.HiP_40.maxRate)
            case kVTProfileLevel_H264_High_3_2:         vcl = min(vcl, H264ProfileLevel.HiP_32.maxRate)
            case kVTProfileLevel_H264_High_3_1:         vcl = min(vcl, H264ProfileLevel.HiP_31.maxRate)
            case kVTProfileLevel_H264_High_3_0:         vcl = min(vcl, H264ProfileLevel.HiP_30.maxRate)
                
            case kVTProfileLevel_H264_Extended_AutoLevel: vcl = min(vcl, H264ProfileLevel.MP_52.maxRate)
            case kVTProfileLevel_H264_Extended_5_0:     vcl = min(vcl, H264ProfileLevel.MP_50.maxRate)
                
            case kVTProfileLevel_H264_Main_AutoLevel:   vcl = min(vcl, H264ProfileLevel.MP_52.maxRate)
            case kVTProfileLevel_H264_Main_5_2:         vcl = min(vcl, H264ProfileLevel.MP_52.maxRate)
            case kVTProfileLevel_H264_Main_5_1:         vcl = min(vcl, H264ProfileLevel.MP_51.maxRate)
            case kVTProfileLevel_H264_Main_5_0:         vcl = min(vcl, H264ProfileLevel.MP_50.maxRate)
            case kVTProfileLevel_H264_Main_4_2:         vcl = min(vcl, H264ProfileLevel.MP_42.maxRate)
            case kVTProfileLevel_H264_Main_4_1:         vcl = min(vcl, H264ProfileLevel.MP_41.maxRate)
            case kVTProfileLevel_H264_Main_4_0:         vcl = min(vcl, H264ProfileLevel.MP_40.maxRate)
            case kVTProfileLevel_H264_Main_3_2:         vcl = min(vcl, H264ProfileLevel.MP_32.maxRate)
            case kVTProfileLevel_H264_Main_3_1:         vcl = min(vcl, H264ProfileLevel.MP_31.maxRate)
            case kVTProfileLevel_H264_Main_3_0:         vcl = min(vcl, H264ProfileLevel.MP_30.maxRate)
                
            case kVTProfileLevel_H264_Baseline_AutoLevel: vcl = min(vcl, H264ProfileLevel.MP_52.maxRate)
            case kVTProfileLevel_H264_Baseline_5_2:     vcl = min(vcl, H264ProfileLevel.MP_52.maxRate)
            case kVTProfileLevel_H264_Baseline_5_1:     vcl = min(vcl, H264ProfileLevel.MP_51.maxRate)
            case kVTProfileLevel_H264_Baseline_5_0:     vcl = min(vcl, H264ProfileLevel.MP_50.maxRate)
            case kVTProfileLevel_H264_Baseline_4_2:     vcl = min(vcl, H264ProfileLevel.MP_42.maxRate)
            case kVTProfileLevel_H264_Baseline_4_1:     vcl = min(vcl, H264ProfileLevel.MP_41.maxRate)
            case kVTProfileLevel_H264_Baseline_4_0:     vcl = min(vcl, H264ProfileLevel.MP_40.maxRate)
            case kVTProfileLevel_H264_Baseline_3_2:     vcl = min(vcl, H264ProfileLevel.MP_32.maxRate)
            case kVTProfileLevel_H264_Baseline_3_1:     vcl = min(vcl, H264ProfileLevel.MP_31.maxRate)
            case kVTProfileLevel_H264_Baseline_3_0:     vcl = min(vcl, H264ProfileLevel.MP_30.maxRate)
                
            default:
                if #available(macOS 12.0, *), profile == kVTProfileLevel_H264_ConstrainedBaseline_AutoLevel {
                    vcl = min(vcl, H264ProfileLevel.MP_52.maxRate)
                } else
                if #available(macOS 12.0, *), profile == kVTProfileLevel_H264_ConstrainedHigh_AutoLevel {
                    vcl = min(vcl, H264ProfileLevel.HiP_52.maxRate)
                } else {
                    // unsupported profile - Force MP_40 instead
                    compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_H264_Main_4_0
                    vcl = H264ProfileLevel.MP_40.maxRate
                }
            }
            compressionProperties[AVVideoAverageBitRateKey] = vcl
        }
    }
    
    /// Adjust HEVC Compression Properties
    /// - Parameter compressionProperties: AVVideoCompressionProperties (inout)
    internal func adjustCompressionPropertiesHEVC(_ compressionProperties:inout [String:Any]) {
        let bitRate = compressionProperties[AVVideoAverageBitRateKey] as? Int
        let profile = compressionProperties[AVVideoProfileLevelKey] as? CFTypeRef
        
        if let profile = profile as CFTypeRef?, let bitRate = bitRate {
            let profile = profile as! CFString
            var vcl = bitRate
            
            switch profile {
            case kVTProfileLevel_HEVC_Main10_AutoLevel: vcl = min(vcl, HEVCProfileLevel.MP_52.maxRate)
            case kVTProfileLevel_HEVC_Main_AutoLevel:   vcl = min(vcl, HEVCProfileLevel.MP_52.maxRate)
            
            default:
                if #available(macOS 12.3, *), profile == kVTProfileLevel_HEVC_Main42210_AutoLevel {
                    vcl = min(vcl, HEVCProfileLevel.MP42210_52.maxRate)
                } else {
                    // unsupported profile - Force Main instead
                    compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
                    vcl = HEVCProfileLevel.MP_52.maxRate
                }
            }
            compressionProperties[AVVideoAverageBitRateKey] = vcl
        }
    }
    
    /// Adjust Audio Compression Settings
    /// - Parameters:
    ///   - audioFormat: AudioFormatID
    ///   - audioOutputSettings: audioOutputSettings (inout)
    internal func adjustSettingsAudio(_ audioFormat:AudioFormatID, _ audioOutputSettings:inout [String:Any]) {
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
    }
    
}
