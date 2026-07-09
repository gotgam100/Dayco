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

            Section("계산 방식") {
                LabeledContent("유형", value: item.type.title)
                LabeledContent("표시 단위", value: item.displayUnit.title)

                if item.type == .recurring {
                    LabeledContent("반복", value: item.repeatRule?.title ?? RepeatRule.yearly.title)
                }

                if item.type == .countUp {
                    LabeledContent("시작일 포함", value: item.countStartAsDayOne ? "켬" : "끔")
                }
            }

            Section("알림") {
                if item.notificationRules.isEmpty {
                    Text("설정된 알림 없음")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.notificationRules) { rule in
                        Label(item.notificationTitle(for: rule), systemImage: "bell")
                    }
                }
            }

            Section("공유") {
                LabeledContent("상태", value: item.isShared ? "공유 중" : "개인 디데이")
                if let permission = item.sharePermission {
                    LabeledContent("권한", value: permission.title)
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .navigationTitle("상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("편집") {
                    isPresentingEditor = true
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            DDayEditorView(item: item)
        }
        .alert("삭제하시겠습니까?", isPresented: $isConfirmingDelete) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        } message: {
            Text("이 디데이는 복구할 수 없습니다.")
        }
    }
}
