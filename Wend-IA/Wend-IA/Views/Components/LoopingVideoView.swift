import AVFoundation
import SwiftUI

/// Exibe um vídeo curto em loop contínuo, mudo, sem controles — como um GIF,
/// mas com qualidade de vídeo (sem banda de cor, arquivo menor).
///
/// Usa `AVQueuePlayer` + `AVPlayerLooper` (looping nativo, sem gap perceptível
/// entre repetições) em vez de um `AVPlayer` simples reiniciado manualmente.
struct LoopingVideoView: UIViewRepresentable {
    /// Nome do arquivo de vídeo (sem extensão) no bundle do app.
    let resourceName: String
    /// Extensão do arquivo (ex: "mp4").
    let resourceExtension: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(resourceName: resourceName, resourceExtension: resourceExtension)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

/// `UIView` cujo layer é um `AVPlayerLayer`, tocando um `AVQueuePlayer` em loop
/// mudo desde a inicialização.
final class LoopingPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    private var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }

    init(resourceName: String, resourceExtension: String) {
        super.init(frame: .zero)

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer = player

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        player.play()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(resourceName:resourceExtension:)")
    }
}
