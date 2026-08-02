import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ResizerError: Error, CustomStringConvertible {
    case loadFailed(URL)
    case writeFailed(URL)

    public var description: String {
        switch self {
        case .loadFailed(let url):
            return "Failed to load image: \(url.path)"
        case .writeFailed(let url):
            return "Failed to write image: \(url.path)"
        }
    }
}

/// Pure-Swift image processing (CoreGraphics/ImageIO — no PIL dependency):
/// alpha flattening and App Store size resizing.
public enum Resizer {
    public static func loadCGImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ResizerError.loadFailed(url)
        }
        return image
    }

    public static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .premultipliedLast, .premultipliedFirst, .last, .first:
            return true
        default:
            return false
        }
    }

    /// Composite onto an opaque background, dropping any alpha channel.
    public static func flatten(
        _ image: CGImage,
        background: (CGFloat, CGFloat, CGFloat) = (1, 1, 1)
    ) -> CGImage {
        guard hasAlpha(image) else { return image }
        let size = CGSize(width: image.width, height: image.height)
        guard let context = rgbContext(size: size) else { return image }
        context.setFillColor(CGColor(srgbRed: background.0, green: background.1, blue: background.2, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? image
    }

    /// Resize to an exact size with high-quality interpolation.
    public static func resize(
        _ image: CGImage,
        to size: CGSize,
        backgroundColor: (CGFloat, CGFloat, CGFloat) = (1, 1, 1)
    ) -> CGImage {
        guard let context = rgbContext(size: size) else { return image }
        context.setFillColor(CGColor(srgbRed: backgroundColor.0, green: backgroundColor.1, blue: backgroundColor.2, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? image
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ResizerError.writeFailed(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ResizerError.writeFailed(url)
        }
    }

    /// Load, flatten alpha, resize to an App Store target, and save as PNG.
    @discardableResult
    public static func makeAppStoreImage(
        input: URL,
        output: URL,
        target: AppStoreTarget
    ) throws -> URL {
        let image = try loadCGImage(at: input)
        let flattened = flatten(image)
        let resized = resize(flattened, to: target.size)
        try writePNG(resized, to: output)
        return output
    }

    private static func rgbContext(size: CGSize) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: nil,
            width: max(1, Int(size.width.rounded())),
            height: max(1, Int(size.height.rounded())),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }
}
