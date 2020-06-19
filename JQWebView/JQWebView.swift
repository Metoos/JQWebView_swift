//
//  JQWebView.swift
//  BaseSwift
//
//  Created by zpp on 2020/6/9.
//  Copyright © 2020 zpp. All rights reserved.
//

import UIKit
import WebKit

typealias ScriptMessageHandler = (Any) -> Void

//协议要继承于class或者NSObjectProtocol，不然weak属性修饰会报错
protocol JQWebViewDelegate: class{
    func jqWebView(_ webView: JQWebView, didFinishLoading URL: URL!) -> Void
    func jqWebView(_ webView: JQWebView, didFailToLoad URL: URL!, error: Error) -> Void
    func jqWebView(_ webView: JQWebView, shouldStartLoadWith request: URLRequest, navigationType: WKNavigationType) -> Bool
    func jqWebViewDidStartLoad(_ webView: JQWebView) -> Void
}
//可选协议
extension JQWebViewDelegate{
    func jqWebView(_ webView: JQWebView, didFinishLoading URL: URL!) {
        
    }
    
    func jqWebView(_ webView: JQWebView, didFailToLoad URL: URL!, error: Error) {
        
    }
    
    func jqWebView(_ webView: JQWebView, shouldStartLoadWith request: URLRequest, navigationType: Int) -> Bool {
        return true
    }
    
    func jqWebViewDidStartLoad(_ webView: JQWebView) {
        
    }
}

class JQWebView: UIView {
    
    static let singleWkProcessPool = WKProcessPool()
    weak var delegate: JQWebViewDelegate?
    
    lazy var wkWebView: WKWebView = {
        //初始化一个WKWebViewConfiguration对象
        let wkConfig = WKWebViewConfiguration()
        //初始化偏好设置属性：preferences
        wkConfig.preferences = WKPreferences()
        //是否支持JavaScript
        wkConfig.preferences.javaScriptEnabled = true
        //不通过用户交互，是否可以打开窗口
        wkConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        //ProcessPool改成单例可实现多webview缓存同步
        wkConfig.processPool = JQWebView.singleWkProcessPool
        
        let wkWebView = WKWebView(frame: self.bounds, configuration: wkConfig)
        wkWebView.isMultipleTouchEnabled = true
        wkWebView.autoresizesSubviews = true
        wkWebView.scrollView.alwaysBounceVertical = true
        wkWebView.scrollView.bounces = false
        
        return wkWebView
    }()
    
    lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
//        (UIApplication.shared.statusBarFrame.size.height >= 44) ? 88.0 : 64.0
        progressView.frame = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: progressView.bounds.size.height)
        progressView.tintColor =  UIColor(red: 240/255, green: 245/255, blue: 245/255, alpha: 1.0)
        return progressView
    }()
    
    var htmlDocumentTitle = ""
    var htmlScrollHeight:CGFloat{
        get{
            wkWebView.sizeToFit()
            return wkWebView.scrollView.contentSize.height
        }
    }
    
    var canGoBack:Bool{
        get{
            return wkWebView.canGoBack
        }
    }
    
    var canGoForward:Bool{
        get{
            return wkWebView.canGoForward
        }
    }
    
    override var frame: CGRect{
        didSet{
            super.frame = frame
            wkWebView.frame = self.bounds
        }
    }
    
    fileprivate var keyboardWillShow = false
    fileprivate var keyboardWillShowPoint = CGPoint()
    fileprivate var urlToLaunchWithPermission:URL?
    
    fileprivate lazy var scriptMessageHandlers:[Dictionary<String, Any>] = {
        return []
    }()
    
    fileprivate lazy var externalAppPermissionAlertView:UIAlertController = {
        let alertView = UIAlertController(title: "Leave this app?", message: "This web page is trying to open an outside app. Are you sure you want to open it?", preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alertView.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] action in
            guard let url = self?.urlToLaunchWithPermission else { return }
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
                UIApplication.shared.openURL(url)
            }
            self?.urlToLaunchWithPermission = nil
        }))
        return alertView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    deinit {
        print("---JQWebView dealloc")
        wkWebView.navigationDelegate = nil
        wkWebView.uiDelegate = nil
        wkWebView.removeObserver(self, forKeyPath: "title", context: nil)
        wkWebView.removeObserver(self, forKeyPath: "estimatedProgress", context: nil)
        NotificationCenter.default.removeObserver(self)
        
        for (_, value) in scriptMessageHandlers.enumerated(){
            let name = value["name"] as! String
            wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
        scriptMessageHandlers.removeAll()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setupView() {
        
        self.backgroundColor = .white
        self.addSubview(wkWebView)
        
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        //标识是否支持左、右swipe手势是否可以前进、后退
        wkWebView.allowsBackForwardNavigationGestures = true
        //监听
        wkWebView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        wkWebView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        
        if #available(iOS 11.0, *) {
            wkWebView.scrollView.contentInsetAdjustmentBehavior = .never
            wkWebView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            wkWebView.scrollView.scrollIndicatorInsets = wkWebView.scrollView.contentInset
        }
        
        //添加键盘通知
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        //进度条
        self.addSubview(progressView)
    }
    
    @objc fileprivate func keyboardWillShow(_ notification: NSNotification) {
        //避免第三方多处调用keyboardWillShow:
        if !keyboardWillShow {
            keyboardWillShowPoint = wkWebView.scrollView.contentOffset
            keyboardWillShow = true
        }
    }
    
    @objc fileprivate func keyboardWillHide(_ notification: NSNotification) {
        //延迟调整滚动 避免切换键盘出现界面跳动问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.wkWebView.scrollView.setContentOffset(self.keyboardWillShowPoint, animated: true)
        }
        keyboardWillShow = false
    }
    /** 添加js交互调用原生方法 */
    func addScriptMessage(name: String, handler: @escaping ScriptMessageHandler){
        let trimmedStr = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedStr.isEmpty {
            return
        }
        
        wkWebView.configuration.userContentController.add(JQWKScriptMessageDelegate(delegate: self), name: name)
        
        let dic:[String:Any] = ["name":name,"handler":handler]
        //        if let _ = handler {
        //            dic["handler"] = handler
        //        }
        scriptMessageHandlers.append(dic)
    }
    
    func loadRequest(_ request: URLRequest) {
        wkWebView.load(request)
    }
    
    func loadURL(_ url: URL) {
        wkWebView.load(URLRequest(url: url))
    }
    
    func loadURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        loadURL(url)
    }
    
    func loadHTMLString(_ htmlString: String) {
        wkWebView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func scrollEnabled(_ enable: Bool) {
        wkWebView.scrollView.isScrollEnabled = enable
    }
    
    func goBack() {
        wkWebView.goBack()
    }
    
    func goForward() {
        wkWebView.goForward()
    }
    
    func reload() {
        wkWebView.reload()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let obj = object as? WKWebView, obj === wkWebView else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == "estimatedProgress" {
            progressView.alpha = 1.0
            let animated = Float(wkWebView.estimatedProgress) > progressView.progress
            progressView.setProgress(Float(wkWebView.estimatedProgress), animated: animated)
            
            if wkWebView.estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.alpha = 0.0
                }) { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                }
            }
        }else if keyPath == "title" {
            htmlDocumentTitle = wkWebView.title ?? ""
        }
    }
}


extension JQWebView: WKUIDelegate {
    /* WKWebView默认禁止了一些跳转
     
     默认禁止了以上行为,除此之外,js端通过alert()`弹窗的动作也被禁掉了.
     这边做处理*/
    
    // 警告框
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确认", style: .default, handler: { action in
            completionHandler()
        }))
        getCurrentViewController()?.present(alertController, animated: true)
    }
    
    //确认框
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "提示", message: message , preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { action in
            completionHandler(false)
        }))
        alertController.addAction(UIAlertAction(title: "确认", style: .default, handler: { action in
            completionHandler(true)
        }))
        getCurrentViewController()?.present(alertController, animated: true)
    }
    
    //输入框
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: prompt, message: "", preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { textField in
            textField.text = defaultText
        })
        alertController.addAction(UIAlertAction(title: "完成", style: .default, handler: { action in
            completionHandler(alertController.textFields?[0].text ?? "")
        }))
        getCurrentViewController()?.present(alertController, animated: true)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let targetFrame = navigationAction.targetFrame else { return nil }
        if !targetFrame.isMainFrame {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    fileprivate func getCurrentViewController() -> UIViewController? {
        
        var window = UIApplication.shared.keyWindow
        if window?.windowLevel != .normal {
            let windows = UIApplication.shared.windows
            for tmpWin in windows {
                if tmpWin.windowLevel == .normal {
                    window = tmpWin
                    break
                }
            }
        }
        
        var result = window?.rootViewController
        while ((result?.presentedViewController) != nil) {
            result = result?.presentedViewController
        }
        
        if (result is UITabBarController) {
            result = (result as? UITabBarController)?.selectedViewController
        }
        
        if (result is UINavigationController) {
            result = (result as? UINavigationController)?.topViewController
        }
        return result
    }
}


extension JQWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.jqWebViewDidStartLoad(self)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = wkWebView.url else { return }
        delegate?.jqWebView(self, didFinishLoading: url)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let url = wkWebView.url else { return }
        delegate?.jqWebView(self, didFailToLoad: url, error: error)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let url = wkWebView.url else { return }
        delegate?.jqWebView(self, didFailToLoad: url, error: error)
    }
    
    //访问不受信任的https
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            var card: URLCredential? = nil
            if let serverTrust = challenge.protectionSpace.serverTrust {
                card = URLCredential(trust: serverTrust)
            }
            
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, card)
        }
    }
    
    /* WKWebView默认禁止了一些跳转
     
     WKWebView
     默认禁止了以上行为,除此之外,js端通过alert()`弹窗的动作也被禁掉了.
     这边做处理*/
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url else { return }
        
        let scheme = url.scheme
        let app = UIApplication.shared
        
        // 打电话
        if scheme == "tel" {
            guard app.canOpenURL(url) else { return }
            if #available(iOS 10.0, *) {
                app.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
                app.openURL(url)
            }
            // 一定要加上这句,否则会打开新页面
            decisionHandler(.cancel)
            return
        }
        
        //打开appstore
        if url.absoluteString.contains("ituns.apple.com") {
            guard app.canOpenURL(url) else { return }
            if #available(iOS 10.0, *) {
                app.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
                app.openURL(url)
            }
            // 一定要加上这句,否则会打开新页面
            decisionHandler(.cancel)
            return
        }
        
        if !externalAppRequired(toOpenURL: url) {
            guard let _ = navigationAction.targetFrame else {
                loadURL(url)
                decisionHandler(.cancel)
                return
            }
            guard let decision = delegate?.jqWebView(self, shouldStartLoadWith: navigationAction.request, navigationType: navigationAction.navigationType) else {
                decisionHandler(.allow)
                return
            }
            if decision {
                decisionHandler(.allow)
                return
            }else{
                decisionHandler(.cancel)
                return
            }
        }
        guard app.canOpenURL(url) else {
            decisionHandler(.allow)
            return
        }
        launchExternalApp(withURL: url)
        decisionHandler(.cancel)
        
    }
    
    
    //MARK: - External App Support
    fileprivate func externalAppRequired(toOpenURL: URL) -> Bool {
        
        //若需要限制只允许某些前缀的scheme通过请求，则取消下述注释，并在数组内添加自己需要放行的前缀
        //        guard let url = wkWebView.url, let scheme = url.scheme else { return false }
        //        let validSchemes = ["http","https","file"]
        //        return validSchemes.contains(scheme)
        
        return false
    }
    
    fileprivate func launchExternalApp(withURL url: URL) {
        urlToLaunchWithPermission = url
        getCurrentViewController()?.present(externalAppPermissionAlertView, animated: true)
    }
}

extension JQWebView: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        for (_, value) in scriptMessageHandlers.enumerated(){
            if message.name == value["name"] as! String, let handler = value["handler"] as? ScriptMessageHandler {
                handler(message.body)
            }
        }
    }
    
}

extension JQWebView {
    /* 清除全部缓存 */
    class func deleteAllWebCache() {
        //allWebsiteDataTypes清除所有缓存
        let websiteDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = NSDate(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: dateFrom as Date) {
//            print("清楚缓存完毕")
            
        }
    }
    
    //        open func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date, completionHandler: @escaping () -> Void)
    
    /* 自定义清除缓存 */
    class func deleteWebCache(ofTypes dataTypes: Array<String>, completionHandler: @escaping () -> Void) {
        /*
         在磁盘缓存上。
         WKWebsiteDataTypeDiskCache,
         
         html离线Web应用程序缓存。
         WKWebsiteDataTypeOfflineWebApplicationCache,
         
         内存缓存。
         WKWebsiteDataTypeMemoryCache,
         
         本地存储。
         WKWebsiteDataTypeLocalStorage,
         
         Cookies
         WKWebsiteDataTypeCookies,
         
         会话存储
         WKWebsiteDataTypeSessionStorage,
         
         IndexedDB数据库。
         WKWebsiteDataTypeIndexedDBDatabases,
         
         查询数据库。
         WKWebsiteDataTypeWebSQLDatabases
         */
        
        let websiteDataTypes = NSSet(array: dataTypes)
        let dateFrom = NSDate(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: dateFrom as Date) {
            
        }
    }
}


