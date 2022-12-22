//
//  AVCaptureVideoDataOutput+Missing.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/10.
//  Copyright © 2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation

extension AVCaptureVideoDataOutput {
    // Swift header bug?
    // https://github.com/apple/swift/blob/master/stdlib/public/SDK/AVFoundation/AVCaptureVideoDataOutput.swift
    
    @nonobjc
    public var availableVideoCVPixelFormatTypes :[Any]! {
        return __availableVideoCVPixelFormatTypes
    }
    
    @nonobjc
    public var availableVideoPixelFormatTypes: [OSType] {
        return __availableVideoCVPixelFormatTypes.map { $0.uint32Value } as [OSType]
    }
}
