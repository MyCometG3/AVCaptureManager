//
//  AVCaptureManager+Desc.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/10.
//  Copyright © 2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation

extension AVCaptureManager {
    
    /* ======================================================================================== */
    // MARK: - public print description API
    /* ======================================================================================== */
    
    /// (Debug) dump device info for muxed, video, and audio.
    public func listDevice() {
        let deviceInfoMuxed = devicesMuxed()
        print("\n", "AVMediaTypeMuxed: \(deviceInfoMuxed?.count ?? 0) found:")
        deviceInfoMuxed?.forEach{ info in print(": ", info)}
        
        let deviceInfoVideo = devicesVideo()
        print("\n", "AVMediaTypeVideo: \(deviceInfoVideo?.count ?? 0) found:")
        deviceInfoVideo?.forEach{ info in print(": ", info )}
        
        let deviceInfoAudio = devicesAudio()
        print("\n", "AVMediaTypeAudio: \(deviceInfoAudio?.count ?? 0) found:")
        deviceInfoAudio?.forEach{ info in print(": ", info )}
    }
    
    /// (Debug) device info for muxed
    /// - Returns: devices info
    public func devicesMuxed() -> [Any]! {
        let deviceArrayInfoMuxed = deviceInfoArray(mediaType: AVMediaType.muxed)
        return deviceArrayInfoMuxed
    }
    
    /// (Debug) device info for video
    /// - Returns: devices info
    public func devicesVideo() -> [Any]! {
        let deviceArrayInfoVideo = deviceInfoArray(mediaType: AVMediaType.video)
        return deviceArrayInfoVideo
    }
    
    /// (Debug) device info for audio
    /// - Returns: devices info
    public func devicesAudio() -> [Any]! {
        let deviceArrayInfoAudio = deviceInfoArray(mediaType: AVMediaType.audio)
        return deviceArrayInfoAudio
    }
    
    /// (Debug) device info for specified uniqueID
    /// - Returns: devices info
    public func deviceInfoForUniqueID(_ uniqueID: String) -> [String:Any]? {
        guard let device = AVCaptureDevice.init(uniqueID: uniqueID) else { return nil }
        let deviceInfo: [String:Any] = deviceInfo(device)
        return deviceInfo
    }
    
    /// (Debug) dump session diag info
    public func printSessionDiag() {
        print("")
        
        /* ============================================ */
        
        if let captureDeviceVideo = captureDeviceVideo {
            print("captureDeviceVideo (\( captureDeviceVideo.localizedName), \(captureDeviceVideo.modelID)):")
            
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
                print(": videoSupportedFrameRateRanges = \(videoSupportedFrameRateRanges?.debugDescription ?? "n/a")")
                let description : CMFormatDescription = (format as AnyObject).formatDescription
                print(": description = \(description)")
                
                let mediaTypeString = fourCharString(CMFormatDescriptionGetMediaType(description))
                let mediaSubTypeString = fourCharString(CMFormatDescriptionGetMediaSubType(description))
                print(": \"\(mediaTypeString)\", \"\(mediaSubTypeString)\"")
                
                let extensions = CMFormatDescriptionGetExtensions(description)
                print(": \(extensions.debugDescription)")
                
                //var size = 0
                //let rect = CMVideoFormatDescriptionGetCleanAperture(description, true)
                //let dimensions = CMVideoFormatDescriptionGetDimensions(description)
                // CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers()
                //let sizeWithoutAspectAndAperture = CMVideoFormatDescriptionGetPresentationDimensions(description, false, false)
                //let sizeWithAspectAndAperture = CMVideoFormatDescriptionGetPresentationDimensions(description, true, true)
            }
            print("")
        } else {
            print("captureDeviceVideo: is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureDeviceAudio = captureDeviceAudio {
            print("captureDeviceAudio (\( captureDeviceAudio.localizedName), \(captureDeviceAudio.modelID)):")
            
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
                print(": \(extensions.debugDescription)")
                
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
            print("captureDeviceAudio: is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureMovieFileOutput = captureMovieFileOutput {
            print("captureMovieFileOutput:")
            
            for connection in captureMovieFileOutput.connections {
                print(": connection = \(connection)")
            }
            
            print("")
        } else {
            print("captureMovieFileOutput: is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureVideoDataOutput = captureVideoDataOutput {
            print("captureVideoDataOutput:")
            print(": videoSettings = \(String(describing: captureVideoDataOutput.videoSettings))")
            
            #if true
                // : availableCodecTypes = [avc1, jpeg]
                let codecTypes = captureVideoDataOutput.availableVideoCodecTypes
                print(": availableCodecTypes = \(codecTypes.debugDescription)") // String array
                
                // : availableVideoCVPixelFormatTypes = [846624121, 2037741171, 875704438, 875704422, 32, 1111970369]
                let pixfmtTypes = captureVideoDataOutput.availableVideoCVPixelFormatTypes
                print(": availableVideoCVPixelFormatTypes = \(pixfmtTypes.debugDescription) in UInt32 array") // UInt32 array
                
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
            print("captureVideoDataOutput: is not ready.")
            print("")
        }
        
        /* ============================================ */
        
        if let captureAudioDataOutput = captureAudioDataOutput {
            print("captureAudioDataOutput:")
            print(": audioSettings = \(String(describing: captureAudioDataOutput.audioSettings))")
            print("")
        } else {
            print("captureAudioDataOutput: is not ready.")
            print("")
        }
    }
    
    /* ======================================================================================== */
    // MARK: - internal print description API
    /* ======================================================================================== */
    
    internal func printDescritionImageBuffer(_ sampleBuffer : CMSampleBuffer) {
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
    
    internal func printDescriptionAudioBuffer(_ sampleBuffer : CMSampleBuffer) {
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
    
    /* ======================================================================================== */
    // MARK: - private support func
    /* ======================================================================================== */
    
    /// (Debug) Get supported meia type by the device
    /// - Parameter device: AVCaptureDevice
    /// - Returns: String representation of supported AVMediaType(s) array
    internal func mediaTypesDescription(for device:AVCaptureDevice) -> [String] {
        let array :[AVMediaType] = [.video,.audio,.text,.closedCaption,.subtitle,.timecode,.metadata,.muxed,.depthData]
        let result:[String] = array.filter{device.hasMediaType($0)}.map{$0.rawValue}
        return result
    }
    
    /// (Debug) Get common FPS values which is supported by the device
    /// - Parameter device: AVCaptureDevice
    /// - Returns: String representation of supported common FPS(s) array
    internal func supportedVideoFPSDescription(for device:AVCaptureDevice) -> [String] {
        var result:[String] = []
        let formatArray = device.formats
        let testFPSArray:[Float64] = [12, 12.5, 14.985, 15, 23.976, 24, 25, 29.97, 30,
                                      47.952, 48, 50, 59.94, 60, 95.904, 96, 100]
        let testDuration:[CMTime] = testFPSArray.map{CMTimeMakeWithSeconds(1.0/$0, preferredTimescale: 120000)}
        for (index, format) in formatArray.enumerated() {
            let validFPSArray:[String] = testDuration
                .filter{validateSampleDuration($0, format: format)}
                .map{1/$0.seconds}
                .map{String(format: "%.3f", $0)}
            let description = (validFPSArray.count > 0 ? validFPSArray.joined(separator: ",") : "n/a")
            let resultFormat = String(format: "format(%d): [%@]", index, description)
            result.append(resultFormat)
        }
        return result
    }
    
    /// (Debug) Test specific sampleDuration is supported or not
    /// - Parameters:
    ///   - duration: duration for query
    ///   - format: AVCaptureDevice.Format
    /// - Returns: true if supported
    internal func validateSampleDuration(_ duration:CMTime, format:AVCaptureDevice.Format) -> Bool {
        let rangeArray: [AVFrameRateRange] = format.videoSupportedFrameRateRanges
        for range in rangeArray {
            #if false
                /*
                 * Some poor UVC device returns broken min/max FPSs, even if the input is in 59.94i.
                 * e.g. <AVFrameRateRange: 0x6000026a2230 30.00 - 60.00 (1000000 / 30000030 - 1000000 / 60000240)>
                 * => FPS(min,max) = (30.00003000,60.00024000),
                 * It does NOT run in 30 fps. And also 29.970fps is out of range... sigh.
                 */
                let debug = String(format: "%.9f,(%.9f-%.9f):",
                                   1.0/duration.seconds, range.minFrameRate, range.maxFrameRate)
                let closed :(ClosedRange<CMTime>) = (range.minFrameDuration...range.maxFrameDuration)
                print(debug, (closed.contains(duration) ? "true" : "false"))
            #endif
            if (range.minFrameDuration...range.maxFrameDuration).contains(duration) {
                return true
            }
        }
        return false
    }
    
    /// (Debug) Device info for AVCaptureDevice
    /// - Parameter device: AVCaptureDevice
    /// - Returns: device info
    internal func deviceInfo(_ device: AVCaptureDevice) -> [String:Any] {
        var deviceInfo: [String:Any] = [
            "uniqueID" : device.uniqueID,
            "modelID" : device.modelID,
            "localizedName" : device.localizedName,
            "manufacturer" : device.manufacturer,
            "transportType" : fourCharString(UInt32.init(device.transportType)),
            "connected" : device.isConnected,
            "inUseByAnotherApplication" : device.isInUseByAnotherApplication,
            "suspended" : device.isSuspended,
            "mediaTypes" : mediaTypesDescription(for: device)
        ]
        if device.hasMediaType(.video) {
            deviceInfo["nativeFPSs"] = supportedVideoFPSDescription(for: device)
        }
        return deviceInfo
    }
    
    /// (Debug) device info array for specified AVMediaType
    /// - Parameter type: AVMediaType
    /// - Returns: device info array
    internal func deviceInfoArray(mediaType type: AVMediaType) -> [Any] {
        let deviceArray = AVCaptureDevice.devices(for: type)
        
        var deviceInfoArray = [Any]()
        for device in deviceArray {
            let deviceInfo: [String:Any] = deviceInfo(device)
            deviceInfoArray.append(deviceInfo)
        }
        
        return deviceInfoArray
    }
    
    /// Translate OSType into String
    /// - Parameter type: OSType
    /// - Returns: String representation
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
