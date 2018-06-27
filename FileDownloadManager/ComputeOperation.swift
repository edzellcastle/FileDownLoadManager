//
//  ComputeOperation.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 4/7/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import Foundation

class ComputeOperation : Operation {
    var urlString: String
    var resultsQueue: OperationQueue
    var job: Job
    var downloadState: String
    
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
    
    init(urlString: String, resultsQueue: OperationQueue, job: Job) {
        self.urlString = urlString
        self.resultsQueue = resultsQueue
        self.job = job
        self.downloadState = ""
    }
    
    override func main() {
        let context = UnsafeMutablePointer<CC_SHA1_CTX>.allocate(capacity: 1)
        var digest = Array<UInt8>(repeating:0, count:Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1_Init(context)
        CC_SHA1_Update(context, self.urlString, CC_LONG(self.urlString.lengthOfBytes(using: String.Encoding.utf8)))
        CC_SHA1_Final(&digest, context)
        context.deallocate()
        var result = ""
        for byte in digest {
            result += String(format:"%02x", byte)
        }
        
        // Rename file in the documents directory
        let filename = urlString.replacingOccurrences(of: "/", with: "_",
                                                      options: NSString.CompareOptions.literal, range:nil)
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let documentDirectory = URL(fileURLWithPath: path)
            let originPath = documentDirectory.appendingPathComponent(filename)
            let destinationPath = documentDirectory.appendingPathComponent(result)
            try FileManager.default.moveItem(at: originPath, to: destinationPath)
        } catch {
            print(error)
        }
        
        let resultOp = UpdateResultsOperation(urlString: urlString, result: result, job: job)
        resultsQueue.addOperation(resultOp)
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

        if downloadState == cancelledStatus || downloadState == failedStatus {
            state = .Finished
            return
        }
        state = .Executing
        main()
        state = .Finished
    }
}
