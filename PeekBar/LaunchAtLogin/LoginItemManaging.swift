/// Abstracts login-item (Launch at Login) registration so tests can run without touching
/// the system service.
@MainActor
protocol LoginItemManaging {
    /// `true` when `SMAppService.mainApp.status == .enabled`.
    var isEnabled: Bool { get }

    func enable() throws
    func disable() throws
}
