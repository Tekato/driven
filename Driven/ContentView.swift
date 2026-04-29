import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @State private var showingDriveSession = false

    var body: some View {
        TabView {
            HomeView {
                showingDriveSession = true
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(.drivenBlue)
        .fullScreenCover(isPresented: $showingDriveSession) {
            DriveSessionView { showingDriveSession = false }
        }
    }
}

struct HomeView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @State private var displayedMonth = Date()
    let onStartDrive: () -> Void

    private var tripDays: Set<Date> {
        Set(trips.map { Calendar.current.startOfDay(for: $0.startDate) })
    }

    private var totalDistanceKm: Double {
        trips.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    private var totalDuration: TimeInterval {
        trips.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    monthHeader
                    calendar
                    homeInsightCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(appBackground)
            .safeAreaInset(edge: .bottom) {
                startButton
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(Color.black.opacity(0.18))
            }
            .navigationTitle("Driven")
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
            Spacer()

            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var calendar: some View {
        let days = Calendar.current.daysForMonthGrid(containing: displayedMonth)
        let weekSymbols = Calendar.current.shortStandaloneWeekdaySymbols

        return VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekSymbols, id: \.self) { day in
                    Text(day.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    DayCell(
                        dayNumber: Calendar.current.component(.day, from: date),
                        hasDrive: tripDays.contains(Calendar.current.startOfDay(for: date)),
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                    )
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var homeInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All drives")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
            Text("\(trips.count) drives • \(totalDuration.formattedAsHoursMinutes) • \(totalDistanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [.drivenPurple.opacity(0.55), .drivenBlue.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var startButton: some View {
        Button(action: onStartDrive) {
            Label("START DRIVE", systemImage: "location.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(LinearGradient(colors: [.drivenOrange, .drivenPink], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.drivenPink.opacity(0.55), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct HistoryView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if trips.isEmpty {
                    emptyState(text: "No drives yet - tap Start Drive to begin")
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(trips) { trip in
                            HistoryCard(trip: trip)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
            .background(appBackground)
            .navigationTitle("History")
        }
    }
}

struct ProfileView: View {
    @Query private var trips: [Trip]

    private var totalDrives: Int { trips.count }
    private var totalDistanceKm: Double { trips.reduce(0) { $0 + $1.distanceMeters } / 1000 }
    private var totalDuration: TimeInterval { trips.reduce(0) { $0 + $1.duration } }

    private var mostActiveDay: String {
        let counts = Dictionary(grouping: trips) { Calendar.current.component(.weekday, from: $0.startDate) }.mapValues(\.count)
        guard let day = counts.max(by: { $0.value < $1.value })?.key else { return "N/A" }
        return Calendar.current.weekdaySymbols[day - 1]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if trips.isEmpty {
                    emptyState(text: "No drives yet - tap Start Drive to begin")
                } else {
                    VStack(spacing: 14) {
                        StatCard(title: "Total Drives", value: "\(totalDrives)", colors: [.drivenOrange, .drivenPink])
                        StatCard(title: "Total Distance", value: "\(totalDistanceKm.formatted(.number.precision(.fractionLength(1)))) km", colors: [.drivenBlue, .drivenPurple])
                        StatCard(title: "Total Time", value: totalDuration.formattedAsHoursMinutes, colors: [.drivenPurple, .drivenPink])
                        StatCard(title: "Most Active Day", value: mostActiveDay, colors: [.drivenTeal, .drivenBlue])
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
            .background(appBackground)
            .navigationTitle("Profile")
        }
    }
}

private struct DayCell: View {
    let dayNumber: Int
    let hasDrive: Bool
    let isCurrentMonth: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(!isCurrentMonth ? .white.opacity(0.08) : (hasDrive ? .drivenPurple.opacity(0.32) : .white.opacity(0.16)))

            if hasDrive {
                Circle()
                    .fill(LinearGradient(colors: [.drivenOrange, .drivenPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 9, height: 9)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            Text("\(dayNumber)")
                .font(.caption.weight(.black))
                .foregroundStyle(isCurrentMonth ? .white : .white.opacity(0.45))
                .padding(6)
        }
        .frame(height: 54)
    }
}

private struct HistoryCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Spacer()
                Text(trip.mood)
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                metric("Distance", String(format: "%.1f km", trip.distanceMeters / 1000))
                metric("Duration", trip.duration.formattedAsHoursMinutes)
            }

            RouteSparkline(coordinates: trip.routeCoordinates)
                .stroke(
                    LinearGradient(colors: [.drivenBlue, .drivenPurple, .drivenPink, .drivenOrange], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 34)
        }
        .padding(16)
        .background(LinearGradient(colors: [.drivenPurple.opacity(0.55), .drivenBlue.opacity(0.5), .drivenPink.opacity(0.48)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RouteSparkline: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        guard coordinates.count > 1 else {
            var fallback = Path()
            fallback.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.75))
            fallback.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY * 0.2),
                control1: CGPoint(x: rect.width * 0.25, y: rect.minY),
                control2: CGPoint(x: rect.width * 0.7, y: rect.maxY)
            )
            return fallback
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return Path() }
        let latSpan = Swift.max(maxLat - minLat, 0.0001)
        let lonSpan = Swift.max(maxLon - minLon, 0.0001)
        var path = Path()

        for (idx, c) in coordinates.enumerated() {
            let x = rect.minX + ((c.longitude - minLon) / lonSpan) * rect.width
            let y = rect.maxY - ((c.latitude - minLat) / latSpan) * rect.height
            if idx == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
            Text(value)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private func emptyState(text: String) -> some View {
    VStack(spacing: 10) {
        Image(systemName: "car.circle.fill")
            .font(.system(size: 46))
            .foregroundStyle(Color.drivenPink)
        Text(text)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white.opacity(0.88))
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 300)
    .padding(.horizontal, 24)
}

private var appBackground: some View {
    LinearGradient(colors: [.drivenBackgroundTop, .drivenBackgroundBottom, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
}

private extension Calendar {
    func daysForMonthGrid(containing month: Date) -> [Date] {
        guard
            let monthInterval = dateInterval(of: .month, for: month),
            let firstWeek = dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastMoment = date(byAdding: .second, value: -1, to: monthInterval.end),
            let lastWeek = dateInterval(of: .weekOfMonth, for: lastMoment)
        else { return [] }

        var days: [Date] = []
        var date = firstWeek.start
        while date < lastWeek.end {
            days.append(startOfDay(for: date))
            guard let next = self.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }
}

private extension TimeInterval {
    var formattedAsHoursMinutes: String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours == 0 ? "\(minutes)m" : "\(hours)h \(minutes)m"
    }
}

#Preview {
    ContentView()
}
