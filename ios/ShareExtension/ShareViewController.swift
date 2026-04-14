import AVFoundation
import MobileCoreServices
import Photos
import UIKit
import UniformTypeIdentifiers

private let kSchemePrefix = "ShareMedia"
private let kUserDefaultsKey = "ShareKey"
private let kUserDefaultsMessageKey = "ShareMessageKey"
private let kAppGroupIdKey = "AppGroupId"

private enum SharedMediaType: String, Codable {
    case image
    case video
    case text
    case file
    case url
}

private struct SharedMediaFile: Codable {
    let path: String
    let mimeType: String?
    let thumbnail: String?
    let duration: Double?
    let message: String?
    let type: SharedMediaType

    init(
        path: String,
        mimeType: String? = nil,
        thumbnail: String? = nil,
        duration: Double? = nil,
        message: String? = nil,
        type: SharedMediaType
    ) {
        self.path = path
        self.mimeType = mimeType
        self.thumbnail = thumbnail
        self.duration = duration
        self.message = message
        self.type = type
    }
}

@available(swift, introduced: 5.0)
open class ShareViewController: UIViewController {
    private var hostAppBundleIdentifier = ""
    private var appGroupId = ""
    private var sharedMedia: [SharedMediaFile] = []
    private var hasStartedProcessing = false

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadIds()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasStartedProcessing else {
            return
        }

        hasStartedProcessing = true
        processSharedItems(message: nil)
    }

    private func processSharedItems(message: String?) {
        guard let content = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = content.attachments,
              !attachments.isEmpty else {
            dismissWithError()
            return
        }

        sharedMedia.removeAll()

        let group = DispatchGroup()
        var handledAny = false

        for attachment in attachments {
            if let type = preferredType(for: attachment) {
                handledAny = true
                group.enter()
                loadAttachment(attachment, as: type) {
                    group.leave()
                }
            }
        }

        guard handledAny else {
            dismissWithError()
            return
        }

        group.notify(queue: .main) {
            if self.sharedMedia.isEmpty {
                self.dismissWithError()
                return
            }

            self.saveAndRedirect(message: message)
        }
    }

    private func preferredType(for attachment: NSItemProvider) -> SharedMediaType? {
        if attachment.hasItemConformingToTypeIdentifier(utiImage) {
            return .image
        }
        if attachment.hasItemConformingToTypeIdentifier(utiMovie) {
            return .video
        }
        if attachment.hasItemConformingToTypeIdentifier(utiFileURL) {
            return .file
        }
        if attachment.hasItemConformingToTypeIdentifier(utiURL) {
            return .url
        }
        if attachment.hasItemConformingToTypeIdentifier(utiText) {
            return .text
        }
        if attachment.hasItemConformingToTypeIdentifier(utiData)
            || attachment.hasItemConformingToTypeIdentifier(utiItem)
            || attachment.hasItemConformingToTypeIdentifier(utiContent) {
            return .file
        }

        return nil
    }

    private func loadAttachment(_ attachment: NSItemProvider, as type: SharedMediaType, completion: @escaping () -> Void) {
        let typeIdentifier = loadTypeIdentifier(for: attachment, type: type)
        attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
            guard let self else {
                completion()
                return
            }

            guard error == nil, let item else {
                completion()
                return
            }

            self.handleLoadedItem(item, provider: attachment, type: type)
            completion()
        }
    }

    private func handleLoadedItem(_ item: NSSecureCoding, provider: NSItemProvider, type: SharedMediaType) {
        switch type {
        case .text:
            if let text = item as? String {
                sharedMedia.append(SharedMediaFile(path: text, mimeType: "text/plain", type: .text))
            }
        case .url:
            if let url = item as? URL {
                sharedMedia.append(SharedMediaFile(path: url.absoluteString, type: .url))
            }
        case .image:
            if let url = item as? URL {
                appendFile(at: url, provider: provider, type: .image)
            } else if let image = item as? UIImage {
                appendImage(image)
            } else if let data = item as? Data {
                appendDataFile(data, provider: provider, type: .image, fallbackExtension: "png")
            }
        case .video, .file:
            if let url = item as? URL {
                appendFile(at: url, provider: provider, type: type)
            } else if let data = item as? Data {
                appendDataFile(data, provider: provider, type: type, fallbackExtension: type == .video ? "mp4" : nil)
            }
        }
    }

    private func appendImage(_ image: UIImage) {
        let tempPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent("TempImage-\(UUID().uuidString).png")
        if writeTempFile(image, to: tempPath) {
            let decodedPath = tempPath.absoluteString.removingPercentEncoding ?? tempPath.path
            sharedMedia.append(SharedMediaFile(path: decodedPath, mimeType: "image/png", type: .image))
        }
    }

    private func appendFile(at url: URL, provider: NSItemProvider, type: SharedMediaType) {
        let fileName = preferredFileName(from: provider, url: url, type: type)
        let targetUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent(fileName)

        let startedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if startedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard copyFile(at: url, to: targetUrl) else {
            return
        }

        let decodedPath = targetUrl.absoluteString.removingPercentEncoding ?? targetUrl.path
        if type == .video, let videoInfo = getVideoInfo(from: targetUrl) {
            sharedMedia.append(
                SharedMediaFile(
                    path: decodedPath,
                    mimeType: targetUrl.mimeType(),
                    thumbnail: videoInfo.thumbnail?.removingPercentEncoding,
                    duration: videoInfo.duration,
                    type: type
                )
            )
        } else {
            sharedMedia.append(SharedMediaFile(path: decodedPath, mimeType: targetUrl.mimeType(), type: type))
        }
    }

    private func appendDataFile(_ data: Data, provider: NSItemProvider, type: SharedMediaType, fallbackExtension: String?) {
        let fileName = preferredFileName(from: provider, url: nil, type: type, fallbackExtension: fallbackExtension)
        let targetUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: targetUrl.path) {
                try FileManager.default.removeItem(at: targetUrl)
            }
            try data.write(to: targetUrl)
            let decodedPath = targetUrl.absoluteString.removingPercentEncoding ?? targetUrl.path
            sharedMedia.append(SharedMediaFile(path: decodedPath, mimeType: targetUrl.mimeType(), type: type))
        } catch {
            print("Cannot write shared data to \(targetUrl): \(error)")
        }
    }

    private func preferredFileName(from provider: NSItemProvider, url: URL?, type: SharedMediaType, fallbackExtension: String? = nil) -> String {
        if let suggestedName = provider.suggestedName, !suggestedName.isEmpty {
            return suggestedName
        }

        if let url {
            let lastPath = url.lastPathComponent
            if !lastPath.isEmpty {
                return lastPath
            }
        }

        let base = UUID().uuidString
        if let fallbackExtension, !fallbackExtension.isEmpty {
            return "\(base).\(fallbackExtension)"
        }

        switch type {
        case .image:
            return "\(base).png"
        case .video:
            return "\(base).mp4"
        case .text:
            return "\(base).txt"
        case .file, .url:
            return base
        }
    }

    private func loadTypeIdentifier(for attachment: NSItemProvider, type: SharedMediaType) -> String {
        switch type {
        case .image:
            return utiImage
        case .video:
            return attachment.hasItemConformingToTypeIdentifier(utiMovie) ? utiMovie : utiData
        case .text:
            return utiText
        case .url:
            return utiURL
        case .file:
            if attachment.hasItemConformingToTypeIdentifier(utiFileURL) {
                return utiFileURL
            }
            if attachment.hasItemConformingToTypeIdentifier(utiData) {
                return utiData
            }
            if attachment.hasItemConformingToTypeIdentifier(utiItem) {
                return utiItem
            }
            return utiContent
        }
    }

    private func loadIds() {
        let shareExtensionAppBundleIdentifier = Bundle.main.bundleIdentifier!
        let lastIndexOfPoint = shareExtensionAppBundleIdentifier.lastIndex(of: ".")
        hostAppBundleIdentifier = String(shareExtensionAppBundleIdentifier[..<lastIndexOfPoint!])
        let defaultAppGroupId = "group.\(hostAppBundleIdentifier)"
        let customAppGroupId = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String
        appGroupId = customAppGroupId ?? defaultAppGroupId
    }

    private func saveAndRedirect(message: String? = nil) {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(toData(data: sharedMedia), forKey: kUserDefaultsKey)
        userDefaults?.set(message, forKey: kUserDefaultsMessageKey)
        userDefaults?.synchronize()
        redirectToHostApp()
    }

    private func redirectToHostApp() {
        loadIds()
        let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share")
        var responder = self as UIResponder?

        if #available(iOS 18.0, *) {
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url!, options: [:], completionHandler: nil)
                }
                responder = responder?.next
            }
        } else {
            let selectorOpenURL = sel_registerName("openURL:")

            while responder != nil {
                if responder?.responds(to: selectorOpenURL) == true {
                    _ = responder?.perform(selectorOpenURL, with: url)
                }
                responder = responder?.next
            }
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func dismissWithError() {
        let alert = UIAlertController(
            title: "Unsupported Share",
            message: "Powerboards currently supports sharing files and images only.",
            preferredStyle: .alert
        )

        let action = UIAlertAction(title: "OK", style: .cancel) { _ in
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    private func writeTempFile(_ image: UIImage, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try image.pngData()?.write(to: dstURL)
            return true
        } catch {
            print("Cannot write to temp file: \(error)")
            return false
        }
    }

    private func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
            return true
        } catch {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
    }

    private func getVideoInfo(from url: URL) -> (thumbnail: String?, duration: Double)? {
        let asset = AVAsset(url: url)
        let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
        let thumbnailPath = getThumbnailPath(for: url)

        if FileManager.default.fileExists(atPath: thumbnailPath.path) {
            return (thumbnail: thumbnailPath.absoluteString, duration: duration)
        }

        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        assetImageGenerator.maximumSize = CGSize(width: 360, height: 360)

        do {
            let image = try assetImageGenerator.copyCGImage(at: CMTimeMakeWithSeconds(600, preferredTimescale: 1), actualTime: nil)
            try UIImage(cgImage: image).pngData()?.write(to: thumbnailPath)
            return (thumbnail: thumbnailPath.absoluteString, duration: duration)
        } catch {
            return nil
        }
    }

    private func getThumbnailPath(for url: URL) -> URL {
        let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(of: "==", with: "")
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent("\(fileName).jpg")
    }

    private func toData(data: [SharedMediaFile]) -> Data {
        let encodedData = try? JSONEncoder().encode(data)
        return encodedData!
    }

    private var utiImage: String { "public.image" }
    private var utiMovie: String { "public.movie" }
    private var utiText: String { "public.text" }
    private var utiURL: String { "public.url" }
    private var utiFileURL: String { "public.file-url" }
    private var utiData: String { "public.data" }
    private var utiItem: String { "public.item" }
    private var utiContent: String { "public.content" }
}

extension URL {
    public func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
        } else {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, self.pathExtension as NSString, nil)?.takeRetainedValue(),
               let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimeType as String
            }
        }

        return "application/octet-stream"
    }
}
