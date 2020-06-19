//
//  WebViewController.swift
//  BaseSwift
//
//  Created by zpp on 2020/6/10.
//  Copyright © 2020 zpp. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController {
    
    /** 是否显示导航栏标题 */
    var showsPageTitleInNavigationBar = true
    /** 是否隐藏导航栏返回按钮 */
    var isHiddenBackItem = false
    /** 返回按钮图片 */
    var backButtonImage: UIImage! = UIImage(named: "jq_back")
    /** 关闭全部网页按钮是否隐藏 */
    var closeButtonHidden = false
    
    lazy var webView: JQWebView = {
        let webView = JQWebView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
        webView.wkWebView.scrollView.showsVerticalScrollIndicator = false
        webView.wkWebView.scrollView.showsHorizontalScrollIndicator = false
        return webView
    }()
    
    lazy var backButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: self.backButtonImage, style: .plain, target: self, action: #selector(goBackAction))
        return button
    }()
    
    lazy var closeButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(closeAction))
        return button
    }()
    
    var urlString:String?
    var htmlString:String?
    
    init(urlString: String) {
        super.init(nibName: nil, bundle: nil)
        self.urlString = urlString
    }
    
    init(htmlString: String) {
        super.init(nibName: nil, bundle: nil)
        self.htmlString = htmlString
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("--------WebViewController dealloc")
    }
    
//    override func viewWillDisappear(_ animated: Bool) {
//        self.navigationController?.setNavigationBarHidden(false, animated: false)
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.blue
        if !isHiddenBackItem {
            navigationItem.leftBarButtonItems = [backButton]
        }
        
        webView.delegate = self
        view.addSubview(webView)
        
        //  取出webView的userAgent 并设置
        self.webView.wkWebView.evaluateJavaScript("navigator.userAgent", completionHandler: { data, error in
            if let data = data {
                print("userAgent = \(data)")
            }
            var userAgent = data as? String
            // 3. 给userAgent中添加自己需要的内容
            userAgent = userAgent ?? "" + "yiqilai-apple"
            // 4. 创建一个UserAgent字典
            let userAgentDict = [
                "UserAgent": userAgent ?? ""
            ]
            // 5. 将字典内容注册到NSUserDefaults中
            UserDefaults.standard.register(defaults: userAgentDict)
            //在网上找到的没有下面这句话，结果只是更改了本地的UserAgent，没修改网页的，导致一直有问题，好低级的错误，这个函数是9.0之后才出现的，在这之前，把这段代码放在WKWebView的alloc之前才会有效
            if #available(iOS 9.0, *) {
                self.webView.wkWebView.customUserAgent = userAgent
            }
        })
        
        if #available(iOS 11.0, *) {
            webView.wkWebView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.wkWebView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            webView.wkWebView.scrollView.scrollIndicatorInsets = webView.wkWebView.scrollView.contentInset
        }
        
        if let urlString = urlString {
            webView.loadURLString(urlString)
        }else if let htmlString = htmlString {
            webView.loadHTMLString(htmlString)
        }
        
        //添加js交互调用原生方法
        addScriptMessage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        self.navigationController?.setNavigationBarHidden(true, animated: false)
        if !webView.wkWebView.isLoading, let _ = self.urlString {
            webView.reload()
        }
    }
    
    @objc func goBackAction() {
        if webView.canGoBack {
            webView.goBack()
        }else{
            self.navigationController?.popViewController(animated: true)
        }
        
    }
    
    @objc func closeAction() {
        self.navigationController?.popViewController(animated: true)
    }
    
    /** 开始加载网页链接 */
    func loadURLString(_ urlString: String) {
        self.urlString = urlString
        webView.loadURLString(urlString)
    }
    
    /** 导航标题 */
    func setNavigationTitleString(_ titleString: String) {
        title = titleString
    }
    
    /** 进度条背景颜色 */
    func setLoadingTintColor(_ loadingTintColor: UIColor) {
        webView.progressView.tintColor = loadingTintColor
    }
    
    /** 进度条进度值颜色 */
    func setLoadingTrackTintColor(_ loadingTrackTintColor: UIColor) {
        webView.progressView.trackTintColor = loadingTrackTintColor
    }
    
    /** 添加js交互调用原生方法 */
    func addScriptMessage(){
        
        webView.addScriptMessage(name: "ScanAction") { data in
            print("ScanAction = \(data)")
        }
        
        webView.addScriptMessage(name: "Share") { data in
            print("Share = \(data)")
        }
        
        webView.addScriptMessage(name: "Location") { data in
            print("Location = \(data)")
        }
        
        webView.addScriptMessage(name: "Color") { data in
            print("Color = \(data)")
        }
        
        webView.addScriptMessage(name: "payClick") { data in
            print("payClick = \(data)")
        }
        
    }
}

extension WebViewController: JQWebViewDelegate {
    
    func jqWebView(_ webView: JQWebView, didFinishLoading URL: URL!) {
        
        if showsPageTitleInNavigationBar {
            if !isBlankString(webView.htmlDocumentTitle) {
                self.title = webView.htmlDocumentTitle
            }
        }
        if webView.canGoBack && !closeButtonHidden {
            navigationItem.leftBarButtonItems = [backButton,closeButton]
        }else{
            if !isHiddenBackItem {
                navigationItem.leftBarButtonItems = [backButton]
            }
        }
        
    }
    
    func jqWebView(_ webView: JQWebView, didFailToLoad URL: URL!, error: Error) {
        
    }
    
    func jqWebView(_ webView: JQWebView, shouldStartLoadWith request: URLRequest, navigationType: WKNavigationType) -> Bool {
        guard let url = request.url else { return true }
        print("url=\(url.absoluteString)")
        
        
        
        if isWirelessDownloadManifestForURL(url) {
            //当前加载链接为苹果企业APP无线安装清单文件，则打开外部浏览器进行展示
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
                UIApplication.shared.openURL(url)
            }
        }
//        
        var isReturnNO = false
        for vc in (navigationController?.viewControllers)! {
            //判断网页是否已打开 已打开则返回打开页
            if vc.isKind(of: WebViewController.self) {
                let webVC = vc as! WebViewController
                if webVC.urlString == url.absoluteString && !(urlString == url.absoluteString) {
                    navigationController?.popToViewController(webVC, animated: true)
                    
                    isReturnNO = true
                }
            }
        }
        if isReturnNO {
            return false
        }
        
        if webView.wkWebView.isLoading {
            return true
        }
        guard let urlString = urlString, urlString.hasPrefix("http"), !(urlString == url.absoluteString) else{
            return true
        }

        let webViewVC = WebViewController(urlString: url.absoluteString)
        self.navigationController?.pushViewController(webViewVC, animated: true)

        
        
        
        
        return true
    }
    
    func jqWebViewDidStartLoad(_ webView: JQWebView) {
        
    }
    
    //MARK: - WARNING 上架appstores时必须删掉这段代码
    func isWirelessDownloadManifestForURL(_ url: URL) -> Bool {
        if isBlankString(url.absoluteString) {
            return false
        }
        if url.absoluteString.hasPrefix("itms-services://?action=download-manifest&url=") {
            return true
        }
        return false
    }
    
    func isBlankString(_ string: String) -> Bool {
        let trimmedStr = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedStr.isEmpty
    }
}
