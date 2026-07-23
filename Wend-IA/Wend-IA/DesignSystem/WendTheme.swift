import SwiftUI

/// Tokens de cor da marca e sistema de design do aplicativo Wend.
public enum WendTheme {
    public enum Colors {
        /// Cream Light: Fundo da tela / telas claras (`#FFFAF8`)
        public static let creamLight = Color(hex: "#FFFAF8")
        
        /// Cream Basic: Fundo dos cards brancos/creme (`#FFF4F0`)
        public static let creamBasic = Color(hex: "#FFF4F0")
        
        /// Cream Dark: Fundo do card "Tip of the day" (`#FFEDE1`)
        public static let creamDark = Color(hex: "#FFEDE1")
        
        /// Green Dark: Botões principais (ex: "Start"), títulos destacados e ícones ativos (`#31493C`)
        public static let greenDark = Color(hex: "#31493C")
        
        /// Green Basic: Anel de progresso, ícones de check concluídos e detalhes (`#306A45`)
        public static let greenBasic = Color(hex: "#306A45")
        
        /// Green Light: Fundo do card "Morning Stretch" e cápsula da aba ativa (`#D2EDD4`)
        public static let greenLight = Color(hex: "#D2EDD4")
        
        /// Coffee: Cor dos textos principais (títulos, nomes de exercícios, textos) (`#201914`)
        public static let coffee = Color(hex: "#201914")
    }
}
