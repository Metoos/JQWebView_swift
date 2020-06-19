//
//  JQWebViewController.swift
//  BaseSwift
//
//  Created by zpp on 2020/6/10.
//  Copyright © 2020 zpp. All rights reserved.
//

import UIKit
import WebKit

class JQWebViewController: UIViewController {
    
    /** 是否显示导航栏标题 */
    var showsPageTitleInNavigationBar = true
    /** 状态栏背景颜色 */
    var statusBarBgColor: UIColor = .black
    /** 返回按钮图片 */
    var backButtonImage: UIImage! = UIImage(named: "jq_back")
    /** 关闭全部网页按钮是否隐藏 */
    var closeButtonHidden = false
    /** 是否取消状态栏高度适配 默认自动适配高度 */
    var isCancelStatus    = false
    /** 设置请求头userAgent之后添加信息 */
    var userAgentCustomer: String?
    
    lazy var webView: JQWebView = {
        
        let barHeight = UIApplication.shared.statusBarFrame.size.height
        if isCancelStatus == false {
            let image = UIImageView()
            image.backgroundColor = statusBarBgColor
            image.frame = CGRect(x:0, y:0, width:UIScreen.main.bounds.size.width, height:barHeight);
            self.view.addSubview(image)
        }
        let webView = JQWebView(frame:CGRect(x: 0, y: (isCancelStatus ? 0 : barHeight)+44, width: self.view.frame.size.width, height: (self.view.frame.size.height - (isCancelStatus ? 0 : barHeight))))
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
    
    init(urlString url: String) {
        super.init(nibName: nil, bundle: nil)
        self.urlString = url
    }
    
    init(htmlString html: String) {
        super.init(nibName: nil, bundle: nil)
        self.htmlString = html
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("--------JQWebViewController dealloc")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = UIColor.blue
        navigationItem.leftBarButtonItems = [backButton]
        
        webView.delegate = self
        webView.progressView.isHidden = true
        view.addSubview(webView)
        
        
        //  取出webView的userAgent 并设置
        self.webView.wkWebView.evaluateJavaScript("navigator.userAgent", completionHandler: {[weak self] data, error in
            if let data = data {
                print("userAgent = \(data)")
            }
            var userAgent = data as? String
            // 3. 给userAgent中添加自己需要的内容
            userAgent = (userAgent ?? "") + (self!.userAgentCustomer ?? "")
            // 4. 创建一个UserAgent字典
            let userAgentDict = [
                "UserAgent": userAgent
            ]
            // 5. 将字典内容注册到NSUserDefaults中
            UserDefaults.standard.register(defaults: userAgentDict as [String : Any])
            //在网上找到的没有下面这句话，结果只是更改了本地的UserAgent，没修改网页的，导致一直有问题，好低级的错误，这个函数是9.0之后才出现的，在这之前，把这段代码放在WKWebView的alloc之前才会有效
            if #available(iOS 9.0, *) {
                self!.webView.wkWebView.customUserAgent = userAgent
            }
        })
        
        if #available(iOS 11.0, *) {
            webView.wkWebView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.wkWebView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            webView.wkWebView.scrollView.scrollIndicatorInsets = webView.wkWebView.scrollView.contentInset
        }else
        {
            self.automaticallyAdjustsScrollViewInsets = false
        }
        
        if let urlString = urlString {
            webView.loadURLString(urlString)
        }else if let htmlString = htmlString {
            webView.loadHTMLString(htmlString)
        }
        
        //添加js交互方法
        addJsAction()
        
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
    
    func addJsAction()
    {
        webView.addScriptMessage(name: "goBack", handler: {[weak self] (data) in
            self?.navigationController?.popViewController(animated: true)
        })
    }
    
}

extension JQWebViewController: JQWebViewDelegate {
    
    func jqWebView(_ webView: JQWebView, didFinishLoading URL: URL!) {
        if showsPageTitleInNavigationBar {
            let trimmedStr = webView.htmlDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedStr.isEmpty {
                self.title = webView.htmlDocumentTitle
            }
        }
        if webView.canGoBack && !closeButtonHidden {
            navigationItem.leftBarButtonItems = [backButton,closeButton]
        }else{
            navigationItem.leftBarButtonItems = [backButton]
        }
        
    }
    
    func jqWebView(_ webView: JQWebView, didFailToLoad URL: URL!, error: Error) {
        
    }
    
    func jqWebView(_ webView: JQWebView, shouldStartLoadWith request: URLRequest, navigationType: WKNavigationType) -> Bool {
        
        let url = request.url?.absoluteString
        print("url=\(url ?? "")")
        
        return true
    }
    
    func jqWebViewDidStartLoad(_ webView: JQWebView) {
        
    }
    
    
}
