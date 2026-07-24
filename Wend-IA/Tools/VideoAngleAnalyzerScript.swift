#!/usr/bin/env swift

// VideoAngleAnalyzerScript.swift — threshold ajustável, modo resumo opcional
// Uso: swift VideoAngleAnalyzerScript.swift <video.mp4> <jointA,jointB,jointC> [minConf=0.3] [summaryOnly=false]

import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import Vision

// MARK: - Geometry

func angleDeg(vertex: CGPoint, a: CGPoint, c: CGPoint) -> Double {
    let ax = Double(a.x - vertex.x), ay = Double(a.y - vertex.y)
    let cx = Double(c.x - vertex.x), cy = Double(c.y - vertex.y)
    let mag = (ax*ax + ay*ay).squareRoot() * (cx*cx + cy*cy).squareRoot()
    guard mag > 0 else { return 0 }
    let cos = max(-1.0, min(1.0, (ax*cx + ay*cy) / mag))
    return acos(cos) * 180.0 / .pi
}

func evalAngle(
    a: VNHumanBodyPoseObservation.JointName,
    b: VNHumanBodyPoseObservation.JointName,
    c: VNHumanBodyPoseObservation.JointName,
    pts: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
    minConf: Float
) -> (deg: Double, cA: Float, cB: Float, cC: Float)? {
    guard let ptA = pts[a], ptA.confidence >= minConf,
          let ptB = pts[b], ptB.confidence >= minConf,
          let ptC = pts[c], ptC.confidence >= minConf else { return nil }
    let deg = angleDeg(
        vertex: CGPoint(x: ptB.location.x, y: ptB.location.y),
        a: CGPoint(x: ptA.location.x, y: ptA.location.y),
        c: CGPoint(x: ptC.location.x, y: ptC.location.y)
    )
    return (deg, ptA.confidence, ptB.confidence, ptC.confidence)
}

// MARK: - Helpers

func joint(_ s: String) -> VNHumanBodyPoseObservation.JointName? {
    switch s.lowercased().replacingOccurrences(of: "_", with: "") {
    case "rightshoulder": return .rightShoulder
    case "righthip":      return .rightHip
    case "rightknee":     return .rightKnee
    case "rightankle":    return .rightAnkle
    case "leftshoulder":  return .leftShoulder
    case "lefthip":       return .leftHip
    case "leftknee":      return .leftKnee
    case "leftankle":     return .leftAnkle
    case "neck":          return .neck
    case "root":          return .root
    case "nose":          return .nose
    default:              return nil
    }
}

func parseRule(_ raw: String) -> (VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, String)? {
    let parts = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    guard parts.count == 3, let a = joint(parts[0]), let b = joint(parts[1]), let c = joint(parts[2])
    else { return nil }
    return (a, b, c, "\(parts[0]) → \(parts[1]) (vértice) → \(parts[2])")
}

func ts(_ s: Double) -> String {
    "\(String(format: "%02d", Int(s)/60)):\(String(format: "%05.2f", s.truncatingRemainder(dividingBy: 60)))"
}
func pad(_ s: String, _ w: Int) -> String {
    s.count >= w ? String(s.prefix(w)) : s + String(repeating: " ", count: w - s.count)
}

// MARK: - Args

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2, let (jA, jB, jC, label) = parseRule(args[1]) else {
    print("Uso: swift script.swift <video.mp4> <jointA,jointB,jointC> [minConf=0.3] [summaryOnly=true]")
    exit(1)
}
let url = URL(fileURLWithPath: (args[0] as NSString).expandingTildeInPath)
guard FileManager.default.fileExists(atPath: url.path) else { print("❌ Não encontrado: \(url.path)"); exit(1) }

let minConf = Float(args.count > 2 ? args[2] : "0.3") ?? 0.3
let summaryOnly = args.count > 3 && args[3] == "true"

if !summaryOnly {
    print("==================================================================")
    print("🎬  \(url.lastPathComponent)")
    print("📐  \(label)  |  conf ≥ \(String(format: "%.2f", minConf))")
    print(String(repeating: "-", count: 66))
    print("\(pad("TEMPO",10)) | \(pad("ÂNGULO",8)) | \(pad("CONF A/B/C",22)) | STATUS")
    print(String(repeating: "-", count: 66))
}

// MARK: - Analysis

let sema = DispatchSemaphore(value: 0)

Task {
    defer { sema.signal() }
    let asset = AVURLAsset(url: url)
    do {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { print("❌ Sem faixa de vídeo."); return }
        let dur = try await asset.load(.duration)
        let durSec = CMTimeGetSeconds(dur)

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let trackOut = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(trackOut)
        reader.startReading()

        let handler = VNSequenceRequestHandler()
        let interval = CMTime(value: 1, timescale: 10)
        var lastPTS = CMTime.invalid
        var totalFrames = 0
        var validDeg: [Double] = []

        while reader.status == .reading, let buf = trackOut.copyNextSampleBuffer() {
            let pts = CMSampleBufferGetPresentationTimeStamp(buf)
            if lastPTS.isValid && (pts - lastPTS) < interval { continue }
            lastPTS = pts
            totalFrames += 1
            guard let pxBuf = CMSampleBufferGetImageBuffer(buf) else { continue }

            let req = VNDetectHumanBodyPoseRequest()
            try? handler.perform([req], on: pxBuf, orientation: .up)

            let t = ts(CMTimeGetSeconds(pts))
            guard let obs = req.results?.first, let ptsMap = try? obs.recognizedPoints(.all) else {
                if !summaryOnly { print("\(pad(t,10)) | \(pad("--",8)) | \(pad("--",22)) | ⚠️ sem pose") }
                continue
            }

            if let r = evalAngle(a: jA, b: jB, c: jC, pts: ptsMap, minConf: minConf) {
                validDeg.append(r.deg)
                if !summaryOnly {
                    let ang = String(format: "%.1f°", r.deg)
                    let conf = String(format: "%.2f/%.2f/%.2f", r.cA, r.cB, r.cC)
                    print("\(pad(t,10)) | \(pad(ang,8)) | \(pad(conf,22)) | ✅")
                }
            } else {
                if !summaryOnly {
                    let cA = ptsMap[jA]?.confidence ?? 0
                    let cB = ptsMap[jB]?.confidence ?? 0
                    let cC = ptsMap[jC]?.confidence ?? 0
                    let conf = String(format: "%.2f/%.2f/%.2f", cA, cB, cC)
                    print("\(pad(t,10)) | \(pad("--",8)) | \(pad(conf,22)) | ❌ conf<\(String(format:"%.2f",minConf))")
                }
            }
        }

        // SUMMARY
        print(String(repeating: "=", count: 66))
        print("📊  \(url.lastPathComponent)")
        print("    Regra: \(label) | conf ≥ \(String(format: "%.2f", minConf))")
        print(String(repeating: "-", count: 66))
        print("⏱️  Duração     : \(String(format: "%.1fs", durSec))")
        print("📸  Amostrados  : \(totalFrames) frames")
        print("✅  Válidos     : \(validDeg.count) frames")
        if !validDeg.isEmpty {
            let sorted = validDeg.sorted()
            let mn  = sorted.first!
            let mx  = sorted.last!
            let avg = validDeg.reduce(0,+) / Double(validDeg.count)
            let p10 = sorted[max(0, Int(Double(sorted.count)*0.10))]
            let p90 = sorted[min(sorted.count-1, Int(Double(sorted.count)*0.90))]
            print("📐  Mínimo      : \(String(format: "%.1f°", mn))")
            print("📐  Máximo      : \(String(format: "%.1f°", mx))")
            print("📐  Média       : \(String(format: "%.1f°", avg))")
            print("📐  P10 → P90   : \(String(format: "%.1f°", p10))  →  \(String(format: "%.1f°", p90))   ← faixa sugerida")
        } else {
            print("⚠️  Zero frames válidos — pontos não detectados com conf ≥ \(String(format: "%.2f", minConf))")
        }
        print(String(repeating: "=", count: 66))

    } catch { print("❌ Erro: \(error)") }
}

sema.wait()
