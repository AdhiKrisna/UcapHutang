import Foundation

enum SpeechRecognizerState: Equatable, Sendable {
    case idle
    case listening
    case finalizing
    case failed(String)
}

/// Permission problems the Catat screen shows inline with a "Buka Pengaturan" button.
enum SpeechPermissionError: LocalizedError, Equatable {
    case microphoneDenied
    case speechDenied
    case restricted

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan."
        case .speechDenied: "Izin Speech Recognition ditolak. Buka Pengaturan untuk mengaktifkan."
        case .restricted: "Speech Recognition dibatasi pada perangkat ini."
        }
    }
}

/// Non-permission failures while starting speech recognition.
enum SpeechRecognitionError: LocalizedError, Equatable {
    case authorizationNotDetermined
    case authorizationUnknown
    case audioSession(String)
    case audioEngine(String)

    var errorDescription: String? {
        switch self {
        case .authorizationNotDetermined: "Izin Speech Recognition belum ditentukan."
        case .authorizationUnknown: "Status otorisasi Speech Recognition tidak dikenal."
        case .audioSession(let detail): "Gagal menginisialisasi AVAudioSession: \(detail)"
        case .audioEngine(let detail): "Gagal memulai AudioEngine: \(detail)"
        }
    }
}
