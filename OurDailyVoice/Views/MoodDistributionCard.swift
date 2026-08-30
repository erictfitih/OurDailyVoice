import SwiftUI

struct MoodDistributionCard: View {
    let title: String
    let subtitle: String
    let values: [Int]

    private var counts: [Int: Int] {
        Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
    }

    private var maximumCount: Int {
        counts.values.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Text("\(values.count) total")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            ForEach(MoodPalette.options) { option in
                let count = counts[option.value, default: 0]

                HStack(spacing: 10) {
                    Text(option.emoji)
                        .font(.title2)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(option.value) • \(option.label)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12))
                                Capsule()
                                    .fill(.white.opacity(0.74))
                                    .frame(width: barWidth(count: count, available: geometry.size.width))
                            }
                        }
                        .frame(height: 10)
                    }

                    Text("\(count)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(Theme.cardOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func barWidth(count: Int, available: CGFloat) -> CGFloat {
        guard maximumCount > 0 else { return 0 }
        return available * CGFloat(count) / CGFloat(maximumCount)
    }
}
