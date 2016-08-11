import PackageDescription

let package = Package(
    name: "Skelton",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 10),
        .Package(url: "https://github.com/slimane-swift/HTTPParser.git", majorVersion: 0, minor: 12),
        .Package(url: "https://github.com/slimane-swift/HTTP.git", majorVersion: 0, minor: 12)
    ]
)
