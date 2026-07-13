import CloudKit
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TodoImageAttachment: Codable, Identifiable, Equatable {
    let id: UUID
    let todoID: UUID
    var sortOrder: Int
    var isOriginalAvailable: Bool
    let createdAt: Date
}

struct TodoImageDeleteAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct TodoImageGrid: View {
    let todoID: UUID
    let isReadOnly: Bool
    @Binding var editingImageID: UUID?
    @ObservedObject private var store = TodoImageStore.shared
    @State private var selectedImageID: UUID?
    @State private var activeDragID: UUID?
    @State private var dragTranslation: CGSize = .zero
    @State private var rawDragTranslation: CGSize = .zero
    @State private var dragCompensation: CGSize = .zero
    @State private var dragStartIndex: Int?
    @State private var transientImages: [TodoImageAttachment]?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    private var cellSide: CGFloat { max(1, (UIScreen.main.bounds.width - 48 - 32) / 5) }

    var body: some View {
        let images = transientImages ?? store.images(for: todoID)
        if !images.isEmpty {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(images) { image in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let preview = store.thumbnail(for: image) {
                                Image(uiImage: preview).resizable().scaledToFill()
                            } else {
                                Color.black.opacity(0.08)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            if !isReadOnly {
                                ImageGestureCapture(
                                    onTap: {
                                        if editingImageID != nil { editingImageID = nil } else { selectedImageID = image.id }
                                    },
                                    onLongPressBegan: {
                                        guard activeDragID == nil else { return }
                                        editingImageID = image.id
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    },
                                    onDragChanged: { translation in
                                        updateDrag(image, images: images, translation: translation)
                                    },
                                    onLongPressEnded: { didDrag in
                                        finishInteraction(didDrag: didDrag)
                                    }
                                )
                                .allowsHitTesting(editingImageID != image.id)
                            }
                        }

                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture { if isReadOnly { selectedImageID = image.id } }
                    .offset(activeDragID == image.id ? dragTranslation : .zero)
                    .scaleEffect(activeDragID == image.id ? 1.08 : 1)
                    .shadow(color: .black.opacity(activeDragID == image.id ? 0.22 : 0), radius: 8, y: 4)
                    .zIndex(activeDragID == image.id ? 1 : 0)
                    .accessibilityLabel("Image")
                    .anchorPreference(key: TodoImageDeleteAnchorKey.self, value: .bounds) { anchor in
                        editingImageID == image.id && !isReadOnly ? [image.id: anchor] : [:]
                    }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: images)
            .fullScreenCover(item: Binding(get: { selectedImageID.flatMap { id in images.first(where: { $0.id == id }) } }, set: { selectedImageID = $0?.id })) { image in
                TodoImageViewer(images: images, initialImageID: image.id)
            }
        }
    }

    private func updateDrag(_ image: TodoImageAttachment, images: [TodoImageAttachment], translation: CGSize) {
        if activeDragID == nil {
            editingImageID = nil
            activeDragID = image.id
            dragStartIndex = images.firstIndex(of: image)
            transientImages = images
            rawDragTranslation = .zero
            dragCompensation = .zero
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        rawDragTranslation = translation
        dragTranslation = CGSize(width: rawDragTranslation.width - dragCompensation.width, height: rawDragTranslation.height - dragCompensation.height)
        reorderDuringDrag(image, images: images)
    }

    private func finishInteraction(didDrag: Bool) {
        if didDrag {
            editingImageID = nil
            if let transientImages { store.setOrder(transientImages, for: todoID) }
        }
        activeDragID = nil
        dragTranslation = .zero
        rawDragTranslation = .zero
        dragCompensation = .zero
        dragStartIndex = nil
        transientImages = nil
    }

    private func reorderDuringDrag(_ image: TodoImageAttachment, images: [TodoImageAttachment]) {
        guard let start = dragStartIndex else { return }
        var reordered = transientImages ?? images
        guard let current = reordered.firstIndex(of: image) else { return }
        let columnDelta = Int((rawDragTranslation.width / (cellSide + 8)).rounded())
        let rowDelta = Int((rawDragTranslation.height / (cellSide + 8)).rounded())
        let target = min(max(start + columnDelta + rowDelta * 5, 0), reordered.count - 1)
        guard target != current else { return }
        let previousPosition = gridPosition(for: current)
        let nextPosition = gridPosition(for: target)
        dragCompensation.width += nextPosition.x - previousPosition.x
        dragCompensation.height += nextPosition.y - previousPosition.y
        dragTranslation = CGSize(width: rawDragTranslation.width - dragCompensation.width, height: rawDragTranslation.height - dragCompensation.height)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            reordered.move(fromOffsets: IndexSet(integer: current), toOffset: target > current ? target + 1 : target)
            transientImages = reordered
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func gridPosition(for index: Int) -> CGPoint {
        CGPoint(x: CGFloat(index % 5) * (cellSide + 8), y: CGFloat(index / 5) * (cellSide + 8))
    }

}

private struct ImageGestureCapture: UIViewRepresentable {
    let onTap: () -> Void
    let onLongPressBegan: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onLongPressEnded: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap))
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.allowableMovement = 18
        tap.require(toFail: longPress)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.parent = self }

    final class Coordinator: NSObject {
        var parent: ImageGestureCapture
        private var didDrag = false
        private var startLocation: CGPoint = .zero
        init(parent: ImageGestureCapture) { self.parent = parent }

        @objc func didTap() { parent.onTap() }

        @objc func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                didDrag = false
                startLocation = recognizer.location(in: recognizer.view?.window)
                parent.onLongPressBegan()
            case .changed:
                let location = recognizer.location(in: recognizer.view?.window)
                let translation = CGPoint(x: location.x - startLocation.x, y: location.y - startLocation.y)
                if hypot(translation.x, translation.y) >= 8 {
                    didDrag = true
                    parent.onDragChanged(CGSize(width: translation.x, height: translation.y))
                }
            case .ended, .cancelled, .failed:
                parent.onLongPressEnded(didDrag)
                didDrag = false
            default:
                break
            }
        }
    }
}

private struct TodoImageViewer: View {
    let images: [TodoImageAttachment]
    let initialImageID: UUID
    @ObservedObject private var store = TodoImageStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID

    init(images: [TodoImageAttachment], initialImageID: UUID) { self.images = images; self.initialImageID = initialImageID; _selection = State(initialValue: initialImageID) }
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(images) { image in
                    Group {
                        if let fullImage = store.displayImage(for: image) { ZoomableImage(image: fullImage) } else { ProgressView().tint(.white) }
                    }
                    .tag(image.id)
                    .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard value.translation.height > 110,
                              value.translation.height > abs(value.translation.width) else { return }
                        dismiss()
                    }
            )
            Button(action: { dismiss() }) { Image(systemName: "xmark").font(.headline).foregroundColor(.white).padding(14).background(.black.opacity(0.45), in: Circle()) }
                .padding(.top, 16).padding(.trailing, 20)
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        return scrollView
    }
    func updateUIView(_ scrollView: UIScrollView, context: Context) { context.coordinator.imageView?.image = image }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

struct TodoCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; picker.allowsEditing = false; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void
        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) { self.onImage = onImage; self.onCancel = onCancel }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { if let image = info[.originalImage] as? UIImage { onImage(image) } else { onCancel() } }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

struct TodoPhotoPicker: UIViewControllerRepresentable {
    let maximumSelectionCount: Int
    let onData: ([Data]) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onData: onData, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = maximumSelectionCount
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onData: ([Data]) -> Void
        let onCancel: () -> Void
        init(onData: @escaping ([Data]) -> Void, onCancel: @escaping () -> Void) { self.onData = onData; self.onCancel = onCancel }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else { onCancel(); return }
            let group = DispatchGroup()
            let lock = NSLock()
            var data: [Data] = []
            for result in results {
                let provider = result.itemProvider
                let type = provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) ? UTType.gif.identifier : UTType.image.identifier
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: type) { value, _ in
                    if let value { lock.lock(); data.append(value); lock.unlock() }
                    group.leave()
                }
            }
            group.notify(queue: .main) { self.onData(data) }
        }
    }
}

enum TodoImageImportError: LocalizedError {
    case limitReached(remaining: Int)
    case sourceTooLarge
    case gifTooLarge
    case cameraUnavailable
    case cameraPermissionDenied
    case unsupported
    case processingFailed

    var errorDescription: String? {
        switch self {
        case let .limitReached(remaining):
            if remaining == 0 {
                return NSLocalizedString("This item already has the maximum of 20 images.", comment: "Image limit reached")
            }
            return String.localizedStringWithFormat(
                NSLocalizedString("Only %d more images can be added to this item.", comment: "Remaining image capacity"),
                remaining
            )
        case .sourceTooLarge: return NSLocalizedString("This image is larger than 30 MB.", comment: "Image file too large")
        case .gifTooLarge: return NSLocalizedString("GIF images must be 10 MB or smaller.", comment: "GIF file too large")
        case .cameraUnavailable: return NSLocalizedString("Camera is not available on this device.", comment: "Camera unavailable")
        case .cameraPermissionDenied: return NSLocalizedString("Camera access is off. Enable it in Settings to take a photo.", comment: "Camera permission denied")
        case .unsupported: return NSLocalizedString("This image format is not supported.", comment: "Unsupported image format")
        case .processingFailed: return NSLocalizedString("This image could not be imported.", comment: "Image import failed")
        }
    }
}

@MainActor
final class TodoImageStore: ObservableObject {
    static let shared = TodoImageStore()

    @Published private(set) var attachments: [TodoImageAttachment] = []
    @Published private(set) var lastSyncError: String?

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let database = CKContainer.default().privateCloudDatabase
    private let recordType = "TodoImageAttachment"
    private let maximumImagesPerTodo = 20
    private var pendingDeletions: Set<UUID> = []

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadMetadata()
        pendingDeletions = (try? Data(contentsOf: pendingDeletionsURL)).flatMap { try? decoder.decode(Set<UUID>.self, from: $0) } ?? []
    }

    func images(for todoID: UUID) -> [TodoImageAttachment] {
        attachments.filter { $0.todoID == todoID }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func hasImages(for todoID: UUID) -> Bool { !images(for: todoID).isEmpty }

    func thumbnail(for attachment: TodoImageAttachment) -> UIImage? {
        UIImage(contentsOfFile: thumbnailURL(for: attachment).path)
    }

    func displayImage(for attachment: TodoImageAttachment) -> UIImage? {
        if attachment.isOriginalAvailable, let image = UIImage(contentsOfFile: originalURL(for: attachment).path) { return image }
        return thumbnail(for: attachment)
    }

    func importImageData(_ data: Data, into todoID: UUID) throws {
        let remaining = maximumImagesPerTodo - images(for: todoID).count
        guard remaining > 0 else { throw TodoImageImportError.limitReached(remaining: 0) }
        guard data.count <= 30 * 1024 * 1024 else { throw TodoImageImportError.sourceTooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { throw TodoImageImportError.unsupported }

        let isGIF = (type as String) == UTType.gif.identifier
        if isGIF && data.count > 10 * 1024 * 1024 { throw TodoImageImportError.gifTooLarge }
        let attachment = TodoImageAttachment(id: UUID(), todoID: todoID, sortOrder: images(for: todoID).count, isOriginalAvailable: true, createdAt: Date())
        try ensureDirectories()
        if isGIF {
            try writeResizedGIF(source: source, to: originalURL(for: attachment))
        } else {
            guard let image = UIImage(data: data), let encoded = normalizedJPEG(image, maximumSide: 2048, quality: 0.8) else { throw TodoImageImportError.processingFailed }
            try encoded.write(to: originalURL(for: attachment), options: .atomic)
        }
        guard let preview = UIImage(contentsOfFile: originalURL(for: attachment).path),
              let thumbnailData = squareThumbnail(preview)?.jpegData(compressionQuality: 0.82) else { throw TodoImageImportError.processingFailed }
        try thumbnailData.write(to: thumbnailURL(for: attachment), options: .atomic)
        attachments.append(attachment)
        saveMetadata()
        upload(attachment)
    }

    func move(_ attachment: TodoImageAttachment, to destination: Int) {
        var todoImages = images(for: attachment.todoID)
        guard let source = todoImages.firstIndex(of: attachment) else { return }
        todoImages.move(fromOffsets: IndexSet(integer: source), toOffset: min(max(destination, 0), todoImages.count))
        for index in todoImages.indices {
            if let attachmentIndex = attachments.firstIndex(where: { $0.id == todoImages[index].id }) {
                attachments[attachmentIndex].sortOrder = index
                upload(attachments[attachmentIndex])
            }
        }
        saveMetadata()
    }

    func setOrder(_ orderedImages: [TodoImageAttachment], for todoID: UUID) {
        let validIDs = Set(images(for: todoID).map(\.id))
        let orderedIDs = orderedImages.map(\.id).filter { validIDs.contains($0) }
        guard orderedIDs.count == validIDs.count else { return }
        for (order, id) in orderedIDs.enumerated() {
            guard let index = attachments.firstIndex(where: { $0.id == id }) else { continue }
            attachments[index].sortOrder = order
            upload(attachments[index])
        }
        saveMetadata()
    }

    func remove(_ attachment: TodoImageAttachment) {
        try? fileManager.removeItem(at: originalURL(for: attachment))
        try? fileManager.removeItem(at: thumbnailURL(for: attachment))
        attachments.removeAll { $0.id == attachment.id }
        pendingDeletions.insert(attachment.id)
        normalizeOrder(for: attachment.todoID)
        saveMetadata()
        savePendingDeletions()
        deleteRemoteRecord(id: attachment.id)
    }

    func removeAllImages(for todoID: UUID) {
        images(for: todoID).forEach(remove)
    }

    /// Original files are deliberately permanent-deleted after the retention period; previews remain available.
    func purgeExpiredOriginals(doneItems: [TodoItem]) {
        let expiry = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let expiredIDs = Set(doneItems.compactMap { item -> UUID? in
            guard let doneDate = item.doneDate, doneDate <= expiry else { return nil }
            return item.id
        })
        for index in attachments.indices where expiredIDs.contains(attachments[index].todoID) && attachments[index].isOriginalAvailable {
            try? fileManager.removeItem(at: originalURL(for: attachments[index]))
            attachments[index].isOriginalAvailable = false
            upload(attachments[index])
        }
        saveMetadata()
    }

    func synchronize() {
        pendingDeletions.forEach(deleteRemoteRecord)
        fetchRemoteAttachments()
    }

    private func normalizedJPEG(_ image: UIImage, maximumSide: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let scale = min(1, maximumSide / max(size.width, size.height))
        let target = CGSize(width: max(1, floor(size.width * scale)), height: max(1, floor(size.height * scale)))
        let renderer = UIGraphicsImageRenderer(size: target)
        let result = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return result.jpegData(compressionQuality: quality)
    }

    private func squareThumbnail(_ image: UIImage) -> UIImage? {
        let side: CGFloat = 360
        let source = image.size
        guard source.width > 0, source.height > 0 else { return nil }
        let scale = max(side / source.width, side / source.height)
        let drawSize = CGSize(width: source.width * scale, height: source.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in image.draw(in: CGRect(origin: origin, size: drawSize)) }
    }

    private func writeResizedGIF(source: CGImageSource, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, CGImageSourceGetCount(source), nil) else { throw TodoImageImportError.processingFailed }
        let gifProperties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let loop = (gifProperties?[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFLoopCount] ?? 0
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loop]] as CFDictionary)
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { throw TodoImageImportError.processingFailed }
            let frame = UIImage(cgImage: image)
            guard let resized = normalizedJPEG(frame, maximumSide: 2048, quality: 0.8), let resizedImage = UIImage(data: resized), let cgImage = resizedImage.cgImage else { throw TodoImageImportError.processingFailed }
            let frameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = frameProperties?[kCGImagePropertyGIFDictionary] as? [CFString: Any] ?? [:]
            CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyGIFDictionary: gif] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { throw TodoImageImportError.processingFailed }
    }

    private var directory: URL { fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TodoImages", isDirectory: true) }
    private var originalsDirectory: URL { directory.appendingPathComponent("originals", isDirectory: true) }
    private var thumbnailsDirectory: URL { directory.appendingPathComponent("thumbnails", isDirectory: true) }
    private var metadataURL: URL { directory.appendingPathComponent("attachments.json") }
    private var pendingDeletionsURL: URL { directory.appendingPathComponent("pending-image-deletions.json") }
    private func originalURL(for attachment: TodoImageAttachment) -> URL { originalsDirectory.appendingPathComponent(attachment.id.uuidString) }
    private func thumbnailURL(for attachment: TodoImageAttachment) -> URL { thumbnailsDirectory.appendingPathComponent("\(attachment.id.uuidString).jpg") }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    private func loadMetadata() { attachments = (try? Data(contentsOf: metadataURL)).flatMap { try? decoder.decode([TodoImageAttachment].self, from: $0) } ?? [] }
    private func saveMetadata() { try? ensureDirectories(); if let data = try? encoder.encode(attachments) { try? data.write(to: metadataURL, options: .atomic) } }
    private func savePendingDeletions() { try? ensureDirectories(); if let data = try? encoder.encode(pendingDeletions) { try? data.write(to: pendingDeletionsURL, options: .atomic) } }
    private func normalizeOrder(for todoID: UUID) { for (order, image) in images(for: todoID).enumerated() { if let index = attachments.firstIndex(where: { $0.id == image.id }) { attachments[index].sortOrder = order } } }

    private func upload(_ attachment: TodoImageAttachment) {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: attachment.id.uuidString))
        record["todoID"] = attachment.todoID.uuidString as CKRecordValue
        record["sortOrder"] = attachment.sortOrder as CKRecordValue
        record["createdAt"] = attachment.createdAt as CKRecordValue
        record["isOriginalAvailable"] = attachment.isOriginalAvailable as CKRecordValue
        if fileManager.fileExists(atPath: thumbnailURL(for: attachment).path) { record["thumbnail"] = CKAsset(fileURL: thumbnailURL(for: attachment)) }
        if attachment.isOriginalAvailable, fileManager.fileExists(atPath: originalURL(for: attachment).path) {
            record["original"] = CKAsset(fileURL: originalURL(for: attachment))
        } else {
            // Explicitly orphan the CloudKit asset when a completed item's retention period expires.
            record["original"] = nil
        }
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { [weak self] result in if case let .failure(error) = result { DispatchQueue.main.async { self?.lastSyncError = error.localizedDescription } } }
        database.add(operation)
    }

    private func deleteRemoteRecord(id: UUID) {
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [CKRecord.ID(recordName: id.uuidString)])
        operation.modifyRecordsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.pendingDeletions.remove(id)
                    self?.savePendingDeletions()
                case let .failure(error): self?.lastSyncError = error.localizedDescription
                }
            }
        }
        database.add(operation)
    }

    private func fetchRemoteAttachments() {
        fetchRemoteAttachments(cursor: nil, accumulated: [])
    }

    private func fetchRemoteAttachments(cursor: CKQueryOperation.Cursor?, accumulated: [CKRecord]) {
        let operation: CKQueryOperation
        if let cursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            operation = CKQueryOperation(query: CKQuery(recordType: recordType, predicate: NSPredicate(value: true)))
        }
        var records: [CKRecord] = []
        operation.recordMatchedBlock = { _, result in if case let .success(record) = result { records.append(record) } }
        operation.queryResultBlock = { [weak self] result in
            if case let .failure(error) = result { DispatchQueue.main.async { self?.lastSyncError = error.localizedDescription }; return }
            if case let .success(nextCursor) = result, let nextCursor {
                self?.fetchRemoteAttachments(cursor: nextCursor, accumulated: accumulated + records)
            } else {
                DispatchQueue.main.async { self?.merge(records: accumulated + records) }
            }
        }
        database.add(operation)
    }

    private func merge(records: [CKRecord]) {
        for record in records {
            guard let id = UUID(uuidString: record.recordID.recordName), let todoString = record["todoID"] as? String, let todoID = UUID(uuidString: todoString) else { continue }
            let remote = TodoImageAttachment(id: id, todoID: todoID, sortOrder: record["sortOrder"] as? Int ?? 0, isOriginalAvailable: record["isOriginalAvailable"] as? Bool ?? false, createdAt: record["createdAt"] as? Date ?? Date())
            if let existing = attachments.firstIndex(where: { $0.id == id }) {
                attachments[existing].sortOrder = remote.sortOrder
                attachments[existing].isOriginalAvailable = remote.isOriginalAvailable
                if !remote.isOriginalAvailable { try? fileManager.removeItem(at: originalURL(for: remote)) }
            } else {
                attachments.append(remote)
                copyAsset(record["thumbnail"] as? CKAsset, to: thumbnailURL(for: remote))
                if remote.isOriginalAvailable { copyAsset(record["original"] as? CKAsset, to: originalURL(for: remote)) }
            }
        }
        saveMetadata()
    }

    private func copyAsset(_ asset: CKAsset?, to destination: URL) { guard let source = asset?.fileURL else { return }; try? ensureDirectories(); try? fileManager.removeItem(at: destination); try? fileManager.copyItem(at: source, to: destination) }
}
