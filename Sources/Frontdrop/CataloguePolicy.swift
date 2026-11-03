import Foundation

enum CatalogueProvider: String, CaseIterable, Identifiable {
    case liveWallpapers4Free = "LiveWallpapers4Free"
    case motionBGS = "MotionBGS"
    case desktopHut = "DesktopHut"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .liveWallpapers4Free: return "Anime, gaming, 3D scenes and landscapes, with downloadable MP4 versions."
        case .motionBGS: return "Anime, games, space, landscapes and ultrawide video wallpapers."
        case .desktopHut: return "Another community video collection, with game, anime and environment categories."
        }
    }
}

enum CatalogueSource: String, CaseIterable, Identifiable {
    case all = "All wallpapers"
    case anime = "Anime"
    case games = "Gaming"
    case space = "Space wallpapers"
    case nature = "Nature"
    case fantasy = "Fantasy"
    case movies = "Movies & TV"
    case animals = "Animals"
    case city = "City & landscapes"
    case cars = "Cars"
    case abstract = "Abstract"
    case cyberpunk = "Cyberpunk"
    var id: String { rawValue }
    static let discoverSources = allCases.filter { $0 != .all }
    var sectionID: String { "Discover " + rawValue }
    var libraryCategory: String? {
        switch self {
        case .all: return nil
        case .space: return "Space"
        case .anime, .games: return "Anime & Games"
        case .nature, .animals: return "Nature"
        case .cars: return "Cars"
        case .abstract: return "Abstract"
        case .cyberpunk: return "Cyberpunk"
        case .fantasy, .movies, .city: return "Scenes"
        }
    }
    var symbol: String {
        switch self {
        case .all: return "globe"
        case .space: return "moon.stars"
        case .anime: return "sparkles"
        case .games: return "gamecontroller"
        case .nature: return "leaf"
        case .fantasy: return "wand.and.stars"
        case .movies: return "film"
        case .animals: return "pawprint"
        case .city: return "building.2.crop.circle"
        case .cars: return "car"
        case .abstract: return "water.waves"
        case .cyberpunk: return "building.2"
        }
    }
    private var keyword: String {
        switch self {
        case .all: return ""
        case .space: return "space"
        case .anime: return "anime"
        case .games: return "games"
        case .nature: return "nature"
        case .fantasy: return "fantasy"
        case .movies: return "movies"
        case .animals: return "animals"
        case .city: return "city"
        case .cars: return "car"
        case .abstract: return "abstract"
        case .cyberpunk: return "cyberpunk"
        }
    }
    var home: URL { home(provider: .motionBGS) }
    func home(provider: CatalogueProvider) -> URL {
        if provider == .liveWallpapers4Free {
            if self == .all { return URL(string: "https://livewallpapers4free.com/")! }
            if self == .space || self == .cyberpunk { return searchURL(keyword, provider: provider) }
            let category = self == .movies ? "movies-tv" : (self == .cars ? "cars" : (self == .city ? "world" : keyword))
            return URL(string: "https://livewallpapers4free.com/category/" + category + "-live-wallpapers/")!
        }
        if provider == .desktopHut {
            let path: String
            switch self {
            case .all: path = ""
            case .anime: path = "category/anime-live-wallpapers"
            case .games: path = "category/games-live-wallpapers"
            case .nature: path = "category/nature-live-wallpapers"
            case .cars: path = "category/cars-motorcycles-live-wallpapers"
            case .abstract: path = "category/abstract-live-wallpapers"
            case .space, .cyberpunk: path = "tag/" + keyword
            default: return searchURL(keyword, provider: provider)
            }
            return URL(string: "https://www.desktophut.com/" + path)!
        }
        if self == .all { return URL(string: "https://motionbgs.com/")! }
        if [.abstract, .movies, .animals, .city, .fantasy].contains(self) { return searchURL(keyword, provider: provider) }
        return URL(string: "https://motionbgs.com/tag:\(keyword)/")!
    }
    func searchURL(_ query: String, provider: CatalogueProvider = .motionBGS) -> URL {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return home(provider: provider) }
        if provider == .desktopHut { return URL(string: "https://www.desktophut.com/search/")!.appendingPathComponent(term) }
        var components = URLComponents(string: provider == .liveWallpapers4Free ? "https://livewallpapers4free.com/" : "https://motionbgs.com/search")!
        components.queryItems = [URLQueryItem(name: provider == .liveWallpapers4Free ? "s" : "q", value: term)]
        return components.url!
    }
    var topics: [String] {
        switch self {
        case .anime: return ["Naruto", "One Piece", "Jujutsu Kaisen", "Demon Slayer", "Dragon Ball", "Solo Leveling", "Bleach", "Attack on Titan", "Chainsaw Man", "Frieren", "Berserk", "Death Note", "My Hero Academia", "Tokyo Ghoul", "Dandadan", "Ghibli"]
        case .games: return ["Minecraft", "Genshin Impact", "Honkai Star Rail", "Wuthering Waves", "Zenless Zone Zero", "Elden Ring", "Cyberpunk 2077", "Valorant", "League of Legends", "Pokemon", "Fortnite", "Final Fantasy", "Zelda", "Hollow Knight", "Ghost of Tsushima", "Resident Evil", "The Last of Us", "God of War", "Warcraft", "Doom"]
        default: return []
        }
    }

}

enum CataloguePolicy {
    static let extensions: Set<String> = ["mp4", "m4v", "mov"]
    static func isWebURL(_ url: URL) -> Bool { url.scheme?.lowercased() == "https" && url.host != nil }
    static func isVideoLink(_ url: URL) -> Bool { extensions.contains(url.pathExtension.lowercased()) }
    static func videoExtension(filename: String, mime: String?) -> String? {
        let ext = (filename as NSString).pathExtension.lowercased()
        let type = mime?.lowercased().split(separator: ";").first.map(String.init) ?? ""
        // Refuse HTML responses, packages and installers before assigning a destination.
        if ["text/html", "application/xhtml+xml", "application/zip", "application/x-msdownload"].contains(type) { return nil }
        if extensions.contains(ext), type.isEmpty || type.hasPrefix("video/") || type == "application/octet-stream" { return ext }
        switch type {
        case "video/mp4", "video/x-m4v": return "mp4"
        case "video/quicktime": return "mov"
        default: return nil
        }
    }
    static func downloadExtension(filename: String, mime: String?) -> String? {
        let type = mime?.lowercased().split(separator: ";").first.map(String.init) ?? ""
        if (filename as NSString).pathExtension.lowercased() == "zip", ["application/zip", "application/x-zip-compressed", "application/octet-stream"].contains(type) { return "zip" }
        return videoExtension(filename: filename, mime: mime)
    }
    static func title(pageTitle: String?, filename: String) -> String {
        let raw = pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let suffixes = [" Live Wallpaper", " Live Wallpapers", " | DesktopHut", " - DesktopHut", " | MotionBGS", " - LiveWallpapers4Free.com"]
        var title = raw
        for suffix in suffixes { if let range = title.range(of: suffix, options: .caseInsensitive) { title = String(title[..<range.lowerBound]) } }
        if title.isEmpty { title = ((filename as NSString).lastPathComponent as NSString).deletingPathExtension }
        return String(title.prefix(180))
    }
}
