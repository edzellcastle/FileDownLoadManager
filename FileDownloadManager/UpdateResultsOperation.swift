//
//  UpdateResultsOperation.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 4/10/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import Foundation

class UpdateResultsOperation: Operation {
    var urlString: String
    var result: String
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
    
    init(urlString: String, result: String, job: Job) {
        self.urlString = urlString
        self.result = result
        self.job = job
    }
    
    override func main() {
        job.resultsMap[urlString] = result
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
        return false
    }
    
    override func start() {
        if isCancelled {
            state = .Finished
            return
        }
        state = .Executing
        main()
        state = .Finished
    }
}
