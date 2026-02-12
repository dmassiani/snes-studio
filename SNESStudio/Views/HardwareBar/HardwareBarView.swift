import SwiftUI

struct HardwareBarView: View {
    let meters: [BudgetMeter]

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 6)
    ]

    var body: some View {
        VStack(spacing: 0) {
            SNESTheme.border.frame(height: 1)

            VStack(alignment: .leading, spacing: 4) {
                // Compact header
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 9))
                        .foregroundStyle(SNESTheme.success)
                    Text("HARDWARE BUDGET")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(SNESTheme.textDisabled)
                }

                // Meters grid
                LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                    ForEach(meters) { meter in
                        BudgetMeterView(meter: meter)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SNESTheme.bgPanel)
        }
    }
}

// MARK: - Budget Meter

struct BudgetMeterView: View {
    let meter: BudgetMeter

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text(meter.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)

                Spacer(minLength: 4)

                Text("\(Int(meter.percentage))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(meter.barColor)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SNESTheme.bgMain)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(meter.barColor)
                        .frame(width: geo.size.width * min(meter.percentage / 100, 1.0))
                        .animation(.easeInOut(duration: 0.3), value: meter.percentage)
                }
            }
            .frame(height: 4)

            Text(meter.formattedValue)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(SNESTheme.textDisabled)
        }
    }
}
