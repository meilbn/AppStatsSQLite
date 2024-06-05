//
//  AppStats.swift
//  AppStats
//
//  Created by Meilbn on 2023/9/26.
//

import UIKit
import CommonCrypto
//import CoreLocation

public final class AppStats {
    
    public static let shared = AppStats()
    
    //
    
    /// 是否启用调试 log 输出
    public var isDebugLogEnable = true
    
    var _appUUID: AppStatsUUID?
    
    public var appUUID: String {
        return _appUUID?.uuid ?? ""
    }
    
    public var appUserId: Int {
        return _appUUID?.appUserId ?? 0
    }
    
    var endpoint = ""
    
//    public var isLocationEnable = false
//    internal var currentLocationCoordinate: CLLocationCoordinate2D?
//    internal var currentLocationInfo: String?
    
    // 加入重试机制，防止国行机子上第一次打开需要网络权限弹窗导致暂时无网络，接口调用失败
    private var retryMaxCount = 10
    private var currentRetryTimes = 0
    private var retryTimer: Timer?
    
    private var isDidEnterBackground = false
    private var isDidBecomeActive = false
    
    private var isUploading = false
    private var latestUploadedTime: TimeInterval = 0
    
    //
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidFinishLaunching(_:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    /// 输出 log
    static func debugLog(_ log: String) {
        if AppStats.shared.isDebugLogEnable {
            debugPrint("\(Date()) AppStats - \(log)")
        }
    }
    
    // MARK: Register App Key
    
    /// 注册 App key
    public func register(withAppKey appkey: String, endpoint: String) {
        assert(appkey.count > 0, "App key can not be empty!")
        AppStats.debugLog("register app key")
        
        guard let uuid = AppStatsSQLite.shared.getUUID(withAppKey: appkey) else {
            AppStats.debugLog("get uuid failed")
            return
        }
        
        _appUUID = uuid
        self.endpoint = endpoint
        checkAppId()
    }
    
    // MARK: Private Methods
    
    /// 检查 app id，为 0 就去服务器获取最新的一个
    private func checkAppId() {
        guard let app = _appUUID else {
            return
        }
        
        if app.appId > 0 {
            AppStats.shared.updateAppUserIfNeeded()
        } else {
            if endpoint.isEmpty {
                AppStats.debugLog("the endpoint is empty...")
                return
            }
            
            AppStatsAPIManager.getAppId(withAppKey: app.appKey, bundleId: AppStatsHelper.bundleID) { _, success, data, msg in
                if success && data > 0 {
                    if AppStatsSQLite.shared.updateAppId(data, forUUID: app) {
                        AppStats.shared.updateAppUserIfNeeded()
                    }
                } else {
                    AppStats.debugLog("register app key failed, error: \(msg ?? "nil"), with return data: \(data)")
                }
            } failure: { error in
                AppStats.debugLog("register app key failed, error: \(error.localizedDescription)")
                AppStats.shared.startRetryTimer()
            }
        }
    }
    
    /// 更新 App user 信息
    private func updateAppUserIfNeeded() {
        guard let app = _appUUID else {
            return
        }
        
        if !app.isUpdateNeeded {
            invalidateRetryTimer()
            return
        }
        
        if endpoint.isEmpty {
            AppStats.debugLog("The endpoint is empty...")
            return
        }
        
        AppStatsAPIManager.updateAppUser(withAppUserId: app.appUserId, appId: app.appId) { _, success, data, msg in
            if success, let user = data {
                AppStatsSQLite.shared.updateUserInfos(withUser: user, forUUID: app)
                AppStats.shared.invalidateRetryTimer()
                AppStats.shared.checkUploadAppCollects()
            } else {
                AppStats.debugLog("update app user failed, error: \(msg ?? "nil")")
            }
        } failure: { error in
            AppStats.debugLog("update app user failed, error: \(error.localizedDescription)")
            AppStats.shared.startRetryTimer()
        }
    }
    
    /// 判断是否需要上传数据
    private func checkUploadAppCollects(ignoreLatestUploadedTime: Bool = false) {
        guard let app = _appUUID, !app.appKey.isEmpty && app.appId > 0 && app.appUserId > 0 else {
            return
        }
        
        if isUploading { 
            return
        }
        
        if endpoint.isEmpty {
            AppStats.debugLog("The endpoint is empty...")
            return
        }
        
        if !ignoreLatestUploadedTime && latestUploadedTime > 0 && Date().timeIntervalSince1970 - latestUploadedTime < (30.0 * 60.0) {
            AppStats.debugLog("距离上次提交不到半小时，先不提交...")
            return
        }
        
        let stats = AppStatsSQLite.shared.getNotUploadedAppStats()
        let events = AppStatsSQLite.shared.getNotUploadedAppEvents()
        if stats.count > 0 || events.count > 0 {
            isUploading = true
            AppStatsAPIManager.collectAppStatsAndEvents(stats, events: events, appId: app.appId, appUserId: app.appUserId) { [weak self] _, success, msg in
                if success {
                    AppStatsSQLite.shared.appStatsDidUpload(stats)
                    AppStatsSQLite.shared.appEventsDidUpload(events)
                    self?.latestUploadedTime = Date().timeIntervalSince1970
                } else {
                    AppStats.debugLog("upload app stats failed, error: \(msg ?? "nil")")
                }
                self?.isUploading = false
            } failure: { [weak self] error in
                AppStats.debugLog("upload app stats failed, error: \(error.localizedDescription)")
                self?.isUploading = false
            }
        }
    }
    
    /// 关闭重试 timer
    private func invalidateRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// 开启重新 timer
    private func startRetryTimer() {
        if let timer = retryTimer, timer.isValid {
            return
        }
        
        invalidateRetryTimer()
        
        let timer = Timer(timeInterval: 5.0, target: self, selector: #selector(retryRegiter), userInfo: nil, repeats: false)
        RunLoop.current.add(timer, forMode: .common)
        retryTimer = timer
    }
    
    @objc private func retryRegiter() {
        if currentRetryTimes >= retryMaxCount {
            invalidateRetryTimer()
            return
        }
        
        currentRetryTimes += 1
        checkAppId()
    }
    
    // MARK: Notifications
    
    @objc private func applicationDidFinishLaunching(_ ntf: Notification) {
        AppStats.debugLog(#function)
        AppStatsSQLite.shared.addAppLaunchingStat()
    }
    
    @objc private func applicationDidEnterBackground(_ ntf: Notification) {
        AppStats.debugLog(#function)
        isDidEnterBackground = true
    }
    
    @objc private func applicationDidBecomeActive(_ ntf: Notification) {
        AppStats.debugLog(#function)
        if !isDidBecomeActive || isDidEnterBackground {
            isDidBecomeActive = true
            
            AppStatsSQLite.shared.addAppBecomeActiveStat()
            checkUploadAppCollects()
            
            isDidEnterBackground = false
        }
    }
    
    // MARK: Add App Event
    
    public func addAppEvent(_ event: String, attrs: [String : Codable]?) {
        AppStatsSQLite.shared.addAppEvent(event, attrs: attrs)
        checkUploadAppCollects(ignoreLatestUploadedTime: true)
    }
    
}

//

struct AppStatsHelper {
    
    static var bundleID: String {
        if let bundleID = Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] {
            return "\(bundleID)"
        } else {
            return ""
        }
    }
    
    static var appVersion: String {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] {
            return "\(appVersion)"
        } else {
            return ""
        }
    }
    
    static var appBuild: String {
        if let buildVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] {
            return "\(buildVersion)"
        } else {
            return ""
        }
    }
    
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    static var currentRegion: String {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier ?? "Unknown"
        } else {
            // Fallback on earlier versions
            return Locale.current.regionCode ?? "Unknown"
        }
    }
    
    // MARK: Time
    
    static var longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static var shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
}

//

extension String {
    
    // Encrypt
    
//    var MD5Data: Data {
//        let length = Int(CC_MD5_DIGEST_LENGTH)
//        let messageData = self.data(using:.utf8)!
//        var digestData = Data(count: length)
//
//        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
//            messageData.withUnsafeBytes { messageBytes -> UInt8 in
//                if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
//                    let messageLength = CC_LONG(messageData.count)
//                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
//                }
//                return 0
//            }
//        }
//        return digestData
//    }
    
    public func app_stats_sha256() -> String {
        if let data = self.data(using: .utf8) {
            return data.app_stats_sha256()
        }
        return ""
    }
    
}

extension Data {
    
    public func app_stats_sha256() -> String{
        return app_stats_hexStringFromData(input: app_stats_digest(input: self as NSData))
    }
    
    public func app_stats_digest(input : NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }
    
    public func app_stats_hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)
        
        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }
        
        return hexString
    }
    
//    var MD5Hex: String {
//        return self.map { String(format: "%02hhx", $0) }.joined()
//    }
    
}
