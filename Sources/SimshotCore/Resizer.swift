import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Image processing failures, with human-readable reasons.
public enum ResizerError: Error, CustomStringConvertible {
    case loadFailed(URL, String)
    case writeFailed(URL, String)

    public var description: String {
        switch self {
        case .loadFailed(let url, let reason):
            return "Failed to load image \(url.path): \(reason)"
        case .writeFailed(let url, let reason):
            return "Failed to write image \(url.path): \(reason)"
        }
    }
}

/// Pure-Swift image processing (CoreGraphics/ImageIO — no PIL dependency):
/// alpha flattening and App Store size resizing.
public enum Resizer {
    /// Load a `CGImage` from a PNG/JPEG/etc. file.
    public static func loadCGImage(at url: URL) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ResizerError.loadFailed(url, "no such file")
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            throw ResizerError.loadFailed(url, "path is a directory, expected an image file")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ResizerError.loadFailed(url, "unsupported or corrupt image data")
        }
        return image
    }

    /// Whether the image carries an alpha channel.
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
        context.setFillColor(
            CGColor(srgbRed: backgroundColor.0, green: backgroundColor.1, blue: backgroundColor.2, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? image
    }

    /// Write a `CGImage` as PNG to `url`.
    ///
    /// Refuses to write through a symlink or into a symlinked directory, and
    /// refuses to overwrite an existing directory, so captures can't clobber
    /// files outside the intended output tree.
    public static func writePNG(_ image: CGImage, to url: URL) throws {
        try validateOutputURL(url)

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw ResizerError.writeFailed(url, "cannot create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ResizerError.writeFailed(url, "image encoding failed")
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

    /// Reject output paths that are directories, symlinks, or nested under a
    /// symlinked directory (symlink-follow write protection).
    static func validateOutputURL(_ url: URL) throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                throw ResizerError.writeFailed(url, "path is a directory, expected an image file")
            }
            if (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil {
                throw ResizerError.writeFailed(url, "refusing to overwrite a symlink")
            }
        }

        let parent = url.deletingLastPathComponent()
        if let resolved = try? fm.destinationOfSymbolicLink(atPath: parent.path) {
            throw ResizerError.writeFailed(url, "refusing to write through symlinked directory \(resolved)")
        }
        guard fm.fileExists(atPath: parent.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ResizerError.writeFailed(url, "output directory does not exist: \(parent.path)")
        }
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
