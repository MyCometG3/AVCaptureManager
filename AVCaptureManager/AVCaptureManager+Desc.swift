//
//  AVCaptureManager+Desc.swift
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

extension AVCaptureManager {
    
    /* ======================================================================================== */
    // MARK: - public print description API
    /* ======================================================================================== */
    
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
    
    public func devicesMuxed() -> [Any]! {
        let deviceArrayInfoMuxed = deviceInfoArray(mediaType: AVMediaType.muxed)
        return deviceArrayInfoMuxed
    }
    
    public func devicesVideo() -> [Any]! {
        let deviceArrayInfoVideo = deviceInfoArray(mediaType: AVMediaType.video)
        return deviceArrayInfoVideo
    }
    
    public func devicesAudio() -> [Any]! {
        let deviceArrayInfoAudio = deviceInfoArray(mediaType: AVMediaType.audio)
        return deviceArrayInfoAudio
    }
    
    public func deviceInfoForUniqueID(_ uniqueID: String) -> [String:Any]? {
        guard let device = AVCaptureDevice.init(uniqueID: uniqueID) else { return nil }
        let deviceInfo: [String:Any] = deviceInfo(device)
        return deviceInfo
    }
    
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
    
    internal func mediaTypesDescription(for device:AVCaptureDevice) -> [String] {
        let array :[AVMediaType] = [.video,.audio,.text,.closedCaption,.subtitle,.timecode,.metadata,.muxed,.depthData]
        let result:[String] = array.filter{device.hasMediaType($0)}.map{$0.rawValue}
        return result
    }
    
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
    
    internal func deviceInfoArray(mediaType type: AVMediaType) -> [Any] {
        let deviceArray = AVCaptureDevice.devices(for: type)
        
        var deviceInfoArray = [Any]()
        for device in deviceArray {
            let deviceInfo: [String:Any] = deviceInfo(device)
            deviceInfoArray.append(deviceInfo)
        }
        
        return deviceInfoArray
    }
    
}
