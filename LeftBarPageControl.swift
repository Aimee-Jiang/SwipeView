import UIKit

/**
 * A kind of narrow pagination bar that can be shown with your table view or collection view to indicate its scroll progress
 *
 * FEATURES:
 * 1) A list of bars are layouted vertically in the view
 * 2) Anmation is shown when changed from one page to another page
 * 3) Bars are faded out if currentPage is not changed in certain seconds
 * 4) Bars are faded in immediately if currentPage is changed
 *
 * See Also: `UIPageControl`
 */

class LeftBarPageControl: UIControl {

    @IBInspectable var currentPage: Int {
        get {
#if !TARGET_INTERFACE_BUILDER
            return _currentPage
#else // this code will execute only in IB
            return max(0, min(Int(_currentPage), numberOfPages - 1))
#endif
        }
        set {
            setCurrentPage(newValue)
        }
    }
    fileprivate var _currentPage: Int = 0

    private func setCurrentPage(_ newPage: Int, animated: Bool = false) {
#if !TARGET_INTERFACE_BUILDER
        let newPage = max(0, min(newPage, numberOfPages - 1))
#endif

        if _currentPage != newPage {
            _currentPage = newPage
            updateHighlightedIndicator(animated: animated)
        }
        flashPageIndicatorsIfNeeded()
    }

    @IBInspectable var numberOfPages: Int = 0 {
        didSet {
            if numberOfPages != oldValue {
                calcIndicatorHeight()
                invalidateIntrinsicContentSize()
                updateColors()
            }
            setCurrentPage(currentPage, animated: false)
        }
    }

    @IBInspectable var hidesForSinglePage: Bool = false {
        didSet {
            isHidden = hidesForSinglePage && numberOfPages <= 1
        }
    }

    func updateCurrentPageDisplay() {
        updateHighlightedIndicator()
    }

    @IBInspectable var pageIndicatorTintColor: UIColor? = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.2)

    @IBInspectable var currentPageIndicatorTintColor: UIColor? = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.6)

    // MARK: - Private

    fileprivate var normalIndicatorColor: UIColor {
        return pageIndicatorTintColor ?? tintColor
    }

    fileprivate var highlightedIndicatorColor: UIColor {
        return currentPageIndicatorTintColor ?? tintColor
    }

    fileprivate let currentPageChangeAnimationDuration: TimeInterval = 0.3

    fileprivate let highlightedPageIndicator = UIView()      // the highlighted bar

    fileprivate let defaultControlWidth: Float = 6            // intrinsic width for current view
    fileprivate let defaultInsetSize: CGFloat = 2             // top/bottom gap for the first/last bar
    fileprivate let pageIndicatorDefaultWidth: Float = 2      // bar width for normal state
    fileprivate let pageIndicatorHighlightedWidth: Float = 4  // bar width for highlighted state
    fileprivate let pageIndicatorSpacing: Float = 2           // gap between each bar
    fileprivate let minimumIndicatorHeight: Float = 28        // minimum bar height
    fileprivate var pageIndicatorHeight: Float = 2 {          // current bar height
        didSet {
            highlightedPageIndicator.frame = frame(forHighlightedPage: currentPage)
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

        didInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        didInit()
    }

    fileprivate func didInit() {
        addSubview(highlightedPageIndicator)
        calcIndicatorHeight()
        updateColors()
        updateHighlightedIndicator(animated: false)
    }
}

// MARK: - Page Display & Animation

private extension LeftBarPageControl {

    func updateHighlightedIndicator(animated: Bool = false) {
        if animated && currentPageChangeAnimationDuration > 0.0 {
            UIView.animate(withDuration: currentPageChangeAnimationDuration, animations: {
                self.highlightedPageIndicator.frame = self.frame(forHighlightedPage: self.currentPage)
            }, completion: { (_) in
                self.setNeedsDisplay()
            })
        } else {
            highlightedPageIndicator.frame = frame(forHighlightedPage: currentPage)
            setNeedsDisplay()
        }
    }
}

// MARK: - Tint Color

extension LeftBarPageControl {
    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateColors()
    }
}

// MARK: - Subview Layout

extension LeftBarPageControl {
    override func layoutSubviews() {
        super.layoutSubviews()
        calcIndicatorHeight()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let highlightedFrame = frame(forHighlightedPage: currentPage)
        let highlightedYRange = (highlightedFrame.origin.y ... highlightedFrame.origin.y + highlightedFrame.size.height)

        for index in (0..<numberOfPages) {
            for rect in truncate(rect: frame(forPage: index), betweenYRange: highlightedYRange) {
                normalIndicatorColor.set()
                UIBezierPath(rect: rect).fill()
            }
        }
    }

    // truncate a rectangle to make sure final pieces not overlaped with y-ranged areas.
    // for example: trancate rect(x: 0, y: 0, width: 10, height: 10) with y range (1, 2), then it returns 
    // two rects rect1(x: 0, y: 1, width: 10, height: 1) rect2(x: 0, y: 2, width: 10, height: 8)
    private func truncate(rect: CGRect, betweenYRange r1: ClosedRange<CGFloat>) -> [CGRect] {
        let r2 = (rect.origin.y ... rect.origin.y + rect.size.height)
        let minOverlapY = max(r1.lowerBound, r2.lowerBound)
        let maxOverlapY = min(r1.upperBound, r2.upperBound)

        guard maxOverlapY > minOverlapY else {
            return [rect]
        }

        var results: [CGRect] = []

        if minOverlapY > r2.lowerBound {
            results.append(CGRect(x: rect.origin.x, y: r2.lowerBound, width: rect.size.width, height: minOverlapY - r2.lowerBound))
        }
        if maxOverlapY < r2.upperBound {
            results.append(CGRect(x: rect.origin.x, y: maxOverlapY, width: rect.size.width, height: r2.upperBound - maxOverlapY))
        }

        return results
    }
}

// MARK: - Interface Builder

extension LeftBarPageControl {

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        updateColors()
    }

}

// MARK: - Page Indicators

private extension LeftBarPageControl {

    func calcIndicatorHeight() {
        if numberOfPages == 0 {
            pageIndicatorHeight = Float(bounds.height - 2 * defaultInsetSize)
        } else {
            pageIndicatorHeight = (Float(bounds.height - 2 * defaultInsetSize) - pageIndicatorSpacing * (Float(numberOfPages) - 1)) / Float(numberOfPages)
        }
    }

    func frame(forPage page: Int) -> CGRect {
        return CGRect(
            x: bounds.width - CGFloat(pageIndicatorDefaultWidth),
            y: CGFloat(pageIndicatorHeight + pageIndicatorSpacing) * CGFloat(page) + defaultInsetSize,
            width: CGFloat(pageIndicatorDefaultWidth),
            height: CGFloat(pageIndicatorHeight))
    }

    func frame(forHighlightedPage page: Int) -> CGRect {
        var rect = frame(forPage: page)
        rect.size.width = CGFloat(pageIndicatorHighlightedWidth)
        rect.origin.x = bounds.width - CGFloat(pageIndicatorHighlightedWidth)

        if pageIndicatorHeight < minimumIndicatorHeight {
            rect.origin.y += (rect.size.height - CGFloat(minimumIndicatorHeight)) / 2.0
            rect.size.height = CGFloat(minimumIndicatorHeight)
        }

        return rect
    }

}

// MARK: - Appearance

extension LeftBarPageControl {
    func flashPageIndicatorsIfNeeded() {
        let shouldAlwaysBeHidden = hidesForSinglePage && numberOfPages <= 1

        if shouldAlwaysBeHidden {
            isHidden = true
        } else {
            flashPageIndicators()
        }
    }

    fileprivate func updateColors() {
        highlightedPageIndicator.backgroundColor = highlightedIndicatorColor
        setNeedsDisplay()
    }

    // show pagination up immediately, then hide it automatically after certain seconds
    fileprivate func flashPageIndicators() {
        isHidden = false
        fadeOut()
    }

    fileprivate func fadeOut() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_fadeOut), object: nil)
        self.perform(#selector(_fadeOut), with: nil, afterDelay: 2)
    }

    @objc fileprivate func _fadeOut() {
        UIView.animate(withDuration: currentPageChangeAnimationDuration, animations: {
            self.alpha = 0
        }) { (_) in
            self.alpha = 1
            self.isHidden = true
        }
    }
}
