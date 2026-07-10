import AppIntents
import SwiftUI
import WidgetKit

struct DaycoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshots: [DaycoWidgetSnapshot]
    let language: DaycoWidgetLanguage
}

struct DaycoWidgetSelection: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "디데이")
    static let defaultQuery = DaycoWidgetSelectionQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct DaycoWidgetSelectionQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DaycoWidgetSelection] {
        selections().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DaycoWidgetSelection] {
        selections()
    }

    func defaultResult() async -> DaycoWidgetSelection? {
        selections().first
    }

    private func selections() -> [DaycoWidgetSelection] {
        DaycoWidgetSnapshotStore.loadSnapshots().map { snapshot in
            DaycoWidgetSelection(
                id: snapshot.id.uuidString,
                title: snapshot.title.isEmpty ? DaycoWidgetSnapshotStore.loadLanguage().text("이름 없는 디데이", "Untitled D-Day") : snapshot.title
            )
        }
    }
}

struct DaycoWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dayco 위젯"
    static let description = IntentDescription("위젯에 표시할 디데이를 선택합니다.")

    @Parameter(title: "디데이")
    var selectedDDay: DaycoWidgetSelection?
}

struct DaycoWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DaycoWidgetEntry {
        DaycoWidgetEntry(date: .now, snapshots: Self.previewSnapshots, language: DaycoWidgetSnapshotStore.loadLanguage())
    }

    func snapshot(for configuration: DaycoWidgetConfigurationIntent, in context: Context) async -> DaycoWidgetEntry {
        let snapshots = DaycoWidgetSnapshotStore.loadSnapshots()
        let language = DaycoWidgetSnapshotStore.loadLanguage()
        let selectedSnapshots = selectedSnapshots(from: snapshots, configuration: configuration)
        return DaycoWidgetEntry(date: .now, snapshots: selectedSnapshots.isEmpty ? Self.previewSnapshots : selectedSnapshots, language: language)
    }

    func timeline(for configuration: DaycoWidgetConfigurationIntent, in context: Context) async -> Timeline<DaycoWidgetEntry> {
        let snapshots = DaycoWidgetSnapshotStore.loadSnapshots()
        let entry = DaycoWidgetEntry(
            date: .now,
            snapshots: selectedSnapshots(from: snapshots, configuration: configuration),
            language: DaycoWidgetSnapshotStore.loadLanguage()
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func selectedSnapshots(
        from snapshots: [DaycoWidgetSnapshot],
        configuration: DaycoWidgetConfigurationIntent
    ) -> [DaycoWidgetSnapshot] {
        guard let selectedID = configuration.selectedDDay?.id else {
            return Array(snapshots.prefix(1))
        }

        if let selectedSnapshot = snapshots.first(where: { $0.id.uuidString == selectedID }) {
            return [selectedSnapshot]
        }

        return Array(snapshots.prefix(1))
    }

    static var previewSnapshots: [DaycoWidgetSnapshot] {
        [
            DaycoWidgetSnapshot(
                id: UUID(),
                title: "기념일",
                date: Calendar.current.date(byAdding: .day, value: 24, to: .now) ?? .now,
                typeRawValue: "countDown",
                repeatRuleRawValue: nil,
                milestoneDayRawValue: nil,
                countStartAsDayOne: false,
                displayUnitRawValue: "days",
                isPinned: true,
                isShared: false,
                cardColorRawValue: "yellow",
                sortIndex: 0,
                listRank: 0,
                updatedAt: .now
            ),
            DaycoWidgetSnapshot(
                id: UUID(),
                title: "프로젝트 시작",
                date: Calendar.current.date(byAdding: .day, value: -42, to: .now) ?? .now,
                typeRawValue: "countUp",
                repeatRuleRawValue: nil,
                milestoneDayRawValue: nil,
                countStartAsDayOne: true,
                displayUnitRawValue: "days",
                isPinned: false,
                isShared: true,
                cardColorRawValue: "blue",
                sortIndex: 1,
                listRank: 1,
                updatedAt: .now
            ),
        ]
    }
}

struct DaycoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DaycoWidgetEntry

    var body: some View {
        Group {
            if entry.snapshots.isEmpty {
                EmptyWidgetView(language: entry.language)
            } else {
                SingleCardWidgetView(snapshot: entry.snapshots[0], family: family, language: entry.language)
            }
        }
        .containerBackground(Color.clear, for: .widget)
    }
}

struct SingleCardWidgetView: View {
    let snapshot: DaycoWidgetSnapshot
    let family: WidgetFamily
    let language: DaycoWidgetLanguage

    var body: some View {
        let calculator = DaycoWidgetCalculator(language: language)
        let calculation = calculator.calculate(snapshot: snapshot)
        DDayWidgetCard(snapshot: snapshot, calculation: calculation, family: family, language: language)
    }
}

struct DDayWidgetCard: View {
    let snapshot: DaycoWidgetSnapshot
    let calculation: DaycoWidgetCalculation
    let family: WidgetFamily
    let language: DaycoWidgetLanguage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(cardColor)

            if calculation.dayDelta == 0 {
                Text("🎉")
                    .font(.system(size: isSmall ? 25 : 38))
                    .offset(x: isSmall ? -8 : -14, y: isSmall ? 8 : 12)
                    .opacity(0.88)
            }

            VStack(alignment: .leading, spacing: verticalSpacing) {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.isShared ? "person.2.fill" : "person.fill")
                        .font(.caption.weight(.bold))
                    Text(typeTitle)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if snapshot.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2.weight(.bold))
                    }
                }
                .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Text(snapshot.title.isEmpty ? language.text("이름 없는 디데이", "Untitled D-Day") : snapshot.title)
                    .font(titleFont)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(isSmall ? 2 : 1)
                    .minimumScaleFactor(0.78)

                Text(calculation.valueText)
                    .font(valueFont)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(calculation.caption)
                    .font(captionFont)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .padding(contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var typeTitle: String {
        switch snapshot.typeRawValue {
        case "countUp": language.text("지난 날짜", "Elapsed")
        case "recurring": language.text("반복", "Recurring")
        case "milestone": language.text("기념일", "Anniversary")
        default: language.text("남은 날짜", "Remaining")
        }
    }

    private var cardColor: Color {
        switch effectiveColorRawValue {
        case "blue", "green":
            Color(red: 0.00, green: 0.31, blue: 0.19)
        case "yellow":
            Color(red: 1.00, green: 0.44, blue: 0.25)
        case "pink", "darkYellow", "beige":
            Color(red: 0.95, green: 0.88, blue: 0.55)
        case "purple":
            Color(red: 0.72, green: 0.11, blue: 0.55)
        case "darkBlue":
            Color(red: 0.15, green: 0.09, blue: 0.89)
        case "red":
            Color(red: 0.83, green: 0.13, blue: 0.20)
        case "cyan":
            Color(red: 0.08, green: 0.74, blue: 0.76)
        case "lightGreen":
            Color(red: 0.73, green: 1.00, blue: 0.68)
        case "gray":
            Color(.secondarySystemGroupedBackground)
        default:
            defaultTypeColor
        }
    }

    private var effectiveColorRawValue: String {
        snapshot.cardColorRawValue ?? "typeDefault"
    }

    private var defaultTypeColor: Color {
        switch snapshot.typeRawValue {
        case "countUp":
            Color(red: 0.00, green: 0.31, blue: 0.19)
        case "recurring":
            Color(red: 0.15, green: 0.09, blue: 0.89)
        case "milestone":
            Color(red: 0.72, green: 0.11, blue: 0.55)
        default:
            Color(red: 1.00, green: 0.44, blue: 0.25)
        }
    }

    private var primaryTextColor: Color {
        switch effectiveColorRawValue {
        case "pink", "darkYellow", "cyan", "beige", "lightGreen", "gray":
            Color(red: 0.00, green: 0.31, blue: 0.19)
        default:
            .white
        }
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(usesDarkForeground ? 0.68 : 0.78)
    }

    private var isSmall: Bool {
        family == .systemSmall
    }

    private var verticalSpacing: CGFloat {
        switch family {
        case .systemSmall: 8
        case .systemMedium: 10
        default: 16
        }
    }

    private var contentPadding: EdgeInsets {
        switch family {
        case .systemSmall:
            EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        case .systemMedium:
            EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
        default:
            EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        }
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall: .headline.weight(.bold)
        case .systemMedium: .title3.weight(.bold)
        default: .title2.weight(.bold)
        }
    }

    private var valueFont: Font {
        switch family {
        case .systemSmall: .title.weight(.black)
        case .systemMedium: .system(size: 42, weight: .black)
        case .systemExtraLarge: .system(size: 72, weight: .black)
        default: .system(size: 58, weight: .black)
        }
    }

    private var captionFont: Font {
        switch family {
        case .systemSmall: .caption.weight(.semibold)
        default: .subheadline.weight(.semibold)
        }
    }

    private var usesDarkForeground: Bool {
        switch effectiveColorRawValue {
        case "pink", "darkYellow", "cyan", "beige", "lightGreen", "gray":
            true
        default:
            false
        }
    }
}

struct EmptyWidgetView: View {
    let language: DaycoWidgetLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dayco")
                .font(.headline.weight(.black))
            Text(language.text("디데이를 추가하면\n여기에 표시돼요", "Add a D-Day\nto see it here"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 1.00, green: 0.44, blue: 0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemGroupedBackground))
    }
}

@main
struct DaycoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: DaycoWidgetConstants.kind,
            intent: DaycoWidgetConfigurationIntent.self,
            provider: DaycoWidgetProvider()
        ) { entry in
            DaycoWidgetView(entry: entry)
        }
        .configurationDisplayName("Dayco")
        .description("중요한 디데이를 카드로 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    DaycoWidget()
} timeline: {
    DaycoWidgetEntry(date: .now, snapshots: DaycoWidgetProvider.previewSnapshots, language: .korean)
}
