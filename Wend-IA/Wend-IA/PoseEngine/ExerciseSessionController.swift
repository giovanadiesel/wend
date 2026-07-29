import Combine
import Foundation
import Vision

/// Coordena uma sessão de exercício combinando `PoseAnalyzer` e `StretchDefinition`.
///
/// ### Máquina de estados
/// ```
///  ┌──────────────────────┐   duração de calibração    ┌─────────────────┐   ângulo dentro da faixa   ┌─────────────────┐
///  │ calibratingBaseline  │ ──────────────────────────▶ │ waitingPosition │ ─────────────────────────▶  │ holdingPosition │
///  └──────────────────────┘                             └─────────────────┘                             └────────┬────────┘
///                                                                 ▲                                               │
///                                                                 │  sem detecção                    ângulo fora  │  cronômetro acumulado
///                                                                 │  ou ângulo inválido              da faixa     │  ≥ holdDuration
///                                                        ┌─────────────────┐ ◀──────────────────────────          ▼
///                                                        │  outOfPosition  │                             ┌─────────────────┐
///                                                        └─────────────────┘    ângulo volta na faixa    │  repCompleted   │ (transitório)
///                                                                               ─────────────────────▶  └────────┬────────┘
///                                                                                                                 │
///                                                                                                     reps == targetRepetitions
///                                                                                                                 ▼
///                                                                                                     ┌─────────────────────┐
///                                                                                                     │   sessionFinished   │
///                                                                                                     └─────────────────────┘
/// ```
///
/// - Ao iniciar, a sessão passa alguns segundos em `calibratingBaseline`: coleta o ângulo
///   neutro do próprio usuário para cada `JointAngleRule`, já que a mesma postura projeta
///   ângulos 2D diferentes dependendo de onde a câmera está apoiada. A partir daí, "dentro
///   da faixa" é decidido por **variação em relação a essa baseline**
///   (`JointAngleRule.minimumDeltaFromBaseline`), não por um ângulo absoluto fixo.
/// - O cronômetro de hold **pausa** (sem zerar) quando o usuário sai da faixa.
/// - Quando o hold acumulado atinge `holdDuration`, a repetição é contabilizada e
///   o cronômetro é reiniciado para a próxima.
/// - Todas as atualizações de estado publicadas ocorrem na main queue.
final class ExerciseSessionController: ObservableObject {

    // MARK: - Fase da Sessão

    enum Phase: Equatable {
        /// Coletando a posição neutra do usuário nos primeiros segundos da sessão.
        case calibratingBaseline
        /// Nenhuma pose detectada ou ângulo fora da faixa.
        case waitingForPosition
        /// Ângulo dentro da faixa — cronômetro de hold ativo.
        case holdingPosition
        /// Usuário saiu da faixa — cronômetro pausado, tempo acumulado preservado.
        case outOfPosition
        /// Sessão encerrada após `targetRepetitions` repetições completas.
        case sessionFinished
    }

    /// Resultado da avaliação de uma `JointAngleRule` em relação à baseline da sessão.
    struct RuleEvaluation {
        /// Ângulo bruto medido no frame atual, em graus.
        let degrees: Double
        /// `true` se `degrees` já se afastou o suficiente da baseline (ver `JointAngleRule.minimumDeltaFromBaseline`).
        let isWithinRange: Bool
    }

    // MARK: - Estado Publicado

    /// Fase atual da sessão.
    @Published private(set) var phase: Phase = .waitingForPosition

    /// Número de repetições completas desde o início da sessão.
    @Published private(set) var repsCompleted: Int = 0

    /// Progresso do hold da repetição atual (0.0 = início, 1.0 = completo).
    @Published private(set) var holdProgress: Double = 0

    /// Progresso da calibração de baseline (0.0 = início, 1.0 = completo).
    @Published private(set) var calibrationProgress: Double = 0

    /// Tempo total decorrido desde `start()`, em segundos.
    @Published private(set) var sessionElapsedTime: TimeInterval = 0

    /// Percentual (0–100) do tempo total de sessão em que o usuário ficou na posição correta.
    @Published private(set) var withinRangePercentage: Double = 0

    /// Resultado da avaliação para cada `JointAngleRule` de `definition.targetJoints`,
    /// mapeados pelo mesmo índice. `nil` quando a articulação não está detectada ou a
    /// baseline ainda não foi calibrada.
    @Published private(set) var evaluations: [RuleEvaluation?] = []

    // MARK: - Configuração

    /// Definição do exercício sendo executado.
    let definition: StretchDefinition

    /// Número de repetições completas necessárias para encerrar a sessão.
    let targetRepetitions: Int

    /// Duração da coleta de posição neutra no início da sessão.
    let calibrationDuration: TimeInterval

    /// Closure chamado quando `repsCompleted == targetRepetitions`.
    /// Recebe `holdDurationAchieved` (tempo total efetivo dentro da faixa)
    /// e `withinRangePercentage` para persistência no `ModelContext`.
    ///
    /// A responsabilidade de criar e salvar `SessionRecord` é da camada de UI —
    /// o controller não importa SwiftData, mantendo o PoseEngine testável.
    var onSessionFinished: ((_ holdDurationAchieved: TimeInterval, _ withinRangePercentage: Double) -> Void)?

    // MARK: - Dependências

    private let analyzer: PoseAnalyzer

    // MARK: - Internals — Cronômetro de Sessão

    /// Momento em que `start()` foi chamado.
    private var sessionStartDate: Date?

    // MARK: - Internals — Calibração de Baseline

    /// Momento em que a calibração começou.
    private var calibrationStartDate: Date?

    /// Amostras de ângulo bruto coletadas por regra durante a calibração,
    /// mapeadas pelo mesmo índice de `definition.targetJoints`.
    private var baselineSamples: [[Double]] = []

    /// Ângulo neutro (média das amostras) por regra. `nil` enquanto não calibrado,
    /// ou se nenhuma amostra confiante foi coletada para aquela regra.
    private var baselineAngles: [Double?] = []

    /// Número mínimo de amostras válidas por regra antes de considerar a
    /// calibração completa — a detecção do Vision é intermitente mesmo com boa
    /// postura, então basear-se só em tempo decorrido pode fechar a janela de
    /// calibração sem nenhuma amostra confiante.
    private let minimumBaselineSamples = 5

    /// Teto absoluto pra calibração, caso as regras nunca atinjam
    /// `minimumBaselineSamples` — evita travar a sessão indefinidamente.
    private let maximumCalibrationDuration: TimeInterval = 8.0

    // MARK: - Internals — Histerese de Avaliação

    /// Estado "dentro da faixa" de cada regra, mapeado pelo mesmo índice de
    /// `definition.targetJoints`. Usa histerese (ver `evaluateFrame()`) para
    /// não oscilar quando o ângulo medido flutua perto do limiar por ruído
    /// natural de detecção do Vision.
    private var ruleInRangeState: [Bool] = []

    /// Margem de histerese, em graus: uma regra que já está "dentro da faixa"
    /// só volta a ficar "fora" quando o delta cai abaixo de
    /// `minimumDeltaFromBaseline - hysteresisMargin`, não assim que cruza o
    /// limiar de entrada. Evita o "flicker" da % de precisão perto da borda.
    private let hysteresisMargin: Double = 5.0

    // MARK: - Internals — Publicação Suavizada da Precisão

    /// Valor de precisão sempre atualizado (não publicado), usado internamente
    /// para o resultado final da sessão — não sofre o throttle de exibição.
    private var latestAccuratePercentage: Double = 0

    /// Throttle da publicação de `withinRangePercentage` — atualiza a UI no
    /// máximo a cada `percentagePublishInterval`, pra não "tontear" o usuário
    /// com o número mudando 10x por segundo.
    private var lastPercentagePublishDate: Date = .distantPast
    private let percentagePublishInterval: TimeInterval = 0.5

    // MARK: - Internals — Cronômetro de Hold (por repetição)

    /// Tempo acumulado dentro da faixa **antes** do intervalo em curso.
    /// Preservado quando o usuário sai da faixa e reutilizado ao retornar.
    private var accumulatedHoldTime: TimeInterval = 0

    /// Início do intervalo de hold em curso. `nil` quando fora da faixa.
    private var inRangeStartDate: Date?

    // MARK: - Internals — Métrica de Precisão

    /// Soma do tempo total de hold de todas as repetições finalizadas.
    private var holdTimeFromCompletedReps: TimeInterval = 0

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    /// Timer de display: atualiza valores publicados de tempo e progresso 10× por segundo
    /// de forma independente da taxa de frames da câmera.
    private var displayTimer: AnyCancellable?

    /// Throttle do log de diagnóstico de avaliação — no máximo 1 print/segundo.
    private var lastEvaluationLogDate: Date = .distantPast

    // MARK: - Init

    /// - Parameters:
    ///   - definition: Exercício a ser executado.
    ///   - analyzer: `PoseAnalyzer` já conectado a um `CameraManager` ativo.
    ///   - targetRepetitions: Número de repetições para encerrar a sessão. Padrão: 3.
    ///   - calibrationDuration: Duração da coleta de posição neutra no início. Padrão: 2.5s.
    ///   - onSessionFinished: Closure chamado ao finalizar a sessão com os dados de hold e precisão.
    init(
        definition: StretchDefinition,
        analyzer: PoseAnalyzer,
        targetRepetitions: Int = 3,
        calibrationDuration: TimeInterval = 2.5,
        onSessionFinished: ((_ holdDurationAchieved: TimeInterval, _ withinRangePercentage: Double) -> Void)? = nil
    ) {
        self.definition = definition
        self.analyzer = analyzer
        self.targetRepetitions = targetRepetitions
        self.calibrationDuration = calibrationDuration
        self.onSessionFinished = onSessionFinished
        self.evaluations = Array(repeating: nil, count: definition.targetJoints.count)
    }

    // MARK: - Controle Público

    /// Inicia a sessão. Começa a observar o `PoseAnalyzer` e o timer de display.
    func start() {
        guard phase != .sessionFinished else { return }
        sessionStartDate = Date()

        if definition.targetJoints.isEmpty {
            // Modo time-only (ex: Lumbar Rotation) — sem ângulo pra calibrar.
            phase = .waitingForPosition
        } else {
            baselineSamples = Array(repeating: [], count: definition.targetJoints.count)
            baselineAngles = Array(repeating: nil, count: definition.targetJoints.count)
            ruleInRangeState = Array(repeating: false, count: definition.targetJoints.count)
            // `calibrationStartDate` só é definido no primeiro frame recebido
            // (ver `evaluateFrame()`) — não aqui, pra não descontar o tempo de
            // startup da câmera (AVCaptureSession pode levar 1-2s pra entregar
            // o primeiro frame) da janela de calibração.
            calibrationStartDate = nil
            calibrationProgress = 0
            phase = .calibratingBaseline
        }

        subscribeToAnalyzer()
        startDisplayTimer()
    }

    /// Encerra a sessão manualmente, parando todas as subscriptions.
    func stop() {
        finalizeHoldAccumulation()
        cancelSubscriptions()
        if phase != .sessionFinished {
            phase = .outOfPosition
        }
    }

    /// Encerra a sessão como concluída (disparado ao tocar em 'Finish Exercise'),
    /// definindo a fase como .sessionFinished e notificando a UI.
    func finishEarly() {
        finalizeHoldAccumulation()
        cancelSubscriptions()
        phase = .sessionFinished
        let achieved = holdTimeFromCompletedReps + accumulatedHoldTime
        let accuracy = sessionElapsedTime > 0 ? min((achieved / sessionElapsedTime) * 100, 100) : latestAccuratePercentage
        withinRangePercentage = accuracy
        onSessionFinished?(achieved, accuracy)
    }

    // MARK: - Subscriptions Privadas

    private func subscribeToAnalyzer() {
        // Observa `detectedJoints` — disparado a cada frame processado pela câmera.
        analyzer.$detectedJoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.evaluateFrame()
            }
            .store(in: &cancellables)
    }

    private func startDisplayTimer() {
        displayTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func cancelSubscriptions() {
        cancellables.removeAll()
        displayTimer?.cancel()
        displayTimer = nil
    }

    // MARK: - Lógica de Frame (main queue)

    /// Chamado a cada frame. Durante a calibração, só coleta amostras; depois,
    /// avalia todas as regras da definição contra a baseline e transita entre fases.
    private func evaluateFrame() {
        guard phase != .sessionFinished else { return }

        // ── Modo time-only (sem regras de ângulo) ────────────────────────────────
        // Usado por exercícios supinos onde o Vision não detecta os joints
        // de forma confiável (ex: Lumbar Rotation). O cronômetro inicia
        // imediatamente sem validação de postura.
        if definition.targetJoints.isEmpty {
            if inRangeStartDate == nil && phase != .holdingPosition {
                inRangeStartDate = Date()
                phase = .holdingPosition
            }
            return
        }

        // ── Calibração da posição neutra ─────────────────────────────────────────
        if phase == .calibratingBaseline {
            // Marca o início real da janela de calibração no primeiro frame
            // processado (câmera pronta), não em `start()`.
            if calibrationStartDate == nil {
                calibrationStartDate = Date()
            }
            for (index, rule) in definition.targetJoints.enumerated() {
                if let degrees = analyzer.rawDegrees(for: rule) {
                    baselineSamples[index].append(degrees)
                }
            }
            return
        }

        // Avalia todas as regras (variação em relação à baseline, com histerese) e publica os resultados.
        let currentEvaluations: [RuleEvaluation?] = definition.targetJoints.enumerated().map { index, rule in
            guard
                let degrees = analyzer.rawDegrees(for: rule),
                let baseline = baselineAngles[index]
            else { return nil }

            let delta = abs(degrees - baseline)
            // Histerese: já dentro da faixa exige cair abaixo de um limiar mais
            // baixo pra sair; ainda fora exige cruzar o limiar normal pra entrar.
            let exitThreshold = max(0, rule.minimumDeltaFromBaseline - hysteresisMargin)
            let wasInRange = ruleInRangeState[index]
            let inRange = wasInRange ? (delta >= exitThreshold) : (delta >= rule.minimumDeltaFromBaseline)
            ruleInRangeState[index] = inRange

            return RuleEvaluation(degrees: degrees, isWithinRange: inRange)
        }
        evaluations = currentEvaluations
        logEvaluationIfNeeded(currentEvaluations)

        // "Em posição" = todas as regras com articulações detectadas e afastadas o
        // suficiente da baseline. Se alguma articulação não é detectada (nil) ou a
        // baseline não foi calibrada, considera fora da posição.
        let allInRange = currentEvaluations.allSatisfy { $0?.isWithinRange == true }

        let wasInRange = (inRangeStartDate != nil)

        switch (wasInRange, allInRange) {
        case (false, true):
            // Entrou na faixa: inicia/retoma o cronômetro de hold.
            inRangeStartDate = Date()
            phase = .holdingPosition

        case (true, false):
            // Saiu da faixa: pausa o cronômetro preservando o tempo acumulado.
            finalizeHoldAccumulation()
            phase = .outOfPosition

        case (false, false):
            // Continua fora da faixa.
            phase = .waitingForPosition

        case (true, true):
            // Continua dentro da faixa — cronômetro rodando, sem alteração de estado.
            break
        }
    }

    // MARK: - Lógica de Timer (0.1s)

    /// Atualiza valores de tempo e verifica conclusão de repetição ou de calibração.
    private func tick() {
        guard let sessionStart = sessionStartDate, phase != .sessionFinished else { return }

        let now = Date()

        // ── Tempo total de sessão ────────────────────────────────────────────────
        sessionElapsedTime = now.timeIntervalSince(sessionStart)

        // ── Calibração da posição neutra ─────────────────────────────────────────
        if phase == .calibratingBaseline {
            guard let calibrationStart = calibrationStartDate else { return }
            let elapsed = now.timeIntervalSince(calibrationStart)
            calibrationProgress = min(elapsed / calibrationDuration, 1.0)

            let hasEnoughSamples = baselineSamples.allSatisfy { $0.count >= minimumBaselineSamples }
            if (elapsed >= calibrationDuration && hasEnoughSamples) || elapsed >= maximumCalibrationDuration {
                finishCalibration()
            }
            return
        }

        // ── Progresso do hold atual ──────────────────────────────────────────────
        let currentHold = currentHoldTime(at: now)
        holdProgress = min(currentHold / definition.holdDuration, 1.0)

        // ── Percentual de precisão ───────────────────────────────────────────────
        // Soma o hold de reps finalizadas + hold em progresso atual. O valor
        // interno (`latestAccuratePercentage`) é sempre exato; a publicação pra
        // UI é throttled separadamente pra não atualizar o número 10x/segundo.
        let totalInRange = holdTimeFromCompletedReps + currentHold
        if sessionElapsedTime > 0 {
            latestAccuratePercentage = min(totalInRange / sessionElapsedTime * 100, 100)
        }
        if now.timeIntervalSince(lastPercentagePublishDate) >= percentagePublishInterval {
            lastPercentagePublishDate = now
            withinRangePercentage = latestAccuratePercentage
        }

        // ── Verificação de repetição completa ────────────────────────────────────
        if currentHold >= definition.holdDuration {
            completeCurrentRep(at: now)
        }
    }

    // MARK: - Helpers de Calibração

    /// Encerra a calibração: calcula a média das amostras coletadas por regra e
    /// libera a avaliação normal de postura. Regras sem nenhuma amostra confiante
    /// ficam com baseline `nil` e nunca são consideradas "dentro da faixa" nesta
    /// sessão — falha fechada, em vez de adivinhar um valor.
    private func finishCalibration() {
        baselineAngles = baselineSamples.map { samples in
            guard !samples.isEmpty else { return nil }
            return samples.reduce(0, +) / Double(samples.count)
        }

        let summary = zip(definition.targetJoints, zip(baselineSamples, baselineAngles))
            .map { rule, pair in
                let (samples, angle) = pair
                let angleStr = angle.map { String(format: "%.1f°", $0) } ?? "NENHUMA AMOSTRA"
                return "\(rule.jointB.rawValue.rawValue)=\(angleStr) (\(samples.count) amostras)"
            }
            .joined(separator: " | ")
        print("🎯 [Baseline] Calibração concluída — \(summary)")

        phase = .waitingForPosition
    }

    /// Log temporário de diagnóstico (throttled a 1x/segundo) comparando o
    /// ângulo atual de cada regra com a baseline calibrada.
    private func logEvaluationIfNeeded(_ currentEvaluations: [RuleEvaluation?]) {
        let now = Date()
        guard now.timeIntervalSince(lastEvaluationLogDate) >= 1.0 else { return }
        lastEvaluationLogDate = now

        let summary = zip(definition.targetJoints, zip(currentEvaluations, baselineAngles))
            .map { rule, pair in
                let (eval, baseline) = pair
                let baselineStr = baseline.map { String(format: "%.1f°", $0) } ?? "sem baseline"
                guard let eval else { return "\(rule.jointB.rawValue.rawValue)=sem detecção (baseline: \(baselineStr))" }
                let delta = baseline.map { abs(eval.degrees - $0) }
                let deltaStr = delta.map { String(format: "%.1f°", $0) } ?? "?"
                return "\(rule.jointB.rawValue.rawValue)=\(String(format: "%.1f°", eval.degrees)) baseline=\(baselineStr) delta=\(deltaStr)/\(rule.minimumDeltaFromBaseline)° inRange=\(eval.isWithinRange)"
            }
            .joined(separator: " | ")
        print("📊 [Eval] \(summary)")
    }

    // MARK: - Helpers de Cronômetro

    /// Tempo acumulado de hold para a repetição em curso, calculado no instante `date`.
    private func currentHoldTime(at date: Date = Date()) -> TimeInterval {
        if let start = inRangeStartDate {
            return accumulatedHoldTime + date.timeIntervalSince(start)
        }
        return accumulatedHoldTime
    }

    /// Incorpora o intervalo em curso ao acumulado e para de contar.
    private func finalizeHoldAccumulation() {
        if let start = inRangeStartDate {
            accumulatedHoldTime += Date().timeIntervalSince(start)
            inRangeStartDate = nil
        }
    }

    /// Registra uma repetição completa, reinicia o cronômetro de hold e verifica encerramento.
    private func completeCurrentRep(at now: Date) {
        // Preserva o tempo de hold desta rep na métrica de precisão.
        holdTimeFromCompletedReps += definition.holdDuration

        // Reinicia o cronômetro de hold para a próxima repetição.
        accumulatedHoldTime = 0
        // Se ainda está dentro da faixa, o hold da próxima rep começa imediatamente.
        inRangeStartDate = (phase == .holdingPosition) ? now : nil

        holdProgress = 0
        repsCompleted += 1

        if repsCompleted >= targetRepetitions {
            cancelSubscriptions()
            phase = .sessionFinished

            // Notifica a camada de UI para persistir o SessionRecord.
            // holdDurationAchieved = tempo total de hold válido (todas as reps).
            // Usa `latestAccuratePercentage` (não a versão throttled pra UI) pra
            // garantir que o valor salvo seja exato, não uma leitura de até
            // `percentagePublishInterval` atrás.
            let achieved = holdTimeFromCompletedReps
            let accuracy = latestAccuratePercentage
            withinRangePercentage = accuracy
            onSessionFinished?(achieved, accuracy)
        }
    }
}
