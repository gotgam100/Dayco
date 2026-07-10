import SwiftData
import SwiftUI

struct DDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: DDayItem
    @State private var isPresentingEditor = false
    @State private var isConfirmingDelete = false

    private let calculator = DDayCalculator()

    var body: some View {
        let calculation = calculator.calculate(item: item)

        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(calculation.valueText)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)

                    Text(item.title)
                        .font(.title3.weight(.semibold))

                    Text(calculation.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }

            Section(DaycoText.t("계산 방식")) {
                LabeledContent(DaycoText.t("유형"), value: item.type.title)
                LabeledContent(DaycoText.t("표시 단위"), value: item.displayUnit.title)

                if item.type == .recurring {
                    LabeledContent(DaycoText.t("반복"), value: item.repeatRule?.title ?? RepeatRule.yearly.title)
                }

                if item.type == .milestone {
                    LabeledContent(DaycoText.t("기념일"), value: MilestoneDay.title(for: item.milestoneDayValue))
                }

                if item.type == .countUp {
                    LabeledContent(DaycoText.t("시작일 포함"), value: item.countStartAsDayOne ? DaycoText.t("켬") : DaycoText.t("끔"))
                }
            }

            Section(DaycoText.t("알림")) {
                if item.notificationRules.isEmpty {
                    Text(DaycoText.t("설정된 알림 없음"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.notificationRules) { rule in
                        Label(item.notificationTitle(for: rule), systemImage: "bell")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label(DaycoText.t("삭제"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(DaycoText.t("상세"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(DaycoText.t("편집")) {
                    isPresentingEditor = true
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            DDayEditorView(item: item)
        }
        .alert(DaycoText.t("삭제하시겠습니까?"), isPresented: $isConfirmingDelete) {
            Button(DaycoText.t("취소"), role: .cancel) {}
            Button(DaycoText.t("삭제"), role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        } message: {
            Text(DaycoText.t("이 디데이는 복구할 수 없습니다."))
        }
    }
}
