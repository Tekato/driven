import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

struct DriveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var tracker = DriveTracker()
    @State private var tripDraft: TripDraft?
    @State private var showingSummary = false
    @State private var now = Date()
    @StateObject private var activityManager = DriveLiveActivityManager()
    private let liveTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                DriveMapView(
                    coordinates: tracker.coordinates,
                    showsUserLocation: true
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    LiveStatsBar(
                        elapsed: tracker.elapsedDuration(at: now),
                        distanceMeters: tracker.distanceMeters
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 14)

                    Spacer()

                    stopButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        tracker.stopTracking()
                        activityManager.end()
                        onClose()
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                tracker.startTracking()
                now = Date()
                activityManager.start(
                    duration: tracker.elapsedDuration(at: now).formattedClock,
                    distanceKm: tracker.distanceMeters / 1000
                )
            }
            .onDisappear {
                tracker.stopTracking()
                activityManager.end()
            }
            .onReceive(liveTimer) { date in
                now = date
                activityManager.updateIfNeeded(
                    duration: tracker.elapsedDuration(at: date).formattedClock,
                    distanceKm: tracker.distanceMeters / 1000
                )
            }
            .navigationDestination(isPresented: $showingSummary) {
                if let tripDraft {
                    TripSummaryView(
                        draft: tripDraft,
                        onSave: { mood, note in
                            saveTrip(draft: tripDraft, mood: mood, note: note)
                        },
                        onDone: onClose
                    )
                }
            }
        }
    }

    private var stopButton: some View {
        Button {
            let end = Date()
            tripDraft = TripDraft(
                startDate: tracker.startDate ?? end,
                endDate: end,
                distanceMeters: tracker.distanceMeters,
                coordinates: tracker.coordinates
            )
            tracker.stopTracking()
            activityManager.end()
            showingSummary = true
        } label: {
            Text("STOP")
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.35, blue: 0.30), Color(red: 0.9, green: 0.12, blue: 0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: Color.red.opacity(0.45), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func saveTrip(draft: TripDraft, mood: TripMood, note: String) {
        let trip = Trip(
            startDate: draft.startDate,
            endDate: draft.endDate,
            distanceMeters: draft.distanceMeters,
            mood: mood.rawValue,
            note: note,
            routeCoordinates: draft.coordinates
        )
        modelContext.insert(trip)
        try? modelContext.save()
    }
}

struct TripSummaryView: View {
    let draft: TripDraft
    let onSave: (TripMood, String) -> Void
    let onDone: () -> Void

    @State private var selectedMood: TripMood = .focused
    @State private var note = ""
    @State private var hasSavedTrip = false
#if canImport(UIKit)
    @State private var snapshotImage: UIImage?
    @State private var shareCardImage: UIImage?
    @State private var shareCardURL: URL?
    @State private var shareMapImage: UIImage?
#endif

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                snapshotSection
                detailRow(title: "Distance", value: String(format: "%.2f km", draft.distanceMeters / 1000))
                detailRow(title: "Duration", value: draft.duration.formattedClock)
                detailRow(title: "Start", value: draft.startDate.formatted(date: .abbreviated, time: .shortened))
                detailRow(title: "End", value: draft.endDate.formatted(date: .abbreviated, time: .shortened))

                moodPicker

                TextField("Add a note", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)

                if hasSavedTrip {
                    shareSection

                    Button("Done") {
                        onDone()
                    }
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Button("Save Trip") {
                        onSave(selectedMood, note.trimmingCharacters(in: .whitespacesAndNewlines))
                        hasSavedTrip = true
                    }
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.drivenOrange, .drivenPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.black.opacity(0.98).ignoresSafeArea())
        .navigationTitle("Trip Summary")
        .task {
#if canImport(UIKit)
            snapshotImage = await RouteSnapshotBuilder.makeSnapshot(
                for: draft.coordinates,
                size: CGSize(width: 600, height: 340)
            )
#endif
        }
    }

    @ViewBuilder
    private var snapshotSection: some View {
#if canImport(UIKit)
        if let snapshotImage {
            Image(uiImage: snapshotImage)
                .resizable()
                .scaledToFill()
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            DriveMapView(coordinates: draft.coordinates, showsUserLocation: false)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
#else
        DriveMapView(coordinates: draft.coordinates, showsUserLocation: false)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
#endif
    }

    @ViewBuilder
    private var shareSection: some View {
#if canImport(UIKit)
        VStack(alignment: .leading, spacing: 12) {
            Text("Share Your Drive")
                .font(.title3.weight(.black))
                .foregroundStyle(.white)

            if let shareCardImage {
                Image(uiImage: shareCardImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let shareCardURL {
                    ShareLink(
                        item: shareCardURL,
                        preview: SharePreview("Driven", image: Image(uiImage: shareCardImage))
                    ) {
                        Text("Share to Stories")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [.drivenPurple, .drivenBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [.drivenPurple, .drivenBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .task(id: hasSavedTrip) {
            guard hasSavedTrip, shareCardImage == nil else { return }
            await renderShareCard()
        }
#endif
    }

#if canImport(UIKit)
    private func renderShareCard() async {
        let mapImage = RouteShareMapBuilder.makeImage(
            for: draft.coordinates,
            size: CGSize(width: 960, height: 960)
        )
        shareMapImage = mapImage

        let card = DriveShareCardView(
            mapImage: mapImage,
            coordinates: draft.coordinates,
            distanceKm: draft.distanceMeters / 1000,
            durationText: draft.duration.formattedClock,
            mood: selectedMood.rawValue,
            driveDate: draft.startDate
        )
        .frame(width: 360, height: 640)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareCardImage = renderer.uiImage
        shareCardURL = shareCardImage.flatMap(Self.writeShareImage)
    }

    nonisolated private static func writeShareImage(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("driven-share-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
#endif

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mood")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(TripMood.allCases, id: \.self) { mood in
                    Button(mood.rawValue) {
                        selectedMood = mood
                    }
                    .font(.caption.weight(.black))
                    .foregroundStyle(selectedMood == mood ? .black : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        selectedMood == mood ? Color.drivenOrange : Color.white.opacity(0.12)
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LiveStatsBar: View {
    let elapsed: TimeInterval
    let distanceMeters: CLLocationDistance

    var body: some View {
        HStack(spacing: 14) {
            stat(label: "Duration", value: elapsed.formattedClock)
            stat(label: "Distance", value: String(format: "%.2f km", distanceMeters / 1000))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.74))
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class DriveTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var distanceMeters: CLLocationDistance = 0
    @Published private(set) var startDate: Date?

    private let locationManager = CLLocationManager()
    private var locationSession: CLServiceSession?
    private var lastLocation: CLLocation?

    var elapsedDuration: TimeInterval {
        elapsedDuration(at: Date())
    }

    func elapsedDuration(at date: Date) -> TimeInterval {
        guard let startDate else { return 0 }
        return date.timeIntervalSince(startDate)
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = true
    }

    func startTracking() {
        // CLServiceSession (iOS 17+) manages authorization; no manual request needed.
        locationSession = CLServiceSession(authorization: .whenInUse)
        if startDate == nil {
            startDate = Date()
        }
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationSession = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy > 0 {
            if let lastLocation {
                let delta = location.distance(from: lastLocation)
                if delta > 2 {
                    distanceMeters += delta
                }
            }
            lastLocation = location
            coordinates.append(location.coordinate)
        }
    }
}

@MainActor
final class DriveLiveActivityManager: ObservableObject {
#if canImport(ActivityKit) && !targetEnvironment(simulator)
    private var activity: Activity<DriveActivityAttributes>?
    private var tickCount = 0
#endif

    func start(duration: String, distanceKm: Double) {
#if canImport(ActivityKit) && !targetEnvironment(simulator)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = DriveActivityAttributes(name: "Driven")
        let state = DriveActivityAttributes.ContentState(
            duration: duration,
            distance: String(format: "%.2f km", distanceKm)
        )
        do {
            activity = try Activity<DriveActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            tickCount = 0
        } catch {
            activity = nil
        }
#endif
    }

    func updateIfNeeded(duration: String, distanceKm: Double) {
#if canImport(ActivityKit) && !targetEnvironment(simulator)
        guard let activity else { return }
        tickCount += 1
        if tickCount % 3 != 0 { return }
        let state = DriveActivityAttributes.ContentState(
            duration: duration,
            distance: String(format: "%.2f km", distanceKm)
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
#endif
    }

    func end() {
#if canImport(ActivityKit) && !targetEnvironment(simulator)
        guard let activity else { return }
        Task {
            // Pass nil to avoid an XPC read on a connection that may already be winding down.
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
#endif
    }
}

struct DriveMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let showsUserLocation: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = .dark
        mapView.mapType = .mutedStandard
        mapView.showsCompass = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = showsUserLocation
        if showsUserLocation {
            mapView.userTrackingMode = .follow
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        guard coordinates.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        if !showsUserLocation {
            if let region = coordinates.region(paddingFactor: 1.35) {
                mapView.setRegion(region, animated: false)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            if #available(iOS 17.0, *) {
                let renderer = MKGradientPolylineRenderer(overlay: polyline)
                renderer.setColors(
                    [UIColor.systemOrange, UIColor.systemPink],
                    locations: [0.0, 1.0]
                )
                renderer.lineWidth = 7
                return renderer
            }

            let renderer = MKPolylineRenderer(overlay: polyline)
            renderer.strokeColor = .systemPink
            renderer.lineWidth = 7
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }
}

struct TripDraft {
    let startDate: Date
    let endDate: Date
    let distanceMeters: CLLocationDistance
    let coordinates: [CLLocationCoordinate2D]

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

enum TripMood: String, Codable, CaseIterable {
    case chill = "Chill"
    case focused = "Focused"
    case pumped = "Pumped"
    case calm = "Calm"
    case lateNight = "Late Night"
}

private enum RouteSnapshotBuilder {
#if canImport(UIKit)
    static func makeSnapshot(for coordinates: [CLLocationCoordinate2D], size: CGSize) async -> UIImage? {
        guard coordinates.count > 1 else { return nil }
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.mapType = .mutedStandard
        guard let region = coordinates.region(paddingFactor: 1.35) else { return nil }
        options.region = region

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            snapshot.image.draw(at: .zero)

            guard let context = UIGraphicsGetCurrentContext() else { return }

            let path = UIBezierPath()
            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.lineWidth = 20
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            context.saveGState()
            context.setShadow(offset: .zero, blur: 28, color: UIColor.systemPink.withAlphaComponent(0.9).cgColor)
            UIColor.systemPink.withAlphaComponent(0.8).setStroke()
            path.stroke()
            context.restoreGState()

            context.saveGState()
            context.addPath(path.cgPath)
            context.replacePathWithStrokedPath()
            context.clip()

            let colors = [
                UIColor.systemOrange.cgColor,
                UIColor.systemPink.cgColor,
                UIColor.systemPurple.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: size.height),
                    end: CGPoint(x: size.width, y: 0),
                    options: []
                )
            }
            context.restoreGState()

            UIColor.white.withAlphaComponent(0.22).setStroke()
            path.lineWidth = 5
            path.stroke()

            if let start = coordinates.first.map(snapshot.point(for:)),
               let end = coordinates.last.map(snapshot.point(for:)) {
                let startRect = CGRect(x: start.x - 10, y: start.y - 10, width: 20, height: 20)
                let endRect = CGRect(x: end.x - 12, y: end.y - 12, width: 24, height: 24)

                UIColor.white.withAlphaComponent(0.95).setFill()
                UIBezierPath(ovalIn: startRect).fill()

                UIColor.systemOrange.setFill()
                UIBezierPath(ovalIn: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)).fill()

                UIColor.white.withAlphaComponent(0.22).setFill()
                UIBezierPath(ovalIn: endRect).fill()

                UIColor.systemPurple.setFill()
                UIBezierPath(ovalIn: CGRect(x: end.x - 7, y: end.y - 7, width: 14, height: 14)).fill()
            }
        }
    }
#endif
}

private enum RouteShareMapBuilder {
#if canImport(UIKit)
    static func makeImage(for coordinates: [CLLocationCoordinate2D], size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)

            let background = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.05, green: 0.09, blue: 0.14, alpha: 1).cgColor,
                    UIColor(red: 0.07, green: 0.14, blue: 0.20, alpha: 1).cgColor,
                    UIColor(red: 0.10, green: 0.12, blue: 0.19, alpha: 1).cgColor
                ] as CFArray,
                locations: [0.0, 0.55, 1.0]
            )

            guard let context = UIGraphicsGetCurrentContext() else { return }
            if let background {
                context.drawLinearGradient(
                    background,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            drawGrid(in: rect, context: context)
            drawContours(in: rect, context: context)

            let points = coordinates.routePoints(in: rect.insetBy(dx: 90, dy: 90))
            guard points.count > 1 else {
                drawFallbackRoute(in: rect, context: context)
                return
            }

            let path = UIBezierPath()
            path.move(to: points[0])
            if points.count == 2 {
                path.addLine(to: points[1])
            } else {
                for index in 1..<points.count {
                    let previous = points[index - 1]
                    let current = points[index]
                    let midpoint = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                    path.addQuadCurve(to: midpoint, controlPoint: previous)
                    if index == points.count - 1 {
                        path.addQuadCurve(to: current, controlPoint: midpoint)
                    }
                }
            }

            drawRoute(path: path, size: size, context: context)

            if let start = points.first, let end = points.last {
                drawMarker(at: start, radius: 11, fill: UIColor.systemOrange, ring: UIColor.white.withAlphaComponent(0.9))
                drawMarker(at: end, radius: 13, fill: UIColor.systemPurple, ring: UIColor.white.withAlphaComponent(0.24))
            }
        }
    }

    private static func drawGrid(in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setLineWidth(1)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)

        let spacing: CGFloat = 72
        var x: CGFloat = rect.minX
        while x <= rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y: CGFloat = rect.minY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }

        context.strokePath()
        context.restoreGState()
    }

    private static func drawContours(in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setLineWidth(1.2)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.05).cgColor)

        for index in 0..<6 {
            let inset = CGFloat(index) * 52 + 30
            let contourRect = rect.insetBy(dx: inset, dy: inset * 0.82)
            context.strokeEllipse(in: contourRect)
        }

        context.restoreGState()
    }

    private static func drawFallbackRoute(in rect: CGRect, context: CGContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.78))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.34),
            controlPoint1: CGPoint(x: rect.width * 0.34, y: rect.height * 0.16),
            controlPoint2: CGPoint(x: rect.width * 0.62, y: rect.height * 0.88)
        )
        drawRoute(path: path, size: rect.size, context: context)
    }

    private static func drawRoute(path: UIBezierPath, size: CGSize, context: CGContext) {
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        context.saveGState()
        context.setShadow(offset: .zero, blur: 34, color: UIColor.systemPink.withAlphaComponent(0.95).cgColor)
        UIColor.systemPink.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 24
        path.stroke()
        context.restoreGState()

        context.saveGState()
        context.addPath(path.cgPath)
        context.replacePathWithStrokedPath()
        context.clip()

        let colors = [
            UIColor.systemOrange.cgColor,
            UIColor.systemPink.cgColor,
            UIColor.systemPurple.cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)
        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end: CGPoint(x: size.width, y: 0),
                options: []
            )
        }
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.20).setStroke()
        path.lineWidth = 5
        path.stroke()
    }

    private static func drawMarker(at point: CGPoint, radius: CGFloat, fill: UIColor, ring: UIColor) {
        let ringPath = UIBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        ring.setFill()
        ringPath.fill()

        let innerRadius = radius * 0.5
        let innerPath = UIBezierPath(ovalIn: CGRect(x: point.x - innerRadius, y: point.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
        fill.setFill()
        innerPath.fill()
    }
#endif
}

struct DriveShareCardView: View {
    let mapImage: UIImage?
    let coordinates: [CLLocationCoordinate2D]
    let distanceKm: Double
    let durationText: String
    let mood: String
    let driveDate: Date

    var body: some View {
        ZStack {
            backgroundGradient
            floatingGlow

            VStack(alignment: .leading, spacing: 0) {
                header
                routePanel
                bottomSection
                watermark
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 30)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .drivenOrange.opacity(0.95),
                            .drivenPink.opacity(0.92),
                            .drivenPurple.opacity(0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .padding(10)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.05, blue: 0.12),
                Color(red: 0.07, green: 0.04, blue: 0.18),
                Color(red: 0.16, green: 0.05, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var floatingGlow: some View {
        ZStack {
            Circle()
                .fill(Color.drivenPink.opacity(0.18))
                .frame(width: 240)
                .blur(radius: 50)
                .offset(x: 110, y: -210)

            Circle()
                .fill(Color.drivenPurple.opacity(0.16))
                .frame(width: 280)
                .blur(radius: 70)
                .offset(x: -100, y: 120)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DRIVEN")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .drivenOrange, .drivenPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Route story")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .textCase(.uppercase)
                .tracking(2)
        }
        .padding(.bottom, 22)
    }

    private var routePanel: some View {
        ZStack {
            if let mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.10),
                                Color.clear,
                                Color.black.opacity(0.32)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.045))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.02),
                                Color.clear,
                                Color.drivenPurple.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                DotGridPattern(dotSize: 2.2, spacing: 18)
                    .opacity(0.18)

                routeArt
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var routeArt: some View {
        if coordinates.count > 1 {
            SharedRouteArtwork(path: ShareRouteShape(coordinates: coordinates))
        } else {
            SharedRouteArtwork(path: DecorativeRouteShape())
        }
    }

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: "%.2f km", distanceKm))
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)

            Text(durationText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text(mood.uppercased())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: moodColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
                .padding(.top, 4)

            Text(driveDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var watermark: some View {
        VStack {
            Spacer(minLength: 16)

            Text("driven app")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.34))
                .tracking(1.4)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var moodColors: [Color] {
        switch mood.lowercased() {
        case "chill":
            return [.drivenTeal, .drivenBlue]
        case "focused":
            return [.drivenBlue, .drivenPurple]
        case "pumped":
            return [.drivenOrange, .drivenPink]
        case "calm":
            return [Color(red: 0.30, green: 0.88, blue: 0.74), .drivenTeal]
        case "late night":
            return [.drivenPurple, .drivenPink]
        default:
            return [.drivenOrange, .drivenPink]
        }
    }
}

private struct DotGridPattern: View {
    let dotSize: CGFloat
    let spacing: CGFloat

    init(dotSize: CGFloat = 3, spacing: CGFloat = 34) {
        self.dotSize = dotSize
        self.spacing = spacing
    }

    var body: some View {
        GeometryReader { proxy in
            let cols = Int((proxy.size.width / spacing).rounded(.up)) + 2
            let rows = Int((proxy.size.height / spacing).rounded(.up)) + 2

            Path { path in
                for row in 0..<rows {
                    for col in 0..<cols {
                        let x = CGFloat(col) * spacing + (row.isMultiple(of: 2) ? 0 : spacing * 0.45)
                        let y = CGFloat(row) * spacing
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        path.addEllipse(in: rect)
                    }
                }
            }
            .fill(Color.white.opacity(0.35))
        }
        .allowsHitTesting(false)
    }
}

private struct SharedRouteArtwork<RoutePath: Shape>: View {
    let path: RoutePath

    private let gradient = LinearGradient(
        colors: [.drivenOrange, .drivenPink, .drivenPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            path
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 14)
                .opacity(0.95)

            path
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                )

            path
                .stroke(
                    Color.white.opacity(0.14),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 1.5)
        }
    }
}

struct ShareRouteShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        let points = coordinates.routePoints(in: rect)
        return RoutePathBuilder.makePath(from: points)
    }
}

private struct DecorativeRouteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.width * 0.12, y: rect.height * 0.82),
            CGPoint(x: rect.width * 0.28, y: rect.height * 0.20),
            CGPoint(x: rect.width * 0.48, y: rect.height * 0.62),
            CGPoint(x: rect.width * 0.68, y: rect.height * 0.28),
            CGPoint(x: rect.width * 0.88, y: rect.height * 0.56)
        ]
        return RoutePathBuilder.makePath(from: points)
    }
}

private enum RoutePathBuilder {
    static func makePath(from points: [CGPoint]) -> Path {
        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: first)

        guard points.count > 1 else { return path }

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: midpoint, control: previous)

            if index == points.count - 1 {
                path.addQuadCurve(to: current, control: midpoint)
            }
        }

        return path
    }
}

private extension Array where Element == CLLocationCoordinate2D {
    func routePoints(in rect: CGRect) -> [CGPoint] {
        guard count > 1 else { return [] }

        let lats = map(\.latitude)
        let lons = map(\.longitude)
        guard
            let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLon = lons.min(),
            let maxLon = lons.max()
        else {
            return []
        }

        let latSpan = Swift.max(maxLat - minLat, 0.0001)
        let lonSpan = Swift.max(maxLon - minLon, 0.0001)
        let contentRect = rect.insetBy(dx: 14, dy: 14)
        let aspect = lonSpan / latSpan

        let drawingRect: CGRect
        if aspect > contentRect.width / contentRect.height {
            let height = contentRect.width / aspect
            drawingRect = CGRect(
                x: contentRect.minX,
                y: contentRect.midY - (height / 2),
                width: contentRect.width,
                height: height
            )
        } else {
            let width = contentRect.height * aspect
            drawingRect = CGRect(
                x: contentRect.midX - (width / 2),
                y: contentRect.minY,
                width: width,
                height: contentRect.height
            )
        }

        return map { coordinate in
            let xRatio = (coordinate.longitude - minLon) / lonSpan
            let yRatio = (coordinate.latitude - minLat) / latSpan
            return CGPoint(
                x: drawingRect.minX + drawingRect.width * xRatio,
                y: drawingRect.maxY - drawingRect.height * yRatio
            )
        }
    }

    func region(paddingFactor: Double = 1.25) -> MKCoordinateRegion? {
        guard !isEmpty else { return nil }

        let lats = map(\.latitude)
        let lons = map(\.longitude)
        guard
            let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLon = lons.min(),
            let maxLon = lons.max()
        else {
            return nil
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latDelta = Swift.max((maxLat - minLat) * paddingFactor, 0.005)
        let lonDelta = Swift.max((maxLon - minLon) * paddingFactor, 0.005)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        return MKCoordinateRegion(center: center, span: span)
    }
}

private extension TimeInterval {
    var formattedClock: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
