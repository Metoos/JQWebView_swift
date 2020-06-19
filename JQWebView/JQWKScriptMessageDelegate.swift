//
//  JQWKScriptMessageDelegate.swift
//  BaseSwift
//
//  Created by zpp on 2020/6/10.
//  Copyright © 2020 zpp. All rights reserved.
//

import UIKit
import WebKit

class JQWKScriptMessageDelegate: NSObject, WKScriptMessageHandler {
    
    weak var delegate: WKScriptMessageHandler?
    
    init(delegate: WKScriptMessageHandler?) {
        super.init()
        self.delegate = delegate
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
    

}
