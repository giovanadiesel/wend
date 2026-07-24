import Combine
import Foundation

/// Coordena uma sessão de exercício combinando `PoseAnalyzer` e `StretchDefinition`.
///
/// ### Máquina de estados
/// ```
///  ┌─────────────────┐   ângulo dentro da faixa   ┌─────────────────┐
///  │ waitingPosition │ ─────────────────────────▶  │ holdingPosition │
///  └─────────────────┘                             └────────┬────────┘
///           ▲                                               │
///           │  sem detecção                    ângulo fora  │  cronômetro acumulado
///           │  ou ângulo inválido              da faixa     │  ≥ holdDuration
///  ┌─────────────────┐ ◀──────────────────────────          ▼
///  │  outOfPosition  │                             ┌─────────────────┐
///  └─────────────────┘    ângulo volta na faixa    │  repCompleted   │ (transitório)
///                         ─────────────────────▶  └────────┬────────┘
///                                                          │
///                                              reps == targetRepetitions
///                                                          ▼
///                                              ┌─────────────────────┐
///                                              │   sessionFinished   │
///                                              └─────────────────────┘
/// ```
///
/// - O cronômetro de hold **pausa** (sem zerar) quando o usuário sai da faixa.
/// - Quando o hold acumulado atinge `holdDuration`, a repetição é contabilizada e
///   o cronômetro é reiniciado para a próxima.
/// - Todas as atualizações de estado publicadas ocorrem na main queue.
final class ExerciseSessionController: ObservableObject {

    // MARK: - Fase da Sessão

    enum Phase: Equatable {
        /// Nenhuma pose detectada ou ângulo fora da faixa na abertura da sessão.
        case waitingForPosition
        /// Ângulo dentro da faixa — cronômetro de hold ativo.
        case holdingPosition
        /// Usuário saiu da faixa — cronômetro pausado, tempo acumulado preservado.
        case outOfPosition
        /// Sessão encerrada após `targetRepetitions` repetições completas.
        case sessionFinished
    }

    // MARK: - Estado Publicado

    /// Fase atual da sessão.
    @Published private(set) var phase: Phase = .waitingForPosition

    /// Número de repetições completas desde o início da sessão.
    @Published private(set) var repsCompleted: Int = 0

    /// Progresso do hold da repetição atual (0.0 = início, 1.0 = completo).
    @Published private(set) var holdProgress: Double = 0

    /// Tempo total decorrido desde `start()`, em segundos.
    @Published private(set) var sessionElapsedTime: TimeInterval = 0

    /// Percentual (0–100) do tempo total de sessão em que o usuário ficou na posição correta.
    @Published private(set) var withinRangePercentage: Double = 0

    /// Resultado da avaliação para cada `JointAngleRule` de `definition.targetJoints`,
    /// mapeados pelo mesmo índice. `nil` quando a articulação não está detectada.
    @Published private(set) var evaluations: [PoseAnalyzer.AngleEvaluation?] = []

    // MARK: - Configuração

    /// Definição do exercício sendo executado.
    let definition: StretchDefinition

    /// Número de repetições completas necessárias para encerrar a sessão.
    let targetRepetitions: Int

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

    // MARK: - Init

    /// - Parameters:
    ///   - definition: Exercício a ser executado.
    ///   - analyzer: `PoseAnalyzer` já conectado a um `CameraManager` ativo.
    ///   - targetRepetitions: Número de repetições para encerrar a sessão. Padrão: 3.
    ///   - onSessionFinished: Closure chamado ao finalizar a sessão com os dados de hold e precisão.
    init(
        definition: StretchDefinition,
        analyzer: PoseAnalyzer,
        targetRepetitions: Int = 3,
        onSessionFinished: ((_ holdDurationAchieved: TimeInterval, _ withinRangePercentage: Double) -> Void)? = nil
    ) {
        self.definition = definition
        self.analyzer = analyzer
        self.targetRepetitions = targetRepetitions
        self.onSessionFinished = onSessionFinished
        self.evaluations = Array(repeating: nil, count: definition.targetJoints.count)
    }

    // MARK: - Controle Público

    /// Inicia a sessão. Começa a observar o `PoseAnalyzer` e o timer de display.
    func start() {
        guard phase != .sessionFinished else { return }
        sessionStartDate = Date()

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
        let accuracy = sessionElapsedTime > 0 ? min((achieved / sessionElapsedTime) * 100, 100) : withinRangePercentage
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

    /// Chamado a cada frame. Avalia todas as regras da definição e transita entre fases.
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

        // Avalia todas as regras e publica os resultados individuais.
        let currentEvaluations = definition.targetJoints.map { rule in
            analyzer.evaluateAngle(rule: rule)
        }
        evaluations = currentEvaluations

        // "Em posição" = todas as regras com articulações detectadas e dentro da faixa.
        // Se alguma articulação não é detectada (nil), considera fora da posição.
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

    /// Atualiza valores de tempo e verifica conclusão de repetição.
    private func tick() {
        guard let sessionStart = sessionStartDate, phase != .sessionFinished else { return }

        let now = Date()

        // ── Tempo total de sessão ────────────────────────────────────────────────
        sessionElapsedTime = now.timeIntervalSince(sessionStart)

        // ── Progresso do hold atual ──────────────────────────────────────────────
        let currentHold = currentHoldTime(at: now)
        holdProgress = min(currentHold / definition.holdDuration, 1.0)

        // ── Percentual de precisão ───────────────────────────────────────────────
        // Soma o hold de reps finalizadas + hold em progresso atual.
        let totalInRange = holdTimeFromCompletedReps + currentHold
        if sessionElapsedTime > 0 {
            withinRangePercentage = min(totalInRange / sessionElapsedTime * 100, 100)
        }

        // ── Verificação de repetição completa ────────────────────────────────────
        if currentHold >= definition.holdDuration {
            completeCurrentRep(at: now)
        }
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
            let achieved = holdTimeFromCompletedReps
            let accuracy = withinRangePercentage
            onSessionFinished?(achieved, accuracy)
        }
    }
}
