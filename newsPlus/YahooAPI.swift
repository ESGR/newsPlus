//
//  YahooApi.swift
//  newsPlus
//
//  Created by Giancarlo Daniele on 9/5/14.
//  Copyright (c) 2014 Giancarlo Daniele. All rights reserved.
//

import UIKit
import CoreLocation

class YahooApi: NSObject {
    class var sharedInstance :YahooApi {
        struct Singleton {
            static let instance = YahooApi()
        }
        return Singleton.instance
    }
    var yahooNewsItems : [YahooNewsItem] = [YahooNewsItem]()
    var constantsInstance : YahooAPIConstants = YahooAPIConstants()
    var delegate = UIApplication.sharedApplication().delegate as AppDelegate
    
//   MARK: Networking
    //gets newsfeed objects from yahoo. returns success once they are successfully saved
    func requestAndLoadYahooNewsfeed(success: ([YahooNewsItem]) -> (), failure: () -> ()) {
        var urlString : String! = "\(YahooAPIConstants().KYAHOO_NEWS_STREAM_URL)"
        var url : NSURL = NSURL(string: urlString)
        YahooApi().httpGetRequestWithCallback(url, success: { (json) -> () in
            var newsItemsJson : JSONValue = JSONValue(json)
            var backgroundQueue = NSOperationQueue()
            backgroundQueue.addOperationWithBlock({ () -> Void in
                YahooApi().loadNewsItems(newsItemsJson, success: success)
            })
        }) { () -> () in
            failure()
        }
    }
    
    //inflates a yahooNewsItem.
    func requestInflationForItems(newsItemIds : [String], success: (NSDictionary) -> (), failure: () -> ()) {
        var allIdsString : String = String()
        for (index, idString) in enumerate(newsItemIds) {
            if index != newsItemIds.count - 1 {
                allIdsString = allIdsString + idString + ","
            } else {
                allIdsString = allIdsString + idString
            }
        }
        var urlString : String! = "\(YahooAPIConstants().KYAHOO_NEWS_STREAM_INFLATION_URL)\(allIdsString)"
        var url : NSURL = NSURL(string: urlString)
        YahooApi().httpGetRequestWithCallback(url, success: { (json) -> () in
            //
        }) { () -> () in
            failure()
        }
    }

//    Prints CURL version of NSMutableRequest
    func getCurl(request : NSMutableURLRequest) -> String {
        var curlString = "curl -k -X \(request.HTTPMethod) --dump-header -"
        for (key, obj) in request.allHTTPHeaderFields as Dictionary<String, String> {
            curlString = curlString + " -H \"\(key) : \(obj)\""
        }
        if let bodyData : NSData = request.HTTPBody {
            var data : String? = NSString(data: bodyData, encoding: NSUTF8StringEncoding) as String?
            
            if data != nil {
                curlString = curlString + " -d \"\(data!)\""
            }
        }
        if let url : NSURL = request.URL {
            curlString = curlString + " \(url.absoluteString!)"
        }
        return curlString
    }
    
//    HTTP GET request using NSURLSession
    func httpGetRequestWithCallback(url : NSURL, success: (NSDictionary) -> (), failure: () -> ()) {
        var session : NSURLSession = NSURLSession.sharedSession()
        var error : NSError?
        delegate.setNetworkActivityIndicatorVisible(true)
        session.dataTaskWithURL(url, completionHandler: {(data: NSData!, response: NSURLResponse!, error: NSError!) in
            if (error != nil) {
                println("ERROR: \(error)")
                failure()
            } else {
                var httpResponse : NSHTTPURLResponse = response as NSHTTPURLResponse
                if httpResponse.statusCode == 200 {
                    // this has to be done in ObjC Foundation!
                    var json : NSDictionary = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.convertFromNilLiteral(), error: nil) as NSDictionary
                    success(json)
                } else {
                    println("ERROR: HTTP Response: \(httpResponse)")
                    // TODO: Reachability request here to make sure server is reachable. If callback succeeds, retry
                    
                    // for now, let's just try again if the api has a timeout
                    self.httpGetRequestWithCallback(url, success: success, failure: failure)
                    failure()
                }
            }
            self.delegate.setNetworkActivityIndicatorVisible(false)
        }).resume()
    }
    
//    MARK: Utilities
    func loadNewsItems(json : JSONValue, success : ([YahooNewsItem]) -> ()) {
        println("got JSON")
        if let newsItemJsonArray : Array<JSONValue> = json["result"]["items"].array {
            for newsItemJson in newsItemJsonArray {
                var newsItem : YahooNewsItem? = YahooNewsItem(fromDictionary: newsItemJson)
                if let item : YahooNewsItem = newsItem {
                    yahooNewsItems.append(item)
                }
            }
        }
        if yahooNewsItems.count > 0 {
            success(yahooNewsItems)
        }
    }
}
