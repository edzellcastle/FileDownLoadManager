//
//  Job.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 3/31/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import Foundation

class Job : Operation {
    var session: URLSession?
    var urlStrings = [String]()
    var timeout: Int
    var retries: Int
    var fileDownloadQueue: OperationQueue
    let resultsQueue = OperationQueue()
    var resultsMap = [String:String]()
    var callback: (_ resultmap: [String:String])->Void
 
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
    
    init(urlStrings: [String],
         timeout: Int,
         retries: Int,
         fileDownloadQueue: OperationQueue,
         callback: @escaping (_ resultmap: [String:String])->Void) {
        
        self.urlStrings = urlStrings
        self.timeout = timeout
        self.retries = retries
        self.fileDownloadQueue = fileDownloadQueue
        self.callback = callback
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = TimeInterval(timeout)
        self.session = nil
        super.init()
        self.session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }
    
    override func main() {
        if !isCancelled {
            let finishOp = BlockOperation() { [weak self] () in
                self?.callback((self?.resultsMap)!)
                self?.state = .Finished
            }
            for urlString in urlStrings {
                let getFileOp = GetFileOperation(urlString: urlString,
                                                 session: session,
                                                 timeout: timeout,
                                                 retries: retries,
                                                 fileDownloadQueue: fileDownloadQueue,
                                                 resultsQueue: resultsQueue,
                                                 job: self)
                finishOp.addDependency(getFileOp)
                fileDownloadQueue.addOperation(getFileOp)
            }
            fileDownloadQueue.addOperation(finishOp)
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
        if isCancelled {
            state = .Finished
            return
        }
        state = .Executing
        main()
    }
    
    public func pause() {
        fileDownloadQueue.isSuspended = true
    }
    
    public func unpause() {
        fileDownloadQueue.isSuspended = false
    }
    
    public override func cancel() {
        // cancel tasks and invalidate session
        fileDownloadQueue.cancelAllOperations()
        if fileDownloadQueue.operationCount == 0 {
            self.callback(self.resultsMap)
            fileDownloadQueue.cancelAllOperations()
            state = .Finished
        } else {
            if let session = session {
                session.invalidateAndCancel()
            }
            self.callback(self.resultsMap)
            state = .Finished
        }
    }
}
extension Job : URLSessionDelegate {

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            print(error)
        }
    }
}
