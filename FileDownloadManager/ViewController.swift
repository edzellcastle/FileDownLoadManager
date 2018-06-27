//
//  ViewController.swift
//  FileDownloadManager
//
//  Created by David Lindsay on 3/31/18.
//  Copyright © 2018 Tapinfuse. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearDocumentsFolder()
        let downloader = URLDownloader.sharedInstance
        let url1 = "https://www.google.com"
        let url2 = "https://www.yahoo.com"
        let url3 = "https://www.wikipedia.org"
        let url4 = "https://www.airbnb.com"
        //let url5 = "https://www.google.com:81"  // Error - timeout
        let url6 = "https://gooble.ocm"
        let url7 = "https://www.familytree.com"
        let url8 = "https://stackoverflow.com"
        let urlSet1 = [url1,url2,url6,url3,url4,url7,url8]
        //let urlSet2 = [url3, url4, url2]

        let job1 = downloader.downloadUrls(urlStrings: urlSet1, timeout: 15, retries: 2) { (resultMap) -> Void in
            print("***** print the resultMap job 1 *****")
            for (key,result) in resultMap {
                print("key = \(key) result = \(result)")
            }
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                print("list of files in document directory")
                for file in fileURLs {
                    print("file = \(file)")
                }
            } catch {
                print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
            }
        }
        
//        print("create job 2")
//        let job2 = downloader.downloadUrls(urlStrings: urlSet2, timeout: 20, retries: 3) { (resultMap) -> Void in
//            print("***** print the resultMap job 2 *****")
//            for (key,result) in resultMap {
//                print("key = \(key) result = \(result)")
//            }
//            let fileManager = FileManager.default
//            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//            do {
//                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
//                print("list of files in document directory")
//                for file in fileURLs {
//                    print("file = \(file)")
//                }
//            } catch {
//                print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
//            }
//        }
//        sleep(UInt32(1))
//        print("cancel job 1")
//        job1.cancel()
//        print("pause job1")
//        job1.pause()
//        print("unpause job1")
//        job1.unpause()
    }
    
    func clearDocumentsFolder() {
        let fileManager = FileManager.default
       
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentDirectory = URL(fileURLWithPath: path)
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: documentDirectory.path)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: documentDirectory.path + "/" + filePath)
            }
        } catch {
            print("Could not clear documents folder: \(error)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

