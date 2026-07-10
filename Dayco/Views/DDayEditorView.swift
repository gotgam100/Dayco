import SwiftData
import SwiftUI

struct DDayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let item: DDayItem?
    @State private var title: String
    @State private var date: Date
    @State private var type: DDayType
    @State private var repeatRule: RepeatRule
    @State private var milestoneSelection: Int
    @State private var customMilestoneDay: Int
    @State private var countStartAsDayOne: Bool
    @State private var displayUnit: DisplayUnit
    @State private var notificationRules: [NotificationRule]
    @State private var notificationDate: Date
    @State private var isComposingNotification = false
    @State private var isPinned: Bool
    @State private var cardColor: DDayCardColor
    @State private var isConfirmingDelete = false
    @State private var isShowingInvalidPastDateAlert = false
    @State private var isDeleting = false

    init(item: DDayItem? = nil) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _date = State(initialValue: item?.date ?? .now)
        _type = State(initialValue: item?.type ?? .countDown)
        _repeatRule = State(initialValue: item?.repeatRule ?? .yearly)
        let initialMilestoneDay = item?.milestoneDayValue ?? MilestoneDay.day100.rawValue
        _milestoneSelection = State(initialValue: MilestoneDay(rawValue: initialMilestoneDay) == nil ? 0 : initialMilestoneDay)
        _customMilestoneDay = State(initialValue: initialMilestoneDay)
        _countStartAsDayOne = State(initialValue: item?.countStartAsDayOne ?? false)
        _displayUnit = State(initialValue: item?.displayUnit ?? .days)
        _notificationRules = State(initialValue: item?.notificationRules ?? [])
        _notificationDate = State(initialValue: Self.defaultNotificationDate(
            eventDate: item?.date ?? .now,
            type: item?.type ?? .countDown,
            repeatRule: item?.repeatRule ?? .yearly,
            countStartAsDayOne: item?.countStartAsDayOne ?? false,
            milestoneDay: initialMilestoneDay
        ))
        _isPinned = State(initialValue: item?.isPinned ?? false)
        _cardColor = State(initialValue: item?.cardColor ?? .typeDefault)
    }

    var body: some View {
        NavigationStack {
            AnyView(editorForm)
            .navigationTitle(item == nil ? DaycoText.t("디데이 추가") : DaycoText.t("디데이 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(item == nil ? DaycoText.t("취소") : DaycoText.t("닫기")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(DaycoText.t("저장")) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: type) { _, newValue in
                if newValue != .recurring {
                    repeatRule = .yearly
                }
                if !availableDisplayUnits.contains(displayUnit) {
                    displayUnit = availableDisplayUnits.first ?? .days
                }
                notificationDate = Self.defaultNotificationDate(
                    eventDate: date,
                    type: newValue,
                    repeatRule: repeatRule,
                    countStartAsDayOne: countStartAsDayOne,
                    milestoneDay: effectiveMilestoneDay
                )
                autosaveExistingItem()
            }
            .onChange(of: date) { _, newValue in
                notificationDate = Self.defaultNotificationDate(
                    eventDate: newValue,
                    type: type,
                    repeatRule: repeatRule,
                    countStartAsDayOne: countStartAsDayOne,
                    milestoneDay: effectiveMilestoneDay
                )
                autosaveExistingItem()
            }
            .onChange(of: repeatRule) { _, newValue in
                notificationDate = Self.defaultNotificationDate(
                    eventDate: date,
                    type: type,
                    repeatRule: newValue,
                    countStartAsDayOne: countStartAsDayOne,
                    milestoneDay: effectiveMilestoneDay
                )
                autosaveExistingItem()
            }
            .onChange(of: milestoneSelection) { _, newValue in
                notificationDate = Self.defaultNotificationDate(
                    eventDate: date,
                    type: type,
                    repeatRule: repeatRule,
                    countStartAsDayOne: countStartAsDayOne,
                    milestoneDay: newValue == 0 ? customMilestoneDay : newValue
                )
                autosaveExistingItem()
            }
            .onChange(of: customMilestoneDay) { _, newValue in
                guard milestoneSelection == 0 else { return }
                notificationDate = Self.defaultNotificationDate(
                    eventDate: date,
                    type: type,
                    repeatRule: repeatRule,
                    countStartAsDayOne: countStartAsDayOne,
                    milestoneDay: newValue
                )
                autosaveExistingItem()
            }
            .onChange(of: countStartAsDayOne) { _, newValue in
                notificationDate = Self.defaultNotificationDate(
                    eventDate: date,
                    type: type,
                    repeatRule: repeatRule,
                    countStartAsDayOne: newValue,
                    milestoneDay: effectiveMilestoneDay
                )
                autosaveExistingItem()
            }
            .onChange(of: autosaveSignature) { _, _ in
                autosaveExistingItem()
            }
            .onDisappear {
                autosaveExistingItem()
            }
            .alert(DaycoText.t("삭제하시겠습니까?"), isPresented: $isConfirmingDelete) {
                Button(DaycoText.t("취소"), role: .cancel) {}
                Button(DaycoText.t("삭제"), role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text(DaycoText.t("이 디데이는 복구할 수 없습니다."))
            }
            .alert(DaycoText.t("지난 날짜를 선택해 주세요"), isPresented: $isShowingInvalidPastDateAlert) {
                Button(DaycoText.t("확인"), role: .cancel) {}
            } message: {
                Text(DaycoText.t("디데이 유형이 지난 날짜일 때는 오늘보다 과거인 날짜로 설정해야 합니다."))
            }
        }
    }

    private var editorForm: some View {
        Form {
            basicSection
            typeSection
            calculationSection
            notificationSection
            deleteSection
        }
    }

    private var basicSection: some View {
        Section(DaycoText.t("기본")) {
            TextField(DaycoText.t("제목"), text: $title)
            DatePicker(DaycoText.t("날짜"), selection: $date, displayedComponents: .date)
            Toggle(DaycoText.t("상단에 고정"), isOn: $isPinned)
        }
    }

    private var typeSection: some View {
        Section(DaycoText.t("유형")) {
            HStack {
                Text(DaycoText.t("디데이 유형"))

                Spacer()

                Menu {
                    ForEach(DDayType.allCases) { type in
                        Button {
                            self.type = type
                        } label: {
                            Label(type.title, systemImage: type.symbolName)
                        }
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: type.symbolName)
                            .frame(width: 22)
                            .foregroundStyle(.primary)

                        Text(type.title)
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            }

            if type == .recurring {
                Picker(DaycoText.t("반복"), selection: $repeatRule) {
                    ForEach(RepeatRule.allCases) { rule in
                        Text(rule.title).tag(rule)
                    }
                }
            }

            milestonePicker

            colorPickerRow
        }
    }

    @ViewBuilder
    private var milestonePicker: some View {
        if type == .milestone {
            Picker(DaycoText.t("기념일"), selection: $milestoneSelection) {
                ForEach(MilestoneDay.allCases) { day in
                    Text(day.title).tag(day.rawValue)
                }
                Text(DaycoText.t("직접 입력")).tag(0)
            }

            if milestoneSelection == 0 {
                HStack {
                    Text(DaycoText.t("직접 입력"))

                    Spacer()

                    TextField(DaycoText.t("일수"), value: $customMilestoneDay, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)

                    Text(DaycoText.t("일"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var colorPickerRow: some View {
        HStack(spacing: 16) {
            Text(DaycoText.t("색상"))
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableCardColors) { color in
                        Button {
                            cardColor = color
                        } label: {
                            ZStack {
                                color.previewSwatch(for: type)
                                    .frame(width: 26, height: 26)

                                if cardColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(color.checkmarkColor(for: type))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.title)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: 230, alignment: .trailing)
        }
    }

    private var calculationSection: some View {
        Section(DaycoText.t("계산 옵션")) {
            Picker(DaycoText.t("표시 단위"), selection: $displayUnit) {
                ForEach(availableDisplayUnits) { unit in
                    Text(unit.title).tag(unit)
                }
            }

            if type == .countUp {
                Toggle(DaycoText.t("시작일을 1일로 계산"), isOn: $countStartAsDayOne)
            }

            if type == .milestone {
                Toggle(DaycoText.t("시작일을 1일로 계산"), isOn: $countStartAsDayOne)
            }
        }
    }

    private var notificationSection: some View {
        Section {
            notificationComposer
            notificationList
        } header: {
            Text(DaycoText.t("알림"))
        } footer: {
            Text(notificationFooterText)
        }
    }

    @ViewBuilder
    private var notificationComposer: some View {
        if isComposingNotification {
            DatePicker(
                DaycoText.t("알림 날짜"),
                selection: $notificationDate,
                in: Date.now...,
                displayedComponents: .date
            )

            DatePicker(
                DaycoText.t("알림 시간"),
                selection: $notificationDate,
                in: Date.now...,
                displayedComponents: .hourAndMinute
            )

            LabeledContent(DaycoText.t("설정한 알림"), value: notificationDateText(for: notificationDate))

            HStack {
                Text(notificationOffsetText(for: notificationDate))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(DaycoText.t("취소")) {
                    isComposingNotification = false
                }

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 2)

                Button(DaycoText.t("완료")) {
                    addNotificationRule()
                }
                .disabled(parsedNotificationRule == nil)
            }
        } else {
            Button {
                notificationDate = Self.defaultNotificationDate(
                    eventDate: date,
                    type: type,
                    repeatRule: repeatRule,
                    countStartAsDayOne: countStartAsDayOne,
                    milestoneDay: effectiveMilestoneDay
                )
                isComposingNotification = true
            } label: {
                Label(DaycoText.t("추가"), systemImage: "plus.circle.fill")
            }
        }
    }

    @ViewBuilder
    private var notificationList: some View {
        if notificationRules.isEmpty {
            Text(DaycoText.t("설정된 알림 없음"))
                .foregroundStyle(.secondary)
        } else {
            ForEach(notificationRules) { rule in
                notificationRuleRow(rule)
            }
        }
    }

    private func notificationRuleRow(_ rule: NotificationRule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell")
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(notificationDateText(for: rule))
                    .foregroundStyle(.primary)
                Text(notificationTitle(for: rule))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                deleteNotificationRule(rule)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(DaycoText.t("알림 삭제"))
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if item != nil {
            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label(DaycoText.t("삭제"), systemImage: "trash")
                }
            }
        }
    }

    private func save() {
        guard isValidDateForSelectedType else {
            isShowingInvalidPastDateAlert = true
            return
        }

        guard persistChanges(allowInsert: true) else { return }
        dismiss()
    }

    private func autosaveExistingItem() {
        guard item != nil, !isDeleting else { return }
        _ = persistChanges(allowInsert: false)
    }

    @discardableResult
    private func persistChanges(allowInsert: Bool) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, isValidDateForSelectedType else {
            return false
        }

        let sortedNotificationRules = notificationRules.uniqued().sorted {
            if $0.day != $1.day {
                return $0.day < $1.day
            }
            if $0.hour != $1.hour {
                return $0.hour < $1.hour
            }
            return $0.minute < $1.minute
        }
        let safeDisplayUnit = availableDisplayUnits.contains(displayUnit) ? displayUnit : .days

        let savedItem: DDayItem

        if let item {
            item.title = trimmedTitle
            item.date = date
            item.type = type
            item.repeatRule = type == .recurring ? repeatRule : nil
            item.milestoneDayRawValue = type == .milestone ? effectiveMilestoneDay : nil
            item.countStartAsDayOne = countStartAsDayOne
            item.displayUnit = safeDisplayUnit
            item.notificationRules = sortedNotificationRules
            item.isPinned = isPinned
            item.isShared = false
            item.sharePermission = nil
            item.cardColor = cardColor
            item.updatedAt = .now
            savedItem = item
        } else {
            guard allowInsert else { return false }
            let newItem = DDayItem(
                title: trimmedTitle,
                date: date,
                type: type,
                repeatRule: type == .recurring ? repeatRule : nil,
                customMilestoneDay: type == .milestone ? effectiveMilestoneDay : nil,
                countStartAsDayOne: countStartAsDayOne,
                displayUnit: safeDisplayUnit,
                notificationDays: [],
                isPinned: isPinned,
                isShared: false,
                sharePermission: nil,
                cardColor: cardColor
            )
            newItem.notificationRules = sortedNotificationRules
            modelContext.insert(newItem)
            savedItem = newItem
        }

        try? modelContext.save()
        Task { @MainActor in
            await NotificationScheduler().rescheduleNotifications(for: savedItem)
        }
        return true
    }

    private var availableDisplayUnits: [DisplayUnit] {
        switch type {
        case .recurring, .milestone:
            return [.days]
        case .countUp, .countDown:
            return DisplayUnit.allCases
        }
    }

    private var availableCardColors: [DDayCardColor] {
        DDayCardColor.allCases.filter { color in
            color != .typeDefault && color != .green && color != .pink && color != .beige
        }
    }

    private var autosaveSignature: String {
        [
            title,
            type.rawValue,
            repeatRule.rawValue,
            milestoneSelection.formatted(),
            customMilestoneDay.formatted(),
            displayUnit.rawValue,
            notificationRules.map(\.rawValue).joined(separator: ","),
            "\(isPinned)",
            cardColor.rawValue
        ].joined(separator: "|")
    }

    private var effectiveMilestoneDay: Int {
        max(milestoneSelection == 0 ? customMilestoneDay : milestoneSelection, 1)
    }

    private var isValidDateForSelectedType: Bool {
        guard type == .countUp else { return true }
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: .now)
    }

    private var parsedNotificationRule: NotificationRule? {
        let calendar = Calendar.current
        guard notificationDate >= Date.now else { return nil }

        let selectedDay = calendar.startOfDay(for: notificationDate)
        let selectedTime = calendar.dateComponents([.hour, .minute], from: notificationDate)
        let hour = selectedTime.hour ?? 9
        let minute = selectedTime.minute ?? 0
        let day: Int

        switch type {
        case .countUp:
            let baseDay = calendar.startOfDay(for: date)
            guard selectedDay >= baseDay else { return nil }
            let offset = calendar.dateComponents([.day], from: baseDay, to: selectedDay).day ?? 0
            day = offset + (countStartAsDayOne ? 1 : 0)
        case .countDown, .recurring, .milestone:
            let targetDay = calendar.startOfDay(for: notificationTargetDate)
            guard selectedDay <= targetDay else { return nil }
            day = calendar.dateComponents([.day], from: selectedDay, to: targetDay).day ?? 0
        }

        let rule = NotificationRule(day: day, hour: hour, minute: minute)
        return notificationRules.contains(rule) ? nil : rule
    }

    private var notificationFooterText: String {
        switch type {
        case .countUp:
            DaycoText.t("달력에서 고른 날짜와 시간에 알림이 옵니다.\n시작일보다 이전 날짜는 추가할 수 없습니다.")
        case .countDown, .recurring, .milestone:
            DaycoText.t("달력에서 고른 날짜와 시간에 알림이 옵니다.\n디데이 이후 날짜는 추가할 수 없습니다.")
        }
    }

    private func notificationTitle(for rule: NotificationRule) -> String {
        let timeText = DaycoText.language == .english
            ? String(format: "%02d:%02d", rule.hour, rule.minute)
            : (rule.minute == 0 ? "\(rule.hour)시" : "\(rule.hour)시 \(rule.minute)분")
        switch type {
        case .countUp:
            return DaycoText.language == .english ? "Day \(rule.day) \(timeText)" : "\(rule.day)일째 \(timeText)"
        case .countDown, .recurring, .milestone:
            if DaycoText.language == .english {
                return rule.day == 0 ? "Same day \(timeText)" : "\(rule.day) days before \(timeText)"
            }
            return rule.day == 0 ? "\(DaycoText.t("당일")) \(timeText)" : "\(rule.day)일 전 \(timeText)"
        }
    }

    private func addNotificationRule() {
        guard let rule = parsedNotificationRule else { return }
        notificationRules.append(rule)
        notificationRules = notificationRules.uniqued().sorted {
            if $0.day != $1.day {
                return $0.day < $1.day
            }
            if $0.hour != $1.hour {
                return $0.hour < $1.hour
            }
            return $0.minute < $1.minute
        }
        isComposingNotification = false
    }

    private func deleteNotificationRule(_ rule: NotificationRule) {
        notificationRules.removeAll { $0 == rule }
    }

    private var notificationTargetDate: Date {
        switch type {
        case .countUp, .countDown:
            return date
        case .recurring:
            return Self.resolvedRecurringDate(from: date, repeatRule: repeatRule)
        case .milestone:
            return Self.resolvedMilestoneDate(from: date, milestoneDay: effectiveMilestoneDay, countStartAsDayOne: countStartAsDayOne)
        }
    }

    private func notificationTriggerDate(for rule: NotificationRule) -> Date {
        let calendar = Calendar.current
        let baseDay: Date
        let offset: Int

        switch type {
        case .countUp:
            baseDay = calendar.startOfDay(for: date)
            offset = max(rule.day - (countStartAsDayOne ? 1 : 0), 0)
        case .countDown:
            baseDay = calendar.startOfDay(for: date)
            offset = -rule.day
        case .recurring:
            baseDay = calendar.startOfDay(for: notificationTargetDate)
            offset = -rule.day
        case .milestone:
            baseDay = calendar.startOfDay(for: notificationTargetDate)
            offset = -rule.day
        }

        let day = calendar.date(byAdding: .day, value: offset, to: baseDay) ?? baseDay
        return calendar.date(bySettingHour: rule.hour, minute: rule.minute, second: 0, of: day) ?? day
    }

    private func notificationDateText(for rule: NotificationRule) -> String {
        notificationDateText(for: notificationTriggerDate(for: rule))
    }

    private func notificationDateText(for date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: DaycoText.language.localeIdentifier)))
    }

    private func notificationOffsetText(for date: Date) -> String {
        guard let rule = parsedNotificationRule else {
            switch type {
            case .countUp:
                return DaycoText.t("시작일 이후 날짜를 선택해 주세요")
            case .countDown, .recurring, .milestone:
                return DaycoText.t("디데이 이전 또는 당일을 선택해 주세요")
            }
        }
        return notificationTitle(for: rule)
    }

    private static func defaultNotificationDate(
        eventDate: Date,
        type: DDayType,
        repeatRule: RepeatRule,
        countStartAsDayOne: Bool,
        milestoneDay: Int
    ) -> Date {
        let calendar = Calendar.current
        let baseDate: Date
        switch type {
        case .recurring:
            baseDate = resolvedRecurringDate(from: eventDate, repeatRule: repeatRule)
        case .milestone:
            baseDate = resolvedMilestoneDate(from: eventDate, milestoneDay: milestoneDay, countStartAsDayOne: countStartAsDayOne)
        case .countUp, .countDown:
            baseDate = eventDate
        }
        let startOfDay = calendar.startOfDay(for: baseDate)
        let preferredDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay) ?? startOfDay
        return preferredDate < Date.now ? Date.now : preferredDate
    }

    private static func resolvedMilestoneDate(from date: Date, milestoneDay: Int, countStartAsDayOne: Bool) -> Date {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let offset = max(milestoneDay, 1) - (countStartAsDayOne ? 1 : 0)
        return calendar.date(byAdding: .day, value: max(offset, 0), to: startDate) ?? startDate
    }

    private static func resolvedRecurringDate(from date: Date, repeatRule: RepeatRule) -> Date {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: .now)

        switch repeatRule {
        case .yearly:
            let sourceComponents = calendar.dateComponents([.month, .day], from: date)
            let currentYear = calendar.component(.year, from: now)
            var components = DateComponents()
            components.year = currentYear
            components.month = sourceComponents.month
            components.day = sourceComponents.day
            let candidate = calendar.date(from: components) ?? date
            if calendar.startOfDay(for: candidate) >= now {
                return candidate
            }
            components.year = currentYear + 1
            return calendar.date(from: components) ?? candidate
        case .monthly:
            let sourceDay = calendar.component(.day, from: date)
            let nowComponents = calendar.dateComponents([.year, .month], from: now)
            let candidate = clampedDate(year: nowComponents.year, month: nowComponents.month, day: sourceDay) ?? date
            if calendar.startOfDay(for: candidate) >= now {
                return candidate
            }
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            let nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
            return clampedDate(year: nextComponents.year, month: nextComponents.month, day: sourceDay) ?? candidate
        }
    }

    private static func clampedDate(year: Int?, month: Int?, day: Int) -> Date? {
        let calendar = Calendar.current
        guard let year, let month else { return nil }
        let monthDate = calendar.date(from: DateComponents(year: year, month: month)) ?? .now
        let range = calendar.range(of: .day, in: .month, for: monthDate)
        return calendar.date(from: DateComponents(year: year, month: month, day: min(day, range?.count ?? day)))
    }

    private func deleteItem() {
        guard let item else { return }
        isDeleting = true
        Task { @MainActor in
            await NotificationScheduler().removeNotifications(for: item)
        }
        modelContext.delete(item)
        dismiss()
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension DDayCardColor {
    @ViewBuilder
    func previewSwatch(for type: DDayType) -> some View {
        switch self {
        case .typeDefault:
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            DaycoPalette.deepGreen,
                            DaycoPalette.calendarOrange,
                            DaycoPalette.magenta,
                            DaycoPalette.vividBlue,
                            DaycoPalette.red,
                            DaycoPalette.cyan,
                            DaycoPalette.lightGreen,
                            DaycoPalette.deepGreen
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
        default:
            Circle().fill(previewColor(for: type))
        }
    }

    private func previewColor(for type: DDayType) -> Color {
        switch self {
        case .typeDefault:
            return type.defaultCardColor
        case .blue:
            return DaycoPalette.deepGreen
        case .green:
            return DaycoPalette.deepGreen
        case .yellow:
            return DaycoPalette.calendarOrange
        case .pink:
            return DaycoPalette.paleYellow
        case .purple:
            return DaycoPalette.magenta
        case .darkYellow:
            return DaycoPalette.paleYellow
        case .darkBlue:
            return DaycoPalette.vividBlue
        case .red:
            return DaycoPalette.red
        case .cyan:
            return DaycoPalette.cyan
        case .beige:
            return DaycoPalette.paleYellow
        case .lightGreen:
            return DaycoPalette.lightGreen
        case .gray:
            return .gray
        }
    }

    func checkmarkColor(for type: DDayType) -> Color {
        switch self {
        case .pink, .darkYellow, .cyan, .beige, .lightGreen:
            return DaycoPalette.deepGreen
        case .typeDefault:
            return type == .countDown ? .white : DaycoPalette.deepGreen
        default:
            return .white
        }
    }
}

private extension DDayType {
    var defaultCardColor: Color {
        switch self {
        case .countUp:
            return DaycoPalette.deepGreen
        case .countDown:
            return DaycoPalette.calendarOrange
        case .recurring:
            return DaycoPalette.vividBlue
        case .milestone:
            return DaycoPalette.magenta
        }
    }
}
