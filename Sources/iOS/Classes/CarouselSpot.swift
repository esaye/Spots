// swiftlint:disable weak_delegate

import UIKit
import Brick

/// A CarouselSpot, a collection view based Spotable object that lays out its items in a horizontal order
open class CarouselSpot: NSObject, Gridable {

  public static var layout: Layout = Layout([:])
  public static var interaction: Interaction = Interaction([:])

  /// Child spots
  public var compositeSpots: [CompositeSpot] = []

  /// A SpotsFocusDelegate object
  weak public var focusDelegate: SpotsFocusDelegate?

  /// A boolean value that affects the sizing of items when using span, if enabled and the item count is less than the span, the CarouselSpot will even out the space between the items to align them
  open var dynamicSpan = false

  /// A Registry object that holds identifiers and classes for cells used in the CarouselSpot
  open static var views: Registry = Registry()

  /// A configuration closure that is run in setup(_:)
  open static var configure: ((_ view: UICollectionView, _ layout: UICollectionViewFlowLayout) -> Void)?

  /// A Registry object that holds identifiers and classes for headers used in the CarouselSpot
  open static var headers = Registry()

  /// A StateCache for the CarouselSpot
  open fileprivate(set) var stateCache: StateCache?

  /// A component struct used as configuration and data source for the CarouselSpot
  open var component: Component {
    willSet(value) {
      #if os(iOS)
        if let layout = component.layout {
          dynamicSpan = layout.dynamicSpan
          if component.items.count > 1 && layout.span > 0.0 {
            pageControl.numberOfPages = Int(floor(Double(component.items.count) / layout.span))
          }

          if layout.pageIndicator && pageControl.superview == nil {
            pageControl.frame.size.width = backgroundView.frame.width
            collectionView.backgroundView?.addSubview(pageControl)
          } else if layout.pageIndicator == false {
            pageControl.removeFromSuperview()
          }
        }
      #endif
    }
  }

  /// A configuration closure
  open var configure: ((SpotConfigurable) -> Void)? {
    didSet {
      guard let configure = configure else { return }
      for case let cell as SpotConfigurable in collectionView.visibleCells {
        configure(cell)
      }
    }
  }

  /// A CarouselScrollDelegate, used when a CarouselSpot scrolls
  open weak var carouselScrollDelegate: CarouselScrollDelegate?

  /// A SpotsDelegate that is used for the CarouselSpot
  open weak var delegate: SpotsDelegate?

  /// A UIPageControl, enable by setting pageIndicator to true
  open lazy var pageControl: UIPageControl = {
    let pageControl = UIPageControl()
    pageControl.frame.size.height = 22
    pageControl.pageIndicatorTintColor = UIColor.lightGray
    pageControl.currentPageIndicatorTintColor = UIColor.gray

    return pageControl
  }()

  /// A custom UICollectionViewFlowLayout
  open var layout: CollectionLayout

  /// A UICollectionView, used as the main UI component for a CarouselSpot
  open var collectionView: UICollectionView

  /// The collection views background view
  open lazy var backgroundView = UIView()

  public var userInterface: UserInterface?
  var spotDataSource: DataSource?
  var spotDelegate: Delegate?

  /// Initialize an instantiate of CarouselSpot
  ///
  /// - parameter component: A component
  /// - parameter collectionView: The collection view that the carousel should use for rendering
  /// - parameter layout: The object that the carousel should use for item layout
  ///
  /// - returns: An initialized carousel spot.
  ///
  /// In case you want to use a default collection view & layout, use `init(component:)`.
  public init(component: Component, collectionView: UICollectionView, layout: CollectionLayout) {
    self.component = component

    if self.component.layout == nil {
      self.component.layout = type(of: self).layout
    }

    if self.component.interaction == nil {
      self.component.interaction = type(of: self).interaction
    }

    collectionView.showsHorizontalScrollIndicator = false
    collectionView.showsVerticalScrollIndicator = false
    collectionView.alwaysBounceHorizontal = true
    collectionView.clipsToBounds = false
    self.collectionView = collectionView
    self.layout = layout

    super.init()
    self.userInterface = collectionView
    self.component.layout?.configure(spot: self)
    self.dynamicSpan = self.component.layout?.dynamicSpan ?? false
    self.spotDataSource = DataSource(spot: self)
    self.spotDelegate = Delegate(spot: self)

    if component.kind.isEmpty {
      self.component.kind = Component.Kind.carousel.string
    }

    registerDefault(view: CarouselSpotCell.self)
    registerComposite(view: CarouselComposite.self)
    registerDefaultHeader(header: CarouselSpotHeader.self)
    register()
    configureCollectionView()
  }

  /// Convenience initializer that creates an instance with a component
  ///
  /// - parameter component: The component model that the carousel should render
  public required convenience init(component: Component) {
    let layout = GridableLayout()
    layout.scrollDirection = .horizontal
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    self.init(component: component, collectionView: collectionView, layout: layout)
  }

  /// A convenience initializer for CarouselSpot with base configuration.
  ///
  /// - parameter component:   A Component.
  /// - parameter top:         Top section inset.
  /// - parameter left:        Left section inset.
  /// - parameter bottom:      Bottom section inset.
  /// - parameter right:       Right section inset.
  /// - parameter itemSpacing: The item spacing used in the flow layout.
  /// - parameter lineSpacing: The line spacing used in the flow layout.
  ///
  /// - returns: An initialized carousel spot with configured layout.
  public convenience init(_ component: Component, top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0, itemSpacing: CGFloat = 0, lineSpacing: CGFloat = 0) {
    self.init(component: component)

    layout.sectionInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    layout.minimumInteritemSpacing = itemSpacing
    layout.minimumLineSpacing = lineSpacing
  }

  /// Instantiate a CarouselSpot with a cache key.
  ///
  /// - parameter cacheKey: A unique cache key for the Spotable object.
  ///
  /// - returns: An initialized carousel spot.
  public convenience init(cacheKey: String) {
    let stateCache = StateCache(key: cacheKey)
    self.init(component: Component(stateCache.load()))
    self.stateCache = stateCache
  }

  deinit {
    spotDataSource = nil
    spotDelegate = nil
    userInterface = nil
  }

  /// Configure collection view with data source, delegate and background view
  public func configureCollectionView() {
    register()
    collectionView.dataSource = spotDataSource
    collectionView.delegate = spotDelegate
    collectionView.backgroundView = backgroundView
  }

  /// Setup Spotable component with base size
  ///
  /// - parameter size: The size of the superview
  open func setup(_ size: CGSize) {
    collectionView.frame.size = size
    prepareItems()

    if collectionView.contentSize.height > 0 {
      collectionView.frame.size.height = collectionView.contentSize.height
    } else {
      collectionView.frame.size.height = component.items.sorted(by: {
        $0.size.height > $1.size.height
      }).first?.size.height ?? 0

      if collectionView.frame.size.height > 0 {
        collectionView.frame.size.height += layout.sectionInset.top + layout.sectionInset.bottom
      }
    }

    if !component.header.isEmpty {
      let resolve = type(of: self).headers.make(component.header)
      layout.headerReferenceSize.width = collectionView.frame.size.width
      layout.headerReferenceSize.height = resolve?.view?.frame.size.height ?? 0.0
    }

    CarouselSpot.configure?(collectionView, layout)

    collectionView.frame.size.height += layout.headerReferenceSize.height

    if let componentLayout = component.layout {
      collectionView.frame.size.height += CGFloat(componentLayout.inset.top + componentLayout.inset.bottom)
    }

    guard component.layout?.pageIndicator == Optional(true) else {
      return
    }

    layout.sectionInset.bottom = layout.sectionInset.bottom
    layout.sectionInset.bottom += pageControl.frame.size.height
    pageControl.frame.origin.y = collectionView.frame.size.height - pageControl.frame.size.height
  }
}

/// A scroll view extension on CarouselSpot to handle scrolling specifically for this object.
extension Delegate: UIScrollViewDelegate {

  /// Tells the delegate when the user scrolls the content view within the receiver.
  ///
  /// - parameter scrollView: The scroll-view object in which the scrolling occurred.
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard let spot = spot as? CarouselSpot else {
      return
    }

    /// This will restrict the scroll view to only scroll horizontally.
    let constrainedYOffset = spot.collectionView.contentSize.height - spot.collectionView.frame.size.height
    if constrainedYOffset >= 0.0 {
      spot.collectionView.contentOffset.y = constrainedYOffset
    }

    spot.carouselScrollDelegate?.spotableCarouselDidScroll(spot)
  }

  #if os(iOS)

  public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    guard let spot = spot as? CarouselSpot else {
      return
    }

    spot.carouselScrollDelegate?.spotableCarouselDidEndScrollingAnimated(spot)
  }

  #endif

  /// Tells the delegate when the user finishes scrolling the content.
  ///
  /// - parameter scrollView:          The scroll-view object where the user ended the touch.
  /// - parameter velocity:            The velocity of the scroll view (in points) at the moment the touch was released.
  /// - parameter targetContentOffset: The expected offset when the scrolling action decelerates to a stop.
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    guard let spot = spot as? CarouselSpot else {
      return
    }

    #if os(iOS)
      guard spot.component.interaction?.paginate == .page else {
        return
      }
    #endif

    let pointXUpperBound = spot.layout.collectionViewContentSize.width - scrollView.frame.width / 2
    var point = targetContentOffset.pointee
    point.x += scrollView.frame.width / 2
    var indexPath: IndexPath?

    while indexPath == nil && point.x < pointXUpperBound {
      indexPath = spot.collectionView.indexPathForItem(at: point)
      point.x += max(spot.layout.minimumInteritemSpacing, 1)
    }

    guard let centerIndexPath = indexPath else {
      return
    }

    guard let centerLayoutAttributes = spot.layout.layoutAttributesForItem(at: centerIndexPath) else {
      return
    }

    targetContentOffset.pointee.x = centerLayoutAttributes.frame.midX - scrollView.frame.width / 2
  }
}
