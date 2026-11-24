import AppKit
import Foundation
import PDFKit
import WebKit

final class PDFExporter: NSObject, WKNavigationDelegate {
    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 816, height: 1056))
    let outputURL: URL
    var finished = false
    var failure: Error?

    init(outputURL: URL) {
        self.outputURL = outputURL
        super.init()
        webView.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.querySelectorAll('.page').length") { [self] result, error in
            guard error == nil, let total = result as? Int, total > 0 else {
                failure = error ?? NSError(domain: "PDFExporter", code: 1)
                finished = true
                return
            }
            createPage(at: 0, total: total, in: PDFDocument())
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failure = error
        finished = true
    }

    private func createPage(at index: Int, total: Int, in document: PDFDocument) {
        guard index < total else {
            guard let data = document.dataRepresentation() else {
                failure = NSError(domain: "PDFExporter", code: 2)
                finished = true
                return
            }
            do {
                try data.write(to: outputURL, options: .atomic)
                print("PDF creado: \(outputURL.path)")
            } catch {
                failure = error
                fputs("No se pudo crear el PDF: \(error)\n", stderr)
            }
            finished = true
            return
        }

        let configuration = WKPDFConfiguration()
        configuration.rect = CGRect(x: 0, y: CGFloat(index * 1056), width: 816, height: 1056)
        webView.createPDF(configuration: configuration) { [self] result in
            do {
                let pageData = try result.get()
                guard let pageDocument = PDFDocument(data: pageData),
                      let page = pageDocument.page(at: 0) else {
                    throw NSError(domain: "PDFExporter", code: 3)
                }
                document.insert(page, at: index)
                createPage(at: index + 1, total: total, in: document)
            } catch {
                failure = error
                fputs("No se pudo crear la página \(index + 1): \(error)\n", stderr)
                finished = true
            }
        }
    }
}

guard CommandLine.arguments.count == 3 else {
    fputs("Uso: swift exportar-informe.swift entrada.html salida.pdf\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let exporter = PDFExporter(outputURL: outputURL)
exporter.webView.loadFileURL(inputURL, allowingReadAccessTo: inputURL.deletingLastPathComponent())

while !exporter.finished {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
}

if exporter.failure != nil {
    exit(1)
}
