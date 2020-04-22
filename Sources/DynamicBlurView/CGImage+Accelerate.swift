//
//  CGImage+Accelerate.swift
//  DynamicBlurView
//
//  Created by Kyohei Ito on 2017/08/17.
//  Copyright © 2017年 kyohei_ito. All rights reserved.
//

import Accelerate
import UIKit

extension CGImage {
    var area: Int {
        width * height
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    var bytes: Int {
        bytesPerRow * height
    }

    func imageBuffer(with data: UnsafeMutableRawPointer?) -> vImage_Buffer {
        vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
    }

    func context(with data: UnsafeMutableRawPointer?) -> CGContext? {
        colorSpace.flatMap {
            CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: $0,
                bitmapInfo: bitmapInfo.rawValue
            )
        }
    }

    func blurred(with boxSize: UInt32, iterations: Int, blendColor: UIColor?, blendMode: CGBlendMode) -> CGImage? {
        guard let providerData = dataProvider?.data else {
            return nil
        }

        let inData = malloc(bytes)
        var inBuffer = imageBuffer(with: inData)

        let outData = malloc(bytes)
        var outBuffer = imageBuffer(with: outData)

        let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize))
        let tempData = malloc(tempSize)

        defer {
            free(inData)
            free(outData)
            free(tempData)
        }

        let source = CFDataGetBytePtr(providerData)
        memcpy(inBuffer.data, source, bytes)

        for _ in 0..<iterations {
            vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempData, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend))

            let temp = inBuffer.data
            inBuffer.data = outBuffer.data
            outBuffer.data = temp
        }

        return context(with: inBuffer.data)?.makeImage(with: blendColor, blendMode: blendMode, size: size)
    }
}
