import LifeOSMenubarCore
import SwiftUI

struct QuickCaptureView: View {
  @ObservedObject var viewModel: QuickCaptureViewModel
  @FocusState private var focusedField: Field?

  let tokenProvider: @MainActor () -> String
  let cancel: () -> Void
  let created: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Quick Capture")
        .font(.title2.weight(.semibold))

      TextField("Task title", text: $viewModel.title)
        .textFieldStyle(.roundedBorder)
        .focused($focusedField, equals: .title)
        .onSubmit(submit)
        .disabled(viewModel.isSubmitting)
        .accessibilityLabel("Task title")

      VStack(alignment: .leading, spacing: 6) {
        Text("Notes")
          .font(.subheadline.weight(.semibold))
        TextEditor(text: $viewModel.body)
          .font(.body)
          .scrollContentBackground(.hidden)
          .padding(6)
          .frame(minHeight: 96)
          .background(.background, in: RoundedRectangle(cornerRadius: 6))
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color.secondary.opacity(0.3))
          )
          .disabled(viewModel.isSubmitting)
          .accessibilityLabel("Optional task notes")
      }

      Picker("Priority", selection: $viewModel.priority) {
        ForEach(QuickCapturePriority.allCases) { priority in
          Text(priority.title).tag(priority)
        }
      }
      .pickerStyle(.segmented)
      .disabled(viewModel.isSubmitting)

      if let errorMessage = viewModel.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Creation error: \(errorMessage)")
      }

      HStack {
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
          .disabled(viewModel.isSubmitting)

        Spacer()

        if viewModel.isSubmitting {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel("Creating task")
        }

        Button("Create Task", action: submit)
          .keyboardShortcut(.defaultAction)
          .disabled(!viewModel.canSubmit)
      }
    }
    .padding(20)
    .frame(width: 440)
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
