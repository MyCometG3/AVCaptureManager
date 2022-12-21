//
//  Constants.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2016/08/07.
//  Copyright © 2016-2022年 MyCometG3. All rights reserved.
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

/// Define h264 profile and level
public enum H264ProfileLevel {
    // For H264 encoder
    case MP_30 ; case HiP_30 ;
    case MP_31 ; case HiP_31 ;
    case MP_32 ; case HiP_32 ;
    case MP_40 ; case HiP_40 ;
    case MP_41 ; case HiP_41 ;
    case MP_42 ; case HiP_42 ;
    case MP_50 ; case HiP_50 ;
    case MP_51 ; case HiP_51 ;
    
    // Maximum video bitrate per Profile_Level
    var maxRate: Int {
        switch self {
        case .MP_30: return  10000000 ; case .HiP_30: return  12500000;
        case .MP_31: return  14000000 ; case .HiP_31: return  17500000;
        case .MP_32: return  20000000 ; case .HiP_32: return  25000000;
        case .MP_40: return  20000000 ; case .HiP_40: return  25000000;
        case .MP_41: return  50000000 ; case .HiP_41: return  62500000;
        case .MP_42: return  50000000 ; case .HiP_42: return  62500000;
        case .MP_50: return 135000000 ; case .HiP_50: return 168750000;
        case .MP_51: return 240000000 ; case .HiP_51: return 300000000;
        }
    }
}

public enum VideoStyle : String {
    case SD_640_480_Full    = "SD 640:480 Full"     // square pixel
    case SD_640_486_Full    = "SD 640:486 Full"     // square pixel
    case SD_768_576_Full    = "SD 768:576 Full"     // square pixel
    case HD_1280_720_Full   = "HD 1280:720 Full"    // square pixel
    case HD_1920_1080_Full  = "HD 1920:1080 Full"   // square pixel
    case SD_720_480_4_3     = "SD 720:480 4:3"      // clap - non square pixel
    case SD_720_480_16_9    = "SD 720:480 16:9"     // clap - non square pixel
    case SD_720_486_4_3     = "SD 720:486 4:3"      // clap - non square pixel
    case SD_720_486_16_9    = "SD 720:486 16:9"     // clap - non square pixel
    case SD_720_576_4_3     = "SD 720:576 4:3"      // clap - non square pixel
    case SD_720_576_16_9    = "SD 720:576 16:9"     // clap - non square pixel
    case HD_1920_1080_16_9  = "HD 1920:1080 16:9"   // clap - square pixel
    case HD_1280_720_16_9   = "HD 1280:720 16:9"    // clap - square pixel
    case SD_525_13_5MHz_4_3    = "525 13.5MHz 4:3"  // clap - non square pixel
    case SD_525_13_5MHz_16_9   = "525 13.5MHz 16:9" // clap - non square pixel
    case SD_625_13_5MHz_4_3    = "625 13.5MHz 4:3"  // clap - non square pixel
    case SD_625_13_5MHz_16_9   = "625 13.5MHz 16:9" // clap - non square pixel
    case HDV_HDCAM          = "HDV/HDCAM"           // clap - non square pixel
    
    case UHD4k_3840_2160_Full  = "UHD4k 3840:2160 Full"   // square pixel
    
    public func settings(
            hOffset horizontalOffset: Int,
            vOffset verticalOffset: Int
        ) -> [String: Any] {
        
        // clap/pasp => Technical Note TN2162
        // Uncompressed Y´CbCr Video in QuickTime Files
        // - Pixel Aspect Ratio, Clean Aperture, and Picture Aspect Ratio
        // - The 'pasp' ImageDescription Extension: Pixel Aspect Ratio
        // - The 'clap' ImageDescription Extension: Clean Aperture
        // (https://developer.apple.com/library/prerelease/content/technotes/tn2162/_index.html)
        
        var videoOutputSettings: [String:Any] = [:]
        var encodedWidth: Double,   encodedHeight: Double
        var visibleWidth: Double,   visibleHeight: Double
        var aspectHorizontal:Int,   aspectVertical: Int
        
        switch self {
        case .SD_640_480_Full:      // SD 640:480 square pixel fullsize
            encodedWidth = 640;     encodedHeight = 480
            visibleWidth = 640;     visibleHeight = 480
            aspectHorizontal = 1;   aspectVertical = 1
        case .SD_640_486_Full:      // SD 640:486 square pixel fullsize
            encodedWidth = 640;     encodedHeight = 486
            visibleWidth = 640;     visibleHeight = 486
            aspectHorizontal = 1;   aspectVertical = 1
        case .SD_768_576_Full:      // SD 768:576 square pixel fullsize
            encodedWidth = 768;     encodedHeight = 576
            visibleWidth = 768;     visibleHeight = 576
            aspectHorizontal = 1;   aspectVertical = 1
        case .HD_1920_1080_Full:    // HD 1920:1080 square pixel fullsize
            encodedWidth = 1920;    encodedHeight = 1080
            visibleWidth = 1920;    visibleHeight = 1080
            aspectHorizontal = 1;   aspectVertical = 1
        case .HD_1280_720_Full:     // HD 1280:720 square pixel fullsize
            encodedWidth = 1280;    encodedHeight = 720
            visibleWidth = 1280;    visibleHeight = 720
            aspectHorizontal = 1;   aspectVertical = 1
            
        case .SD_720_480_4_3:       // Digital 525 4:3
            encodedWidth = 720;     encodedHeight = 480
            visibleWidth = 704;     visibleHeight = 480
            aspectHorizontal = 10;  aspectVertical = 11
        case .SD_720_480_16_9:      // Digital 525 16:9
            encodedWidth = 720;     encodedHeight = 480
            visibleWidth = 704;     visibleHeight = 480
            aspectHorizontal = 40;  aspectVertical = 33
        case .SD_720_486_4_3:       // Digital 525 4:3
            encodedWidth = 720;     encodedHeight = 486
            visibleWidth = 704;     visibleHeight = 480
            aspectHorizontal = 10;  aspectVertical = 11
        case .SD_720_486_16_9:      // Digital 525 16:9
            encodedWidth = 720;     encodedHeight = 486
            visibleWidth = 704;     visibleHeight = 480
            aspectHorizontal = 40;  aspectVertical = 33
        case .SD_720_576_4_3:       // Digital 625 4:3
            encodedWidth = 720;     encodedHeight = 576
            visibleWidth = 704;     visibleHeight = 576
            aspectHorizontal = 12;  aspectVertical = 11
        case .SD_720_576_16_9:      // Digital 625 16:9
            encodedWidth = 720;     encodedHeight = 576
            visibleWidth = 704;     visibleHeight = 576
            aspectHorizontal = 16;  aspectVertical = 11
            
        case .HD_1920_1080_16_9:    // 1125-line (1920x1080) HDTV
            encodedWidth = 1920;    encodedHeight = 1080
            visibleWidth = 1888;    visibleHeight = 1062
            aspectHorizontal = 1;   aspectVertical = 1
        case .HD_1280_720_16_9:     // 750-line (1280x720) HDTV
            encodedWidth = 1280;    encodedHeight = 720
            visibleWidth = 1248;    visibleHeight = 702
            aspectHorizontal = 1;   aspectVertical = 1
            
        case .SD_525_13_5MHz_4_3:   // 525-line 13.5MHz Sampling 4:3
            encodedWidth = 720;     encodedHeight = 486
            visibleWidth = 704;     visibleHeight = 480
            aspectHorizontal = 10;  aspectVertical = 11
        case .SD_525_13_5MHz_16_9:  // 525-line 13.5MHz Sampling 16:9
            encodedWidth = 720;     encodedHeight = 486
            visibleWidth = 704;     visibleHeight = 480
            aspectHorizontal = 40;  aspectVertical = 33
        case .SD_625_13_5MHz_4_3:   // 625-line 13.5MHz Sampling 4:3
            encodedWidth = 720;     encodedHeight = 576
            visibleWidth = 768.0*(54.0/59.0); visibleHeight = 576
            aspectHorizontal = 59;  aspectVertical = 54
        case .SD_625_13_5MHz_16_9:  // 625-line 13.5MHz Sampling 16:9
            encodedWidth = 720;     encodedHeight = 576
            visibleWidth = 768.0*(54.0/59.0); visibleHeight = 576
            aspectHorizontal = 118;  aspectVertical = 81
            
        case .HDV_HDCAM:            // HDV / HDCAM 16:9
            encodedWidth = 1440;    encodedHeight = 1080
            visibleWidth = 1416;    visibleHeight = 1062
            aspectHorizontal = 4;   aspectVertical = 3
            
        case .UHD4k_3840_2160_Full: // 4K UHD FullAperture
            encodedWidth = 3840;    encodedHeight = 2160
            visibleWidth = 3840;    visibleHeight = 2160
            aspectHorizontal = 1;   aspectVertical = 1
        }
        
        videoOutputSettings[AVVideoWidthKey] = encodedWidth
        videoOutputSettings[AVVideoHeightKey] = encodedHeight
        
        // clap
        videoOutputSettings[AVVideoCleanApertureKey] = [
            AVVideoCleanApertureWidthKey : visibleWidth ,
            AVVideoCleanApertureHeightKey : visibleHeight ,
            AVVideoCleanApertureHorizontalOffsetKey : horizontalOffset ,
            AVVideoCleanApertureVerticalOffsetKey : verticalOffset
        ]
        
        // pasp
        videoOutputSettings[AVVideoPixelAspectRatioKey] = [
            AVVideoPixelAspectRatioHorizontalSpacingKey : aspectHorizontal ,
            AVVideoPixelAspectRatioVerticalSpacingKey : aspectVertical
        ]
        
        // nclc => Technical Note TN2227
        // Video Color Management in AV Foundation and QTKit
        // (https://developer.apple.com/library/prerelease/content/technotes/tn2227/_index.html)
        
        if encodedHeight <= 525 && encodedWidth <= 720 {
            // SD (SMPTE-C)
            //   Composite NTSC (SMPTE 170M-1994)
            //   Digital 525 (SMPTE 125M-1995 (4:3 parallel)
            //   SMPTE 267M-1995 (16:9 parallel)
            //   SMPTE 259M-1997 (serial))
            videoOutputSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey : AVVideoColorPrimaries_SMPTE_C,
                AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_601_4
            ]
        } else if encodedHeight <= 625 && encodedWidth <= 768 {
            // SD (PAL)
            //   Composite PAL (Rec. ITU-R BT. 470-4)
            //   Digital 625 (Rec. ITU-R BT. 656-3)
            videoOutputSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey : AVVideoColorPrimaries_EBU_3213,
                AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_601_4
            ]
        } else if encodedHeight <= 1125 {
            // HD (Rec. 709)
            //   1920x1080 HDTV (SMPTE 274M-1995)
            //   1280x720 HDTV (SMPTE 296M-1997)
            videoOutputSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        } else {
            // UHD (Rec. 2020)
            //   3840x2160 UHDTV (Rec. ITU-R BT. 2020)
            videoOutputSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_2020
            ]
        }
        
        /*
         NOTE: About missing nclc setting
         
         According to tn2162, the section "Sample 'colr' Settings" shows special HD case for:
         - 1920x1035 HDTV (SMPTE 240M-1995, SMPTE 260M-1992)
         - 1920x1080 HDTV interim color implementation (SMPTE 274M-1995)
         These two use a combination of :
         - AVVideoColorPrimaries_SMPTE_C
         - AVVideoTransferFunction_SMPTE_240M_1995
         - AVVideoYCbCrMatrix_SMPTE_240M_1995
         
         I am not sure if this is really required because tn2227 do not mention on these settings.
         
         If you need, you can update AVCaptureManager.updateVideoSettings() as is.
         */
        
        return videoOutputSettings
    }

}
