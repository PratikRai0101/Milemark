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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let run: Run

    @State private var graphic: ReceiptGraphic = .route
    @State private var isCollected: Bool
    @State private var isTearing = false
    @State private var tearOpacity: Double = 1
    @State private var tearProgress: CGFloat = 0
    @State private var showShare = false
    @State private var showGraphicPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoTreatment: PhotoTreatment = .halftone
    @State private var viewportHeight: CGFloat = 0
    @State private var gripBottom: CGFloat = 0

    init(run: Run) {
        self.run = run
        _isCollected = State(initialValue: run.isCollected)
        // -treatment=halftone|dither|poster opens a treatment directly.
        if let requested = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("-treatment=") })?
            .replacingOccurrences(of: "-treatment=", with: ""),
           let requested = PhotoTreatment(rawValue: requested) {
            _photoTreatment = State(initialValue: requested)
        }
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
                    showGraphicPicker: $showGraphicPicker,
                    tearProgress: $tearProgress,
                    photoItem: $photoItem,
                    photoTreatment: $photoTreatment,
                    comparisonRun: store.similarRun(to: run),
                    isAtEnd: isAtEnd,
                    onTear: { tearOff() }
                )
                .rotationEffect(.degrees(tearProgress * 3))
                .offset(y: tearProgress * 150)
                .opacity(tearOpacity)
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
        // The three actions share one glass surface, so they sit together the
        // way a set of controls on a layer of glass does.
        LiquidGlassBar(shape: actionBarShape) {
            // At the larger text sizes the three actions do not fit side by
            // side: a row of three divides its width equally, and "Tear off"
            // ends up as "Tear…". The primary action gets a row of its own
            // and the other two share the next.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // A row divides its width equally, and at the largest text
                    // sizes that is not enough for "Tear off". Each action
                    // gets a row of its own, so no word is ever cut off.
                    VStack(spacing: 8) {
                        saveButton
                        tearButton
                        shareButton
                    }
                } else {
                    HStack(spacing: 8) {
                        saveButton
                        tearButton
                        shareButton
                    }
                }
            }
            .padding(6)        }
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

    /// The glass takes a different shape when the actions are stacked.
    private var actionBarShape: GlassShape {
        dynamicTypeSize.isAccessibilitySize
            ? .roundedRect(cornerRadius: 24)
            : .capsule
    }

    private var saveButton: some View {
        Button {
            isCollected.toggle()
            store.setCollected(isCollected, for: run.id)
            Haptics.shared.success()
        } label: {
            actionLabel(isCollected ? "Saved" : "Save", systemImage: isCollected ? "checkmark" : "square.and.arrow.down")
        }
        .buttonStyle(ReceiptActionStyle(isPrimary: true))
    }

    private var tearButton: some View {
        Button {
            tearOff()
        } label: {
            actionLabel("Tear off", systemImage: "doc.on.doc")
        }
        .buttonStyle(ReceiptActionStyle(isPrimary: false))
    }

    private var shareButton: some View {
        Button {
            showShare = true
        } label: {
            actionLabel("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(ReceiptActionStyle(isPrimary: false))
    }

    /// A button's label.
    ///
    /// The icon is dropped at the larger text sizes. An icon and a word side
    /// by side need more room than a word on its own, and a button that has
    /// been squeezed until it says "Tear…" has stopped saying what it does.
    ///
    /// The word may then wrap, rather than being cut off.
    @ViewBuilder
    private func actionLabel(_ title: String, systemImage: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(title)
                .multilineTextAlignment(.center)
        } else {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
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
        Haptics.shared.impact(.medium)
        // The paper falls away and fades as it goes, so the departure is seen
        // rather than skipped.
        withAnimation(.easeIn(duration: Motion.tear(reduceMotion))) {
            tearProgress = 3
            tearOpacity = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(Int(Motion.tear(reduceMotion) * 1000) + 40))
            Haptics.shared.success()
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
    @Binding var showGraphicPicker: Bool
    @Binding var tearProgress: CGFloat
    @Binding var photoItem: PhotosPickerItem?
    /// How the photograph is printed.
    @Binding var photoTreatment: PhotoTreatment
    /// The last time the same route was run, when there was one.
    let comparisonRun: Run?
    /// Whether the receipt has been scrolled to the end of the paper.
    let isAtEnd: Bool
    let onTear: () -> Void

    @State private var feedProgress: CGFloat = 0
    @State private var isPulling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .animation(.linear(duration: Motion.feed(reduceMotion)), value: feedProgress)
        .task {
            // The paper feeds out when the receipt first appears. Setting the
            // value again if the view is rebuilt means the paper can never be
            // left hidden behind the slot.
            // The paper is simply there when motion is reduced: nothing
            // travels, and no tick is felt.
            feedProgress = 1
            if !reduceMotion {
                Haptics.shared.printTicks(over: 1.1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            MilemarkGlyph()
            Spacer()
            Text("MILEMARK")
                .font(Theme.Font.labelStrong)
                .tracking(0.6)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            // The title and the city sit side by side when there is room for
            // them. When there is not, the city drops below rather than
            // squeezing the title into a truncated stub.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    title
                    Spacer(minLength: 8)
                    city
                }
                VStack(alignment: .leading, spacing: 3) {
                    title
                    city
                }
            }
            // The same for the run type and the date.
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("OUTDOOR RUN")
                    Spacer()
                    Text(Format.receiptDate(run.startedAt))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("OUTDOOR RUN")
                    Text(Format.receiptDate(run.startedAt))
                }
            }
            .font(Theme.Font.footnote)
            .foregroundStyle(Theme.paperSecondary)
        }
        .foregroundStyle(Theme.paperInk)
    }

    /// The name of the run. It wraps rather than truncating: a receipt whose
    /// title is cut off is a receipt that misreports the run.
    private var title: some View {
        Text(run.title.uppercased())
            .font(Theme.Font.paperTitle)
            .tracking(-0.8)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var city: some View {
        Text("SINGAPORE")
            .font(Theme.Font.value)
            .lineLimit(1)
    }

/// The badge that opens the graphic chooser.
    ///
    /// It is always on the strip: it is the only way back to the other
    /// treatments once a photograph has been chosen.
    private var graphicBadge: some View {
        Button {
            showGraphicPicker = true
        } label: {
            HStack(spacing: 5) {
                // The photograph names itself with its treatment chips, so
                // the title is left out to make room.
                if graphic != .photo {
                    Text(graphic.title)
                        .font(Theme.Font.labelStrong)
                        .lineLimit(1)
                }
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.paperInk)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(minHeight: 24)
            .background(Theme.paper, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change receipt graphic, currently \(graphic.title)")
        .accessibilityIdentifier("graphic-badge")
    }

    /// The photograph controls, which only appear on a photograph receipt.
    ///
    /// The chips scroll sideways rather than being squeezed, so a long
    /// treatment name is never cut off.
    @ViewBuilder
    private var photoControls: some View {
        if graphic == .photo {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.paperInk)
                            .padding(.horizontal, 9)
                            .frame(minHeight: 24)
                            .background(Theme.paper, in: Capsule())
                    }
                    .accessibilityLabel("Choose a photo to print")

                    // The same photograph can be printed several ways.
                    ForEach(PhotoTreatment.allCases) { treatment in
                        Button {
                            photoTreatment = treatment
                        } label: {
                            Text(treatment.title)
                                .font(Theme.Font.labelStrong)
                                .lineLimit(1)
                                .fixedSize()
                                .foregroundStyle(photoTreatment == treatment ? Theme.ground : Theme.paperInk)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 24)
                                .background(
                                    photoTreatment == treatment ? Theme.paperInk : Theme.paper,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Print the photo as \(treatment.title)")
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            // The row is as tall as the chips in it. A scroll view will
            // otherwise take all the height left over in the strip, and
            // push the chips out of the plate.
            .frame(height: 26)
        }
    }

    private var graphicRegion: some View {
        VStack(spacing: 0) {
            // The picture. It is the whole of the printed plate, so nothing
            // is ever laid over the route.
            ReceiptGraphicView(graphic: graphic, run: run, photoItem: photoItem, photoTreatment: photoTreatment)
                .frame(maxWidth: .infinity)
                .frame(height: 218)
                .clipped()

            // The caption sits on a strip below the picture, the way a label
            // sits under a plate, rather than over the top of it.
            //
            // The badge and the photograph's treatment chips share the strip.
            // At the larger text sizes they do not fit side by side, so the
            // chips move to a row of their own and scroll sideways if even
            // that is too much.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    graphicBadge
                    photoControls
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    graphicBadge
                    photoControls
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 7)
            .frame(minHeight: 32)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.paperSecondary.opacity(0.18)).frame(height: 1)
            }
        }
        .frame(minHeight: 250)
        .background(Theme.graphic)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .padding(.vertical, 15)
        .overlay {
            if showGraphicPicker {
                GraphicPicker(graphic: $graphic, isPresented: $showGraphicPicker)
            }
        }
        .onChange(of: graphic) { _, _ in
            // Changing the treatment is a selection, so it ticks.
            Haptics.shared.selection()
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
        // At the larger text sizes three columns of figures do not fit, so
        // the receipt becomes two columns rather than shrinking the numbers
        // back down to something unreadable.
        let columns = Theme.receiptColumns(for: dynamicTypeSize)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: columns),
            spacing: 14
        ) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 2) {
                    Text(value.0.uppercased())
                        .font(Theme.Font.label)
                        .tracking(-0.35)
                        .foregroundStyle(Theme.paperSecondary)
                        .lineLimit(1)
                    Text(value.1)
                        .font(Theme.Font.metricValue)
                        .tracking(-0.55)
                        .foregroundStyle(Theme.paperInk)
                        .lineLimit(1)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: index % columns == 1 ? .center : (index % columns == 0 ? .leading : .trailing)
                )
            }
        }
    }

    /// How this run compares with the last time the same route was run.
    @ViewBuilder
    private var comparison: some View {
        if let previous = comparisonRun {
            let timeDifference = run.movingTime - previous.movingTime
            // The pace is the fair comparison: two runs of the same loop can
            // cover different distances, so the total time says little on its
            // own.
            let paceDifference = RouteGeometry.paceSecondsPerKm(
                distanceMeters: run.distanceMeters,
                movingTime: run.movingTime
            ).map { current in
                RouteGeometry.paceSecondsPerKm(
                    distanceMeters: previous.distanceMeters,
                    movingTime: previous.movingTime
                ).map { current - $0 } ?? 0
            } ?? 0
            let hasPace = paceDifference != 0 || RouteGeometry.paceSecondsPerKm(
                distanceMeters: run.distanceMeters,
                movingTime: run.movingTime
            ) != nil
            let faster = paceDifference < 0
            let samePace = hasPace && abs(paceDifference) < 1
            // The total time is only worth quoting when both runs covered a
            // comparable distance.
            let comparableDistance = previous.distanceMeters > 0
                && abs(run.distanceMeters - previous.distanceMeters) / previous.distanceMeters < 0.05

            VStack(spacing: 3) {
                Text(samePace ? "SAME PACE ON THE SAME ROUTE" : (faster ? "FASTER ON THE SAME ROUTE" : "SLOWER ON THE SAME ROUTE"))
                    .font(Theme.Font.labelStrong)
                    .tracking(0.4)
                    .foregroundStyle(Theme.paperSecondary)
                if samePace {
                    // The same pace, so the time is the whole story.
                    Text(timeDifference == 0
                        ? "The same time as \(previous.startedAt.formatted(.dateTime.day().month(.abbreviated)))"
                        : "\(Format.duration(abs(timeDifference))) \(timeDifference < 0 ? "quicker" : "slower") than \(previous.startedAt.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(Theme.Font.metricValue)
                        .foregroundStyle(Theme.paperInk)
                } else {
                    Text("\(Format.paceDifference(abs(paceDifference))) per km \(faster ? "faster" : "slower")")
                        .font(Theme.Font.metricValue)
                        .foregroundStyle(Theme.paperInk)
                }
                if !samePace, comparableDistance {
                    Text("\(Format.duration(abs(timeDifference))) \(timeDifference < 0 ? "quicker" : "slower") in total")
                        .font(Theme.Font.footnote)
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
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.paperSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("LOGGED \(Format.receiptStamp(run.startedAt))")
                    .font(Theme.Font.labelStrong)
                Spacer()
                Text("PRINTED ON THIS PHONE")
                    .font(Theme.Font.label)
                    .tracking(0.3)
                    .foregroundStyle(Theme.paperSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tearGrip: some View {
        HStack(spacing: 7) {
            Image(systemName: isAtEnd ? "arrow.down" : "arrow.down.right")
                .font(Theme.Font.labelStrong)
            Text(gripTitle)
                .font(Theme.Font.footnote)
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
        // The paper moves during the pull. Measure in a stationary space so
        // its own offset cannot subtract from the finger's travel, causing
        // feedback jitter or a completed pull to spring back unexpectedly.
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
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
            .font(Theme.Font.label)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            // The height is a minimum, not a fixed size. A fixed height would
            // clip the label at the larger text sizes, which is exactly when
            // the label matters most.
            .frame(minHeight: 55)
            .padding(.vertical, 6)
            .background(
                isPrimary ? Theme.ink : Theme.tile,
                in: Capsule()
            )
            .foregroundStyle(isPrimary ? Theme.ground : Theme.ink)
            .shadow(color: .black.opacity(isPrimary ? 0 : 0.08), radius: 8, y: 3)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}
