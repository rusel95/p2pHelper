//
//  PaymentMethod.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum PaymentMethod: Equatable {
    
    // MARK: - BINANCE
    
    enum Binance: Equatable {
        
        enum P2P: String {
            case privatbank = "Privatbank"
            case monobank = "Monobank"
            case pumb = "PUMBBank"
            case abank = "ABank"
            case wise = "Wise"
            case binancePayUAH = "UAHfiatbalance"
            
            var shortDescription: String {
                switch self {
                case .privatbank: return "P2P_Privat"
                case .monobank: return "P2P_Mono"
                case .pumb: return "P2P_PUMB"
                case .abank: return "P2P_ABank"
                case .wise: return "P2P_Wise"
                case .binancePayUAH: return "P2P_Fiat"
                }
            }
        }
        
        enum Spot: String {
            
            case usdtUAH = "USDTUAH"
            
            var shortDescription: String {
                switch self {
                case .usdtUAH: return "BinanceSpot"
                }
            }
        }
        
        case p2p(P2P)
        case spot(Spot)
        
    }
    
    // MARK: - WHITEBIT
    
    enum WhiteBit: String {
        
        case usdtuahSpot = "USDT_UAH"
        
        var description: String {
            switch self {
            case .usdtuahSpot: return "WhiteBit_Spot"
            }
        }
    }
    
    // MARK: - Huobi
    
    enum Huobi: String {
        case usdtuahSpot = "usdtuah"
        
        var description: String {
            switch self {
            case .usdtuahSpot: return "Huobi_Spot"
            }
        }
    }
    
    // MARK: - EXMO
    
    enum EXMO: String {
        
        case usdtuahSpot = "USDT_UAH"
        
        var description: String {
            switch self {
            case .usdtuahSpot: return "EXMO_Spot"
            }
        }
    }
    
    // MARK: - KUNA
    
    enum Kuna: String {
        
        case usdtuahSpot = "USDTUAH"
        
        var description: String {
            switch self {
            case .usdtuahSpot: return "KUNA_Spot"
            }
        }
    }
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    case exmo(EXMO)
    case kuna(Kuna)
    
    var apiDescription: String {
        switch self {
        case .binance(let binancePaymentMethod):
            switch binancePaymentMethod {
            case .p2p(let p2pPaymentMethod):
                return p2pPaymentMethod.rawValue
            case .spot(let binanceSpot):
                return binanceSpot.rawValue
            }
        case .whiteBit(let paymentMethod):
            return paymentMethod.rawValue
        case .huobi(let paymentMethod):
            return paymentMethod.rawValue
        case .exmo(let paymentMethod):
            return paymentMethod.rawValue
        case .kuna(let paymentMethod):
            return paymentMethod.rawValue
        }
    }
    
    var description: String {
        switch self {
        case .binance(let binancePaymentMethod):
            switch binancePaymentMethod {
            case .p2p(let p2pPaymentMethod):
                return p2pPaymentMethod.shortDescription
            case .spot(let binanceSpot):
                return binanceSpot.shortDescription
            }
        case .whiteBit(let paymentMethod):
            return paymentMethod.description
        case .huobi(let paymentMethod):
            return paymentMethod.description
        case .exmo(let paymentMethod):
            return paymentMethod.description
        case .kuna(let paymentMethod):
            return paymentMethod.description
        }
    }
    
}
