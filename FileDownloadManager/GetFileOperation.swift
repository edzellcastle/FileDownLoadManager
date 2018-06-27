//
//  GetFileOperation.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 4/8/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import Foundation

class GetFileOperation: Operation {
    // MARK: Properties
    var session: URLSession?
    var urlString: String
    var timeout: Int
    var retries: Int
    var fileDownloadQueue: OperationQueue
    var resultsQueue: OperationQueue
    var job: Job
    
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
    
    init(urlString: String,
         session: URLSession?,
         timeout: Int,
         retries: Int,
         fileDownloadQueue: OperationQueue,
         resultsQueue: OperationQueue,
         job: Job) {
        self.urlString = urlString
        self.session = session
        self.timeout = timeout
        self.retries = retries
        self.fileDownloadQueue = fileDownloadQueue
        self.resultsQueue = resultsQueue
        self.job = job
    }

    override func main() {
        if !isCancelled {
            let downloadOp = DownloadFileOperation(urlString: urlString, session: session, timeout: timeout, retries: retries, fileDownloadQueue: fileDownloadQueue, resultsQueue: resultsQueue, job: job)
            let computeOp = ComputeOperation(urlString: urlString, resultsQueue: resultsQueue, job: job)
            let adapterOp = BlockOperation() {
                [unowned downloadOp, unowned computeOp] in
                computeOp.downloadState = downloadOp.downloadState
            }
            let finishOp = BlockOperation() { [weak self] () in
                self?.state = .Finished
            }
            adapterOp.addDependency(downloadOp)
            computeOp.addDependency(adapterOp)
            finishOp.addDependency(computeOp)
            fileDownloadQueue.addOperation(downloadOp)
            fileDownloadQueue.addOperation(adapterOp)
            fileDownloadQueue.addOperation(computeOp)
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
}
