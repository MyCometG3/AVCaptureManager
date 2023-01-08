//
//  Constants.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2016/08/07.
//  Copyright © 2016-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

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
    case MP_52 ; case HiP_52 ;
    
    case Hi10P_30 ; case Hi422P_30 ;
    case Hi10P_31 ; case Hi422P_31 ;
    case Hi10P_32 ; case Hi422P_32 ;
    case Hi10P_40 ; case Hi422P_40 ;
    case Hi10P_41 ; case Hi422P_41 ;
    case Hi10P_42 ; case Hi422P_42 ;
    case Hi10P_50 ; case Hi422P_50 ;
    case Hi10P_51 ; case Hi422P_51 ;
    case Hi10P_52 ; case Hi422P_52 ;
    
    // Maximum video bitrate per Profile_Level
    public var maxRate: Int {
        switch self {
        case .MP_30: return  10_000_000 ; case .HiP_30: return  12_500_000;
        case .MP_31: return  14_000_000 ; case .HiP_31: return  17_500_000;
        case .MP_32: return  20_000_000 ; case .HiP_32: return  25_000_000;
        case .MP_40: return  20_000_000 ; case .HiP_40: return  25_000_000;
        case .MP_41: return  50_000_000 ; case .HiP_41: return  62_500_000;
        case .MP_42: return  50_000_000 ; case .HiP_42: return  62_500_000;
        case .MP_50: return 135_000_000 ; case .HiP_50: return 168_750_000;
        case .MP_51: return 240_000_000 ; case .HiP_51: return 300_000_000;
        case .MP_52: return 240_000_000 ; case .HiP_52: return 300_000_000;
        
        case .Hi10P_30: return  30_000_000; case .Hi422P_30: return  40_000_000;
        case .Hi10P_31: return  42_000_000; case .Hi422P_31: return  56_000_000;
        case .Hi10P_32: return  60_000_000; case .Hi422P_32: return  80_000_000;
        case .Hi10P_40: return  60_000_000; case .Hi422P_40: return  80_000_000;
        case .Hi10P_41: return 150_000_000; case .Hi422P_41: return 200_000_000;
        case .Hi10P_42: return 150_000_000; case .Hi422P_42: return 200_000_000;
        case .Hi10P_50: return 405_000_000; case .Hi422P_50: return 540_000_000;
        case .Hi10P_51: return 720_000_000; case .Hi422P_51: return 960_000_000;
        case .Hi10P_52: return 720_000_000; case .Hi422P_52: return 960_000_000;
        }
    }
}

/// Define HEVC profile and level with Tiers
public enum HEVCProfileLevel {
    // For HEVC encoder
    case MP_30 ;
    case MP_31 ;
    case MP_40 ; case MP_40_HT ;
    case MP_41 ; case MP_41_HT ;
    case MP_50 ; case MP_50_HT ;
    case MP_51 ; case MP_51_HT ;
    case MP_52 ; case MP_52_HT ;
    
    case MP42210_30 ;
    case MP42210_31 ;
    case MP42210_40 ; case MP42210_40_HT ;
    case MP42210_41 ; case MP42210_41_HT ;
    case MP42210_50 ; case MP42210_50_HT ;
    case MP42210_51 ; case MP42210_51_HT ;
    case MP42210_52 ; case MP42210_52_HT ;
    
    // Maximum video bitrate per Profile_level (Main and Main10; Chroma sampling 4:2:0)
    public var maxRate: Int {
        switch self {
        case .MP_30: return  6_000_000 ;
        case .MP_31: return 10_000_000 ;
        case .MP_40: return 12_000_000 ; case .MP_40_HT: return  30_000_000 ;
        case .MP_41: return 20_000_000 ; case .MP_41_HT: return  50_000_000 ;
        case .MP_50: return 25_000_000 ; case .MP_50_HT: return 100_000_000 ;
        case .MP_51: return 40_000_000 ; case .MP_51_HT: return 160_000_000 ;
        case .MP_52: return 60_000_000 ; case .MP_52_HT: return 240_000_000 ;
        
        case .MP42210_30: return  9_000_000 ;
        case .MP42210_31: return 15_000_000 ;
        case .MP42210_40: return 18_000_000 ; case .MP42210_40_HT: return  45_000_000 ;
        case .MP42210_41: return 30_000_000 ; case .MP42210_41_HT: return  75_000_000 ;
        case .MP42210_50: return 37_500_000 ; case .MP42210_50_HT: return 150_000_000 ;
        case .MP42210_51: return 60_000_000 ; case .MP42210_51_HT: return 240_000_000 ;
        case .MP42210_52: return 90_000_000 ; case .MP42210_52_HT: return 360_000_000 ;
        }
    }
}

public enum VideoStyle : String {
    case SD_640_480_Full    = "SD 640:480 Full"     // square pixel
    case SD_640_486_Full    = "SD 640:486 Full"     // square pixel
    case SD_768_576_Full    = "SD 768:576 Full"     // square pixel
    case HD_960_540_Full    = "HD 960:540 Full"     // square pixel
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
        case .HD_960_540_Full:    // HD 960:540 square pixel fullsize
            encodedWidth = 960;     encodedHeight = 540
            visibleWidth = 960;     visibleHeight = 540
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
        let clapOffsetH:Int = clampOffset(horizontalOffset, visibleWidth, encodedWidth)
        let clapOffsetV:Int = clampOffset(verticalOffset, visibleHeight, encodedHeight)
        videoOutputSettings[AVVideoCleanApertureKey] = [
            AVVideoCleanApertureWidthKey : visibleWidth ,
            AVVideoCleanApertureHeightKey : visibleHeight ,
            AVVideoCleanApertureHorizontalOffsetKey : clapOffsetH ,
            AVVideoCleanApertureVerticalOffsetKey : clapOffsetV
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
    
    /// Clamp out-of-range clap offset value
    /// - Parameters:
    ///   - offset: offset value to clamp
    ///   - visible: visible size
    ///   - encoded: encoded size
    /// - Returns: clamped offset value
    private func clampOffset(_ offset:Int, _ visible:Double, _ encoded:Double) -> Int {
        guard (visible + 2) <= encoded else { return 0 }
        
        let maxOffset:Int = Int(floor((encoded - visible)/2))
        let minOffset:Int = -maxOffset
        let clapOffset:Int = min(max(minOffset, offset), maxOffset)
        return clapOffset
    }
}
