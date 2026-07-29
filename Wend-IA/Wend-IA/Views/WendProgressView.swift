import SwiftData
import SwiftUI

/// Aba "Progress" — evolução do usuário: streak em destaque, calendário do
/// mês com os dias em que houve sessão, e as atividades mais recentes.
///
/// Nomeada `WendProgressView` (não `ProgressView`) para não colidir com o
/// tipo nativo do SwiftUI.
struct WendProgressView: View {

    // MARK: - SwiftData

    @Query(sort: \SessionRecord.date, order: .reverse)
    private var allRecords: [SessionRecord]

    // MARK: - State Local

    /// Qualquer dia dentro do mês atualmente exibido no calendário.
    @State private var displayedMonthAnchor: Date = Date()

    private let calendar = Calendar.current

    // MARK: - Dados Derivados

    private var streakDays: Int {
        SessionStore(records: allRecords).streakDays
    }

    /// Dias (início do dia, timezone local) com pelo menos uma sessão registrada.
    private var sessionDays: Set<Date> {
        Set(allRecords.map { calendar.startOfDay(for: $0.date) })
    }

    private var recentRecords: [SessionRecord] {
        Array(allRecords.prefix(8))
    }

    // MARK: - Body

    var body: some View {
        BlurTopScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection
                streakHeroCard
                calendarCard
                recentActivitySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        // Estrutura idêntica a `HeaderView` (aba Exercise): ícone 26pt +
        // título 26pt bold rounded + subtítulo — mesmo ícone acima do título
        // é o que garante a mesma posição vertical do texto "Good Morning".
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(WendTheme.Colors.greenDark)
                .accessibilityLabel("Progress icon")

            Text("Your Progress")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(WendTheme.Colors.coffee)

            Text("Track your consistency and journey.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Streak Hero Card

    private var streakHeroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(WendTheme.Colors.greenLight)
                    .frame(width: 64, height: 64)
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.greenBasic)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakDays)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(WendTheme.Colors.coffee)
                    + Text(streakDays == 1 ? " day streak" : " day streak")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))

                Text(streakDays > 0 ? "Keep it going — every day counts." : "Complete an exercise to start your streak.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.55))
            }

            Spacer()
        }
        .padding(20)
        .background(
            ZStack {
                WendTheme.Colors.creamLight
                GeometryReader { geo in
                    RadialGradient(
                        colors: [WendTheme.Colors.greenLight.opacity(0.5), Color.clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: geo.size.width * 0.7
                    )
                    .blur(radius: 40)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            monthNavigationHeader
            weekdayHeaderRow
            calendarGrid
        }
        .padding(20)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var monthNavigationHeader: some View {
        HStack {
            Text(monthTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)

            Spacer()

            HStack(spacing: 8) {
                monthNavButton(systemName: "chevron.left") {
                    shiftMonth(by: -1)
                }
                monthNavButton(systemName: "chevron.right") {
                    shiftMonth(by: 1)
                }
            }
        }
    }

    private func monthNavButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(WendTheme.Colors.greenDark)
                .frame(width: 30, height: 30)
                .background(WendTheme.Colors.greenLight)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = daysInDisplayedMonth
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let startOfDay = calendar.startOfDay(for: day)
        let hasSession = sessionDays.contains(startOfDay)
        let isToday = calendar.isDateInToday(day)

        return Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 13, weight: hasSession ? .bold : .medium))
            .foregroundColor(hasSession ? WendTheme.Colors.creamLight : WendTheme.Colors.coffee.opacity(0.75))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(hasSession ? WendTheme.Colors.greenBasic : Color.clear)
            )
            .overlay(
                Circle()
                    .stroke(isToday ? WendTheme.Colors.greenDark : Color.clear, lineWidth: 1.5)
            )
            .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)

            if recentRecords.isEmpty {
                emptyActivityView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentRecords.enumerated()), id: \.element.persistentModelID) { index, record in
                        activityRow(for: record)

                        if index < recentRecords.count - 1 {
                            Divider()
                                .background(WendTheme.Colors.coffee.opacity(0.1))
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(WendTheme.Colors.creamLight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private func activityRow(for record: SessionRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(WendTheme.Colors.greenLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(WendTheme.Colors.greenBasic)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseName(for: record.exerciseID))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee)
                Text(formattedDate(record.date))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
            }

            Spacer()

            Text("\(Int(record.withinRangePercentage.rounded()))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(WendTheme.Colors.greenBasic)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WendTheme.Colors.greenLight)
                .clipShape(Capsule())
        }
        .padding(.vertical, 10)
    }

    private var emptyActivityView: some View {
        VStack(spacing: 6) {
            Text("No sessions yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
            Text("Complete an exercise to see it here.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Helpers

    private func exerciseName(for exerciseID: String) -> String {
        StretchDefinition.sampleStretches.first(where: { $0.id == exerciseID })?.name ?? exerciseID
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonthAnchor)
    }

    private func shiftMonth(by value: Int) {
        guard let newAnchor = calendar.date(byAdding: .month, value: value, to: displayedMonthAnchor) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonthAnchor = newAnchor
        }
    }

    /// Símbolos de dia da semana (Sun, Mon...) reordenados a partir de `calendar.firstWeekday`.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    /// Dias do mês exibido, com `nil` para células vazias de preenchimento
    /// (antes do dia 1 e depois do último dia, pra completar as semanas da grade).
    private var daysInDisplayedMonth: [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthAnchor),
            let dayRange = calendar.range(of: .day, in: .month, for: displayedMonthAnchor)
        else { return [] }

        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmptyRaw = firstWeekday - calendar.firstWeekday
        let leadingEmpty = leadingEmptyRaw >= 0 ? leadingEmptyRaw : leadingEmptyRaw + 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for offset in dayRange {
            if let date = calendar.date(byAdding: .day, value: offset - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }
}

// MARK: - Preview

#Preview {
    WendProgressView()
        .background(WendTheme.Colors.creamBasic)
        .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
