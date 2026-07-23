import AVFoundation
import SwiftUI

/// `UIViewRepresentable` que embute um `AVCaptureVideoPreviewLayer` em SwiftUI.
///
/// Usa a abordagem de subclasse de `UIView` com `layerClass` para garantir que o layer
/// de preview redimensione corretamente junto com a view, sem necessitar de constraints manuais.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        PreviewUIView(session: session)
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    // MARK: - UIView Wrapper

    /// View cujo `layerClass` é `AVCaptureVideoPreviewLayer`, garantindo que
    /// o layer cresce/encolhe automaticamente com a view.
    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("Use init(session:)") }
    }
}
