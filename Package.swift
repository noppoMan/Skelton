import PackageDescription

let package = Package(
    name: "Skelton",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/noppoman/HTTPParser", majorVersion: 0, minor: 6),
        .Package(url: "https://github.com/noppoMan/HTTP.git", majorVersion: 0, minor: 5)
    ]
)
