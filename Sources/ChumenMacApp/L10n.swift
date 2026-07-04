import Foundation
import ChumenCore

enum L10n {
    enum Key: String {
        case dashboard
        case profiles
        case proxies
        case connections
        case rules
        case providers
        case logs
        case settings
        case coreSettings
        case appSettings
        case quickSettings
        case all
        case globalSearch
        case globalSearchPlaceholder
        case searchResults
        case displayedResults
        case noSearchResults
        case aiAssistant
        case aiOpenAssistant
        case aiCloseAssistant
        case aiModelSettings
        case aiBaseURL
        case aiModel
        case aiAPIKey
        case aiSaveKey
        case aiClearKey
        case aiKeyStored
        case aiKeyMissing
        case aiSearchOnly
        case aiUseLocalOllama
        case aiOllamaReady
        case aiOllamaNoKeyRequired
        case aiRemoteAPI
        case aiAskPlaceholder
        case aiSend
        case aiThinking
        case aiPendingChanges
        case aiApplyChange
        case aiDismissChange
        case aiClearChat
        case aiNoMessages
        case aiChangeApplied
        case aiReviewBeforeApply
        case aiDiff
        case aiUseAsSearch
        case runtime
        case running
        case stopped
        case activeProfile
        case configUpdated
        case mode
        case outboundMode
        case traffic
        case cumulativeTraffic
        case currentSpeed
        case routedTraffic
        case proxiedTraffic
        case directTraffic
        case systemProxy
        case lastRefresh
        case start
        case stop
        case restart
        case refresh
        case enableProxy
        case disableProxy
        case importLocal
        case subscriptionURL
        case displayName
        case subscriptionEditHint
        case importSubscription
        case importFromClients
        case importOne
        case scanClients
        case externalImportHint
        case importAllFound
        case noExternalProfilesFound
        case externalProfilesFound
        case subscriptionURLFound
        case useProfile
        case activate
        case active
        case currentActive
        case update
        case edit
        case editInfo
        case editFile
        case editRules
        case editNodes
        case editProxyGroups
        case extendOverrideConfig
        case globalExtendOverrideConfig
        case extendScript
        case updateViaProxy
        case visualEditor
        case codeEditor
        case addSection
        case deleteSection
        case topLevelKey
        case content
        case applyToCode
        case openFile
        case save
        case cancel
        case delete
        case unsupportedFeature
        case refreshProxies
        case refreshProviders
        case groups
        case node
        case delay
        case delayTest
        case groupDelayTest
        case refreshConnections
        case searchConnections
        case noConnections
        case noMatchingConnections
        case closeAll
        case activeConnections
        case close
        case networkReport
        case activeTraffic
        case routeDistribution
        case topHosts
        case topProcesses
        case topRules
        case topChains
        case proxyRoute
        case directRoute
        case unknownRoute
        case historyTrend
        case refreshRules
        case processLog
        case runtimeLog
        case logReport
        case logLevels
        case totalLines
        case errorLogs
        case warningLogs
        case infoLogs
        case debugLogs
        case recentIssues
        case frequentMessages
        case aiAnalysisReady
        case clear
        case executable
        case useDetectedCore
        case secret
        case ports
        case controllerHost
        case systemProxyHost
        case notifications
        case notificationPermission
        case notificationPermissionAuthorized
        case notificationPermissionDenied
        case notificationPermissionNotDetermined
        case requestNotificationPermission
        case testNotification
        case notificationTestTitle
        case notificationTestBody
        case notificationCoreStarted
        case notificationCoreStopped
        case notificationCoreRestarted
        case notificationCoreFailed
        case notificationCoreExited
        case configSync
        case syncBackend
        case syncBackendDirectory
        case syncBackendCloudKit
        case syncDirectory
        case chooseSyncDirectory
        case syncDirectorySelected
        case cloudKitContainerIdentifier
        case checkCloudKitStatus
        case syncUpload
        case syncDownload
        case syncUploaded
        case syncDownloaded
        case syncCompleted
        case syncFailed
        case lastSync
        case syncPlaintextWarning
        case syncDirectoryNotSelected
        case syncMissingProfileFile
        case syncCloudKitAvailable
        case syncCloudKitNoAccount
        case syncCloudKitRestricted
        case syncCloudKitUnknown
        case syncCloudKitTemporaryUnavailable
        case syncCloudKitNoSnapshot
        case statusBar
        case showStatusBarItem
        case statusBarDisplayMode
        case statusBarCustomTemplate
        case statusBarTemplatePreview
        case statusBarModeIconOnly
        case statusBarModeAppName
        case statusBarModeStatus
        case statusBarModeSpeed
        case statusBarModeStackedSpeed
        case statusBarModeTraffic
        case statusBarModeStatusAndSpeed
        case statusBarModeCustom
        case networkOptions
        case allowLAN
        case ipv6
        case unifiedDelay
        case logLevel
        case tunMode
        case enableTun
        case disableTun
        case tunStack
        case dns
        case enableDNS
        case dnsListen
        case dnsMode
        case nameservers
        case autoStartCoreOnLaunch
        case setProxyOnStart
        case clearProxyOnStop
        case files
        case openDataDirectory
        case more
        case quit
        case saveSettings
        case language
        case apiNotTested
        case controllerUnavailable
        case coreNotRunning
        case coreNotRunningHint
        case apiConnected
        case apiConnectedHint
        case apiUnavailable
        case apiUnavailableHint
        case apiNotTestedHint
        case externalCoreDetected
        case externalCoreDetectedHint
        case actionStartCore
        case actionCheckAPI
        case ready
        case pending
        case noLogs
        case noService
        case externalProxy
        case on
        case off
        case imported
        case skipped
        case failed
        case updated
        case saved
        case healthchecked
        case deleted
        case subscriptionURLEmpty
        case coreDetected
        case coreNotFound
        case connectionsClosed
        case systemProxyEnabled
        case systemProxyDisabled
        case tunEnabled
        case tunDisabled
        case tunFailed
        case ineffective
        case tunRouteConflict
        case tunPermissionRequired
        case unknown
        case upload
        case download
        case proxyProviders
        case ruleProviders
        case vehicle
        case providerItems
        case coreExited
        case clearedSelection
        case ruleDisabled
        case ruleEnabled
        case runtimeConfigReloaded
        case coreRestartRequested
        case fakeIPFlushed
        case dnsCacheFlushed
        case geoUpdated
        case webUIUpdated
        case debugGCDone
        case dnsQueryDone
        case storageRead
        case storageWritten
        case storageDeleted
        case coreTools
        case speed
        case memory
        case memoryUnavailable
        case cache
        case flushFakeIP
        case flushDNS
        case updateGeo
        case upgradeGeo
        case upgradeUI
        case debugGC
        case reloadRuntimeConfig
        case applySettingsToCore
        case restartKernelAPI
        case dnsQuery
        case storage
        case rawAPI
        case request
        case response
        case body
        case key
        case value
        case read
        case write
        case openDashboard
        case dashboardPreset
        case dashboardSelected
        case configAppendix
        case externalUI
        case corsOrigins
        case advancedTun
        case advancedDNS
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .zhHans, .system:
            zhHans[key] ?? en[key] ?? key.rawValue
        case .en:
            en[key] ?? key.rawValue
        }
    }

    private static let zhHans: [Key: String] = [
        .dashboard: "总览",
        .profiles: "配置",
        .proxies: "代理",
        .connections: "连接",
        .rules: "规则",
        .providers: "Provider",
        .logs: "日志",
        .settings: "设置",
        .coreSettings: "内核",
        .appSettings: "设置",
        .quickSettings: "快捷设置",
        .all: "全部",
        .globalSearch: "搜索",
        .globalSearchPlaceholder: "搜索任意内容",
        .searchResults: "搜索结果",
        .displayedResults: "显示",
        .noSearchResults: "没有匹配结果",
        .aiAssistant: "智能体",
        .aiOpenAssistant: "打开智能体",
        .aiCloseAssistant: "关闭智能体",
        .aiModelSettings: "模型配置",
        .aiBaseURL: "Base URL",
        .aiModel: "模型",
        .aiAPIKey: "API Key",
        .aiSaveKey: "保存 Key",
        .aiClearKey: "清除 Key",
        .aiKeyStored: "Key 已保存",
        .aiKeyMissing: "请先配置 API Key",
        .aiSearchOnly: "未接入 AI，当前作为搜索使用",
        .aiUseLocalOllama: "本地 Ollama",
        .aiOllamaReady: "本地 Ollama 就绪",
        .aiOllamaNoKeyRequired: "本地无需 Key",
        .aiRemoteAPI: "远程接口需要 Key",
        .aiAskPlaceholder: "搜索，或让智能体生成配置变更",
        .aiSend: "发送",
        .aiThinking: "正在生成建议...",
        .aiPendingChanges: "待审核变更",
        .aiApplyChange: "应用",
        .aiDismissChange: "忽略",
        .aiClearChat: "清空对话",
        .aiNoMessages: "输入需求后，智能体只会生成待审核变更。",
        .aiChangeApplied: "变更已应用",
        .aiReviewBeforeApply: "所有变更都需要先审核 diff，再手动应用。",
        .aiDiff: "Diff",
        .aiUseAsSearch: "搜索",
        .runtime: "运行状态",
        .running: "运行中",
        .stopped: "已停止",
        .activeProfile: "当前配置",
        .configUpdated: "配置更新",
        .mode: "模式",
        .outboundMode: "出站模式",
        .traffic: "流量",
        .cumulativeTraffic: "累计流量",
        .currentSpeed: "当前速率",
        .routedTraffic: "累计分流",
        .proxiedTraffic: "代理",
        .directTraffic: "直连",
        .systemProxy: "系统代理",
        .lastRefresh: "上次刷新",
        .start: "启动",
        .stop: "停止",
        .restart: "重启",
        .refresh: "刷新",
        .enableProxy: "开启代理",
        .disableProxy: "关闭代理",
        .importLocal: "导入本地 YAML",
        .subscriptionURL: "订阅地址",
        .displayName: "显示名称",
        .subscriptionEditHint: "保存后，配置名称会立即更新；订阅地址用于后续“更新”重新下载，清空则转为本地 YAML 配置。",
        .importSubscription: "导入订阅",
        .importFromClients: "从其他客户端导入",
        .importOne: "导入",
        .scanClients: "扫描客户端",
        .externalImportHint: "扫描 Clash Verge、ClashX、Mihomo Party 和常见 .config 目录，只复制可识别的 YAML 配置。",
        .importAllFound: "导入全部",
        .noExternalProfilesFound: "未发现可导入配置",
        .externalProfilesFound: "发现可导入配置",
        .subscriptionURLFound: "订阅 URL 已读取",
        .useProfile: "使用",
        .activate: "启用",
        .active: "已启用",
        .currentActive: "当前启用",
        .update: "更新",
        .edit: "编辑",
        .editInfo: "编辑信息",
        .editFile: "编辑文件",
        .editRules: "编辑规则",
        .editNodes: "编辑节点",
        .editProxyGroups: "编辑代理组",
        .extendOverrideConfig: "扩展覆写配置",
        .globalExtendOverrideConfig: "全局扩展覆写配置",
        .extendScript: "扩展脚本",
        .updateViaProxy: "更新（代理）",
        .visualEditor: "可视化",
        .codeEditor: "代码",
        .addSection: "新增",
        .deleteSection: "删除",
        .topLevelKey: "顶层键",
        .content: "内容",
        .applyToCode: "应用到代码",
        .openFile: "打开文件",
        .save: "保存",
        .cancel: "取消",
        .delete: "删除",
        .unsupportedFeature: "暂未支持",
        .refreshProxies: "刷新代理",
        .refreshProviders: "刷新 Provider",
        .groups: "个代理组",
        .node: "节点",
        .delay: "延迟",
        .delayTest: "测速",
        .groupDelayTest: "组测速",
        .refreshConnections: "刷新连接",
        .searchConnections: "搜索连接",
        .noConnections: "暂无连接",
        .noMatchingConnections: "无匹配连接",
        .closeAll: "全部关闭",
        .activeConnections: "活跃连接",
        .close: "关闭",
        .networkReport: "网络报表",
        .activeTraffic: "活跃流量",
        .routeDistribution: "路由分布",
        .topHosts: "Top 主机",
        .topProcesses: "Top 进程",
        .topRules: "Top 规则",
        .topChains: "Top 链路",
        .proxyRoute: "代理",
        .directRoute: "直连",
        .unknownRoute: "未知",
        .historyTrend: "历史曲线",
        .refreshRules: "刷新规则",
        .processLog: "进程日志",
        .runtimeLog: "运行日志",
        .logReport: "日志报表",
        .logLevels: "日志级别",
        .totalLines: "总行数",
        .errorLogs: "错误",
        .warningLogs: "警告",
        .infoLogs: "信息",
        .debugLogs: "调试",
        .recentIssues: "最近问题",
        .frequentMessages: "高频问题",
        .aiAnalysisReady: "AI 分析上下文已准备",
        .clear: "清空",
        .executable: "内核程序",
        .useDetectedCore: "使用检测到的内核",
        .secret: "密钥",
        .ports: "端口",
        .controllerHost: "控制地址",
        .systemProxyHost: "系统代理地址",
        .notifications: "通知",
        .notificationPermission: "桌面通知权限",
        .notificationPermissionAuthorized: "已允许",
        .notificationPermissionDenied: "已拒绝，使用应用内通知",
        .notificationPermissionNotDetermined: "未请求",
        .requestNotificationPermission: "请求权限",
        .testNotification: "发送测试通知",
        .notificationTestTitle: "Chumen 通知已就绪",
        .notificationTestBody: "如果系统通知不可用，会显示这条应用内通知。",
        .notificationCoreStarted: "内核已启动",
        .notificationCoreStopped: "内核已停止",
        .notificationCoreRestarted: "内核已重启",
        .notificationCoreFailed: "内核运行失败",
        .notificationCoreExited: "内核异常退出",
        .configSync: "配置同步",
        .syncBackend: "同步方式",
        .syncBackendDirectory: "同步目录",
        .syncBackendCloudKit: "iCloud CloudKit",
        .syncDirectory: "同步目录",
        .chooseSyncDirectory: "选择同步目录",
        .syncDirectorySelected: "同步目录已选择",
        .cloudKitContainerIdentifier: "CloudKit Container ID（可留空使用默认容器）",
        .checkCloudKitStatus: "检查 iCloud 状态",
        .syncUpload: "上传本机配置",
        .syncDownload: "拉取同步配置",
        .syncUploaded: "配置已上传",
        .syncDownloaded: "配置已拉取",
        .syncCompleted: "同步完成",
        .syncFailed: "同步失败",
        .lastSync: "上次同步",
        .syncPlaintextWarning: "同步目录和 CloudKit 快照会包含订阅地址、密钥和配置内容；请选择可信目录或私有 iCloud 账户。",
        .syncDirectoryNotSelected: "尚未选择同步目录",
        .syncMissingProfileFile: "同步快照缺少配置文件",
        .syncCloudKitAvailable: "iCloud 账户可用；CloudKit 仍需要应用签名包含 iCloud entitlement。",
        .syncCloudKitNoAccount: "当前系统未登录 iCloud 账户。",
        .syncCloudKitRestricted: "当前 iCloud 账户受限。",
        .syncCloudKitUnknown: "无法确认 iCloud 状态。",
        .syncCloudKitTemporaryUnavailable: "iCloud 暂时不可用。",
        .syncCloudKitNoSnapshot: "CloudKit 中还没有 Chumen 同步快照。",
        .statusBar: "菜单栏",
        .showStatusBarItem: "显示菜单栏图标",
        .statusBarDisplayMode: "菜单栏显示",
        .statusBarCustomTemplate: "自定义模板",
        .statusBarTemplatePreview: "预览",
        .statusBarModeIconOnly: "仅图标",
        .statusBarModeAppName: "应用名称",
        .statusBarModeStatus: "运行状态",
        .statusBarModeSpeed: "实时速度",
        .statusBarModeStackedSpeed: "上下行速率",
        .statusBarModeTraffic: "累计流量",
        .statusBarModeStatusAndSpeed: "状态和速度",
        .statusBarModeCustom: "自定义",
        .networkOptions: "网络选项",
        .allowLAN: "允许局域网连接",
        .ipv6: "IPv6",
        .unifiedDelay: "统一延迟",
        .logLevel: "日志级别",
        .tunMode: "TUN 模式",
        .enableTun: "启用 TUN",
        .disableTun: "关闭 TUN",
        .tunStack: "TUN 栈",
        .dns: "DNS",
        .enableDNS: "启用 DNS",
        .dnsListen: "DNS 监听地址",
        .dnsMode: "DNS 模式",
        .nameservers: "DNS 服务器",
        .autoStartCoreOnLaunch: "打开 Chumen 后自动启动内核",
        .setProxyOnStart: "启动后自动开启系统代理",
        .clearProxyOnStop: "停止时自动清理系统代理",
        .files: "文件",
        .openDataDirectory: "打开数据目录",
        .more: "更多",
        .quit: "退出",
        .saveSettings: "保存设置",
        .language: "语言",
        .apiNotTested: "尚未测试 API",
        .controllerUnavailable: "无法连接内核 API",
        .coreNotRunning: "内核未启动",
        .coreNotRunningHint: "代理、连接和流量统计需要先启动内核。",
        .apiConnected: "控制 API 已连接",
        .apiConnectedHint: "可以读取代理、连接、规则和流量状态。",
        .apiUnavailable: "控制 API 未连接",
        .apiUnavailableHint: "内核控制端口无响应，请检查内核是否已启动或端口是否一致：",
        .apiNotTestedHint: "启动后会自动检测控制 API。",
        .externalCoreDetected: "外部内核占用控制端口",
        .externalCoreDetectedHint: "控制 API 有响应，但进程不是 Chumen 启动的内核。",
        .actionStartCore: "需要启动",
        .actionCheckAPI: "需要检查",
        .ready: "已就绪",
        .pending: "待检测",
        .noLogs: "暂无日志。",
        .noService: "无网络服务",
        .externalProxy: "其他代理开启",
        .on: "开",
        .off: "关",
        .imported: "已导入",
        .skipped: "已跳过",
        .failed: "失败",
        .updated: "已更新",
        .saved: "已保存",
        .healthchecked: "已测速",
        .deleted: "已删除",
        .subscriptionURLEmpty: "订阅地址为空",
        .coreDetected: "已找到可执行内核",
        .coreNotFound: "未找到可执行的 mihomo 内核",
        .connectionsClosed: "连接已关闭",
        .systemProxyEnabled: "系统代理已开启",
        .systemProxyDisabled: "系统代理已关闭",
        .tunEnabled: "TUN 模式已开启",
        .tunDisabled: "TUN 模式已关闭",
        .tunFailed: "TUN 启动失败",
        .ineffective: "未生效",
        .tunRouteConflict: "路由冲突",
        .tunPermissionRequired: "需要管理员权限",
        .unknown: "未知",
        .upload: "上传",
        .download: "下载",
        .proxyProviders: "代理 Provider",
        .ruleProviders: "规则 Provider",
        .vehicle: "来源",
        .providerItems: "项目",
        .coreExited: "内核已退出",
        .clearedSelection: "已清除固定选择",
        .ruleDisabled: "规则已禁用",
        .ruleEnabled: "规则已启用",
        .runtimeConfigReloaded: "运行配置已重新加载",
        .coreRestartRequested: "已请求内核重启",
        .fakeIPFlushed: "Fake-IP 缓存已清理",
        .dnsCacheFlushed: "DNS 缓存已清理",
        .geoUpdated: "Geo 数据已更新",
        .webUIUpdated: "Web UI 已更新",
        .debugGCDone: "已触发 GC",
        .dnsQueryDone: "DNS 查询完成",
        .storageRead: "Storage 已读取",
        .storageWritten: "Storage 已写入",
        .storageDeleted: "Storage 已删除",
        .coreTools: "内核工具",
        .speed: "速率",
        .memory: "内存",
        .memoryUnavailable: "未提供",
        .cache: "缓存",
        .flushFakeIP: "清理 Fake-IP",
        .flushDNS: "清理 DNS",
        .updateGeo: "更新 Geo",
        .upgradeGeo: "升级 Geo",
        .upgradeUI: "升级 Web UI",
        .debugGC: "触发 GC",
        .reloadRuntimeConfig: "重新加载配置",
        .applySettingsToCore: "应用到内核",
        .restartKernelAPI: "API 重启内核",
        .dnsQuery: "DNS 查询",
        .storage: "Storage",
        .rawAPI: "Raw API",
        .request: "请求",
        .response: "响应",
        .body: "Body",
        .key: "键",
        .value: "值",
        .read: "读取",
        .write: "写入",
        .openDashboard: "打开 Dashboard",
        .dashboardPreset: "Dashboard 面板",
        .dashboardSelected: "已选中",
        .configAppendix: "附加 YAML",
        .externalUI: "External UI",
        .corsOrigins: "CORS 来源",
        .advancedTun: "高级 TUN",
        .advancedDNS: "高级 DNS"
    ]

    private static let en: [Key: String] = [
        .dashboard: "Dashboard",
        .profiles: "Profiles",
        .proxies: "Proxies",
        .connections: "Connections",
        .rules: "Rules",
        .providers: "Providers",
        .logs: "Logs",
        .settings: "Settings",
        .coreSettings: "Core",
        .appSettings: "Settings",
        .quickSettings: "Quick Settings",
        .all: "All",
        .globalSearch: "Search",
        .globalSearchPlaceholder: "Search anything",
        .searchResults: "Search Results",
        .displayedResults: "Showing",
        .noSearchResults: "No matching results",
        .aiAssistant: "Assistant",
        .aiOpenAssistant: "Open Assistant",
        .aiCloseAssistant: "Close Assistant",
        .aiModelSettings: "Model Settings",
        .aiBaseURL: "Base URL",
        .aiModel: "Model",
        .aiAPIKey: "API Key",
        .aiSaveKey: "Save Key",
        .aiClearKey: "Clear Key",
        .aiKeyStored: "Key saved",
        .aiKeyMissing: "Configure API key first",
        .aiSearchOnly: "AI is not connected; using local search",
        .aiUseLocalOllama: "Local Ollama",
        .aiOllamaReady: "Local Ollama ready",
        .aiOllamaNoKeyRequired: "No key needed locally",
        .aiRemoteAPI: "Remote API requires a key",
        .aiAskPlaceholder: "Search, or ask the assistant to draft changes",
        .aiSend: "Send",
        .aiThinking: "Drafting suggestions...",
        .aiPendingChanges: "Pending Changes",
        .aiApplyChange: "Apply",
        .aiDismissChange: "Dismiss",
        .aiClearChat: "Clear Chat",
        .aiNoMessages: "Ask for a change; the assistant only creates reviewable drafts.",
        .aiChangeApplied: "Change applied",
        .aiReviewBeforeApply: "Review the diff before applying any change.",
        .aiDiff: "Diff",
        .aiUseAsSearch: "Search",
        .runtime: "Runtime",
        .running: "Running",
        .stopped: "Stopped",
        .activeProfile: "Active Profile",
        .configUpdated: "Config Updated",
        .mode: "Mode",
        .outboundMode: "Outbound Mode",
        .traffic: "Traffic",
        .cumulativeTraffic: "Total Traffic",
        .currentSpeed: "Current Speed",
        .routedTraffic: "Routed Traffic",
        .proxiedTraffic: "Proxy",
        .directTraffic: "Direct",
        .systemProxy: "System Proxy",
        .lastRefresh: "Last Refresh",
        .start: "Start",
        .stop: "Stop",
        .restart: "Restart",
        .refresh: "Refresh",
        .enableProxy: "Enable Proxy",
        .disableProxy: "Disable Proxy",
        .importLocal: "Import Local YAML",
        .subscriptionURL: "Subscription URL",
        .displayName: "Display name",
        .subscriptionEditHint: "After saving, the display name updates immediately. The subscription URL is used by Update; clear it to keep this as a local YAML profile.",
        .importSubscription: "Import Subscription",
        .importFromClients: "Import From Other Clients",
        .importOne: "Import",
        .scanClients: "Scan Clients",
        .externalImportHint: "Scans Clash Verge, ClashX, Mihomo Party, and common .config folders. Only recognized YAML configs are copied.",
        .importAllFound: "Import All",
        .noExternalProfilesFound: "No importable configs found",
        .externalProfilesFound: "Importable configs found",
        .subscriptionURLFound: "Subscription URL found",
        .useProfile: "Use",
        .activate: "Activate",
        .active: "Active",
        .currentActive: "Current",
        .update: "Update",
        .edit: "Edit",
        .editInfo: "Edit Info",
        .editFile: "Edit File",
        .editRules: "Edit Rules",
        .editNodes: "Edit Nodes",
        .editProxyGroups: "Edit Proxy Groups",
        .extendOverrideConfig: "Extend Override Config",
        .globalExtendOverrideConfig: "Global Extend Override Config",
        .extendScript: "Extend Script",
        .updateViaProxy: "Update via Proxy",
        .visualEditor: "Visual",
        .codeEditor: "Code",
        .addSection: "Add",
        .deleteSection: "Delete",
        .topLevelKey: "Top-level Key",
        .content: "Content",
        .applyToCode: "Apply to Code",
        .openFile: "Open File",
        .save: "Save",
        .cancel: "Cancel",
        .delete: "Delete",
        .unsupportedFeature: "Not supported yet",
        .refreshProxies: "Refresh Proxies",
        .refreshProviders: "Refresh Providers",
        .groups: "groups",
        .node: "Node",
        .delay: "Delay",
        .delayTest: "Test Delay",
        .groupDelayTest: "Test Group",
        .refreshConnections: "Refresh Connections",
        .searchConnections: "Search Connections",
        .noConnections: "No Connections",
        .noMatchingConnections: "No Matching Connections",
        .closeAll: "Close All",
        .activeConnections: "active",
        .close: "Close",
        .networkReport: "Network Report",
        .activeTraffic: "Active Traffic",
        .routeDistribution: "Route Distribution",
        .topHosts: "Top Hosts",
        .topProcesses: "Top Processes",
        .topRules: "Top Rules",
        .topChains: "Top Chains",
        .proxyRoute: "Proxy",
        .directRoute: "Direct",
        .unknownRoute: "Unknown",
        .historyTrend: "History",
        .refreshRules: "Refresh Rules",
        .processLog: "Process",
        .runtimeLog: "Runtime",
        .logReport: "Log Report",
        .logLevels: "Log Levels",
        .totalLines: "Total Lines",
        .errorLogs: "Errors",
        .warningLogs: "Warnings",
        .infoLogs: "Info",
        .debugLogs: "Debug",
        .recentIssues: "Recent Issues",
        .frequentMessages: "Frequent Issues",
        .aiAnalysisReady: "AI analysis context ready",
        .clear: "Clear",
        .executable: "Executable",
        .useDetectedCore: "Use Detected Core",
        .secret: "Secret",
        .ports: "Ports",
        .controllerHost: "Controller host",
        .systemProxyHost: "System proxy host",
        .notifications: "Notifications",
        .notificationPermission: "Desktop notification permission",
        .notificationPermissionAuthorized: "Allowed",
        .notificationPermissionDenied: "Denied; using in-app notifications",
        .notificationPermissionNotDetermined: "Not requested",
        .requestNotificationPermission: "Request Permission",
        .testNotification: "Send Test Notification",
        .notificationTestTitle: "Chumen notifications are ready",
        .notificationTestBody: "If desktop notifications are unavailable, this appears in the app.",
        .notificationCoreStarted: "Core started",
        .notificationCoreStopped: "Core stopped",
        .notificationCoreRestarted: "Core restarted",
        .notificationCoreFailed: "Core failed",
        .notificationCoreExited: "Core exited unexpectedly",
        .configSync: "Config Sync",
        .syncBackend: "Sync backend",
        .syncBackendDirectory: "Sync Folder",
        .syncBackendCloudKit: "iCloud CloudKit",
        .syncDirectory: "Sync folder",
        .chooseSyncDirectory: "Choose Sync Folder",
        .syncDirectorySelected: "Sync folder selected",
        .cloudKitContainerIdentifier: "CloudKit Container ID (blank uses the default container)",
        .checkCloudKitStatus: "Check iCloud Status",
        .syncUpload: "Upload Local Config",
        .syncDownload: "Pull Synced Config",
        .syncUploaded: "Config uploaded",
        .syncDownloaded: "Config pulled",
        .syncCompleted: "Sync completed",
        .syncFailed: "Sync failed",
        .lastSync: "Last sync",
        .syncPlaintextWarning: "The sync folder and CloudKit snapshot contain subscription URLs, secrets, and config content. Use a trusted folder or private iCloud account.",
        .syncDirectoryNotSelected: "No sync folder selected",
        .syncMissingProfileFile: "Sync snapshot is missing a profile file",
        .syncCloudKitAvailable: "iCloud account is available; CloudKit still requires iCloud entitlements in the app signature.",
        .syncCloudKitNoAccount: "No iCloud account is signed in on this Mac.",
        .syncCloudKitRestricted: "The current iCloud account is restricted.",
        .syncCloudKitUnknown: "Could not determine iCloud status.",
        .syncCloudKitTemporaryUnavailable: "iCloud is temporarily unavailable.",
        .syncCloudKitNoSnapshot: "No Chumen sync snapshot exists in CloudKit yet.",
        .statusBar: "Menu Bar",
        .showStatusBarItem: "Show menu bar item",
        .statusBarDisplayMode: "Menu bar display",
        .statusBarCustomTemplate: "Custom template",
        .statusBarTemplatePreview: "Preview",
        .statusBarModeIconOnly: "Icon Only",
        .statusBarModeAppName: "App Name",
        .statusBarModeStatus: "Status",
        .statusBarModeSpeed: "Live Speed",
        .statusBarModeStackedSpeed: "Stacked Speed",
        .statusBarModeTraffic: "Total Traffic",
        .statusBarModeStatusAndSpeed: "Status and Speed",
        .statusBarModeCustom: "Custom",
        .networkOptions: "Network Options",
        .allowLAN: "Allow LAN",
        .ipv6: "IPv6",
        .unifiedDelay: "Unified Delay",
        .logLevel: "Log Level",
        .tunMode: "TUN Mode",
        .enableTun: "Enable TUN",
        .disableTun: "Disable TUN",
        .tunStack: "TUN Stack",
        .dns: "DNS",
        .enableDNS: "Enable DNS",
        .dnsListen: "DNS listen address",
        .dnsMode: "DNS Mode",
        .nameservers: "DNS servers",
        .autoStartCoreOnLaunch: "Start core when Chumen opens",
        .setProxyOnStart: "Set system proxy after start",
        .clearProxyOnStop: "Clear system proxy on stop",
        .files: "Files",
        .openDataDirectory: "Open Data Directory",
        .more: "More",
        .quit: "Quit",
        .saveSettings: "Save Settings",
        .language: "Language",
        .apiNotTested: "API not tested",
        .controllerUnavailable: "Could not connect to core API",
        .coreNotRunning: "Core is not running",
        .coreNotRunningHint: "Proxy, connections, and traffic require the core to be started first.",
        .apiConnected: "Controller API connected",
        .apiConnectedHint: "Proxy, connection, rule, and traffic status can be read.",
        .apiUnavailable: "Controller API unavailable",
        .apiUnavailableHint: "The controller port is not responding. Check whether the core is running and the port matches:",
        .apiNotTestedHint: "The controller API will be checked after startup.",
        .externalCoreDetected: "External core owns controller port",
        .externalCoreDetectedHint: "The controller API responds, but the process was not started by Chumen.",
        .actionStartCore: "Start required",
        .actionCheckAPI: "Check required",
        .ready: "Ready",
        .pending: "Pending",
        .noLogs: "No logs yet.",
        .noService: "No service",
        .externalProxy: "Other proxy enabled",
        .on: "On",
        .off: "Off",
        .imported: "Imported",
        .skipped: "Skipped",
        .failed: "Failed",
        .updated: "Updated",
        .saved: "Saved",
        .healthchecked: "Healthchecked",
        .deleted: "Deleted",
        .subscriptionURLEmpty: "Subscription URL is empty",
        .coreDetected: "Core detected",
        .coreNotFound: "No executable mihomo candidate found",
        .connectionsClosed: "Connections closed",
        .systemProxyEnabled: "System proxy enabled",
        .systemProxyDisabled: "System proxy disabled",
        .tunEnabled: "TUN mode enabled",
        .tunDisabled: "TUN mode disabled",
        .tunFailed: "TUN failed to start",
        .ineffective: "Inactive",
        .tunRouteConflict: "Route conflict",
        .tunPermissionRequired: "Administrator permission required",
        .unknown: "unknown",
        .upload: "Up",
        .download: "Down",
        .proxyProviders: "Proxy Providers",
        .ruleProviders: "Rule Providers",
        .vehicle: "Vehicle",
        .providerItems: "items",
        .coreExited: "Core exited",
        .clearedSelection: "Selection cleared",
        .ruleDisabled: "Rule disabled",
        .ruleEnabled: "Rule enabled",
        .runtimeConfigReloaded: "Runtime config reloaded",
        .coreRestartRequested: "Kernel restart requested",
        .fakeIPFlushed: "Fake-IP cache flushed",
        .dnsCacheFlushed: "DNS cache flushed",
        .geoUpdated: "Geo data updated",
        .webUIUpdated: "Web UI updated",
        .debugGCDone: "GC triggered",
        .dnsQueryDone: "DNS query completed",
        .storageRead: "Storage read",
        .storageWritten: "Storage written",
        .storageDeleted: "Storage deleted",
        .coreTools: "Core Tools",
        .speed: "Speed",
        .memory: "Memory",
        .memoryUnavailable: "Unavailable",
        .cache: "Cache",
        .flushFakeIP: "Flush Fake-IP",
        .flushDNS: "Flush DNS",
        .updateGeo: "Update Geo",
        .upgradeGeo: "Upgrade Geo",
        .upgradeUI: "Upgrade Web UI",
        .debugGC: "Run GC",
        .reloadRuntimeConfig: "Reload Config",
        .applySettingsToCore: "Apply to Core",
        .restartKernelAPI: "API Restart Kernel",
        .dnsQuery: "DNS Query",
        .storage: "Storage",
        .rawAPI: "Raw API",
        .request: "Request",
        .response: "Response",
        .body: "Body",
        .key: "Key",
        .value: "Value",
        .read: "Read",
        .write: "Write",
        .openDashboard: "Open Dashboard",
        .dashboardPreset: "Dashboard Panel",
        .dashboardSelected: "selected",
        .configAppendix: "Append YAML",
        .externalUI: "External UI",
        .corsOrigins: "CORS Origins",
        .advancedTun: "Advanced TUN",
        .advancedDNS: "Advanced DNS"
    ]
}
