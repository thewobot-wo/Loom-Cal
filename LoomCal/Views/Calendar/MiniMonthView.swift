import SwiftUI
import HorizonCalendar

/// Compact month calendar at the top of the main calendar screen.
/// Wraps HorizonCalendar's UIKit CalendarView in a UIViewRepresentable.
/// Tapping a day updates CalendarViewModel.selectedDate.
/// Long-pressing a day triggers onDateLongPress callback (wired to event creation in Plan 02).
struct MiniMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel

    /// Callback for long-press on a date — wired to event creation in Plan 02
    var onDateLongPress: ((Date) -> Void)?

    var body: some View {
        HorizonCalendarView(
            selectedDate: viewModel.selectedDate,
            eventsForDate: { date in
                !viewModel.timedEvents(for: date).isEmpty || !viewModel.allDayEvents(for: date).isEmpty
            },
            onDateSelected: { date in
                viewModel.selectedDate = date
            },
            onDateLongPress: onDateLongPress
        )
        .frame(height: 260)
        .background(Color(.systemBackground))
    }
}

// MARK: - HorizonCalendarView (UIViewRepresentable wrapper)

/// UIViewRepresentable wrapper for HorizonCalendar 1.x CalendarView.
/// HorizonCalendar 1.x uses UIKit's CalendarView; CalendarViewRepresentable is a 2.x API.
struct HorizonCalendarView: UIViewRepresentable {
    let selectedDate: Date
    let eventsForDate: (Date) -> Bool
    let onDateSelected: (Date) -> Void
    var onDateLongPress: ((Date) -> Void)?

    private var visibleDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: selectedDate)
        ) ?? Date()
        let threeMonthsLater = calendar.date(byAdding: .month, value: 3, to: monthStart) ?? Date()
        return monthStart...threeMonthsLater
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDateSelected: onDateSelected, onDateLongPress: onDateLongPress)
    }

    func makeUIView(context: Context) -> CalendarView {
        let content = makeContent()
        let calendarView = CalendarView(initialContent: content)
        calendarView.daySelectionHandler = { day in
            let calendar = Calendar.current
            if let date = calendar.date(from: day.components) {
                context.coordinator.onDateSelected(date)
            }
        }

        // Add long-press gesture for date selection
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        calendarView.addGestureRecognizer(longPress)
        context.coordinator.calendarView = calendarView
        context.coordinator.currentContent = content

        return calendarView
    }

    func updateUIView(_ calendarView: CalendarView, context: Context) {
        // Update content when selected date or events change
        let newContent = makeContent()
        calendarView.setContent(newContent)
        context.coordinator.currentContent = newContent
    }

    private func makeContent() -> CalendarViewContent {
        let calendar = Calendar.current
        let today = Date()

        return CalendarViewContent(
            calendar: calendar,
            visibleDateRange: visibleDateRange,
            monthsLayout: .horizontal(options: .init())
        )
        .dayItemProvider { day in
            let date = calendar.date(from: day.components) ?? Date()
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let hasEvents = eventsForDate(date)
            let isToday = calendar.isDateInToday(date)

            return CalendarItemModel<MiniDayCellView>(
                invariantViewProperties: .init(),
                viewModel: .init(
                    dayNumber: day.day,
                    isSelected: isSelected,
                    hasEvents: hasEvents,
                    isToday: isToday
                )
            )
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        let onDateSelected: (Date) -> Void
        let onDateLongPress: ((Date) -> Void)?
        weak var calendarView: CalendarView?
        var currentContent: CalendarViewContent?

        init(onDateSelected: @escaping (Date) -> Void, onDateLongPress: ((Date) -> Void)?) {
            self.onDateSelected = onDateSelected
            self.onDateLongPress = onDateLongPress
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let calView = calendarView,
                  let handler = onDateLongPress else { return }

            let location = gesture.location(in: calView)
            // Use the day under the long press location — approximate via hit test
            if let dayView = calView.hitTest(location, with: nil),
               let dayNumber = extractDayNumber(from: dayView) {
                let calendar = Calendar.current
                let today = Date()
                var components = calendar.dateComponents([.year, .month], from: today)
                components.day = dayNumber
                if let date = calendar.date(from: components) {
                    handler(date)
                }
            }
        }

        private func extractDayNumber(from view: UIView) -> Int? {
            // Walk up view hierarchy to find a label with a day number
            var current: UIView? = view
            while let v = current {
                if let label = v as? UILabel, let num = Int(label.text ?? "") {
                    return num
                }
                for subview in v.subviews {
                    if let label = subview as? UILabel, let num = Int(label.text ?? "") {
                        return num
                    }
                }
                current = v.superview
            }
            return nil
        }
    }
}

// MARK: - MiniDayCellView (UIView for CalendarItemModel)

/// A single day cell in the mini month grid.
/// Conforms to CalendarItemViewRepresentable (HorizonCalendar 1.x requirement).
final class MiniDayCellView: UIView, CalendarItemViewRepresentable {

    struct InvariantViewProperties: Hashable {
        // No invariant properties needed — cell content always updatable
    }

    struct ViewModel: Equatable {
        let dayNumber: Int
        let isSelected: Bool
        let hasEvents: Bool
        let isToday: Bool
    }

    private let circleView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 16
        return v
    }()

    private let numberLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        return l
    }()

    private let dotView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 2
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(circleView)
        circleView.addSubview(numberLabel)
        addSubview(dotView)

        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            circleView.widthAnchor.constraint(equalToConstant: 32),
            circleView.heightAnchor.constraint(equalToConstant: 32),

            numberLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            dotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotView.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 2),
            dotView.widthAnchor.constraint(equalToConstant: 4),
            dotView.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    static func makeView(withInvariantViewProperties invariantViewProperties: InvariantViewProperties) -> MiniDayCellView {
        MiniDayCellView()
    }

    static func setViewModel(_ viewModel: ViewModel, on view: MiniDayCellView) {
        view.numberLabel.text = "\(viewModel.dayNumber)"

        if viewModel.isSelected {
            view.circleView.backgroundColor = .systemBlue
            view.numberLabel.textColor = .white
            view.numberLabel.font = .systemFont(ofSize: 16, weight: .bold)
        } else if viewModel.isToday {
            view.circleView.backgroundColor = .clear
            view.numberLabel.textColor = .systemBlue
            view.numberLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        } else {
            view.circleView.backgroundColor = .clear
            view.numberLabel.textColor = .label
            view.numberLabel.font = .systemFont(ofSize: 16, weight: .regular)
        }

        view.dotView.isHidden = !viewModel.hasEvents
        view.dotView.backgroundColor = viewModel.isSelected ? .white.withAlphaComponent(0.8) : .systemBlue
    }
}

#Preview {
    MiniMonthView(viewModel: CalendarViewModel())
        .padding()
}
