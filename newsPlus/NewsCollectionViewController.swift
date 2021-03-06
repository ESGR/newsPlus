//
//  NewsCollectionViewController.swift
//  newsPlus
//
//  Created by Giancarlo Daniele on 9/3/14.
//  Copyright (c) 2014 Giancarlo Daniele. All rights reserved.
//

import UIKit
import CoreLocation

let reuseIdentifier = "newsCell"

class NewsCollectionViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UINavigationBarDelegate {
    var collectionView: UICollectionView?
    let kImageViewTag : Int = 11 //the imageView for the collectionViewCell is tagged with 11 in IB
    let kHeaderViewTag : Int = 33 //the header for the collectionViewCell is tagged with 33 in IB
    let kFooterViewTag : Int = 22 //the footer for the collectionViewCell is tagged with 22 in IB
    let kNavbarTag : Int = 87
    var api : YahooApi = YahooApi.sharedInstance //shared instance of our api helper
    dynamic var accessToken : String! //dynamic KVO variable that sets access_token from UIWebView presented in this controller
    let activityIndicator : UIActivityIndicatorView! = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray) //for loading UIWebView
    var stateStatusView : UIView! // UIView overlay that communicates state messages to user
    var navBar : UINavigationBar!
    var imageDownloadsInProgress = Dictionary<NSIndexPath, YahooNewsDownloader>() // Mutable data structure of images currently being downloaded. We are lazy loading!
    var yahooNewsItems : [YahooNewsItem] = [YahooNewsItem]() // Mutable data structure supporting uicollectionvioew
    
    var refreshControl : UIRefreshControl! = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
        layout.itemSize = CGSize(width: CGFloat(YahooAPIConstants().cellWidth), height: CGFloat(YahooAPIConstants().cellHeight))
        //add the image view for photo display
        collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: layout)
        collectionView!.dataSource = self
        collectionView!.delegate = self
        collectionView!.registerNib(UINib(nibName: "YahooNewsItemCollectionViewCell", bundle: NSBundle.mainBundle()), forCellWithReuseIdentifier: reuseIdentifier)
        collectionView!.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(collectionView!)
        
        // add KVO
        addobservers()
        
        //set up uinavigation bar
        navBar = UINavigationBar()
        navBar.frame = CGRectMake(0, 20, self.view.frame.size.width, 44)
        navBar.delegate = self
        
        //navbar titles and location swapping
        var item = UINavigationItem(title: "Loading News from Yahoo!..")
        navBar.pushNavigationItem(item, animated: true)
        navBar.tag = kNavbarTag
        self.view.addSubview(navBar)
        self.collectionView?.alwaysBounceVertical = true
        
        refreshControl.addTarget(self, action: "refresh", forControlEvents: UIControlEvents.ValueChanged)
        self.collectionView?.addSubview(refreshControl)
    }
    
    override func viewDidDisappear(animated: Bool) {
        removeObservers()
    }
    
    override func viewWillAppear(animated: Bool) {
        api.requestAndLoadYahooNewsfeed({ (newsItems) -> () in
            self.yahooNewsItems = newsItems as [YahooNewsItem]
            self.yahooNewsItemsLoaded()
        }, failure: { () -> () in
            //
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        for (key, downloader) in imageDownloadsInProgress {
            downloader.cancelDownload({
                println("DEBUG: Cancelled download successfully")
            })
        }
        self.imageDownloadsInProgress.removeAll(keepCapacity: false)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView?.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)
        self.collectionView?.reloadData()
    }
    
    func refresh() {
        println("Refreshing feed...")
        refreshControl.removeFromSuperview()

    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return yahooNewsItems.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var screenSize = UIScreen.mainScreen().bounds.size
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as YahooNewsItemCollectionViewCell
        
//        Load the newsItem for this cell
        if yahooNewsItems.count >= indexPath.row {
            var item : YahooNewsItem = yahooNewsItems[indexPath.row]
            cell.item = item
            if let uuid : String = item.uuid {
                cell.uuid = uuid
            } else {
                println("ERROR: cell without uuid")
            }
            if let publisherString : String = item.publisher {
                cell.publisherLabel.text = publisherString
            } else {
                cell.publisherLabel.text = ""
            }
            if let titleString : String = item.title {
                cell.titleLabel.text = titleString
            } else {
                cell.titleLabel.text = ""
            }
            
            if (item.fullImage == nil) {
                // Dispatch operation to download the image
                if self.collectionView?.dragging == false && self.collectionView?.decelerating == false
                {
                    startPhotoDownload(item, indexPath: indexPath)
                }
                if let imageView = cell.viewWithTag(kImageViewTag) as? UIImageView {
                    imageView.image = UIImage(named: "placeholder")
                }
            } else {
                if let imageView = cell.viewWithTag(kImageViewTag) as? UIImageView {
                    imageView.image = item.fullImage
                }
            }

        }
        return cell
    }
    
    // Starts PhotoDownload for Photo at index
    func startPhotoDownload(newsItem : YahooNewsItem, indexPath : NSIndexPath) {
        var downloader = self.imageDownloadsInProgress[indexPath]
        
        if (downloader == nil) {
            downloader = YahooNewsDownloader()
            downloader?.newsItem = newsItem
            self.imageDownloadsInProgress[indexPath] = downloader
            downloader!.completion = {
                if let cell : YahooNewsItemCollectionViewCell = self.collectionView?.cellForItemAtIndexPath(indexPath) as? YahooNewsItemCollectionViewCell {
                    cell.imageView.image = newsItem.fullImage
                    self.imageDownloadsInProgress.removeValueForKey(indexPath)
                }
            }
            downloader?.startDownload()
        }
    }
    
    // This method is used in case the user scrolled into a set of cells that don't
    //  have their app icons yet.
    func loadImagesForOnscreenRows() {
        var item = self.yahooNewsItems[2]
        if self.yahooNewsItems.count > 0  {
            var visiblePaths = self.collectionView!.indexPathsForVisibleItems() as [NSIndexPath]
            for path in visiblePaths {
                var index : Int = path.row
                var item = self.yahooNewsItems[index]
                if (item.fullImage == nil) {
                    startPhotoDownload(item, indexPath: path)
                }
            }
        }
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.loadImagesForOnscreenRows()
        }
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.loadImagesForOnscreenRows()
        
        // Calculate where the collection view should be at the right-hand end item
        var height : CGFloat? = self.collectionView?.frame.size.height
        if let h : CGFloat = height {
            var contentOffsetWhenFullyScrolledDown = CGFloat(h) * CGFloat(self.yahooNewsItems.count - 1)
            
            if scrollView.contentOffset.y == CGFloat(contentOffsetWhenFullyScrolledDown) {
                var newIndexPath = NSIndexPath(forItem: 1, inSection: 0)
                self.collectionView?.scrollToItemAtIndexPath(newIndexPath, atScrollPosition: UICollectionViewScrollPosition.Bottom, animated: false)
            } else if scrollView.contentOffset.y == 0 {
                var newIndexPath = NSIndexPath(forItem: self.yahooNewsItems.count - 2, inSection: 0)
                self.collectionView?.scrollToItemAtIndexPath(newIndexPath, atScrollPosition: UICollectionViewScrollPosition.Bottom, animated: false)
            }
        }

    }
    
    //    MARK: Utilities
    func addobservers() {
        self.addObserver(api, forKeyPath: "accessToken", options: NSKeyValueObservingOptions.New, context: nil)
        self.addObserver(api, forKeyPath: "bestEffortAtLocation", options: NSKeyValueObservingOptions.New, context: nil)
        self.addObserver(self, forKeyPath: "currentLocation", options: NSKeyValueObservingOptions.New, context: nil)
    }
    
    func removeObservers() {
        self.removeObserver(api, forKeyPath: "accessToken")
        self.removeObserver(api, forKeyPath: "bestEffortAtLocation")
        self.removeObserver(self, forKeyPath: "currentLocation")
    }
    
    func yahooNewsItemsLoaded() {
        println("DEBUG: Downloaded YahooNewsItem objects")
        if self.yahooNewsItems.count > 0 {
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                if self.yahooNewsItems.count > 0 {
                    self.navBar.topItem?.title = "Recent News"
                    self.collectionView?.reloadData()
                }
            })
        }
    }
    
//    Toggles stateStatusView
    func toggleStateStatusView(enabled : Bool, text : String?) {
        if enabled{
            var screenBounds = UIScreen.mainScreen().bounds
            stateStatusView = UIView(frame: CGRect(x: 0, y: 20, width: screenBounds.size.width, height: screenBounds.size.height - 20))
            var messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 180, height: 100))
            messageLabel.text = text
            messageLabel.center = stateStatusView.center
            messageLabel.font = UIFont(name: "Helvetica Neue", size: 25)
            messageLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
            messageLabel.numberOfLines = 0
            messageLabel.textAlignment = NSTextAlignment.Center
            messageLabel.sizeToFit()
            messageLabel.textColor = UIColor.darkGrayColor()
            stateStatusView.addSubview(messageLabel)
            self.view.addSubview(stateStatusView)
        } else {
            if self.stateStatusView != nil {
                self.stateStatusView.removeFromSuperview()
                self.stateStatusView = nil
            }
        }
    }
    
//    UINavigationBar Delegates
    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.TopAttached
    }
    
    func uicolorFromHex(rgbValue:UInt32)->UIColor{
        let red = CGFloat((rgbValue & 0xFF0000) >> 16)/256.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8)/256.0
        let blue = CGFloat(rgbValue & 0xFF)/256.0
        
        return UIColor(red:red, green:green, blue:blue, alpha:1.0)
    }
}
