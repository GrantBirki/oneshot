import SwiftUI

struct AboutInfoView: View {
    private let linkColor = Color.primary.opacity(0.75)

    var body: some View {
        HStack(spacing: 4) {
            Text("Made with")
            Text("♥")
                .foregroundStyle(.red)
            Text("by")
            Link("GrantBirki", destination: URL(string: "https://github.com/GrantBirki")!)
                .foregroundStyle(linkColor)
                .tint(linkColor)
                .underline()
            Text("•")
            if let sha = BuildInfo.gitSHA,
               let url = URL(string: "https://github.com/GrantBirki/oneshot/tree/\(sha)") {
                Link("commit \(BuildInfo.shortGitSHA)", destination: url)
                    .foregroundStyle(linkColor)
                    .tint(linkColor)
                    .underline()
            } else {
                Text("commit \(BuildInfo.shortGitSHA)")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct AboutView: View {
    private let linkColor = Color.primary.opacity(0.75)

    var body: some View {
        VStack(spacing: 12) {
            Text("OneShot")
                .font(.title2)
                .fontWeight(.semibold)

            AboutInfoView()

            Link("Source code", destination: URL(string: "https://github.com/GrantBirki/oneshot")!)
                .font(.footnote)
                .foregroundStyle(linkColor)
                .tint(linkColor)
                .underline()
        }
        .padding(20)
        .frame(width: 320)
    }
}
