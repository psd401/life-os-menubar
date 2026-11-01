import LifeOSMenubarCore
import NexusKit
import SwiftUI

/// Geometry for the quick-capture window. `rail-width` is the Nexus token for a
/// floating single-column surface of this kind, which is what the `MacQuickAsk`
/// bar is.
enum QuickCaptureMetrics {
  static let width = NexusSize.railWidth + NexusSpace.s24
}

struct QuickCaptureView: View {
  @ObservedObject var viewModel: QuickCaptureViewModel
  @Environment(\.nexus) private var palette
  @FocusState private var focusedField: Field?

  let tokenProvider: @MainActor () -> String
  let cancel: () -> Void
  let created: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s4) {
      // The ask row is the one glass surface here, per `MacQuickAsk`: the bar
      // floats and everything it collects below sits on paper.
      HStack(spacing: NexusSpace.s3) {
        Image(systemName: "plus.circle")
          .font(.system(size: NexusSize.iconMd, weight: .regular))
          .foregroundStyle(palette.action)
          .accessibilityHidden(true)

        TextField("Capture a task", text: $viewModel.title)
          .textFieldStyle(.plain)
          .font(NexusFont.title2)
          .focused($focusedField, equals: .title)
          .onSubmit(submit)
          .disabled(viewModel.isSubmitting)
          .accessibilityLabel("Task title")

        Text("Return")
          .font(NexusFont.caption2)
          .foregroundStyle(palette.inkSubtle)
      }
      .padding(.horizontal, NexusSpace.s4)
      .padding(.vertical, NexusSpace.s3)
      .nexusChrome(in: RoundedRectangle(cornerRadius: NexusRadius.sheet))

      VStack(alignment: .leading, spacing: NexusSpace.s2) {
        Text("Notes (optional)")
          .font(NexusFont.caption2)
          .foregroundStyle(palette.inkMuted)
        TextEditor(text: $viewModel.body)
          .font(NexusFont.body)
          .scrollContentBackground(.hidden)
          .padding(NexusSpace.s2)
          .frame(minHeight: NexusSize.headerHeight + NexusSpace.s10)
          .background(
            palette.surfaceRaised,
            in: RoundedRectangle(cornerRadius: NexusRadius.sm)
          )
          .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.sm)
              .stroke(palette.line, lineWidth: 1)
          )
          .disabled(viewModel.isSubmitting)
          .accessibilityLabel("Optional task notes")
      }

      VStack(alignment: .leading, spacing: NexusSpace.s2) {
        Text("Priority")
          .font(NexusFont.caption2)
          .foregroundStyle(palette.inkMuted)
        Picker("Priority", selection: $viewModel.priority) {
          ForEach(QuickCapturePriority.allCases) { priority in
            Text(priority.title).tag(priority)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(viewModel.isSubmitting)
      }

      if let errorMessage = viewModel.errorMessage {
        HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: NexusSize.iconSm, weight: .regular))
            .accessibilityHidden(true)
          Text(errorMessage)
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(NexusFont.caption1)
        .foregroundStyle(palette.dangerInk)
        .padding(.horizontal, NexusSpace.s3)
        .padding(.vertical, NexusSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.dangerSoft, in: RoundedRectangle(cornerRadius: NexusRadius.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Creation error: \(errorMessage)")
      }

      HStack(spacing: NexusSpace.s3) {
        Button("Discard capture", role: .cancel, action: cancel)
          .buttonStyle(.bordered)
          .keyboardShortcut(.cancelAction)
          .disabled(viewModel.isSubmitting)

        Spacer()

        if viewModel.isSubmitting {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel("Creating task")
        }

        // The one prominent `action` button in this window.
        Button("Create task", action: submit)
          .buttonStyle(.borderedProminent)
          .tint(palette.action)
          .keyboardShortcut(.defaultAction)
          .disabled(!viewModel.canSubmit)
      }
    }
    .padding(NexusSpace.s5)
    .frame(width: QuickCaptureMetrics.width)
    .onAppear {
      focusedField = .title
    }
    .onChange(of: viewModel.titleFocusRequest) {
      focusedField = .title
    }
    .onExitCommand(perform: cancel)
  }

  private func submit() {
    guard viewModel.canSubmit else {
      return
    }
    Task {
      if let issue = await viewModel.submit(token: tokenProvider()) {
        created(issue)
      }
    }
  }
}

private enum Field {
  case title
}
