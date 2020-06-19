//
//  ViewController.swift
//  JQWebViewSwift
//
//  Created by life on 2020/6/19.
//  Copyright © 2020 life. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func showWebViewAction(_ sender: UIButton) {
        
        let webView = JQWebViewController(urlString: "https://www.apple.com.cn")
        webView.setLoadingTrackTintColor(UIColor.white)
        webView.setLoadingTintColor(UIColor.red)
        self.navigationController?.pushViewController(webView, animated: true)
    }
    
    @IBAction func showCustomController(_ sender: UIButton) {
        
        
        let path = Bundle.main.path(forResource: "index", ofType: "html") ?? ""
        if let html = try?String(contentsOfFile: path, encoding: .utf8) {
            
            let webView = JQWebViewController(htmlString: html)
            self.navigationController?.pushViewController(webView, animated: true)
        }
        
    }
    
}

