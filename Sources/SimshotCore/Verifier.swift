import CoreGraphics
import Foundation

/// A single problem found while verifying captured screenshots.
public struct VerifyIssue: Equatable {
    /// The class of problem. String-backed so `--json` output stays stable.
    public enum Kind: String {
        case missingDirectory = "missing-directory"
        case emptyDirectory = "empty-directory"
        case unreadable = "unreadable"
        case notAppStoreSize = "not-app-store-size"
        case wrongSize = "wrong-size"
        case inconsistentSize = "inconsistent-size"
        case alphaChannel = "alpha-channel"
    }

    public let kind: Kind
    /// File or directory the issue was found in.
    public let path: String
    public let message: String
    /// One-line remediation hint.
    public let fix: String

    public init(kind: Kind, path: String, message: String, fix: String) {
        self.kind = kind
        self.path = path
        self.message = message
        self.fix = fix
    }
}

/// One `<device>/<language>` folder that was inspected.
public struct VerifiedFolder: Equatable {
    public let device: String
    public let language: String
    public let path: String
    public let fileCount: Int
    /// The size every accepted file in the folder agrees on, when there is one.
    public let size: CGSize?
    public let target: AppStoreTarget?
}

/// The outcome of a `simshot verify` run.
public struct VerifyReport {
    public let root: String
    public let folders: [VerifiedFolder]
    public let issues: [VerifyIssue]
    public let checkedFiles: Int
    /// Names of subdirectories that were deliberately skipped (e.g. `raw`).
    public let skipped: [String]

    public var ok: Bool { issues.isEmpty }
}

/// Verifies that a captured output tree is actually publishable: correct App
/// Store dimensions, no alpha channel, no empty or missing folders.
///
/// Pure filesystem + ImageIO inspection — never touches a simulator, so it can
/// run in CI right after `simshot shoot --resize`.
public enum Verifier {
    /// Directories under the output root that are not device folders.
    static let reservedNames: Set<String> = ["raw"]

    /// Inspect an output tree.
    ///
    /// - Parameters:
    ///   - root: Output directory produced by `simshot shoot` (default `appstore`).
    ///   - devices: Device folder names to require. Empty = use what is on disk.
    ///   - languages: Language folder names to require. Empty = use what is on disk.
    public static func verify(root: URL, devices: [String] = [], languages: [String] = []) -> VerifyReport {
        let fm = FileManager.default
        var issues: [VerifyIssue] = []
        var folders: [VerifiedFolder] = []
        var skipped: [String] = []
        var checkedFiles = 0

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            issues.append(
                VerifyIssue(
                    kind: .missingDirectory,
                    path: root.path,
                    message: "output directory does not exist",
                    fix: "run `simshot shoot --output \(root.lastPathComponent) ... --resize` first, or check the path"
                ))
            return VerifyReport(
                root: root.path, folders: [], issues: issues, checkedFiles: 0, skipped: [])
        }

        let requestedDevices = devices.isEmpty ? nil : devices

        // `raw/` holds the untouched simctl captures, so it is never a device
        // folder. Report it as skipped whenever it exists, so a run that filters
        // by `--devices` still says out loud that raw captures were ignored.
        let rootEntries = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        skipped = rootEntries.filter { reservedNames.contains($0) }.sorted()

        let deviceNames: [String]
        if let requestedDevices {
            deviceNames = requestedDevices
        } else {
            let dirs = rootEntries.filter { name in
                !name.hasPrefix(".") && !reservedNames.contains(name)
                    && fm.fileExists(
                        atPath: root.appendingPathComponent(name).path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
            deviceNames = dirs.sorted()
        }

        for device in deviceNames {
            let deviceDir = root.appendingPathComponent(device)
            guard fm.fileExists(atPath: deviceDir.path, isDirectory: &isDirectory), isDirectory.boolValue
            else {
                issues.append(
                    VerifyIssue(
                        kind: .missingDirectory,
                        path: deviceDir.lastPathComponent,
                        message: "no screenshots captured for device '\(device)'",
                        fix: "check the device name against `simshot devices`, then re-run shoot"
                    ))
                continue
            }

            let languageNames: [String]
            if languages.isEmpty {
                let entries = (try? fm.contentsOfDirectory(atPath: deviceDir.path)) ?? []
                languageNames = entries.filter { name in
                    !name.hasPrefix(".") && !reservedNames.contains(name)
                        && fm.fileExists(
                            atPath: deviceDir.appendingPathComponent(name).path, isDirectory: &isDirectory)
                        && isDirectory.boolValue
                }.sorted()
            } else {
                languageNames = languages
            }

            for language in languageNames {
                let folder = deviceDir.appendingPathComponent(language)
                guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue
                else {
                    issues.append(
                        VerifyIssue(
                            kind: .missingDirectory,
                            path: "\(device)/\(language)",
                            message: "no screenshots captured for language '\(language)'",
                            fix: "check the language code against `--langs`, then re-run shoot"
                        ))
                    continue
                }

                let files = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? [])
                    .filter { $0.lowercased().hasSuffix(".png") }
                    .sorted()

                guard !files.isEmpty else {
                    issues.append(
                        VerifyIssue(
                            kind: .emptyDirectory,
                            path: "\(device)/\(language)",
                            message: "no PNG screenshots in this folder",
                            fix: "a scene may not have settled — raise `--wait <secs>` and re-run shoot"
                        ))
                    folders.append(
                        VerifiedFolder(
                            device: device,
                            language: language,
                            path: "\(device)/\(language)",
                            fileCount: 0,
                            size: nil,
                            target: nil
                        ))
                    continue
                }

                var folderSize: CGSize?
                var folderTarget: AppStoreTarget?

                for file in files {
                    let fileURL = folder.appendingPathComponent(file)
                    let relative = "\(device)/\(language)/\(file)"
                    checkedFiles += 1

                    let image: CGImage
                    do {
                        image = try Resizer.loadCGImage(at: fileURL)
                    } catch {
                        issues.append(
                            VerifyIssue(
                                kind: .unreadable,
                                path: relative,
                                message: "cannot read image data",
                                fix: "re-run shoot; the capture may be truncated"
                            ))
                        continue
                    }

                    let actual = CGSize(width: image.width, height: image.height)

                    if Resizer.hasAlpha(image) {
                        issues.append(
                            VerifyIssue(
                                kind: .alphaChannel,
                                path: relative,
                                message: "image has an alpha channel — App Store Connect rejects these",
                                fix: "run shoot with `--resize` to write flattened App Store copies"
                            ))
                    }

                    guard let target = DeviceSpec.matchTarget(width: image.width, height: image.height) else {
                        issues.append(
                            VerifyIssue(
                                kind: .notAppStoreSize,
                                path: relative,
                                message: "\(image.width)×\(image.height) is not an App Store screenshot size",
                                fix: "run shoot with `--resize` to get an accepted size automatically"
                            ))
                        continue
                    }

                    if target.size != actual {
                        issues.append(
                            VerifyIssue(
                                kind: .wrongSize,
                                path: relative,
                                message: "expected \(Int(target.size.width))×\(Int(target.size.height)) "
                                    + "(\(target.name)) but got \(image.width)×\(image.height)",
                                fix: "run shoot with `--resize` to write the exact accepted size"
                            ))
                    }

                    if let folderSize {
                        if folderSize != actual {
                            issues.append(
                                VerifyIssue(
                                    kind: .inconsistentSize,
                                    path: relative,
                                    message: "mixed sizes in one folder: \(Int(folderSize.width))×"
                                        + "\(Int(folderSize.height)) vs \(image.width)×\(image.height)",
                                    fix: "re-capture this device with a single device profile"
                                ))
                        }
                    } else {
                        folderSize = actual
                        folderTarget = target
                    }
                }

                folders.append(
                    VerifiedFolder(
                        device: device,
                        language: language,
                        path: "\(device)/\(language)",
                        fileCount: files.count,
                        size: folderSize,
                        target: folderTarget
                    ))
            }
        }

        return VerifyReport(
            root: root.path, folders: folders, issues: issues, checkedFiles: checkedFiles, skipped: skipped)
    }
}
