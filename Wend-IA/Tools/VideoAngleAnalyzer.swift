import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import Vision

/// Ferramenta de linha de comando para análise offline de ângulos em arquivos de vídeo (MP4 / MOV).
///
/// Extrai frames do vídeo a ~10 fps, detecta articulações corporais usando Vision (`VNDetectHumanBodyPoseRequest`),
/// calcula o ângulo de articulação solicitado usando `evaluateJointAngle` e exibe logs em tempo real
/// mais um resumo estatístico (mínimo, máximo e média).
@main
struct VideoAngleAnalyzer {

    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let firstArg = args.first, !firstArg.isEmpty else {
            printUsage()
            exit(1)
        }

        let videoPath = (firstArg as NSString).expandingTildeInPath
        let videoURL = URL(fileURLWithPath: videoPath)

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ Erro: Arquivo de vídeo não encontrado no caminho: \(videoPath)")
            exit(1)
        }

        let jointRuleArg = args.count > 1 ? args[1] : "rightShoulder,rightHip,rightKnee"
        let (jointA, jointB, jointC, ruleLabel) = parseJointsRule(jointRuleArg)

        print("==================================================================")
        print("🎬 VIDEO ANGLE ANALYZER — WEND")
        print("==================================================================")
        print("📹 Arquivo: \(videoURL.lastPathComponent)")
        print("📐 Regra de Ângulo: \(ruleLabel)")
        print("   (Articulação A: \(jointA.rawValue.rawValue), Vértice B: \(jointB.rawValue.rawValue), Articulação C: \(jointC.rawValue.rawValue))")
        print("⏱️ Taxa de amostragem: ~10 frames por segundo")
        print("------------------------------------------------------------------")
        print(String(format: "%-10s | %-10s | %-38s | %-12s", "TIMESTAMP", "ÂNGULO", "CONFIANÇA (A / B / C)", "STATUS"))
        print("------------------------------------------------------------------")

        let asset = AVURLAsset(url: videoURL)

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else {
                print("❌ Erro: Nenhuma faixa de vídeo encontrada no arquivo.")
                exit(1)
            }

            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
            reader.add(trackOutput)
            reader.startReading()

            let sequenceHandler = VNSequenceRequestHandler()
            let sampleInterval = CMTime(value: 1, timescale: 10) // 10 fps (0.1s)
            var lastProcessedTime = CMTime.invalid

            var totalFramesExamined = 0
            var validDegrees: [Double] = []

            while reader.status == .reading, let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let currentSeconds = CMTimeGetSeconds(pts)

                // Subamostrar para ~10 fps
                if lastProcessedTime.isValid && (pts - lastProcessedTime) < sampleInterval {
                    continue
                }
                lastProcessedTime = pts
                totalFramesExamined += 1

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

                let request = VNDetectHumanBodyPoseRequest()
                try? sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)

                let timestampStr = formatTimestamp(seconds: currentSeconds)

                guard
                    let observation = request.results?.first,
                    let points = try? observation.recognizedPoints(.all)
                else {
                    print(String(format: "%-10s | %-10s | %-38s | ⚠️ Nenhuma pose", timestampStr, "--", "--"))
                    continue
                }

                // Avalia o ângulo usando a função compartilhada evaluateJointAngle (com minConfidence 0.5)
                if let eval = evaluateJointAngle(jointA: jointA, jointB: jointB, jointC: jointC, in: points, minConfidence: 0.5) {
                    validDegrees.append(eval.degrees)

                    let angleStr = String(format: "%.1f°", eval.degrees)
                    let confStr = String(format: "A: %.2f | B: %.2f | C: %.2f", eval.confA, eval.confB, eval.confC)
                    print(String(format: "%-10s | %-10s | %-38s | ✅ Válido", timestampStr, angleStr, confStr))
                } else {
                    let pA = points[jointA]?.confidence ?? 0
                    let pB = points[jointB]?.confidence ?? 0
                    let pC = points[jointC]?.confidence ?? 0
                    let confStr = String(format: "A: %.2f | B: %.2f | C: %.2f", pA, pB, pC)
                    print(String(format: "%-10s | %-10s | %-38s | ❌ Baixa conf (<0.5)", timestampStr, "--", confStr))
                }
            }

            // Imprime resumo estatístico final
            print("==================================================================")
            print("📊 RESUMO FINAL DA ANÁLISE DO VÍDEO")
            print("==================================================================")
            print("📹 Vídeo: \(videoURL.lastPathComponent)")
            print("⏱️ Duração total: \(String(format: "%.2f", durationSeconds))s")
            print("📸 Frames amostrados (~10 fps): \(totalFramesExamined)")
            print("✅ Frames válidos (confiança ≥ 0.5 nos 3 pontos): \(validDegrees.count)")

            if !validDegrees.isEmpty {
                let minAngle = validDegrees.min()!
                let maxAngle = validDegrees.max()!
                let avgAngle = validDegrees.reduce(0, +) / Double(validDegrees.count)

                print("------------------------------------------------------------------")
                print("📐 Ângulo Mínimo Observado: \(String(format: "%.1f°", minAngle))")
                print("📐 Ângulo Máximo Observado: \(String(format: "%.1f°", maxAngle))")
                print("📐 Ângulo Médio Observado:  \(String(format: "%.1f°", avgAngle))")
            } else {
                print("⚠️ Nenhum frame atendeu aos critérios de confiança (≥ 0.5) para as 3 articulações.")
            }
            print("==================================================================")

        } catch {
            print("❌ Erro ao abrir ou ler o arquivo de vídeo: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func printUsage() {
        print("""
        ==================================================================
        VideoAngleAnalyzer — Análise offline de pose e ângulos em vídeos
        ==================================================================
        Uso:
          swift VideoAngleAnalyzer.swift <caminho-do-video> [regra-de-articulações]

        Exemplos:
          VideoAngleAnalyzer ~/Desktop/alongamento.mp4
          VideoAngleAnalyzer ~/Desktop/bridge.mov rightHip,rightKnee,rightAnkle
          VideoAngleAnalyzer ~/Desktop/cat_camel.mp4 rightShoulder,rightHip,rightKnee

        Formato da regra: jointA,jointB,jointC (onde jointB é o vértice do ângulo)
        ==================================================================
        """)
    }

    private static func formatTimestamp(seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", mins, secs)
    }

    private static func parseJointsRule(_ raw: String) -> (
        jointA: VNHumanBodyPoseObservation.JointName,
        jointB: VNHumanBodyPoseObservation.JointName,
        jointC: VNHumanBodyPoseObservation.JointName,
        label: String
    ) {
        let parts = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        if parts.count == 3,
           let a = parseJoint(parts[0]),
           let b = parseJoint(parts[1]),
           let c = parseJoint(parts[2]) {
            return (a, b, c, "\(parts[0]) -> \(parts[1]) (vértice) -> \(parts[2])")
        }
        // Padrão: rightShoulder, rightHip, rightKnee
        return (.rightShoulder, .rightHip, .rightKnee, "rightShoulder -> rightHip (vértice) -> rightKnee")
    }

    private static func parseJoint(_ name: String) -> VNHumanBodyPoseObservation.JointName? {
        let lower = name.lowercased()
        switch lower {
        case "rightshoulder", "right_shoulder": return .rightShoulder
        case "righthip", "right_hip": return .rightHip
        case "rightknee", "right_knee": return .rightKnee
        case "rightankle", "right_ankle": return .rightAnkle
        case "leftshoulder", "left_shoulder": return .leftShoulder
        case "lefthip", "left_hip": return .leftHip
        case "leftknee", "left_knee": return .leftKnee
        case "leftankle", "left_ankle": return .leftAnkle
        case "neck": return .neck
        case "root": return .root
        default: return nil
        }
    }
}
