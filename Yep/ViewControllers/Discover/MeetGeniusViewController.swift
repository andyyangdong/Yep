//
//  MeetGeniusViewController.swift
//  Yep
//
//  Created by NIX on 16/5/27.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit
import YepKit
import YepNetworking

class MeetGeniusViewController: UIViewController {

    var tapBannerAction: ((url: NSURL) -> Void)?
    var showGeniusInterviewAction: ((geniusInterview: GeniusInterview) -> Void)?

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            let view = MeetGeniusShowView(frame: CGRect(x: 0, y: 0, width: 100, height: 180))
            view.tapAction = { [weak self] url in
                self?.tapBannerAction?(url: url)
            }

            tableView.tableHeaderView = view
            tableView.tableFooterView = UIView()

            tableView.rowHeight = 90

            tableView.registerNibOf(GeniusInterviewCell)
            tableView.registerNibOf(LoadMoreTableViewCell)
        }
    }

    private lazy var noGeniusInterviewsFooterView: InfoView = InfoView(NSLocalizedString("No Interviews.", comment: ""))
    private lazy var fetchFailedFooterView: InfoView = InfoView(NSLocalizedString("Fetch Failed!", comment: ""))

    var geniusInterviews: [GeniusInterview] = []

    private var canLoadMore: Bool = false
    private var isFetchingGeniusInterviews: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        updateGeniusInterviews()
    }

    private enum UpdateGeniusInterviewsMode {
        case Top
        case LoadMore
    }

    private func updateGeniusInterviews(mode mode: UpdateGeniusInterviewsMode = .Top, finish: (() -> Void)? = nil) {

        if isFetchingGeniusInterviews {
            finish?()
            return
        }

        isFetchingGeniusInterviews = true

        let maxNumber: Int?
        switch mode {
        case .Top:
            canLoadMore = true
            maxNumber = nil
        case .LoadMore:
            maxNumber = geniusInterviews.last?.number
        }

        let failureHandler: FailureHandler = { reason, errorMessage in

            SafeDispatch.async { [weak self] in

                if case .Top = mode {
                    self?.geniusInterviews = []
                    self?.tableView.reloadData()
                }

                self?.tableView.tableFooterView = self?.fetchFailedFooterView

                self?.isFetchingGeniusInterviews = false

                finish?()
            }

            defaultFailureHandler(reason: reason, errorMessage: errorMessage)
        }

        let count = 10
        geniusInterviewsWithCount(count, afterNumber: maxNumber, failureHandler: failureHandler, completion: { [weak self] geniusInterviews in

            SafeDispatch.async { [weak self] in

                if case .Top = mode where geniusInterviews.isEmpty {
                    self?.tableView.tableFooterView = self?.noGeniusInterviewsFooterView
                } else {
                    self?.tableView.tableFooterView = UIView()
                }

                guard let strongSelf = self else {
                    return
                }

                strongSelf.canLoadMore = (geniusInterviews.count == count)

                let newGeniusInterviews = geniusInterviews
                let oldGeniusInterviews = strongSelf.geniusInterviews

                var wayToUpdate: UITableView.WayToUpdate = .None

                if oldGeniusInterviews.isEmpty {
                    wayToUpdate = .ReloadData
                }

                switch mode {

                case .Top:
                    strongSelf.geniusInterviews = newGeniusInterviews

                    wayToUpdate = .ReloadData

                case .LoadMore:
                    let oldGeniusInterviewsCount = oldGeniusInterviews.count

                    let oldGeniusInterviewNumberSet = Set<Int>(oldGeniusInterviews.map({ $0.number }))
                    var realNewGeniusInterviews = [GeniusInterview]()
                    for geniusInterview in newGeniusInterviews {
                        if !oldGeniusInterviewNumberSet.contains(geniusInterview.number) {
                            realNewGeniusInterviews.append(geniusInterview)
                        }
                    }
                    strongSelf.geniusInterviews += realNewGeniusInterviews

                    let newGeniusInterviewsCount = strongSelf.geniusInterviews.count

                    let indexPaths = Array(oldGeniusInterviewsCount..<newGeniusInterviewsCount).map({ NSIndexPath(forRow: $0, inSection: Section.GeniusInterview.rawValue) })
                    if !indexPaths.isEmpty {
                        wayToUpdate = .Insert(indexPaths)
                    }
                }

                wayToUpdate.performWithTableView(strongSelf.tableView)

                self?.isFetchingGeniusInterviews = false

                finish?()
            }
        })
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension MeetGeniusViewController: UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int {
        case GeniusInterview
        case LoadMore
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {

        return 2
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        guard let section = Section(rawValue: section) else {
            fatalError("Invalid Section")
        }

        switch section {

        case .GeniusInterview:
            return geniusInterviews.count

        case .LoadMore:
            return geniusInterviews.isEmpty ? 0 : 1
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Invalid Section")
        }

        switch section {

        case .GeniusInterview:
            let cell: GeniusInterviewCell = tableView.dequeueReusableCell()
            let geniusInterview = geniusInterviews[indexPath.row]
            cell.configure(withGeniusInterview: geniusInterview)
            return cell

        case .LoadMore:
            let cell: LoadMoreTableViewCell = tableView.dequeueReusableCell()
            cell.isLoading = true
            return cell
        }
    }

    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {

        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Invalid Section")
        }

        switch section {

        case .GeniusInterview:
            break

        case .LoadMore:
            guard let cell = cell as? LoadMoreTableViewCell else {
                break
            }

            guard canLoadMore else {
                cell.isLoading = false
                break
            }

            println("load more feeds")

            if !cell.isLoading {
                cell.isLoading = true
            }

            updateGeniusInterviews(mode: .LoadMore, finish: {
                delay(0.5) { [weak cell] in
                    cell?.isLoading = false
                }
            })
        }
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {

        defer {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }

        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Invalid Section")
        }

        switch section {

        case .GeniusInterview:
            let geniusInterview = geniusInterviews[indexPath.row]
            showGeniusInterviewAction?(geniusInterview: geniusInterview)

        case .LoadMore:
            break
        }
    }
}

