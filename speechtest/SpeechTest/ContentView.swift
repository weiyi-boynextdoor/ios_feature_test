import AVFoundation
import SwiftUI

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String
    let languageName: String
}

@MainActor
final class SpeechController: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, voiceIdentifier: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first)
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

struct ContentView: View {
    @StateObject private var speechController = SpeechController()
    @State private var inputText = "Hello from AVSpeechSynthesizer."
    @State private var selectedLanguageCode = ""
    @State private var selectedVoiceIdentifier = ""

    private let installedVoices: [VoiceOption] = AVSpeechSynthesisVoice.speechVoices()
        .map { voice in
            VoiceOption(
                id: voice.identifier,
                name: voice.name,
                languageCode: voice.language,
                languageName: Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
            )
        }
        .sorted {
            if $0.languageName == $1.languageName {
                return $0.name < $1.name
            }
            return $0.languageName < $1.languageName
        }

    private var availableLanguages: [(code: String, name: String)] {
        Array(
            Dictionary(
                installedVoices.map { ($0.languageCode, $0.languageName) },
                uniquingKeysWith: { first, _ in first }
            )
            .map { (code: $0.key, name: $0.value) }
            .sorted { $0.name < $1.name }
        )
    }

    private var filteredVoices: [VoiceOption] {
        guard !selectedLanguageCode.isEmpty else { return installedVoices }
        return installedVoices.filter { $0.languageCode == selectedLanguageCode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Speech Demo")
                .font(.largeTitle.bold())

            Text("Enter text below and tap the button to hear it spoken aloud.")
                .foregroundStyle(.secondary)

            TextField("Type something to speak", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Picker("Language", selection: $selectedLanguageCode) {
                Text("All Languages").tag("")

                ForEach(availableLanguages, id: \.code) { language in
                    Text(language.name)
                        .tag(language.code)
                }
            }
            .pickerStyle(.menu)

            Picker("Voice", selection: $selectedVoiceIdentifier) {
                Text("System Default").tag("")

                ForEach(filteredVoices) { voice in
                    Text("\(voice.name) (\(voice.languageName))")
                        .tag(voice.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedLanguageCode) { _, newLanguageCode in
                let selectedVoiceStillAvailable = filteredVoices.contains { $0.id == selectedVoiceIdentifier }
                if selectedVoiceStillAvailable || selectedVoiceIdentifier.isEmpty {
                    return
                }

                selectedVoiceIdentifier = filteredVoices.first?.id ?? ""
            }

            Button(action: {
                let voiceIdentifier = selectedVoiceIdentifier.isEmpty ? nil : selectedVoiceIdentifier
                speechController.speak(inputText, voiceIdentifier: voiceIdentifier)
            }) {
                Text(speechController.isSpeaking ? "Speak Again" : "Play Speech")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding(24)
        .onAppear {
            guard selectedLanguageCode.isEmpty else { return }
            selectedLanguageCode = availableLanguages.first?.code ?? ""
        }
    }
}
