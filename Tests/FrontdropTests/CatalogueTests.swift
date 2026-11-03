import Foundation

@main
struct CatalogueTests {
    static func main() throws {
        var checks=0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(),message); checks+=1 }
        expect(CatalogueSource.space.home.absoluteString == "https://motionbgs.com/tag:space/", "Dedicated Space library")
        let collections: [(CatalogueSource, String)] = [(.anime, "anime"), (.games, "games"), (.nature, "nature"), (.cars, "car"), (.cyberpunk, "cyberpunk")]
        for (source, tag) in collections {
            expect(source.home.absoluteString == "https://motionbgs.com/tag:\(tag)/", "Discover opens the provider's actual collection")
            expect(URLComponents(url: source.searchURL("rain"), resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "rain", "Search must not hide matches by injecting a category keyword")
        }
        expect(CatalogueSource.abstract.home == CatalogueSource.all.searchURL("abstract"), "Abstract opens populated provider search")
        expect(CatalogueSource.anime.home(provider: .desktopHut).absoluteString == "https://www.desktophut.com/category/anime-live-wallpapers", "Anime has a second provider")
        expect(CatalogueSource.games.home(provider: .desktopHut).absoluteString == "https://www.desktophut.com/category/games-live-wallpapers", "Gaming has a second provider")
        expect(CatalogueSource.games.searchURL("Elden Ring", provider: .desktopHut).absoluteString == "https://www.desktophut.com/search/Elden%20Ring", "Franchise search works across providers")
        expect(CatalogueSource.anime.topics.contains("Jujutsu Kaisen") && CatalogueSource.games.topics.contains("Elden Ring"), "Series and game shortcuts are available")
        expect(CatalogueProvider.allCases.count == 3, "Three actual video libraries; paid community references are separate")
        expect(CatalogueSource.anime.home(provider: .liveWallpapers4Free).absoluteString == "https://livewallpapers4free.com/category/anime-live-wallpapers/", "Open the full anime collection")
        expect(CatalogueSource.games.home(provider: .liveWallpapers4Free).absoluteString == "https://livewallpapers4free.com/category/games-live-wallpapers/", "Open the full game collection")
        expect(URLComponents(url: CatalogueSource.anime.searchURL("Gojo & Sukuna", provider: .liveWallpapers4Free), resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "Gojo & Sukuna", "Encode franchise searches without losing punctuation")
        expect(CatalogueSource.space.home(provider: .liveWallpapers4Free).absoluteString.contains("s=space"), "Space does not silently map to a generic sci-fi category")
        expect(CatalogueSource.discoverSources.contains(.fantasy) && CatalogueSource.discoverSources.contains(.movies) && CatalogueSource.discoverSources.contains(.animals) && CatalogueSource.discoverSources.contains(.city), "More wallpaper genres are directly discoverable")
        expect(Set(CatalogueSource.discoverSources.map(\.sectionID)).count == CatalogueSource.discoverSources.count, "Discover IDs remain unique")
        expect(CatalogueSource.nature.libraryCategory == "Nature" && CatalogueSource.games.libraryCategory == "Anime & Games", "Downloads inherit usable local categories")
        expect(CatalogueSource.all.libraryCategory == nil, "General Browse remains separate from collection shortcuts")
        expect(CataloguePolicy.videoExtension(filename: "../../cool.mp4", mime: "video/mp4") == "mp4", "Filename does not carry path components")
        expect(CataloguePolicy.videoExtension(filename: "installer.exe", mime: "application/octet-stream") == nil, "Reject installers")
        expect(CataloguePolicy.videoExtension(filename: "scene.zip", mime: "application/zip") == nil, "Reject interactive ZIP packages")
        expect(CataloguePolicy.videoExtension(filename: "download", mime: "video/mp4") == "mp4", "Extensionless video response")
        expect(CataloguePolicy.videoExtension(filename: "movie.mp4", mime: "text/html") == nil, "Reject HTML error pages masquerading as MP4")
        expect(CataloguePolicy.isVideoLink(URL(string:"https://cdn.example/video.MP4?download=1")!), "Case-insensitive video extension")
        expect(!CataloguePolicy.isVideoLink(URL(string:"https://example/scene.html")!), "HTML remains browsable")
        expect(CataloguePolicy.isWebURL(URL(string:"https://motionbgs.com/foo")!), "HTTPS allowed")
        expect(!CataloguePolicy.isWebURL(URL(string:"file:///etc/passwd")!), "Remote catalogue cannot navigate local files")
        expect(CataloguePolicy.downloadExtension(filename: "wallpaper.zip", mime: "application/zip") == "zip", "Archive downloads go through bounded video-only extraction")
        expect(CataloguePolicy.downloadExtension(filename: "wallpaper.zip", mime: "text/html") == nil, "HTML challenges must not masquerade as archives")
        expect(CataloguePolicy.title(pageTitle:"Yuta Summer Sky Live Wallpaper",filename:"yuta-4k.mp4") == "Yuta Summer Sky", "Preserve scene title without site suffix")
        print("PASS: \(checks) catalogue URL and download checks")
    }
}
