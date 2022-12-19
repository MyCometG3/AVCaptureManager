//
//  AVCaptureManager+Trim.swift
//  AVCaptureManager
//
//  Created by Takashi Mochizuki on 2022/12/18.
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
    
    /// Trim no Video timeRange at the beggining/end, if exist(s).
    /// NOTE: if no trim is required, true returned and movie is kept untouched.
    /// - Parameter url: Movie file URL to modify
    /// - Returns: true if no error.
    public func trimMovie(_ url: URL) -> Bool {
        guard chekMovieUTI(url) else {
            print("ERROR: Invalid UTI detected.")
            return false
        }
        
        var srcMovie:AVMutableMovie
        var dstMovie:AVMutableMovie
        
        do {
            srcMovie = try AVMutableMovie(url: url, options: nil, error: ())
            dstMovie = try AVMutableMovie(settingsFrom: srcMovie, options:nil)
        } catch {
            print("ERROR: Prepare AVMutableMovie() failed.")
            return false
        }
        
        // Inspect srcMovie
        if debugTrimMovie { print("# srcMovie:") }
        var visualRange:CMTimeRange? = timeRangeUnion(srcMovie, .visual)
        var audibleRange:CMTimeRange? = timeRangeUnion(srcMovie, .audible)
        
        // Validate if srcMovie needs trimming
        if let srcVisualRange = visualRange, let srcAudibleRange = audibleRange {
            if srcAudibleRange.start < srcVisualRange.start || srcVisualRange.end < srcAudibleRange.end {
                // Prepare dstMovie - Extract srcVisualRange from srcMovie into dstMovie
                do {
                    try dstMovie.insertTimeRange(srcVisualRange,
                                                 of: srcMovie,
                                                 at: .zero,
                                                 copySampleData: false)
                } catch {
                    print("ERROR: Failed to dstMovie.insertTimeRange(); \(error)")
                    return false
                }
                
                // Inspect dstMovie
                if debugTrimMovie { print("# dstMovie:") }
                visualRange = timeRangeUnion(dstMovie, .visual)
                audibleRange = timeRangeUnion(dstMovie, .audible)
                
                // Write dstMovie - Update source movie file using new movieHeader
                do {
                    let replaceHeader:AVMovieWritingOptions = .addMovieHeaderToDestination
                    try dstMovie.writeHeader(to: url,
                                             fileType: .mov,
                                             options: replaceHeader)
                    return true
                } catch {
                    print("ERROR: Failed to dstMovie.writeHeader(); \(error)")
                    return false
                }
            }
        }
        
        // No modification is required
        return true
    }
    
    /// Inspect movie for valid CMTimeRange of specified MediaCharacteristic
    /// - Parameters:
    ///   - movie: AVMovie to inspect
    ///   - characteristic: AVMediaCharacteristic
    /// - Returns: valid CMTimeRange
    private func timeRangeUnion(_ movie:AVMovie, _ characteristic: AVMediaCharacteristic) -> CMTimeRange? {
        //
        var unionRange:CMTimeRange? = nil // track CMTimeRange where media is available
        
        let tracks = movie.tracks(withMediaCharacteristic: characteristic)
        for track in tracks {
            if debugTrimMovie {
                print("Track:\(track.trackID);", "Media:\(track.mediaType.rawValue);", "NumSegments:\(track.segments.count);" )
                track.segments.forEach{
                    let isEmpty = ($0.isEmpty ? "Empty" : "Media")
                    let range = $0.timeMapping.target // Track time range
                    let start = range.start.seconds
                    let end = range.end.seconds
                    let duration = range.duration.seconds
                    print(String(format: " segment:%@: (%8.4f,%8.4f,%8.4f)", isEmpty, start, end, duration ))
                }
            }
            track.segments.filter{$0.isEmpty == false}.forEach {
                // CMTimeMapping.source is CMTimeRange in Media timeScale;
                // CMTimeMapping.target is CMTimeRange in Movie/Track timeScale;
                let segment:CMTimeRange = $0.timeMapping.target
                if let current = unionRange {
                    unionRange = CMTimeRangeGetUnion(current, otherRange: segment)
                } else {
                    unionRange = segment
                }
            }
        }
        if debugTrimMovie {
            if let range = unionRange, characteristic == .visual {
                print(String(format:"   visualRange: (%8.4f,%8.4f,%8.4f)",
                             range.start.seconds, range.end.seconds, range.duration.seconds))
            }
            if let range = unionRange, characteristic == .audible {
                print(String(format:"  audibleRange: (%8.4f,%8.4f,%8.4f)",
                             range.start.seconds, range.end.seconds, range.duration.seconds))
            }
        }
        
        return unionRange
    }
    
    /// Check URL and verify UTI for QuickTime Movie
    /// - Parameter url: fileURL to test
    /// - Returns: true if no error
    private func chekMovieUTI(_ url: URL) -> Bool {
        var isMovie = false
        
        do {
            if #available(macOS 11.0, *) {
                let resources: URLResourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
                if let contentType = resources.contentType {
                    isMovie = (contentType == UTType.quickTimeMovie)
                }
            } else {
                let resources: URLResourceValues = try url.resourceValues(forKeys: [.typeIdentifierKey])
                if let uti = resources.typeIdentifier {
                    isMovie = (uti == AVFileType.mov.rawValue)
                }
            }
        } catch {
            print(error)
            return false
        }
        
        return isMovie
    }
}
