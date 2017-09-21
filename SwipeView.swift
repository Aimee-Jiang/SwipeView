//
//  SwipeView
// 
//  SwipeView is a class designed to replace table view, and to show fade in-out bluring UI vertically
//  when user swipes between different 'cells'. A bar-typed pagination is also showed at the left side.
//
//  It's implemented basing on a UIScrollView, and UITableView-styled dataSource/delgate are included
//  to make it behavoir just like a UITableView
//

import UIKit

struct SwipeViewCell {
    let view: UIView
    let index: Int
}

protocol SwipeViewDataSource: class {
    func numberOfCellsIn(swipeView: SwipeView) -> Int
    func swipeView(_ swipeView: SwipeView, cellForRowAt index: Int, reusingCell: UIView?) -> UIView
}

protocol SwipeViewDelegate: class {
    func swipeView(_ swipeView: SwipeView, didDisplayCell cell: SwipeViewCell)
    func swipeView(_ swipeView: SwipeView, didSelectCell cell: SwipeViewCell)
    func swipeView(_ swipeView: SwipeView, translatingBetweenTopCell cell: SwipeViewCell, bottomCell: SwipeViewCell, topCellPercent: CGFloat)

    // Note:
    // 1. Those 2 functions only control the animations inside the cell, and cell position is calculated
    //    automatically by function SwipeView.updateCell()
    // 2. The value of percent is in [-1, 1], and it's positive when user is swiping from top to bottom,
    //    otherwise it's negative when user is swiping bottom to top
    // 3. When fading in, percent is ranged from 0 ~ 1, or 0 ~ -1, and 0 means that cell is invisible
    // 4. When fanding out, percent is ranged from 0 ~ 1, or 0 ~ -1, and 0 means that cell is visible
    func swipeView(_ swipeView: SwipeView, fadeInCell cell: SwipeViewCell, withPercent percent: CGFloat)
    func swipeView(_ swipeView: SwipeView, fadeOutCell cell: SwipeViewCell, withPercent percent: CGFloat)
}

extension SwipeViewDelegate {
    func swipeView(_ view: SwipeView, fadeInCell cell: SwipeViewCell, withPercent percent: CGFloat) {
        swipeView(view, updateCell: cell, withPercent: percent, isFadingIn: true)
    }

    func swipeView(_ view: SwipeView, fadeOutCell cell: SwipeViewCell, withPercent percent: CGFloat) {
        swipeView(view, updateCell: cell, withPercent: percent, isFadingIn: false)
    }

    private func swipeView(_ swipeView: SwipeView, updateCell cell: SwipeViewCell, withPercent percent: CGFloat, isFadingIn: Bool) {
        guard let cellNum = swipeView.dataSource?.numberOfCellsIn(swipeView: swipeView) else {
            return
        }
        let isFirstCell = cell.index == 0 && percent <= 0
        let isLastCell = cell.index == cellNum - 1 && percent >= 0

        guard !isFirstCell, !isLastCell else {
            cell.view.layer.opacity = 1
            return
        }

        cell.view.layer.opacity = Float(isFadingIn ? fabs(percent) : 1 - fabs(percent))
    }
}

class SwipeView: UIView, UIScrollViewDelegate {

    weak var dataSource: SwipeViewDataSource?
    weak var delegate: SwipeViewDelegate?

    var currentIndex: Int? = nil {
        didSet(oldValue) {
            guard let newValue = currentIndex, newValue != oldValue, let cell = visibleCellsDict[newValue] else {
                return
            }
            delegate?.swipeView(self, didDisplayCell: cell)
            paginationView.currentPage = newValue
        }
    }

    var currentCell: SwipeViewCell? {
        guard let currentIndex = currentIndex else {
            return nil
        }
        return visibleCellsDict[currentIndex]
    }

    private let paginationView = LeftBarPageControl()
    fileprivate let scrollView = UIScrollView()

    // As we should at most 2 UIViews at the same time, so both cellsPool and visibleCellsDict contains
    // at most 2 items inside
    private var cellsPool = Set<UIView>()
    private var visibleCellsDict = [Int: SwipeViewCell]()

    var topCell: SwipeViewCell? {
        guard !visibleCellsDict.isEmpty else {
            return nil
        }

        var item = visibleCellsDict.first!

        visibleCellsDict.forEach {
            if $0.key < item.key {
                item = $0
            }
        }
        return item.value
    }

    var bottomCell: SwipeViewCell? {
        guard !visibleCellsDict.isEmpty else {
            return nil
        }

        var item = visibleCellsDict.first!

        visibleCellsDict.forEach {
            if $0.key > item.key {
                item = $0
            }
        }
        return item.value
    }

    private struct Constants {
        static let paginationControlWidth: CGFloat = 6.0
        static let paginationControlYOffset: CGFloat = 82.0
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        didInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        didInit()
    }

    fileprivate func didInit() {
        setupScrollView()
        setupScrollIndicator()
    }

    // MARK: - Public Methods

    func reloadData() {
        for (_, cell) in visibleCellsDict {
            cell.view.removeFromSuperview()
            queueCell(cell)
        }
        visibleCellsDict.removeAll()
        scrollToViewAtIndex(0)

        paginationView.numberOfPages = numberOfCells
        paginationView.currentPage = 0
    }

    func scrollToViewAtIndex(_ index: Int?) {
        let yOffset: CGFloat

        if var index = index {
            index = max(0, min(index, numberOfCells))
            yOffset = CGFloat(index) * cellHeight
        } else {
            yOffset = 0
        }

        scrollView.contentSize = contentSize()
        scrollView.contentOffset = CGPoint(x: 0, y: yOffset)
        refreshUI()

        currentIndex = visibleCellsDict.first?.key
    }

    var visibleCells: [SwipeViewCell] {
        return visibleCellsDict.values.map { $0 }
    }

    // MARK: - UI Layout

    override public func layoutSubviews() {
        super.layoutSubviews()

        let oldCurrentIndex = currentIndex
        paginationView.frame = CGRect(x: bounds.width - Constants.paginationControlWidth, y: Constants.paginationControlYOffset, width: Constants.paginationControlWidth, height: bounds.height - Constants.paginationControlYOffset)
        scrollView.frame = bounds
        scrollToViewAtIndex(oldCurrentIndex)
    }

    // MARK: - Views (Cells)

    // Refresh UI according to scrollView.contentOffset
    private func refreshUI() {
        // load or unload cells
        loadOrUnloadCellsIfNeeded()

        // update cell positions and opacity
        for (_, cell) in visibleCellsDict {
            updateCell(cell)
        }

        // reorder cell hierarchy
        guard let topCell = topCell, let bottomCell = bottomCell else {
            return
        }
        scrollView.bringSubview(toFront: bottomCell.view)

        // send translating percent to delegation
        delegate?.swipeView(self, translatingBetweenTopCell: topCell, bottomCell: bottomCell,
                            topCellPercent: fabs(modf(currentPercentIndex).1))
    }

    private func loadOrUnloadCellsIfNeeded() {
        let visibleIndexes = currentVisibleIndexes

        // load or unload views if needed
        var oldVisibleIndexes = Set<Int>()

        for idx in visibleCellsDict.keys {
            oldVisibleIndexes.insert(idx)
        }

        for idx in oldVisibleIndexes.subtracting(visibleIndexes) {
            let cell = visibleCellsDict.removeValue(forKey: idx)
            queueCell(cell)
            cell?.view.removeFromSuperview()
        }

        // layout UI for all visible cells
        for idx in visibleIndexes.subtracting(oldVisibleIndexes) {
            if let view = dataSource?.swipeView(self, cellForRowAt: idx, reusingCell: dequeueCell()) {
                visibleCellsDict[idx] = SwipeViewCell(view: view, index: idx)
                scrollView.addSubview(view)
            }
        }

        // calculate current index dynamically, to avoid currentIndex out of currentVisibleIndexes's scope
        currentIndex = potentialCurrentIndex()
    }

    // Update cell appearence according to current scroll position, including position, opacity
    private func updateCell(_ cell: SwipeViewCell) {
        let maxIndex = numberOfCells - 1

        // cell position
        if (cell.index == 0 && currentPercentIndex <= 0) || (cell.index == maxIndex && currentPercentIndex >= CGFloat(maxIndex)) {
            cell.view.frame = CGRect(x: 0, y: cellHeight * CGFloat(cell.index), width: cellWidth, height: cellHeight)
        } else {
            cell.view.frame = CGRect(x: 0, y: floor(scrollView.contentOffset.y), width: cellWidth, height: cellHeight)
        }

        // update animations inside the cell
        if let fadeInPercent = fadingInPercentForCell(cell) {
            delegate?.swipeView(self, fadeInCell: cell, withPercent: fadeInPercent)
        } else if let fadeOutPercent = fadingOutPercentForCell(cell) {
            delegate?.swipeView(self, fadeOutCell: cell, withPercent: fadeOutPercent)
        } else {
            delegate?.swipeView(self, fadeOutCell: cell, withPercent: 0.0)
        }
    }

    // if cell is fading in, then return its animation percent, otherwise return nil
    private func fadingInPercentForCell(_ cell: SwipeViewCell) -> CGFloat? {
        guard let currentIndex = currentIndex, abs(currentIndex - cell.index) == 1 else {
            // this cell is not fading in, maybe is fading out
            return nil
        }

        let percent = currentPercentIndex - CGFloat(currentIndex)
        guard abs(percent) <= 1 else {
            // if scrolling to top happens, fabs(percent) may greater than 1
            return percent < 0 ? -1 : 1
        }

        return percent
    }

    // if cell is fading out, then return its animation percent, otherwise return nil
    private func fadingOutPercentForCell(_ cell: SwipeViewCell) -> CGFloat? {
        let isFadingOutCell = currentIndex == cell.index
        let isFirstCell = currentPercentIndex < 0 && currentIndex == 0
        let isLastCell = currentPercentIndex > CGFloat(numberOfCells - 1) && currentIndex == numberOfCells - 1

        guard isFadingOutCell, !isFirstCell, !isLastCell else {
            return nil
        }

        let percent = currentPercentIndex - CGFloat(cell.index)
        guard (0.000_001 ... 1.0).contains(abs(percent)) else {
            // user scrolls a small offset, or scroll to top
            return nil
        }
        return percent
    }

    private func queueCell(_ cell: SwipeViewCell?) {
        guard let cell = cell else {
            return
        }
        cellsPool.insert(cell.view)
    }

    private func dequeueCell() -> UIView? {
        return cellsPool.popFirst()
    }

    var currentPercentIndex: CGFloat {
        return scrollView.contentOffset.y / cellHeight
    }

    private var currentVisibleIndexes: Set<Int> {
        let num = numberOfCells

        guard num > 0  else {
            return Set<Int>()
        }

        var indexes = Set<Int>()
        let percentIndex = currentPercentIndex

        if num == 1 || currentPercentIndex <= 0 {
            indexes.insert(0)
        } else if currentPercentIndex >= CGFloat(num - 1) {
            indexes.insert(num - 1)
        } else {
            indexes.insert( Int(floor(percentIndex)) )
            indexes.insert( Int(ceil(percentIndex)) )
        }

        return indexes
    }

    private var numberOfCells: Int {
        guard let num = dataSource?.numberOfCellsIn(swipeView: self), num > 0 else {
            return 0
        }
        return num
    }

    // MARK: - Scroll View UI

    private func setupScrollIndicator() {
        paginationView.hidesForSinglePage = true
        paginationView.pageIndicatorTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.2)
        paginationView.currentPageIndicatorTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.6)
        paginationView.backgroundColor = UIColor.clear
        addSubview(paginationView)
    }

    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = UIColor.clear
        scrollView.frame = bounds
        scrollView.delegate = self
        addSubview(scrollView)
    }

    private func contentSize() -> CGSize {
        var num = numberOfCells
        num = (num < 0) ? 0 : num

        if num == 1 {
            // when there is only one item here, set contentSize a little lager in order to make scrollView can scroll
            return CGSize(width: cellWidth, height: cellHeight + 1)
        }
        return CGSize(width: cellWidth, height: cellHeight * CGFloat(num))
    }

    private var cellWidth: CGFloat {
        guard frame.size.width > 1 else {
            return 1
        }
        return floor(frame.size.width)
    }

    private var cellHeight: CGFloat {
        guard frame.size.height > 1 else {
            return 1
        }
        return floor(frame.size.height)
    }

    // calculate current index from scrollview's content offset
    private func potentialCurrentIndex() -> Int? {
        let visibleIndexes = currentVisibleIndexes
        guard let minIndex = visibleIndexes.min(), let maxIndex = visibleIndexes.max() else {
            return nil
        }

        guard let currentIndex = currentIndex else {
            return minIndex
        }

        return min(max(currentIndex, minIndex), maxIndex)
    }

    // MARK: - UIScrollViewDelegate 

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshUI()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollToViewAtIndex(currentVisibleIndexes.first)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollToViewAtIndex(currentVisibleIndexes.first)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        showPagination()
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        scrollToViewAtIndex(currentVisibleIndexes.first)
    }

    func showPagination() {
        // show paginationView when user taps on the scroll view
        paginationView.flashPageIndicatorsIfNeeded()
    }
}
