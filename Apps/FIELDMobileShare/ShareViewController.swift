import FieldCore
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "square.and.arrow.down.fill"))
        icon.tintColor = .tintColor
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true

        statusLabel.text = "Guardando en FIELD…"
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, activityIndicator, statusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        activityIndicator.startAnimating()

        loadSharedContent()
    }

    private func loadSharedContent() {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []
        var payload = SharedPayload()
        let group = DispatchGroup()
        var foundSupportedContent = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                foundSupportedContent = true
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    DispatchQueue.main.async {
                        if payload.imageData == nil { payload.imageData = data }
                        group.leave()
                    }
                }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                foundSupportedContent = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        let url = (item as? URL)
                            ?? (item as? NSURL).map { $0 as URL }
                        let string = (item as? String)
                            ?? (item as? NSString).map { String($0) }
                        if payload.urlString.isEmpty {
                            payload.urlString = url?.absoluteString ?? string ?? ""
                        }
                        group.leave()
                    }
                }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                foundSupportedContent = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        let text = (item as? String)
                            ?? (item as? NSString).map { String($0) }
                            ?? (item as? NSAttributedString)?.string
                            ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                            ?? ""
                        if !text.isEmpty {
                            payload.text = [payload.text, text].filter { !$0.isEmpty }.joined(separator: "\n")
                        }
                        group.leave()
                    }
                }
            }
        }

        guard foundSupportedContent else {
            showFailure("Esta app no ha compartido una imagen, un enlace ni texto compatible.")
            return
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.enqueue(payload)
        }
    }

    private func enqueue(_ payload: SharedPayload) {
        let payload = payload.withURLExtractedFromText()
        guard payload.imageData != nil || !payload.urlString.isEmpty || !payload.text.isEmpty else {
            showFailure("No se pudo leer el contenido compartido.")
            return
        }
        guard
            let groupID = Bundle.main.object(forInfoDictionaryKey: "FIELD_APP_GROUP_ID") as? String,
            groupID != "group.com.example.field",
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        else {
            showFailure("Falta configurar el grupo compartido de FIELD en Xcode.")
            return
        }

        do {
            let directory = groupURL.appendingPathComponent("ReferenceImports", isDirectory: true)
            let queue = try ReferenceImportQueue(directory: directory)
            let type: ReferenceImportContentType
            if payload.imageData != nil && !payload.urlString.isEmpty {
                type = .imageAndURL
            } else if payload.imageData != nil {
                type = .image
            } else if !payload.urlString.isEmpty {
                type = .url
            } else {
                type = .text
            }
            try queue.enqueue(
                contentType: type,
                assetData: payload.imageData,
                urlString: payload.urlString,
                text: payload.text
            )
            activityIndicator.stopAnimating()
            statusLabel.text = "Guardado. Abre FIELD para verlo en Recopilar."
            statusLabel.textColor = .secondaryLabel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        } catch {
            showFailure("No se pudo guardar la referencia: \(error.localizedDescription)")
        }
    }

    private func showFailure(_ message: String) {
        activityIndicator.stopAnimating()
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        let alert = UIAlertController(title: "No se pudo guardar en FIELD", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cerrar", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "FIELDShareExtension", code: 1))
        })
        present(alert, animated: true)
    }
}

private struct SharedPayload {
    var imageData: Data?
    var urlString = ""
    var text = ""

    func withURLExtractedFromText() -> SharedPayload {
        var result = self
        let lines = text.components(separatedBy: .newlines)
        let urlLine = urlString.isEmpty ? lines.first(where: { line in
            guard
                let url = URL(string: line.trimmingCharacters(in: .whitespacesAndNewlines)),
                let scheme = url.scheme?.lowercased()
            else { return false }
            return scheme == "http" || scheme == "https"
        }) : urlString
        guard let urlLine, !urlLine.isEmpty else { return self }

        result.urlString = urlLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalURL = ReferenceSourceResolver.normalize(result.urlString)
        result.text = lines
            .filter { line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    let lineURL = URL(string: trimmedLine),
                    let scheme = lineURL.scheme?.lowercased(),
                    scheme == "http" || scheme == "https"
                else { return true }
                return ReferenceSourceResolver.normalize(trimmedLine) != canonicalURL
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}
