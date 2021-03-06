//
//  UserInfoService.swift
//
//
//  Created by Ruslan Popesku on 14.07.2022.
//

import telegram_vapor_bot
import Vapor

public final class UsersInfoProvider: NSObject {
    
    // MARK: - PROPERTIES
    
    public static let shared = UsersInfoProvider()
    
    private var usersInfo: Set<UserInfo> = []
    private var logger = Logger(label: "handlers.logger")
    
    private var storageURL: URL {
        let fileName = "usersInfo"
        let isDevelopment: Bool = ProcessInfo.processInfo.environment["token"] != nil
        let fileURL: URL
        if isDevelopment,
            let documentsDirectory = try? FileManager.default.url(for: .desktopDirectory,
                                                                  in: .userDomainMask,
                                                                  appropriateFor: nil,
                                                                  create: true) {
            fileURL = documentsDirectory.appendingPathComponent(fileName)
        } else {
            fileURL = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/\(fileName)")
        }
        return fileURL
    }

    // MARK: - INIT
    
    override init() {
        super.init()
        do {
            let jsonData = try Data(contentsOf: self.storageURL)
            self.usersInfo = try JSONDecoder().decode(Set<UserInfo>.self, from: jsonData)
        } catch {
            logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
        }
    }
    
    // MARK: - METHODS
    
    func getAllUsersInfo() -> Set<UserInfo> {
        usersInfo
    }
    
    func getUsersInfo(selectedMode: Mode) -> Set<UserInfo> {
        usersInfo.filter { $0.selectedModes.contains(selectedMode) }
    }
    
    func handleModeSelected(chatId: Int64, user: TGUser, mode: Mode, onlineUpdatesMessageId: Int? = nil) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.insert(mode)
            if onlineUpdatesMessageId != nil {
                userInfo.onlineUpdatesMessageId = onlineUpdatesMessageId
            }
        } else {
            let newUserInfo = UserInfo(chatId: chatId,
                                       user: user,
                                       selectedModes: [mode],
                                       onlineUpdatesMessageId: onlineUpdatesMessageId)
            usersInfo.insert(newUserInfo)
        }
        syncStorage()
    }
    
    func handleStopAllModes(chatId: Int64) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.removeAll()
            syncStorage()
        }
    }
    
    public func syncStorage() {
        do {
            let endcodedData = try JSONEncoder().encode(usersInfo)
            try endcodedData.write(to: storageURL)
        } catch {
            logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
        }
    }
    
}

