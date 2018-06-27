//
//  URLDownloader.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 3/31/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import Foundation

class URLDownloader {
    static let sharedInstance = URLDownloader()
    var jobQueue: OperationQueue
    private init() {
        jobQueue = OperationQueue()
    }

    func downloadUrls (urlStrings: [String],
                       timeout: Int,
                       retries: Int,
                       _ callback: @escaping (_ resultmap: [String:String])->Void) -> Job {
  
        let fileDownloadQueue = OperationQueue()
        let job = Job(urlStrings: urlStrings, timeout: timeout, retries: retries, fileDownloadQueue: fileDownloadQueue, callback: callback)
        
        jobQueue.addOperation(job)
        return job
    }
}
