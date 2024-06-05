//
//  AppStatsSQLite.swift
//  AppStatsSQLite
//
//  Created by Meilbn on 2023/12/2.
//

import SQLite
//import CoreLocation

// MARK: Enums

enum AppStatType: Int {
    case download = 0, launching = 1, active = 2
}

// MARK: Objects

class AppStatsUUID: Codable {
    
    var id: Int64 = 0
    var appKey: String = ""
    var appUserId: Int = 0
    var appId: Int = 0
    var uuid: String = ""
    var systemVersion: String = ""
    var deviceModel: String = ""
    var appVersion: String = ""
    var appBuild: String = ""
    var region: String = ""
    var location: String?
    var address: String?
    var lat: String?
    var lng: String?
    
    var isUpdateNeeded: Bool {
        return 0 == appUserId || systemVersion != UIDevice.current.systemVersion || deviceModel != AppStatsHelper.deviceModel || appVersion != AppStatsHelper.appVersion || region != AppStatsHelper.currentRegion || appBuild != AppStatsHelper.appBuild
    }
    
    func update(withRow row: Row) {
        self.id = row[AppStatsSQLite.shared.c_id]
        self.appKey = row[AppStatsSQLite.shared.c_appKey]
        self.appUserId = row[AppStatsSQLite.shared.c_appUserId]
        self.appId = row[AppStatsSQLite.shared.c_appId]
        self.uuid = row[AppStatsSQLite.shared.c_uuid]
        self.systemVersion = row[AppStatsSQLite.shared.c_systemVersion]
        self.deviceModel = row[AppStatsSQLite.shared.c_deviceModel]
        self.appVersion = row[AppStatsSQLite.shared.c_appVersion]
        self.appBuild = row[AppStatsSQLite.shared.c_appBuild]
        self.region = row[AppStatsSQLite.shared.c_region]
        self.location = row[AppStatsSQLite.shared.c_location]
        self.address = row[AppStatsSQLite.shared.c_address]
        self.lat = row[AppStatsSQLite.shared.c_lat]
        self.lng = row[AppStatsSQLite.shared.c_lng]
    }
    
}

class AppStat: Codable {
    
    var id: Int64 = 0
    var appKey: String = ""
    var appId: Int = 0
    var type: Int = AppStatType.download.rawValue
    var count: Int = 1
    var date: String = ""
    var isUploaded: Bool = false
    
    func update(withRow row: Row) {
        self.id = row[AppStatsSQLite.shared.c_id]
        self.appKey = row[AppStatsSQLite.shared.c_appKey]
        self.appId = row[AppStatsSQLite.shared.c_appId]
        self.type = row[AppStatsSQLite.shared.c_type]
        self.count = row[AppStatsSQLite.shared.c_count]
        self.date = row[AppStatsSQLite.shared.c_date]
        self.isUploaded = row[AppStatsSQLite.shared.c_isUploaded]
    }
    
}

class AppEvent: Codable {
    
    var id: Int64 = 0
    var appKey: String = ""
    var appId: Int = 0
    var event: String = ""
    var attrs: String?
    var time = Date()
    var isUploaded: Bool = false
    
    func update(withRow row: Row) {
        self.id = row[AppStatsSQLite.shared.c_id]
        self.appKey = row[AppStatsSQLite.shared.c_appKey]
        self.appId = row[AppStatsSQLite.shared.c_appId]
        self.event = row[AppStatsSQLite.shared.c_event]
        self.attrs = row[AppStatsSQLite.shared.c_attrs]
        self.time = row[AppStatsSQLite.shared.c_time]
        self.isUploaded = row[AppStatsSQLite.shared.c_isUploaded]
    }
    
}

// MARK: AppStatsSQLite

class AppStatsSQLite {
    
    private init() {
        config()
    }
    
    static let shared = AppStatsSQLite()
    
    //
    
    private var db: Connection?
    
    // MARK: Tables
    
    let c_id = Expression<Int64>("id")
    let c_appKey = Expression<String>("appKey")
    let c_appId = Expression<Int>("appId")
    
    // AppStatsUUID
    
    let t_AppStatsUUIDs = Table("AppStatsUUID")
    let c_appUserId = Expression<Int>("appUserId")
    let c_uuid = Expression<String>("uuid")
    let c_systemVersion = Expression<String>("systemVersion")
    let c_deviceModel = Expression<String>("deviceModel")
    let c_appVersion = Expression<String>("appVersion")
    let c_appBuild = Expression<String>("appBuild")
    let c_region = Expression<String>("region")
    let c_location = Expression<String?>("location")
    let c_address = Expression<String?>("address")
    let c_lat = Expression<String?>("lat")
    let c_lng = Expression<String?>("lng")
    
    // AppStat
    
    let t_AppStats = Table("AppStats")
    let c_type = Expression<Int>("type") // AppStatType
    let c_count = Expression<Int>("count")
    let c_date = Expression<String>("date")
    
    let c_isUploaded = Expression<Bool>("isUploaded")
    
    // AppEvent
    
    let t_AppEvent = Table("AppEvent")
    let c_event = Expression<String>("event")
    let c_attrs = Expression<String?>("attrs")
    let c_time = Expression<Date>("time")
    
    // MARK: Private Methods
    
    private func config() {
        do {
            let libraryDirectoryURL = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!)
            let appStatsDirectoryURL = libraryDirectoryURL.appendingPathComponent("AppStats", isDirectory: true)
            if !FileManager.default.fileExists(atPath: appStatsDirectoryURL.path) {
                try FileManager.default.createDirectory(at: appStatsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let filePath = appStatsDirectoryURL.appendingPathComponent("db.sqlite3", isDirectory: false)
            
            let db = try Connection(filePath.path)
            
            try db.run(t_AppStatsUUIDs.create(ifNotExists: true, block: { t in
                t.column(c_id, primaryKey: .autoincrement)
                t.column(c_appKey, unique: true)
                t.column(c_appUserId)
                t.column(c_appId)
                t.column(c_uuid)
                t.column(c_systemVersion)
                t.column(c_deviceModel)
                t.column(c_appVersion)
                t.column(c_appBuild)
                t.column(c_region)
                t.column(c_location)
                t.column(c_address)
                t.column(c_lat)
                t.column(c_lng)
            }))
            
            try db.run(t_AppStats.create(ifNotExists: true, block: { t in
                t.column(c_id, primaryKey: .autoincrement)
                t.column(c_appKey)
                t.column(c_appId)
                t.column(c_type)
                t.column(c_count)
                t.column(c_date)
                t.column(c_isUploaded)
            }))
            
            try db.run(t_AppEvent.create(ifNotExists: true, block: { t in
                t.column(c_id, primaryKey: .autoincrement)
                t.column(c_appKey)
                t.column(c_appId)
                t.column(c_event)
                t.column(c_attrs)
                t.column(c_time)
                t.column(c_isUploaded)
            }))
            
            self.db = db
        } catch {
            AppStats.debugLog("config failed, error = \(error.localizedDescription)")
        }
    }
    
    // MARK: Public Methods
    
    func getMaxId(of table: Table) -> Int64 {
        guard let db = self.db else {
            return 0
        }
        
        var maxId: Int64 = 0
        let query = table.select(c_id).order(c_id.desc).limit(1)
        do {
            if let row = try db.pluck(query) {
                maxId = row[c_id]
            }
        } catch {
            AppStats.debugLog("get max id of table: \(table) failed, error: \(error.localizedDescription)")
        }
        return maxId
    }
    
}

// MARK: AppStatsUUID

extension AppStatsSQLite {
    
    func getUUID(withAppKey key: String) -> AppStatsUUID? {
        guard let db = self.db else {
            return nil
        }
        
        let query = t_AppStatsUUIDs.filter(c_appKey == key)
        do {
            if let row = try db.pluck(query) {
                // 如果有找到则说明不是第一次打开
                let uuid = AppStatsUUID()
                uuid.update(withRow: row)
                return uuid
            }
        } catch {
            AppStats.debugLog("get app stats uuid record with key: \(key) failed, error: \(error.localizedDescription)")
            return nil
        }
        
        let uuid = AppStatsUUID()
        uuid.id = getMaxId(of: t_AppStatsUUIDs) + 1
        uuid.appKey = key
        uuid.uuid = UUID().uuidString
        uuid.systemVersion = UIDevice.current.systemVersion
        uuid.deviceModel = AppStatsHelper.deviceModel
        uuid.appVersion = AppStatsHelper.appVersion
        uuid.appBuild = AppStatsHelper.appBuild
        uuid.region = AppStatsHelper.currentRegion
        
        // 没有则添加一条下载的记录
        let stat = AppStat()
        stat.id = getMaxId(of: t_AppStats) + 1
        stat.appKey = key
        stat.type = AppStatType.download.rawValue
        stat.date = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        do {
            try db.transaction {
//                c_appKey <- key,
//                  c_uuid <- uuid.uuid,
//                  c_systemVersion <- uuid.systemVersion,
//                  c_deviceModel <- uuid.deviceModel,
//                  c_appVersion <- uuid.appVersion,
//                  c_appBuild <- uuid.appBuild,
//                  c_region <- uuid.region
                try db.run(t_AppStatsUUIDs.insert(uuid))
                
                // c_appKey <- key, c_type <- stat.type, c_date <- stat.date
                try db.run(t_AppStats.insert(stat))
            }
            
            AppStats.debugLog("insert app uuid and stat success with key: \(key)")
            
            return uuid
        } catch {
            AppStats.debugLog("insert app uuid and stat record with key: \(key) failed, error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    @discardableResult func updateAppId(_ appId: Int, forUUID uuid: AppStatsUUID) -> Bool {
        guard let db = self.db else {
            return false
        }
        
        do {
            try db.transaction {
                try db.run(t_AppStatsUUIDs.filter(c_id == uuid.id).update(c_appId <- appId))
                try db.run(t_AppStats.filter(c_appKey == uuid.appKey && c_appId == 0).update(c_appId <- appId))
                try db.run(t_AppEvent.filter(c_appKey == uuid.appKey && c_appId == 0).update(c_appId <- appId))
            }
            
            uuid.appId = appId
        } catch {
            AppStats.debugLog("update appid with id:\(uuid.id) failed, error: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    @discardableResult func updateUserInfos(withUser user: AppAPIUser, forUUID uuid: AppStatsUUID) -> Bool {
        guard let db = self.db else {
            return false
        }
        
        do {
            let query = t_AppStatsUUIDs.filter(c_id == uuid.id)
            try db.run(query.update(c_appUserId <- user.id,
                                    c_systemVersion <- user.systemVersion,
                                    c_deviceModel <- user.deviceModel,
                                    c_appVersion <- user.appVersion,
                                    c_appBuild <- user.appBuild,
                                    c_region <- user.region))
            
            uuid.appUserId = user.id
            uuid.systemVersion = user.systemVersion
            uuid.deviceModel = user.deviceModel
            uuid.appVersion = user.appVersion
            uuid.appBuild = user.appBuild
            uuid.region = user.region
            
            AppStats.debugLog("update user for uuid id: \(uuid.id) success")
        } catch {
            AppStats.debugLog("update uuid infos with id:\(uuid.id) failed, error: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
}

// MARK: AppStats

extension AppStatsSQLite {
    
    func addAppLaunchingStat() {
        guard let app = AppStats.shared._appUUID, let appKey = AppStats.shared._appUUID?.appKey, !appKey.isEmpty, let db = self.db else {
            return
        }
        
        // 先找到今日的
        if let stat = getTodayStat(withType: .launching) {
            let query = t_AppStats.filter(c_id == stat.id)
            do {
                let rows = try db.run(query.update(c_count += 1,
                                                   c_isUploaded <- false))
                AppStats.debugLog("update today launching app stats success, rows: \(rows)")
            } catch {
                AppStats.debugLog("update today launching stat failed, error: \(error.localizedDescription)")
            }
            
            return
        }
        
        // 没有找到今日的就添加一条
        let stat = AppStat()
        stat.id = getMaxId(of: t_AppStats) + 1
        stat.appKey = appKey
        stat.appId = app.appId
        stat.type = AppStatType.launching.rawValue
        stat.date = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        do {
            let rowid = try db.run(t_AppStats.insert(stat))
            AppStats.debugLog("insert launching app stat success, rowid: \(rowid)")
        } catch {
            AppStats.debugLog("insert launching app stat failed, error: \(error.localizedDescription)")
        }
    }
    
    func getTodayStat(withType type: AppStatType) -> AppStat? {
        guard let app = AppStats.shared._appUUID, let db = self.db else {
            return nil
        }
        
        let today = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        do {
            let query = t_AppStats.filter(c_appKey == app.appKey && c_type == type.rawValue && c_date == today)
            if let row = try db.pluck(query) {
                let stat = AppStat()
                stat.update(withRow: row)
                return stat
            }
        } catch {
            AppStats.debugLog("get today stat with type:\(type.rawValue) failed, error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    //
    
    func addAppBecomeActiveStat() {
        guard let app = AppStats.shared._appUUID, let appKey = AppStats.shared._appUUID?.appKey, !appKey.isEmpty, let db = self.db else {
            return
        }
        
        // 先找到今日的
        if let stat = getTodayStat(withType: .active) {
            let query = t_AppStats.filter(c_id == stat.id)
            do {
                let rows = try db.run(query.update(c_count += 1,
                                                    c_isUploaded <- false))
                AppStats.debugLog("update active app stat success, rows: \(rows)")
            } catch {
                AppStats.debugLog("update active stat failed, error: \(error.localizedDescription)")
            }
            
            return
        }
        
        // 没有找到今日的就添加一条
        let stat = AppStat()
        stat.id = getMaxId(of: t_AppStats) + 1
        stat.appKey = appKey
        stat.appId = app.appId
        stat.type = AppStatType.active.rawValue
        stat.date = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        do {
            let rowid = try db.run(t_AppStats.insert(stat))
            AppStats.debugLog("insert active app stat success, rowid: \(rowid)")
        } catch {
            AppStats.debugLog("insert active app stat failed, error: \(error.localizedDescription)")
        }
    }
    
    //
    
    func getNotUploadedAppStats() -> [AppStat] {
        guard let db = self.db, let appKey = AppStats.shared._appUUID?.appKey else {
            return []
        }
        
        var stats = [AppStat]()
        do {
            let query = t_AppStats.filter(c_appKey == appKey && c_isUploaded == false)
            for row in try db.prepare(query) {
                let stat = AppStat()
                stat.update(withRow: row)
                stats.append(stat)
            }
            AppStats.debugLog("get not uploaded app stats success, count: \(stats.count)")
        } catch {
            AppStats.debugLog("query not uploaded app stats failed, error: \(error.localizedDescription)")
        }
        
        return stats
    }
    
    func appStatsDidUpload(_ stats: [AppStat]) {
        if 0 == stats.count {
            return
        }
        
        guard let db = self.db else {
            return
        }
        
        do {
            try db.transaction {
                for stat in stats {
                    let query = t_AppStats.filter(c_id == stat.id)
                    try db.run(query.update(c_isUploaded <- true))
                }
            }
            AppStats.debugLog("update app stats uploaded success")
        } catch {
            AppStats.debugLog("update app stats uploaded failed, error: \(error.localizedDescription)")
        }
    }
    
}


// MARK: AppEvent

extension AppStatsSQLite {
    
    func addAppEvent(_ event: String, attrs: [String : Codable]?) {
        if event.isEmpty {
            return
        }
        
        guard let app = AppStats.shared._appUUID, let appKey = AppStats.shared._appUUID?.appKey, !appKey.isEmpty, let db = self.db else {
            return
        }
        
        let obj = AppEvent()
        obj.id = getMaxId(of: t_AppEvent) + 1
        obj.appKey = appKey
        obj.appId = app.appId
        obj.event = event
        
        if let ats = attrs, let data = try? JSONSerialization.data(withJSONObject: ats), let jsonString = String(data: data, encoding: .utf8) {
            obj.attrs = jsonString
        }
        
        do {
            let rowid = try db.run(t_AppEvent.insert(obj))
            AppStats.debugLog("insert app event: \(event) success, rowid: \(rowid)")
        } catch {
            AppStats.debugLog("insert app event: \(event) failed, error: \(error.localizedDescription)")
        }
    }
    
    func getNotUploadedAppEvents() -> [AppEvent] {
        guard let db = self.db, let appKey = AppStats.shared._appUUID?.appKey else {
            return []
        }
        
        var events = [AppEvent]()
        do {
            let query = t_AppEvent.filter(c_appKey == appKey && c_isUploaded == false)
            for row in try db.prepare(query) {
                let event = AppEvent()
                event.update(withRow: row)
                events.append(event)
            }
            AppStats.debugLog("get not uploaded app events success, count: \(events.count)")
        } catch {
            AppStats.debugLog("query not uploaded app events failed, error: \(error.localizedDescription)")
        }
        
        return events
    }
    
    func appEventsDidUpload(_ events: [AppEvent]) {
        if 0 == events.count {
            return
        }
        
        guard let db = self.db else {
            return
        }
        
        do {
            try db.transaction {
                for event in events {
                    let query = t_AppEvent.filter(c_id == event.id)
                    try db.run(query.update(c_isUploaded <- true))
                }
            }
            AppStats.debugLog("update app events uploaded success")
        } catch {
            AppStats.debugLog("update app events uploaded failed, error: \(error.localizedDescription)")
        }
    }
    
}
