import SwiftUI


@available(iOS 13.0, *)
public struct SlideOverCard<Content> : View where Content : View {
    @Binding var defaultPosition : CardPosition
    @Binding var backgroundStyle: BackgroundStyle
    var content: () -> Content
    let configuration: SlideOverCardConfiguration
    
    public init(configuration: SlideOverCardConfiguration, position: Binding<CardPosition> = .constant(.middle), backgroundStyle: Binding<BackgroundStyle> = .constant(.solid), content: @escaping () -> Content) {
        self.configuration = configuration
        self.content = content
        self._defaultPosition = position
        self._backgroundStyle = backgroundStyle
    }
     
    public var body: some View {
        ModifiedContent(content: self.content(), modifier: Card(position: self.$defaultPosition, backgroundStyle: self.$backgroundStyle, configuration: configuration))
       }
}

public enum BackgroundStyle {
    case solid, clear, blur
}

public enum CardPosition: CGFloat {
    case bottom , middle, top
}

enum DragState {
    
    case inactive
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
    
    var isDragging: Bool {
        switch self {
        case .inactive:
            return false
        case .dragging:
            return true
        }
    }
}

public struct CardPositionsOffset {
    public let top: CGFloat
    public let middle: CGFloat
    public let bottom: CGFloat
    
    public init(top: CGFloat, middle: CGFloat, bottom: CGFloat) {
        self.top = top
        self.middle = middle
        self.bottom = bottom
    }
}

public struct SlideOverCardConfiguration {
    let offsetsFromTop: CardPositionsOffset
    
    public init(offsetsFromTop: CardPositionsOffset) {
        self.offsetsFromTop = offsetsFromTop
    }

    public func offsetFromTop(for position: CardPosition) -> CGFloat {
        switch position {
        case .bottom: return offsetsFromTop.bottom
        case .middle: return offsetsFromTop.middle
        case .top: return offsetsFromTop.top
        }
    }
}

struct Card: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @GestureState var dragState: DragState = .inactive
    @Binding var position : CardPosition
    @Binding var backgroundStyle: BackgroundStyle
    @State var offset: CGSize = CGSize.zero
    
    let configuration : SlideOverCardConfiguration
        
    var animation: Animation {
        Animation.interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)
    }
    
    var timer: Timer? {
        return Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
            if self.position == .top && self.dragState.translation.height == 0  {
                self.position = .top
            } else {
                timer.invalidate()
            }
        }
    }
    
    func body(content: Content) -> some View {
        let drag = DragGesture()
            .updating($dragState) { drag, state, transaction in state = .dragging(translation:  drag.translation) }
            .onChanged {_ in
                self.offset = .zero
        }
        .onEnded(onDragEnded)
        
        return ZStack(alignment: .top) {
            ZStack(alignment: .top) {

                if backgroundStyle == .blur {
                    BlurView(style: colorScheme == .dark ? .dark : .extraLight)
                }

                if backgroundStyle == .clear {
                    Color.clear
                }

                if backgroundStyle == .solid {
                    colorScheme == .dark ? Color.black : Color.white
                }

                Handle()
                
                content.padding(.top, 15)

            }
            .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(x: 1, y: 1, anchor: .center)
        }
        .offset(y:  max(0, offsetFromTop() + self.dragState.translation.height))
        .animation((self.dragState.isDragging ? nil : animation))
        .highPriorityGesture(drag)
    }
    
    private func offsetFromTop() -> CGFloat {
        configuration.offsetFromTop(for: position)
    }
    
    private func onDragEnded(drag: DragGesture.Value) {
        
        // Setting stops
        let higherStop: CardPosition
        let lowerStop: CardPosition
        
        // Nearest position for drawer to snap to.
        let nearestPosition: CardPosition
        
        // Determining the direction of the drag gesture and its distance from the top
        let dragDirection = drag.predictedEndLocation.y - drag.location.y
        let offsetFromTopOfView = offsetFromTop() + drag.translation.height
        
        // Determining whether drawer is above or below `.partiallyRevealed` threshold for snapping behavior.
        if offsetFromTopOfView <= configuration.offsetFromTop(for: .middle) {
            higherStop = .top
            lowerStop = .middle
        } else {
            higherStop = .middle
            lowerStop = .bottom
        }
        
        // Determining whether drawer is closest to top or bottom
        if (offsetFromTopOfView - configuration.offsetFromTop(for: higherStop)) < (configuration.offsetFromTop(for: lowerStop) - offsetFromTopOfView) {
            nearestPosition = higherStop
        } else {
            nearestPosition = lowerStop
        }
        
        // Determining the drawer's position.
        if dragDirection > 0 {
            position = lowerStop
        } else if dragDirection < 0 {
            position = higherStop
        } else {
            position = nearestPosition
        }
        _ = timer
    }
}

@available(iOS 13.0, *)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        return view
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<BlurView>) {}

}

@available(iOS 13.0, *)
struct Handle : View {
    private let handleThickness = CGFloat(5.0)
    var body: some View {
        RoundedRectangle(cornerRadius: handleThickness / 2.0)
            .frame(width: 40, height: handleThickness)
            .foregroundColor(Color.secondary)
            .padding(5)
    }
}
