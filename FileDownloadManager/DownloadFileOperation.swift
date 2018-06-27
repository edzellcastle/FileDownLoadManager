//
//  DownloadFileOperation.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 4/3/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import Foundation

class DownloadFileOperation : Operation {
    var session: URLSession?
    var urlString: String
    var timeout: Int
    var retries: Int
    var fileDownloadQueue: OperationQueue
    var resultsQueue: OperationQueue
    var job: Job
    var attemps = 0
    var retry: Bool
    var resultMap = [String:String]()
    var downloadState: String
    var request: URLRequest
    
    // States for Operation
    enum State: String {
        case Ready, Executing, Finished
        
        fileprivate var keyPath: String {
            return "is" + rawValue
        }
    }
    
    // KVO for managing state related to Operation
    var state = State.Ready {
        willSet {
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: state.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
    
    init(urlString: String, session: URLSession?, timeout: Int, retries: Int, fileDownloadQueue: OperationQueue, resultsQueue: OperationQueue, job: Job) {
        self.urlString = urlString
        self.session = session
        self.timeout = timeout
        self.retries = retries
        self.fileDownloadQueue = fileDownloadQueue
        self.resultsQueue = resultsQueue
        self.job = job
        self.retry = false
        self.downloadState = ""
        self.request = URLRequest(url: URL(string: self.urlString)!,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: TimeInterval(timeout))
    }
    
    func isTemporaryError(didTimeOut: Bool, responseCode: Int) -> Bool {
        if didTimeOut || responseCode == 503 {
            return true
        }
        return false
    }
    
    func receivedResponse(didTimeOut: Bool, responseCode: Int, urlString: String, location: URL?) -> Bool {
        if responseCode == 200 {
            let filename = urlString.replacingOccurrences(of: "/", with: "_",
                                                          options: NSString.CompareOptions.literal, range:nil)
            // mark the url as successful
            downloadState = filename
            let finishOp = BlockOperation() { [weak self] () in
                self?.state = .Finished
            }
            let resultOp = UpdateResultsOperation(urlString: self.urlString, result: downloadState, job: job)
            finishOp.addDependency(resultOp)
            self.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
            
            // move the file to documents directory
            if let location = location {
                let fileManager = FileManager.default
                let filename = urlString.replacingOccurrences(of: "/", with: "_",
                                                      options: NSString.CompareOptions.literal, range:nil)
                var fileURL: URL = URL(fileURLWithPath: "")
                do {
                    let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
                    fileURL = documentDirectory.appendingPathComponent(filename)
                } catch {
                    print(error)
                }
                // Move file from temp folder to documents directory
                let filePath = fileURL.path
                if !fileManager.fileExists(atPath: filePath) {
                    do {
                        try fileManager.moveItem(at: location, to: fileURL)
                    }
                    catch {
                        print(error)
                    }
                }
                else {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        try fileManager.moveItem(at: location, to: fileURL)
                    }
                    catch {
                        print(error)
                    }
                }
                // no retry
                return false
            }
        } else if isTemporaryError(didTimeOut: didTimeOut, responseCode: responseCode) {
            // retry download
            return true
        } else {
            // not a temporary error, so either request finished without error
            // or its a permanent error and there's no point in retrying.
            // give up on this url
            downloadState = failedStatus
            let finishOp = BlockOperation() { [weak self] () in
                self?.state = .Finished
            }
            let resultOp = UpdateResultsOperation(urlString: urlString, result: failedStatus, job: job)
            finishOp.addDependency(resultOp)
            resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
            // no retry
            return false
        }
        return false
    }
    
    func createTask (completion: ((Bool) -> (Void))?) {
        if let session = session {
            let task = session.downloadTask(with: request) { [weak self] (location, response, error) in
                if !(self?.isCancelled)! {
                    let urlString = self?.urlString
                    if let error = error {
                        // Handle Error
                        if error._code == NSURLErrorTimedOut {
                            self?.retry = (self?.receivedResponse(didTimeOut: true, responseCode: 0, urlString: urlString!, location: location))!
                            completion?((self?.retry)!)
                        } else {
                            // error, not a timeout
                            self?.downloadState = failedStatus
                            let finishOp = BlockOperation() { [weak self] () in
                                self?.state = .Finished
                            }
                            let resultOp = UpdateResultsOperation(urlString: (self?.urlString)!, result: failedStatus, job: (self?.job)!)
                            finishOp.addDependency(resultOp)
                            self?.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
                            // Do not retry
                            self?.retry = false
                            completion?((self?.retry)!)
                        }
                        // error is not nil
                    } else {
                        let statusCode = (response as! HTTPURLResponse).statusCode
                        self?.retry = (self?.receivedResponse(didTimeOut: false, responseCode: statusCode, urlString: urlString!, location: location))!
                        completion?((self?.retry)!)
                    }
                }
            }
            if !isCancelled {
                task.resume()
            } else {
                self.downloadState = cancelledStatus
                let finishOp = BlockOperation() { [weak self] () in
                    self?.state = .Finished
                }
                let resultOp = UpdateResultsOperation(urlString: self.urlString, result: cancelledStatus, job: self.job)
                finishOp.addDependency(resultOp)
                self.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
            }
        }
    }
    
    func tryDownload(retryCount: Int,  attemptNumber: Int) {
        var triesRemaining = retryCount
        if retryCount == 0 {
            self.downloadState = failedStatus
            let finishOp = BlockOperation() { [weak self] () in
                self?.state = .Finished
            }
            let resultOp = UpdateResultsOperation(urlString: self.urlString, result: failedStatus, job: self.job)
            finishOp.addDependency(resultOp)
            self.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
            return
        }
        triesRemaining -= 1
        var attempt = attemptNumber
        
        createTask () { [weak self] mustRetry in
            if mustRetry {
                // backoff algorithm:
                attempt += 1
                let retryTime = UInt32(attempt * (self?.timeout)!)
                sleep(retryTime)
                if (self?.isCancelled)! {
                    self?.downloadState = cancelledStatus
                    let finishOp = BlockOperation() { [weak self] () in
                        self?.state = .Finished
                    }
                    let resultOp = UpdateResultsOperation(urlString: (self?.urlString)!, result: cancelledStatus, job: (self?.job)!)
                    finishOp.addDependency(resultOp)
                    self?.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
                    return
                }
                if attempt <= (self?.retries)! {
                    self?.tryDownload(retryCount: triesRemaining, attemptNumber: attempt)
                }
            } else {
                self?.state = .Finished
            }
        }
    }
    
    override func main() {
        if !isCancelled {
            tryDownload(retryCount: self.retries,  attemptNumber: 0)
        } else {
            // Mark status as cancelled
            downloadState = cancelledStatus
            let finishOp = BlockOperation() { [weak self] () in
                self?.state = .Finished
            }
            let resultOp = UpdateResultsOperation(urlString: self.urlString, result: cancelledStatus, job: self.job)
            finishOp.addDependency(resultOp)
            self.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: false)
        }
    }
    
    override var isReady: Bool {
        return super.isReady && state == .Ready
    }
    
    override var isExecuting: Bool {
        return state == .Executing
    }
    
    override var isFinished: Bool {
        return state == .Finished
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override func start() {
        state = .Executing
        main()
    }
    
    public override func cancel() {
        // cancel task
        super.cancel()
        downloadState = cancelledStatus
        let finishOp = BlockOperation() { [weak self] () in
            self?.state = .Finished
        }
        let resultOp = UpdateResultsOperation(urlString: self.urlString, result: cancelledStatus, job: self.job)
        finishOp.addDependency(resultOp)
        self.resultsQueue.addOperations([resultOp,finishOp],waitUntilFinished: true)
    }
}
