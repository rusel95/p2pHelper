//
//  File.swift
//  
//
//  Created by Ruslan Popesku on 22.06.2022.
//

import Vapor
import telegram_vapor_bot
import Jobs

final class DefaultBotHandlers {
    
    typealias PricesInfo = (possibleBuyPrice: Double, possibleSellPrice: Double)
    
    // MARK: - ENUMERATIONS
    
    private enum Mode {
        
        case logging
        case trading
        case alerting /*
                       example 1: USDT/UAH spot -> UAH Crypto to UAH fiat -> UAH fiat to USDT
                       example 2: BTC(other coint)/USDT spot price >= 2% difference to p2p market
                       example 3: Stable Coin/Stable Coin price >= 3% difference then normal level
                       */
        case suspended
        
        var jobInterval: Double { // in seconds
            switch self {
            case .logging: return 900
            case .trading: return 30
            case .alerting: return 60
            case .suspended: return 0
            }
        }
        
        var command: String {
            switch self {
            case .logging: return "/start_logging"
            case .trading: return "/start_trading"
            case .alerting: return "/start_alerting"
            case .suspended: return "/stop"
            }
        }
    }
    
    // MARK: - PROPERTIES
    
    static let shared = DefaultBotHandlers()
    
    private var loggingJob: Job?
    private var tradingJob: Job?
    private var alertingJob: Job?
    
    let resultsFormatDescription = "платежный способ - возможная цена Продажи / Покупки - спред грязный / чистый - чистый профит в %"
    
    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartLoggingHandler(app: app, bot: bot)
        commandStartTradingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
    }

}

// MARK: - HELPERS

private extension DefaultBotHandlers {
    
    /// add handler for command "/start_logging"
    func commandStartLoggingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.logging.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            let infoMessage = "Now you will see market updates every \(Int(Mode.logging.jobInterval / 60)) minutes\n\(self.resultsFormatDescription)"
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            self.loggingJob = Jobs.add(interval: .seconds(Mode.logging.jobInterval)) { [weak self] in
                self?.printMarketPosibilities(for: BinanceService.Crypto.allCases, bot: bot, update: update)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_trading"
    func commandStartTradingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.trading.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            let infoMessage = "Now you will see market updates every \(Int(Mode.trading.jobInterval)) seconds \n\(self.resultsFormatDescription)"
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            
            self.alertingJob = Jobs.add(interval: .seconds(Mode.trading.jobInterval)) { [weak self] in
                self?.printMarketPosibilities(for: BinanceService.Crypto.allCases, bot: bot, update: update)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_alerting"
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.alerting.command]) { [weak self] update, bot in
            self?.alertingJob = Jobs.add(interval: .seconds(Mode.alerting.jobInterval)) { [weak self] in
                self?.checkWhiteBitArbitrage(for: bot, update: update)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/stop"
    func commandStopHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.suspended.command]) { [weak self] update, bot in
            self?.loggingJob?.stop()
            self?.tradingJob?.stop()
            self?.alertingJob?.stop()
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text:  "Now bot will have some rest"))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    func printMarketPosibilities(for cryptos: [BinanceService.Crypto], bot: TGBotPrtcl, update: TGUpdate) {
        let cryptoGroup = DispatchGroup()
        var totalDescriptioon: String = ""
        
        cryptos.forEach { crypto in
            cryptoGroup.enter()
            getSpreadDescription(for: crypto) { description in
                totalDescriptioon.append("\(description)\n")
                cryptoGroup.leave()
            }
        }
        
        cryptoGroup.notify(queue: .global()) {
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: totalDescriptioon)
            _ = try? bot.sendMessage(params: params)
        }
    }
    
    func getSpreadDescription(for crypto: BinanceService.Crypto, completion: @escaping(String) -> Void) {
        let spreadGroup = DispatchGroup()
        
        var message: String = "\(crypto.rawValue):\n"
        BinanceService.PaymentMethod.allCases.forEach { paymentMethod in
            spreadGroup.enter()
            getSpread(for: paymentMethod, crypto: crypto) { pricesInfo in
                guard let pricesInfo = pricesInfo else {
                    spreadGroup.leave()
                    return
                }

                let buyPriceString = String(format: "%.2f", pricesInfo.possibleBuyPrice)
                let sellPriceString = String(format: "%.2f", pricesInfo.possibleSellPrice)
                let dirtySpread = pricesInfo.possibleBuyPrice - pricesInfo.possibleSellPrice
                let dirtySpreadString = String(format: "%.2f", dirtySpread)
                let cleanSpread = dirtySpread - pricesInfo.possibleBuyPrice * 0.001 * 2
                let cleanSpreadString = String(format: "%.2f", cleanSpread)
                let cleanSpreadPercentString = String(format: "%.2f", (cleanSpread / pricesInfo.possibleBuyPrice * 100))
                
                message.append("\(paymentMethod.rawValue) - \(buyPriceString) / \(sellPriceString) - \(dirtySpreadString) / \(cleanSpreadString) - \(cleanSpreadPercentString)%\n")
                spreadGroup.leave()
            }
        }
        
        spreadGroup.notify(queue: .global()) {
            completion(message)
        }
    }
    
    func getSpread(
        for paymentMethod: BinanceService.PaymentMethod,
        crypto: BinanceService.Crypto,
        completion: @escaping(PricesInfo?) -> Void
    ) {
        BinanceService.shared.loadAdvertisements(for: paymentMethod, crypto: crypto) { buyAdvs, sellAdvs, error in
            guard let buyAdvs = buyAdvs, let sellAdvs = sellAdvs else {
                completion(nil)
                return
            }
            
            let buyPrices = buyAdvs
                .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                .compactMap { Double($0.price) }
                .compactMap { $0 }
            
            let averageBuyPrice = buyPrices.reduce(0.0, +) / Double(buyPrices.count)
            
            let sellPrices = sellAdvs
                .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                .compactMap { Double($0.price) }
                .compactMap { $0 }
            let averageSellPrice = sellPrices.reduce(0.0, +) / Double(sellPrices.count)
            completion(PricesInfo(possibleBuyPrice: averageBuyPrice, possibleSellPrice: averageSellPrice))
        }
    }
    
    func checkWhiteBitArbitrage(for bot: TGBotPrtcl, update: TGUpdate) {
        var whiteBitAsks: [Double]?
        var whiteBitBids: [Double]?
        var monoPricesInfo: PricesInfo? = nil
        let arbitrageGroup = DispatchGroup()
        
        arbitrageGroup.enter()
        getSpread(for: .monobank, crypto: .usdt) { pricesInfo in
            monoPricesInfo = pricesInfo
            arbitrageGroup.leave()
        }
        arbitrageGroup.enter()
        WhiteBitService.shared.getOrderbook(for: .usdtuah) { asks, bids, error in
            whiteBitAsks = asks
            whiteBitBids = bids
            arbitrageGroup.leave()
        }
        
        arbitrageGroup.notify(queue: .global()) {
            guard let whiteBitAsks = whiteBitAsks,
                  let whiteBitBids = whiteBitBids,
                  let monoPricesInfo = monoPricesInfo else {
                return
            }

            let whiteBitBuyDescription = whiteBitAsks.first.map { String($0) } ?? "no prices"
            let monoSellDescription = String(format: "%.2f", monoPricesInfo.possibleBuyPrice)
            var text = "WhiteBit buy: \(whiteBitBuyDescription) Mono Sell: \(monoSellDescription)\n"
            let whiteBitSellDescription = whiteBitBids.first.map { String($0) } ?? "no prices"
            let monoBuyDescription = String(format: "%.2f", monoPricesInfo.possibleSellPrice)
            text.append("WhiteBit sell: \(whiteBitSellDescription) Mono Buy: \(monoBuyDescription)")
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
        }
    }
    
}
