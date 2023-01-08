//
//  CMIOSampleBuffer+Missing.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/12.
//  Copyright © 2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation
import AVFoundation
import CoreMediaIO.CMIOSampleBuffer

// Missing CoreMediaIO.CMIOSampleBuffer definitions (CMIOSampleBuffer.h)

internal let kCMIOInvalidSequenceNumber:UInt64 = ~UInt64(0)

internal func CMIOGetNextSequenceNumber(_ x:UInt64) -> UInt64 {
    return UInt64( (kCMIOInvalidSequenceNumber == x) ? 0 : (x + 1) )
}

