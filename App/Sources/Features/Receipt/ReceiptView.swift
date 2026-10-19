import PhotosUI
import SwiftUI

/// The printed receipt.
///
/// The paper feeds out of a fixed slot, so the page appears to travel rather
/// than fade in. Everything on the paper is printed at once: the route, the
/// data, the note. The only thing that changes on the page is the graphic
/// treatment, and it changes *inside* a fixed region so the receipt never
/// reflows while you look at it.
struct ReceiptView: View {
    @Environment(RunStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let run: Run

    @State private var graphic: ReceiptGraphic = .route
    @State private var isFeeding = true
    @State private var isCollected: Bool
    @State private var isTearing = false
    @State private var tearProgress: CGFloat = 0
    @State private var showShare = false
    @State private var showGraphicPicker = false
    @State private var photoItem: PhotosPickerItem?

    init(run: Run) {
        self.run = run
        _isCollected = State(initialValue: run.isCollected)
        // -graphic=ascii|pace|photo opens the receipt in a given treatment,
        // for screenshots and UI checks.
        if let requested = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("-graphic=") })?
            .replacingOccurrences(of: "-graphic=", with: ""),
           let requested = ReceiptGraphic(rawValue: requested) {
            _graphic = State(initialValue: requested)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PrinterSlot()
                ReceiptPaper(
                    run: run,
                    graphic: $graphic,
                    isFeeding: isFeeding,
                    showGraphicPicker: $showGraphicPicker,
                    tearProgress: $tearProgress,
                    photoItem: $photoItem,
                    onTear: { tearOff() }
                )
                .rotationEffect(.degrees(isTearing ? 3 : 0))
                .offset(y: isTearing ? 260 : 0)
                .opacity(isTearing ? 0 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .background(Theme.ground)
        .scrollIndicators(.hidden)
        .navigationTitle("Run receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            actions
        }
        .onAppear {
            isFeeding = true
        }
        .sheet(isPresented: $showShare) {
            SharePreviewView(run: run)
        }
        .task {
            // -showShare opens the share preview directly.
            if ProcessInfo.processInfo.arguments.contains("-showShare") {
                showShare = true
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                isCollected.toggle()
                store.setCollected(isCollected, for: run.id)
            } label: {
                Label(isCollected ? "Saved" : "Save", systemImage: isCollected ? "checkmark" : "square.and.arrow.down")
            }
            .buttonStyle(ReceiptActionStyle(isPrimary: true))

            Button {
                tearOff()
            } label: {
                Label("Tear off", systemImage: "doc.on.doc")
            }
            .buttonStyle(ReceiptActionStyle(isPrimary: false))

            Button {
                showShare = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(ReceiptActionStyle(isPrimary: false))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background {
            LinearGradient(
                colors: [Theme.ground.opacity(0), Theme.ground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    /// Detaches the receipt and returns to the archive.
    private func tearOff() {
        guard !isTearing else { return }
        isTearing = true
        store.setCollected(true, for: run.id)
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            dismiss()
        }
    }
}

/// The dark physical output slot the paper emerges from.
struct PrinterSlot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.26), Color(white: 0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 27)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(white: 0.79))
                .frame(height: 11)
                .padding(.horizontal, 13)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(white: 0.93))
                .frame(height: 5)
                .padding(.horizontal, 14)
                .offset(y: 8)
        }
        .padding(.horizontal, -16)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

/// The paper itself.
struct ReceiptPaper: View {
    let run: Run
    @Binding var graphic: ReceiptGraphic
    let isFeeding: Bool
    @Binding var showGraphicPicker: Bool
    @Binding var tearProgress: CGFloat
    @Binding var photoItem: PhotosPickerItem?
    let onTear: () -> Void

    @State private var paperHeight: CGFloat = 0
    @State private var feedProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .overlay(Theme.paperSecondary.opacity(0.55))
                .padding(.vertical, 14)
            heading
            graphicRegion
            metrics
            Divider()
                .overlay(Theme.paperSecondary.opacity(0.55))
                .padding(.vertical, 14)
            footer
            tearGrip
        }
        .padding(.horizontal, 20)
        .padding(.top, 19)
        .padding(.bottom, 8)
        .background(Theme.paper)
        .foregroundStyle(Theme.paperInk)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .clipShape(SerratedBottomShape())
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { paperHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, newValue in paperHeight = newValue }
            }
        }
        .mask(alignment: .top) {
            Rectangle()
                .frame(height: paperHeight * feedProgress)
                .overlay(alignment: .bottom) {
                    // A contact shadow follows the exposed edge of the paper.
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.13)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 12)
                    .offset(y: 6)
                }
        }
        .onAppear {
            feedProgress = 0
            withAnimation(.linear(duration: 1.1)) { feedProgress = 1 }
        }
    }

    private var header: some View {
        HStack {
            RunnerStamp()
            Spacer()
            Text("Run receipt")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 8) {
                Text(run.title.uppercased())
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .tracking(-0.8)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("SINGAPORE")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            HStack {
                Text("OUTDOOR RUN")
                Spacer()
                Text(Format.receiptDate(run.startedAt))
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Theme.paperSecondary)
        }
        .foregroundStyle(Theme.paperInk)
    }

    private var graphicRegion: some View {
        ZStack(alignment: .topLeading) {
            ReceiptGraphicView(graphic: graphic, run: run, photoItem: photoItem)

            Button {
                showGraphicPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(graphic.title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.paperInk)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Theme.paper, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(7)
            .accessibilityLabel("Change receipt graphic, currently \(graphic.title)")

            if graphic == .photo {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.paperInk)
                        .frame(width: 44, height: 44)
                        .background(Theme.paper, in: Circle())
                }
                .padding(7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityLabel("Choose a photo to print")
            }

            if showGraphicPicker {
                GraphicPicker(graphic: $graphic, isPresented: $showGraphicPicker)
            }
        }
        .frame(height: 250)
        .background(Theme.graphic)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .padding(.vertical, 15)
    }

    private var metrics: some View {
        let values: [(String, String)] = [
            ("Distance", Format.kilometres(run.distanceMeters) + " KM"),
            ("Avg pace", Format.pace(RouteGeometry.paceSecondsPerKm(
                distanceMeters: run.distanceMeters,
                movingTime: run.movingTime
            ))),
            ("Avg HR", run.averageHeartRate.map { "\($0) BPM" } ?? "—"),
            ("Duration", Format.duration(run.elapsedTime)),
            ("Elevation", "\(Int(run.elevationGainMeters)) m"),
            ("Calories", "—")
        ]
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
            spacing: 14
        ) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 2) {
                    Text(value.0.uppercased())
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(-0.35)
                        .foregroundStyle(Theme.paperSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(value.1)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(-0.55)
                        .foregroundStyle(Theme.paperInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: index % 3 == 1 ? .center : (index % 3 == 0 ? .leading : .trailing))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if !run.note.isEmpty {
                Text(run.note)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            VStack(spacing: 1) {
                Text("KEEP FOR YOUR RECORDS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text(Format.receiptStamp(run.startedAt))
                    .font(.system(size: 11, design: .monospaced))
            }
            Text("A route worth keeping.")
                .font(.system(size: 11, design: .monospaced))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var tearGrip: some View {
        HStack(spacing: 7) {
            Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .semibold))
            Text(tearProgress > 0.6 ? "Release to collect" : "Pull to tear")
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(Theme.paperSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
        .gesture(tearGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTear() }
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                tearProgress = min(1, max(0, value.translation.height / 90))
            }
            .onEnded { value in
                if value.translation.height > 72 {
                    tearProgress = 1
                    onTear()
                } else {
                    withAnimation(.spring(duration: 0.26, bounce: 0)) {
                        tearProgress = 0
                    }
                }
            }
    }
}

/// The four ways a route can be printed.
enum ReceiptGraphic: String, CaseIterable, Identifiable {
    case route
    case ascii
    case pace
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .route: "ROUTE TRACE"
        case .ascii: "ASCII MAP"
        case .pace: "PACE TREND"
        case .photo: "PHOTO PRINT"
        }
    }
}

/// A rectangle whose bottom edge is torn rather than cut.
struct SerratedBottomShape: Shape {
    var toothWidth: CGFloat = 10
    var toothHeight: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - toothHeight))
        var x = rect.maxX
        while x > rect.minX {
            let next = max(rect.minX, x - toothWidth)
            path.addLine(to: CGPoint(x: next, y: rect.maxY - toothHeight))
            path.addLine(to: CGPoint(x: next, y: rect.maxY))
            x = next
        }
        path.closeSubpath()
        return path
    }
}

/// The three-runner mark printed at the top of every receipt.
struct RunnerStamp: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.16, y: size.height * 0.18))
            path.addArc(
                center: CGPoint(x: size.width * 0.16, y: size.height * 0.18),
                radius: size.height * 0.16,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            context.stroke(path, with: .color(Theme.paperInk), lineWidth: 2.6)

            var body = Path()
            body.move(to: CGPoint(x: size.width * 0.02, y: size.height * 0.55))
            body.addLine(to: CGPoint(x: size.width * 0.30, y: size.height * 0.32))
            body.addLine(to: CGPoint(x: size.width * 0.30, y: size.height * 0.72))
            body.addLine(to: CGPoint(x: size.width * 0.06, y: size.height * 0.96))
            body.move(to: CGPoint(x: size.width * 0.30, y: size.height * 0.40))
            body.addLine(to: CGPoint(x: size.width * 0.52, y: size.height * 0.62))
            body.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.30))
            context.stroke(body, with: .color(Theme.paperInk), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 47, height: 25)
        .accessibilityHidden(true)
    }
}

struct ReceiptActionStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .regular))
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(
                isPrimary ? Theme.ink : Theme.tile,
                in: Capsule()
            )
            .foregroundStyle(isPrimary ? Theme.ground : Theme.ink)
            .shadow(color: .black.opacity(isPrimary ? 0 : 0.08), radius: 8, y: 3)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
    }
}
