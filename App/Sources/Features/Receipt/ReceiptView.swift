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
    @State private var viewportHeight: CGFloat = 0
    @State private var gripBottom: CGFloat = 0

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
                    comparisonRun: store.similarRun(to: run),
                    isAtEnd: isAtEnd,
                    onTear: { tearOff() }
                )
                .rotationEffect(.degrees(tearProgress * 3))
                .offset(y: tearProgress * 150)
                .opacity(isTearing ? 0 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { viewportHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, newValue in viewportHeight = newValue }
            }
        }
        .coordinateSpace(name: "receipt-scroll")
        .onPreferenceChange(GripPositionKey.self) { gripBottom = $0 }
        .background(Theme.ground)
        .scrollIndicators(.hidden)
        .navigationTitle("Printed record")
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

    /// Whether the receipt has been scrolled to the end.
    ///
    /// The tear only engages here: at the end of the paper a pull down
    /// cannot be a scroll, so there is no ambiguity about what the gesture
    /// means.
    private var isAtEnd: Bool {
        guard viewportHeight > 0 else { return true }
        return gripBottom <= viewportHeight + 24
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
            .accessibilityIdentifier("share-receipt")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .accessibilityIdentifier("receipt-actions")
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
    ///
    /// The paper has already been pulled down by the grip, so this only has
    /// to let it fall away and take the run with it.
    private func tearOff() {
        guard !isTearing else { return }
        isTearing = true
        store.setCollected(true, for: run.id)
        withAnimation(.easeIn(duration: 0.42)) {
            tearProgress = 3
        }
        Task {
            try? await Task.sleep(for: .milliseconds(460))
            dismiss()
        }
    }
}

/// The lip of the tray the paper comes out of.
///
/// It is a metal edge rather than a black slot: a shallow rail with a lit top
/// edge and a shadow beneath it, so the paper reads as resting in a printer
/// tray.
struct PrinterSlot: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.74), Color(white: 0.44)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 10)

            Rectangle()
                .fill(.white.opacity(0.8))
                .frame(height: 1)

            Rectangle()
                .fill(.black.opacity(0.16))
                .frame(height: 6)
                .offset(y: 6)
                .blur(radius: 3)
        }
        .frame(height: 10)
        .padding(.horizontal, -16)
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
    /// The last time the same route was run, when there was one.
    let comparisonRun: Run?
    /// Whether the receipt has been scrolled to the end of the paper.
    let isAtEnd: Bool
    let onTear: () -> Void

    @State private var feedProgress: CGFloat = 0
    @State private var isPulling = false
    @State private var tearArmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .overlay(Theme.paperSecondary.opacity(0.55))
                .padding(.vertical, 14)
            heading
            graphicRegion
            metrics
            comparison
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
        .clipShape(TornEdgeShape())
        .mask {
            // The reveal is measured from the paper itself, so it cannot be
            // left showing a stale height.
            GeometryReader { proxy in
                Rectangle()
                    .frame(height: proxy.size.height * feedProgress)
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
        }
        .animation(.linear(duration: 1.1), value: feedProgress)
        .task {
            // The paper feeds out when the receipt first appears. Setting the
            // value again if the view is rebuilt means the paper can never be
            // left hidden behind the slot.
            feedProgress = 1
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            MilemarkGlyph()
            Spacer()
            Text("MILEMARK")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.6)
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
        VStack(spacing: 0) {
            // The picture. It is the whole of the printed plate, so nothing
            // is ever laid over the route.
            ReceiptGraphicView(graphic: graphic, run: run, photoItem: photoItem)
                .frame(maxWidth: .infinity)
                .frame(height: 218)
                .clipped()

            // The caption sits on a strip below the picture, the way a label
            // sits under a plate, rather than over the top of it.
            HStack(spacing: 8) {
                Button {
                    showGraphicPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Text(graphic.title)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.paperInk)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Theme.paper, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change receipt graphic, currently \(graphic.title)")
                .accessibilityIdentifier("graphic-badge")

                if graphic == .photo {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.paperInk)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Theme.paper, in: Capsule())
                    }
                    .accessibilityLabel("Choose a photo to print")
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 7)
            .frame(height: 32)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.paperSecondary.opacity(0.18)).frame(height: 1)
            }
        }
        .frame(height: 250)
        .background(Theme.graphic)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .padding(.vertical, 15)
        .overlay {
            if showGraphicPicker {
                GraphicPicker(graphic: $graphic, isPresented: $showGraphicPicker)
            }
        }
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

    /// How this run compares with the last time the same route was run.
    @ViewBuilder
    private var comparison: some View {
        if let previous = comparisonRun {
            let difference = run.movingTime - previous.movingTime
            let faster = difference < 0
            let magnitude = abs(difference)
            let paceDifference = RouteGeometry.paceSecondsPerKm(
                distanceMeters: run.distanceMeters,
                movingTime: run.movingTime
            ).map { current in
                RouteGeometry.paceSecondsPerKm(
                    distanceMeters: previous.distanceMeters,
                    movingTime: previous.movingTime
                ).map { current - $0 } ?? 0
            } ?? 0

            VStack(spacing: 3) {
                Text(faster ? "FASTER ON THE SAME ROUTE" : "SLOWER ON THE SAME ROUTE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Theme.paperSecondary)
                Text("\(Format.duration(magnitude)) \(faster ? "quicker" : "slower") than \(previous.startedAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.paperInk)
                if abs(paceDifference) >= 1 {
                    Text("Pace \(Format.paceDifference(paceDifference)) per km \(faster ? "faster" : "slower")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.paperSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.paperSecondary.opacity(0.35)).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.paperSecondary.opacity(0.35)).frame(height: 1)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !run.note.isEmpty {
                Text(run.note)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.paperSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("LOGGED \(Format.receiptStamp(run.startedAt))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                Text("PRINTED ON THIS PHONE")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(Theme.paperSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tearGrip: some View {
        HStack(spacing: 7) {
            Image(systemName: isAtEnd ? "arrow.down" : "arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
            Text(gripTitle)
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(Theme.paperSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
        // The grip takes the drag before the scroll view can, so pulling the
        // paper does not scroll the receipt instead. There is no tap action
        // on the grip: a pull must never tear the receipt off by accident.
        // The Tear off button in the action bar is the alternative.
        .highPriorityGesture(tearGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(gripTitle)
        .accessibilityIdentifier("tear-grip")
        .accessibilityValue("\(Int(tearProgress * 100)) percent pulled")
        .accessibilityHint("Scroll to the end of the receipt, then drag down to collect it")
        .accessibilityAction { onTear() }
        .background {
            // Where the grip sits in the receipt, so the tear only engages
            // once the receipt has been scrolled to the end.
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GripPositionKey.self,
                    value: proxy.frame(in: .named("receipt-scroll")).maxY
                )
            }
        }
    }

    private var gripTitle: String {
        if !isAtEnd { return "Scroll to the end to tear" }
        return tearProgress > 0.6 ? "Release to collect" : "Pull to tear"
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                // The tear is armed when the pull starts, at the end of the
                // paper. The scroll view bounces a little at the end of its
                // travel, and the pull must not be cancelled by that.
                if !isPulling {
                    isPulling = true
                    tearArmed = isAtEnd
                }
                // The paper follows the finger directly: no easing, no lag.
                tearProgress = tearArmed ? TearRule.progress(for: value.translation.height) : 0
            }
            .onEnded { value in
                defer { isPulling = false }
                guard tearArmed else { return }
                if TearRule.shouldTear(translation: value.translation.height) {
                    tearProgress = 1
                    onTear()
                } else {
                    // Released early: the paper settles back into the slot.
                    withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                        tearProgress = 0
                    }
                }
            }
    }
}

/// Reports where the tear grip sits inside the receipt.
struct GripPositionKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
