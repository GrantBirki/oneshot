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
            Text(BuildInfo.displayVersion)
            Text("•")
            if let sha = BuildInfo.gitSHA,
               let url = URL(string: "https://github.com/GrantBirki/oneshot/tree/\(sha)")
            {
                Text("commit")
                Link(BuildInfo.shortGitSHA, destination: url)
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
    @StateObject private var updateChecker = UpdateCheckViewModel()

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

            UpdateCheckView(viewModel: updateChecker)
        }
        .padding(20)
        .frame(width: 340)
    }
}

private struct UpdateCheckView: View {
    @ObservedObject var viewModel: UpdateCheckViewModel

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.checkForUpdates()
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(viewModel.isChecking ? "Checking..." : "Check for Updates")
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isChecking)

            statusView
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.state {
        case .idle,
             .checking:
            EmptyView()
        case let .upToDate(version):
            Text("OneShot is up to date (\(version.displayValue)).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case let .updateAvailable(version, releaseURL):
            HStack(spacing: 6) {
                Text("\(version.displayValue) is available.")
                Link("Open Release", destination: releaseURL)
                    .underline()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        case let .failed(message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
