import UIKit
import PDFKit

class mainViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
}

extension mainViewController: UIDocumentPickerDelegate {
    @IBAction func openPDF(_ sender: UIButton) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["com.adobe.pdf"], in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .fullScreen
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }
                
        guard let pdfViewController = self.storyboard?.instantiateViewController(withIdentifier: "pdfViewController") as? ViewController else { return }
    
        let pdfDocument = PDFDocument(url: selectedFileURL)
        pdfViewController.pdfURL = pdfDocument
        navigationController?.pushViewController(pdfViewController, animated: true)
    }
    
}
